# Module: Worker

This module represents the core execution engine of the stress test. While the
Controller acts as the brain, the Worker is the muscle—responsible for
generating high-frequency outbound traffic and capturing high-fidelity timing
data without introducing significant overhead.

## Data Models

We define our data structures early so the reader understands the objects 
being manipulated.

### Data Definitions

```go {name="module_worker_datamodels"}
type Worker struct {
    id           string
    client       *http.Client
    metricSink   chan Metrics
    config       ProfileConfig
    logger       *slog.Logger
    weightedPool []int 
}
```

### Invariants

Explain the rules of your data.

- **RPS Bound**: The RequestsPerSecond must be a positive integer. If it is 0, the worker will remain idle.

- **BaseUrl Validity**: The BaseUrl must include a valid scheme (http:// or https://).

- **Weight Sum**: The total Weight of all endpoints in a LoadProfile must be greater than 0 to ensure the selection algorithm doesn't enter an infinite loop.

- **Duration Seconds**: The duration of the test must be greater than 0.

- **Endpoints**: The config must contain at least one test endpoint.

```go {name="module_worker_invariants"}
func (w *Worker) ValidateConfig() error {
    var err error

    if w.config.RequestsPerSecond <= 0 {
        err = errors.Join(err, InvalidConfigError("RequestsPerSecond", "must be greater than zero"))
    }

    if w.config.BaseUrl == "" {
        err = errors.Join(err, InvalidConfigError("BaseUrl", "cannot be empty"))
    }

    if w.config.DurationSeconds <= 0 {
        err = errors.Join(err, InvalidConfigError("DurationSeconds", "must be greater than zero"))
    }

    if len(w.config.Endpoints) == 0 {
        err = errors.Join(err, InvalidConfigError("Endpoints", "must contain at least one"))
    }

    return err
}
```

## Algorithm

This section explains how the worker translates a configuration into a storm of
requests while maintaining precision.

### Pre-processing

First, we prepare the data for the operation. This includes tuning the
http.Client for high-concurrency (otherwise, we'd run out of file descriptors
or hit connection pool limits) and pre-calculating the weighted distribution of
endpoints.

```go {name="module_worker_preprocessing"}
func (w *Worker) Prepare() {
    w.logger.Info("preparing_worker")

    // Tune the transport for high-load
    transport := &http.Transport{
        MaxIdleConns:        1000,
        MaxIdleConnsPerHost: 500,
        IdleConnTimeout:     30 * time.Second,
    }

    w.client = &http.Client{Transport: transport, Timeout: 10 * time.Second}

    // Pre-calculate endpoint weight distribution to keep the "Processing" loop fast
    for index, endpoint := range w.config.Endpoints {
        for weight := 0; weight < endpoint.Weight; weight++ {
            w.weightedPool = append(w.weightedPool, index)
        }
    }
}
```

### Processing

This is the heart of the algorithm. We use a `time.Ticker` to maintain the
pace.  For every "tick," we launch a goroutine to handle the request. This
prevents a slow API response from "blocking" the worker and causing the RPS to
drop.

```go {name="module_worker_processing"}
func (w *Worker) Run(ctx context.Context) {
    interval := time.Second / time.Duration(w.config.RequestsPerSecond)
    ticker := time.NewTicker(interval)
    defer ticker.Stop()

    w.logger.Info("running_worker")

    for {
        select {
        case <-ctx.Done():
            return
        case <-ticker.C:
            // Pick an endpoint based on weight
            index := w.weightedPool[rand.Intn(len(w.weightedPool))]
            endpoint := w.config.Endpoints[index]

            // Fire off the request in a goroutine
            go w.executeRequest(endpoint)
        }
    }
}

func (w *Worker) executeRequest(endpoint EndpointConfig) {
    start := time.Now()
    url := w.config.BaseUrl + endpoint.Path
    
    request, _ := http.NewRequest(endpoint.Method.String(), url, bytes.NewBuffer(endpoint.Body))
    for key, value := range endpoint.Headers {
        request.Header.Set(key, value)
    }

    response, err := w.client.Do(request)
    
    metrics := Metrics{
        Timestamp: start,
        Latency:   time.Since(start),
    }

    if err != nil {
        metrics.Error = err.Error()
    } else {
        metrics.StatusCode = response.StatusCode
        metrics.BytesReceived = response.ContentLength
        response.Body.Close()
    }

    // Stream the result back to the Controller
    w.metricSink <- metrics
}
```

### Post-processing

Cleanup and return. This ensures that we don't terminate the worker before the
final metrics have been flushed to the transport layer.

```go {name="module_worker_postprocessing"}
func (w *Worker) Teardown() {
    close(w.metricSink)

    w.logger.Info("worker_shutdown")
}
```

### Entry Point

The entry point for the module should handle the full life-cycle of the
algorithm from the creation of the data models to tearing down and reporting
results.

```go {name="module_worker_entrypoint"}
func RunWorker(ctx context.Context, name string, config ProfileConfig) (<-chan Metrics, error) {
    metrics := make(chan Metrics)

    worker := Worker{
        id:           name,
        metricSink:   metrics,
        config:       config,
        logger:       slog.With("worker", name),
    }

    worker.logger.Info("created_worker")

    if err := worker.ValidateConfig(); err != nil {
        worker.logger.Error("validation_failed",
            slog.String("error", err.Error()),
        )

        worker.Teardown()

        return nil, fmt.Errorf("worker validation failed: %w", err)
    }

    go func() {
        worker.Prepare()
        worker.Run(ctx)
        worker.Teardown()
    }()

    return metrics, nil
}
```

### Full Algorithm Implementation

We assemble the chunks into the final function.

```go {name="module_worker_algorithm"}
// ┌─────────────────────────────────┐
// │ PREPROCESSING                   │
// └─────────────────────────────────┘

{{include "module_worker_preprocessing"}}

// ┌─────────────────────────────────┐
// │ PROCESSING                      │
// └─────────────────────────────────┘

{{include "module_worker_processing"}}

// ┌─────────────────────────────────┐
// │ POSTPROCESSING                  │
// └─────────────────────────────────┘

{{include "module_worker_postprocessing"}}

// ┌─────────────────────────────────┐
// │ MODULE ENTRY POINT              │
// └─────────────────────────────────┘

{{include "module_worker_entrypoint"}}
```

## Source File

```go {name="module_worker_source" filename="module_worker.go"}
{{include "file_header"}}

import (
	"bytes"
	"context"
	"errors"
    "fmt"
	"log/slog"
	"math/rand"
	"net/http"
	"time"
)

// ╔════════════════════════════════════════════════════════════════════╗
// ║ DATA MODELS                                                        ║
// ╚════════════════════════════════════════════════════════════════════╝

{{include "module_worker_datamodels"}}

// ╔════════════════════════════════════════════════════════════════════╗
// ║ DATA VALIDATION                                                    ║
// ╚════════════════════════════════════════════════════════════════════╝

{{include "module_worker_invariants"}}

// ╔════════════════════════════════════════════════════════════════════╗
// ║ ALGORITHM                                                          ║
// ╚════════════════════════════════════════════════════════════════════╝

{{include "module_worker_algorithm"}}
```

## Testing

To validate the module in isolation we should create test code. This code
should not be part of the main application but rather a build step to help
catch bugs in development early.

### Test Case : Config Validation

This test case ensures that the invariant cases for the worker config is
correct.

```go {name="module_worker_config_validation"}
// ╔════════════════════════════════════════════════════════════════════╗
// ║ TEST CONFIG VALIDATION                                             ║
// ╚════════════════════════════════════════════════════════════════════╝

func TestWorkerConfigValidation(t *testing.T) {
    valid := ProfileConfig{
        BaseUrl: "http://example.com/v1",
        RequestsPerSecond: 1,
        DurationSeconds: 1,
        Endpoints: []EndpointConfig{
            {
                Path: "/endpoint1",
                Method: "GET",
                Weight: 1,
            },
        },
    }

    tests := []struct{
        name            string
        modify          func(c *ProfileConfig)
        hasError        bool
        invalidVariable string
    }{
        {
            name:     "valid config",
            modify:   func(c *ProfileConfig) {}, 
            hasError: false, 
        },
        {
            name:            "invalid BaseUrl",
            modify:          func(c *ProfileConfig) { c.BaseUrl = "" },
            hasError:        true,
            invalidVariable: "BaseUrl",
        },
        {
            name:            "invalid RequestsPerSecond",
            modify:          func(c *ProfileConfig) { c.RequestsPerSecond = 0 },
            hasError:        true,
            invalidVariable: "RequestsPerSecond",
        },
        {
            name:            "invalid DurationSeconds",
            modify:          func(c *ProfileConfig) { c.DurationSeconds = 0 },
            hasError:        true,
            invalidVariable: "DurationSeconds",
        },
        {
            name:            "invalid Endpoints",
            modify:          func(c *ProfileConfig) { c.Endpoints = nil },
            hasError:        true,
            invalidVariable: "Endpoints",
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            config := valid
            tt.modify(&config)

            worker := Worker{config: config}
            err := worker.ValidateConfig()

            if tt.hasError {
                if assert.Error(t, err) {
                    var target *ErrInvalidConfig

                    if assert.ErrorAs(t, err, &target) {
                        assert.Equal(t, tt.invalidVariable, target.VariableName)
                    }
                }
            } else {
                assert.NoError(t, err)
            }
        })
    }
}
```

### Test Case : Worker Run

This test ensures that the worker can be started, executes a request against a
mock server, and returns metrics before the context is cancelled.

```go {name="module_worker_run"}
// ╔════════════════════════════════════════════════════════════════════╗
// ║ TEST WORKER RUN                                                    ║
// ╚════════════════════════════════════════════════════════════════════╝

func TestWorkerRun(t *testing.T) {
    // Start a local HTTP server
    server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
    }))
    defer server.Close()

    config := ProfileConfig{
        BaseUrl: server.URL,
        RequestsPerSecond: 10,
        DurationSeconds: 1,
        Endpoints: []EndpointConfig{
            {
                Path: "/",
                Method: "GET",
                Weight: 1,
            },
        },
    }

    ctx, cancel := context.WithTimeout(context.Background(), 200*time.Millisecond)
    defer cancel()

    metricsChan, err := RunWorker(ctx, "test-worker", config)
    assert.NoError(t, err)

    select {
    case metric, ok := <-metricsChan:
        if ok {
            assert.Equal(t, http.StatusOK, metric.StatusCode)
            assert.NotZero(t, metric.Latency)
        } else {
            t.Error("expected at least one metric, but channel was closed")
        }
    case <-time.After(1 * time.Second):
        t.Error("timeout waiting for metric")
    }
}
```

### Test Source File

```go {name="module_worker_test" filename="module_worker_test.go"}
{{include "file_header"}}

import (
    "context"
    "net/http"
    "net/http/httptest"
    "testing"
    "time"

	"github.com/stretchr/testify/assert"
)

{{include "module_worker_config_validation"}}

{{include "module_worker_run"}}
```

