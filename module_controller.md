# Module: Controller

The Controller is the orchestrator of the distributed system. Its primary
responsibilities are to act as the single source of truth for the test
configuration, manage the lifecycle of the Workers, and reduce a high-volume
stream of telemetry into a human-readable performance report.

## Data Models

The Controller requires structures to track active workers and a stateful
accumulator for the metrics flowing back from the edge.

### Data Definitions

```go {name="module_controller_datamodels"}
type Transport interface {
	SendTask(workerId string, config ProfileConfig) error
	ReceiveMetrics() <-chan Metrics
}

type Controller struct {
	Config     ProfileConfig
	Workers    map[string]WorkerProxy
	Aggregator *ResultAggregator
	Transport  Transport
	Lock       sync.RWMutex
}

type WorkerProxy struct {
	Id       string
	Endpoint string 
	Status   string 
}

type ResultAggregator struct {
	Latencies    []time.Duration
	StatusCounts map[int]int
	TotalBytes   int64
	ErrorCounts  map[string]int
	StartTime    time.Time
}
```

### Invariants

* **Worker Threshold:** A test cannot start until at least one worker has
  successfully registered and responded to a heartbeat.

* **Uniform Configuration:** Every worker must receive the exact same
  `ProfileConfig` version to ensure data integrity during aggregation.

* **Monotonic Time:** The `StartTime` must be captured only when the first
  worker signals it has begun firing requests, not when the controller process
  starts.

```go {name="module_controller_invariants"}
func (c *Controller) CanStart() bool {
	c.Lock.RLock()
	defer c.Lock.RUnlock()
	return len(c.Workers) > 0 && c.Config.BaseUrl != ""
}
```

---

## Algorithm

The controller operates as a fan-out/fan-in engine.

### Pre-processing

First, we prepare the data for the operation. This involves reading the
configuration from a file (or environment variable) and opening a listener port.

```go {name="module_controller_preprocessing"}
func (c *Controller) LoadConfig(path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}

	return json.Unmarshal(data, &c.Config)
}

func (c *Controller) RegisterWorker(worker WorkerProxy) {
	c.Lock.Lock()
	defer c.Lock.Unlock()

	c.Workers[worker.Id] = worker
	slog.Info("worker_registered", 
        slog.String("worker", worker.Id), 
        slog.String("endpoint", worker.Endpoint),
    )
}
```

### Processing

This is the heart of the algorithm. The controller broadcasts the
`ProfileConfig` to all workers and then enters a "Collection" loop. It must be
able to handle asynchronous metric packets without bottlenecking the workers.

```go {name="module_controller_processing"}
func (c *Controller) RunTest(ctx context.Context) {
	// Fan-out: Tell all workers to start
	for id := range c.Workers {
		go func(workerId string) {
			if err := c.Transport.SendTask(workerId, c.Config); err != nil {
				slog.Error("worker_failed", 
                    slog.String("worker", workerId), 
                    slog.String("error", err.Error()),
                )
			}
		}(id)
	}

	c.Aggregator.StartTime = time.Now()

	// Fan-in: Listen for metrics
	metrics := c.Transport.ReceiveMetrics()

	for {
		select {
		case <-ctx.Done():
			return
		case metric, ok := <-metrics:
			if !ok {
				return
			}

			c.Aggregator.Record(metric)
		}
	}
}

func (a *ResultAggregator) Record(m Metrics) {
	a.Latencies = append(a.Latencies, m.Latency)
	a.StatusCounts[m.StatusCode]++
	a.TotalBytes += m.BytesReceived

	if m.Error != "" {
		a.ErrorCounts[m.Error]++
	}
}
```

### Post-processing

Cleanup and return. Once the duration is met or the context is cancelled, the
controller sorts the collected latencies to calculate percentiles and generates
the final JSON report.

```go {name="module_controller_postprocessing"}
func (c *Controller) GenerateReport() AggregatedReport {
	sort.Slice(c.Aggregator.Latencies, func(i, j int) bool {
		return c.Aggregator.Latencies[i] < c.Aggregator.Latencies[j]
	})

	var p95 time.Duration
	if len(c.Aggregator.Latencies) > 0 {
		p95Index := int(float64(len(c.Aggregator.Latencies)) * 0.95)
		p95 = c.Aggregator.Latencies[p95Index]
	}

	return AggregatedReport{
		TotalRequests: len(c.Aggregator.Latencies),
		P95Latency:    p95,
		StatusCounts:  c.Aggregator.StatusCounts,
		SuccessRate:   calculateSuccess(c.Aggregator.StatusCounts),
	}
}

func calculateSuccess(counts map[int]int) float64 {
	total := 0
	success := 0

	for code, count := range counts {
		total += count
		if code >= 200 && code < 300 {
			success += count
		}
	}

	if total == 0 {
		return 0
	}

	return float64(success) / float64(total)
}
```

### Entry Point

The entry point for the module handles the initialization of the controller.

```go {name="module_controller_entrypoint"}
func NewController(transport Transport) *Controller {
	return &Controller{
		Workers:   make(map[string]WorkerProxy),
		Transport: transport,
		Aggregator: &ResultAggregator{
			StatusCounts: make(map[int]int),
			ErrorCounts:  make(map[string]int),
		},
	}
}
```

### Full Algorithm Implementation

We assemble the chunks into the final function.

