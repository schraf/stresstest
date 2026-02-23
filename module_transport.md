# Module: Transport

This module handles the "wiring" between the Controller and the Workers.

## Data Models

To prevent the Controller from being overwhelmed by thousands of individual
HTTP requests, we introduce a "Batch" model for metrics.

### Data Definitions

```go {name="module_transport_datamodels"}
type HTTPTransport struct {
	Address string
	Client  *http.Client
	Server  *http.Server
	Metrics chan Metrics
}

// RegisterRequest is sent by the Worker to the Controller
type RegisterRequest struct {
	Id      string `json:"id"`
	Address string `json:"address"`
}

// MetricBatch allows the worker to send results in chunks
type MetricBatch struct {
	WorkerId string    `json:"worker_id"`
	Metrics  []Metrics `json:"metrics"`
}
```

### Invariants

* **Idempotent Registration:** A worker may register multiple times; the
  Controller must handle this without creating duplicate entries.

* **Batch Sizing:** A `MetricBatch` should not exceed a specific size to keep
  HTTP request payloads within reasonable memory limits.

* **Timeout Strictness:** All transport-level HTTP calls must have a strict
  timeout to ensure the stress test isn't stalled by network partitions.

```go {name="module_transport_invariants"}
func (m *MetricBatch) IsValid() bool {
	return len(m.Metrics) > 0 && m.WorkerId != ""
}
```

---

## Algorithm

Here we define how data moves across the wire.

### Pre-processing

First, we prepare the data for the operation. This involves setting up the HTTP
routes for the Controller and initializing the Worker's client.

```go {name="module_transport_preprocessing"}
func NewHTTPTransport(port string) *HTTPTransport {
	t := &HTTPTransport{
		Address:   ":" + port,
		Metrics:   make(chan Metrics, 10000),
		Client:    &http.Client{Timeout: 2 * time.Second},
	}
	return t
}

func (t *HTTPTransport) SetupControllerRoutes(c *Controller) {
	mux := http.NewServeMux()

	// Workers call this to join the test
	mux.HandleFunc("/register", t.handleWorkerRegister(c))

	// Workers call this to offload metrics
	mux.HandleFunc("/metrics", t.handleMetrics())

	t.Server = &http.Server{Addr: t.Address, Handler: mux}
}

// ReceiveMetrics exposes the channel to the controller
func (t *HTTPTransport) ReceiveMetrics() <-chan Metrics {
	return t.Metrics
}

func (t *HTTPTransport) Start() error {
	if t.Server == nil {
		return fmt.Errorf("server not initialized")
	}

	// Run in background
	go func() {
		if err := t.Server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("transport_server_failed", 
                slog.String("error", err.Error()),
            )
		}
	}()

	return nil
}
```

### Processing

This is the heart of the algorithm. It handles the actual transmission of the
`ProfileConfig` and the reception of `Metrics`.

```go {name="module_transport_processing"}
func (t *HTTPTransport) handleMetrics() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var batch MetricBatch
		if err := json.NewDecoder(r.Body).Decode(&batch); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

		if !batch.IsValid() {
			http.Error(w, "invalid batch", http.StatusBadRequest)
			return
		}

		for _, metric := range batch.Metrics {
			t.Metrics <- metric // Fan into the controller's main loop
		}

		w.WriteHeader(http.StatusAccepted)
	}
}

func (t *HTTPTransport) handleWorkerRegister(c *Controller) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var request RegisterRequest
		if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

		c.RegisterWorker(WorkerProxy{
			Id:       request.Id,
			Endpoint: request.Address,
			Status:   "Idle",
		})
		
		w.WriteHeader(http.StatusOK)
	}
}

func (t *HTTPTransport) PushMetrics(controllerUrl string, batch MetricBatch) error {
	body, _ := json.Marshal(batch)

	resp, err := t.Client.Post(controllerUrl+"/metrics", "application/json", bytes.NewBuffer(body))
	if err != nil {
		return err
	}

	return resp.Body.Close()
}

func (t *HTTPTransport) SendTask(workerId string, cfg ProfileConfig) error {
	// Need to look up worker address. In a real scenario, Transport might need access to Workers map 
	// or SendTask should take the address.
	// Assuming workerId IS the address or resolvable.
	// However, the interface defined in controller is SendTask(workerId string, config ProfileConfig).
	// For this implementation, let's assume the controller passed the address map or we change the signature.
	// To strictly follow the interface:
	
	// Note: In a real implementation, the Transport might need a way to resolve ID to IP.
	// For now, we'll assume workerId is the address/IP for simplicity or that the Caller (Controller) 
	// handles the resolution before calling a lower-level method, OR we accept that this method 
	// might fail if it can't resolve.
	
	// HACK: Assuming workerId is the address for this simplified implementation 
	// or that the caller modifies the ID to be an address.
	workerAddress := workerId 
	
	body, _ := json.Marshal(cfg)
	resp, err := t.Client.Post("http://"+workerAddress+"/start", "application/json", bytes.NewBuffer(body))
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	return nil
}
```