```go {name="module_controller_algorithm"}
// ┌─────────────────────────────────┐
// │ PREPROCESSING                   │
// └─────────────────────────────────┘

{{include "module_controller_preprocessing"}}

// ┌─────────────────────────────────┐
// │ PROCESSING                      │
// └─────────────────────────────────┘

{{include "module_controller_processing"}}

// ┌─────────────────────────────────┐
// │ POSTPROCESSING                  │
// └─────────────────────────────────┘

{{include "module_controller_postprocessing"}}

// ┌─────────────────────────────────┐
// │ MODULE ENTRY POINT              │
// └─────────────────────────────────┘

{{include "module_controller_entrypoint"}}
```

## Source File

```go {name="module_controller_source" filename="module_controller.go"}
{{include "file_header"}}

import (
	"context"
    "encoding/json"
	"log/slog"
	"os"
	"sort"
	"sync"
	"time"
)

// ╔════════════════════════════════════════════════════════════════════╗
// ║ DATA MODELS                                                        ║
// ╚════════════════════════════════════════════════════════════════════╝

{{include "module_controller_datamodels"}}

// ╔════════════════════════════════════════════════════════════════════╗
// ║ DATA VALIDATION                                                    ║
// ╚════════════════════════════════════════════════════════════════════╝

{{include "module_controller_invariants"}}

// ╔════════════════════════════════════════════════════════════════════╗
// ║ ALGORITHM                                                          ║
// ╚════════════════════════════════════════════════════════════════════╝

{{include "module_controller_algorithm"}}
```

## Testing

To validate the module in isolation we should create test code. This code
should not be part of the main application but rather a build step to help
catch bugs in development early.

### Test Case : Config Loading

This test ensures that the configuration can be loaded correctly.

```go {name="module_controller_config_test"}
// ╔════════════════════════════════════════════════════════════════════╗
// ║ TEST CONFIG LOADING                                                ║
// ╚════════════════════════════════════════════════════════════════════╝

func TestLoadConfig(t *testing.T) {
	configContent := `{
        "base_url": "http://example.com",
        "requests_per_second": 100,
        "duration_second": 60,
        "endpoints": [
            {
                "path": "/api/v1/users",
                "method": "GET",
                "weight": 1
            }
        ]
    }
`
	tmpfile, err := os.CreateTemp("", "config.json")
	assert.NoError(t, err)
	defer os.Remove(tmpfile.Name())

	_, err = tmpfile.Write([]byte(configContent))
	assert.NoError(t, err)
	tmpfile.Close()

	// Test loading
	c := NewController(nil)
	err = c.LoadConfig(tmpfile.Name())
	assert.NoError(t, err)
	assert.Equal(t, "http://example.com", c.Config.BaseUrl)
	assert.Equal(t, 100, c.Config.RequestsPerSecond)
}
```

### Test Case : Report Generation

This test ensures that the report generation logic correctly aggregates
metrics.

```go {name="module_controller_report_test"}
// ╔════════════════════════════════════════════════════════════════════╗
// ║ TEST REPORT GENERATION                                             ║
// ╚════════════════════════════════════════════════════════════════════╝

func TestGenerateReport(t *testing.T) {
	c := NewController(nil)
	
	// Simulate some metrics
	metrics := []Metrics{
		{Latency: 10 * time.Millisecond, StatusCode: 200},
		{Latency: 20 * time.Millisecond, StatusCode: 200},
		{Latency: 30 * time.Millisecond, StatusCode: 500},
		{Latency: 100 * time.Millisecond, StatusCode: 200},
	}

	for _, m := range metrics {
		c.Aggregator.Record(m)
	}

	report := c.GenerateReport()

	assert.Equal(t, 4, report.TotalRequests)
	assert.Equal(t, 0.75, report.SuccessRate)
	assert.Equal(t, 100*time.Millisecond, report.P95Latency) 
	assert.Equal(t, 3, report.StatusCounts[200])
	assert.Equal(t, 1, report.StatusCounts[500])
}
```

### Test Case : Controller Workflow

This test verifies the controller's main loop with a mock transport.

```go {name="module_controller_workflow_test"}
// ╔════════════════════════════════════════════════════════════════════╗
// ║ TEST CONTROLLER WORKFLOW                                           ║
// ╚════════════════════════════════════════════════════════════════════╝

type MockTransport struct {
	SentTasks map[string]ProfileConfig
	Metrics   chan Metrics
}

func (m *MockTransport) SendTask(workerId string, config ProfileConfig) error {
	m.SentTasks[workerId] = config
	return nil
}

func (m *MockTransport) ReceiveMetrics() <-chan Metrics {
	return m.Metrics
}

func TestControllerWorkflow(t *testing.T) {
	transport := &MockTransport{
		SentTasks: make(map[string]ProfileConfig),
		Metrics:   make(chan Metrics, 10),
	}
	
	c := NewController(transport)
	c.RegisterWorker(WorkerProxy{Id: "worker-1", Status: "Idle"})
	c.Config = ProfileConfig{BaseUrl: "http://test.com"}

	ctx, cancel := context.WithCancel(context.Background())
	
	// Start controller in background
	go c.RunTest(ctx)

	// Verify task sent
	time.Sleep(10 * time.Millisecond) // Allow goroutine to run
	assert.Contains(t, transport.SentTasks, "worker-1")

	// Send metrics
	transport.Metrics <- Metrics{Latency: 50 * time.Millisecond, StatusCode: 200}
	
	// Wait a bit and cancel
	time.Sleep(10 * time.Millisecond)
	cancel()

	// Check results
	report := c.GenerateReport()
	assert.Equal(t, 1, report.TotalRequests)
	assert.Equal(t, 50*time.Millisecond, report.P95Latency)
}
```

### Test Source File

```go {name="module_controller_test" filename="module_controller_test.go"}
{{include "file_header"}}

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

{{include "module_controller_config_test"}}

{{include "module_controller_report_test"}}

{{include "module_controller_workflow_test"}}
```