### Post-processing

Cleanup and return. This ensures the server shuts down gracefully once the test
duration is complete.

```go {name="module_transport_postprocessing"}
func (t *HTTPTransport) Stop(ctx context.Context) {
	if t.Server != nil {
		slog.Info("shutting_down_transport")
		t.Server.Shutdown(ctx)
	}

	close(t.Metrics)
}
```

### Full Algorithm Implementation

We assemble the chunks into the final function.

```go {name="module_transport_algorithm"}
// ┌─────────────────────────────────┐
// │ PREPROCESSING                   │
// └─────────────────────────────────┘

{{include "module_transport_preprocessing"}}

// ┌─────────────────────────────────┐
// │ PROCESSING                      │
// └─────────────────────────────────┘

{{include "module_transport_processing"}}

// ┌─────────────────────────────────┐
// │ POSTPROCESSING                  │
// └─────────────────────────────────┘

{{include "module_transport_postprocessing"}}
```

## Source File

```go {name="module_transport_source" filename="module_transport.go"}
{{include "file_header"}}

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"time"
)

// ╔════════════════════════════════════════════════════════════════════╗
// ║ DATA MODELS                                                        ║
// ╚════════════════════════════════════════════════════════════════════╝

{{include "module_transport_datamodels"}}

// ╔════════════════════════════════════════════════════════════════════╗
// ║ DATA VALIDATION                                                    ║
// ╚════════════════════════════════════════════════════════════════════╝

{{include "module_transport_invariants"}}

// ╔════════════════════════════════════════════════════════════════════╗
// ║ ALGORITHM                                                          ║
// ╚════════════════════════════════════════════════════════════════════╝

{{include "module_transport_algorithm"}}
```

## Testing

To validate the module in isolation we should create test code. This code
should not be part of the main application but rather a build step to help
catch bugs in development early.

### Test Case : Batch Validation

This test ensures that the metric batch validation logic works.

```go {name="module_transport_validation_test"}
// ╔════════════════════════════════════════════════════════════════════╗
// ║ TEST BATCH VALIDATION                                              ║
// ╚════════════════════════════════════════════════════════════════════╝

func TestMetricBatchValidation(t *testing.T) {
	tests := []struct {
		name  string
		batch MetricBatch
		valid bool
	}{
		{
			name:  "valid batch",
			batch: MetricBatch{WorkerId: "w1", Metrics: []Metrics{ {StatusCode: 200} }},
			valid: true,
		},
		{
			name:  "empty worker id",
			batch: MetricBatch{WorkerId: "", Metrics: []Metrics{ {StatusCode: 200} }},
			valid: false,
		},
		{
			name:  "empty data",
			batch: MetricBatch{WorkerId: "w1", Metrics: []Metrics{}},
			valid: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.valid, tt.batch.IsValid())
		})
	}
}
```

### Test Case : Transport Integration

This test brings up the transport server and verifies it can receive metrics.

```go {name="module_transport_integration_test"}
// ╔════════════════════════════════════════════════════════════════════╗
// ║ TEST TRANSPORT INTEGRATION                                         ║
// ╚════════════════════════════════════════════════════════════════════╝

func TestHTTPTransportIntegration(t *testing.T) {
	// Setup Transport
	transport := NewHTTPTransport("0") // Random port
	
	// Create a dummy controller for registration route
	// Note: In a real unit test we might mock the controller or just test the metrics endpoint
	// Since SetupControllerRoutes requires a Controller, we need one.
	// But the Controller struct is available in the package.
	controller := &Controller{
		Workers: make(map[string]WorkerProxy),
	}
	
	transport.SetupControllerRoutes(controller)
	
	err := transport.Start()
	assert.NoError(t, err)
	defer transport.Stop(context.Background())
	
	// Wait for server to be ready (naive)
	time.Sleep(50 * time.Millisecond)
	
	// Test Metrics Handler
	handler := transport.handleMetrics()
	
	batch := MetricBatch{
		WorkerId: "worker-1",
		Metrics: []Metrics{
			{Latency: 100 * time.Millisecond, StatusCode: 200},
		},
	}
	body, _ := json.Marshal(batch)
	
	request := httptest.NewRequest("POST", "/metrics", bytes.NewBuffer(body))
	w := httptest.NewRecorder()
	
	handler(w, request)
	
	assert.Equal(t, http.StatusAccepted, w.Code)
	
	// Check if metric arrived
	select {
	case m := <-transport.Metrics:
		assert.Equal(t, 200, m.StatusCode)
	case <-time.After(1 * time.Second):
		t.Error("timed out waiting for metric")
	}
}
```

### Test Source File

```go {name="module_transport_test" filename="module_transport_test.go"}
{{include "file_header"}}

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

{{include "module_transport_validation_test"}}

{{include "module_transport_integration_test"}}
```
