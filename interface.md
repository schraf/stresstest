# Interface

Now that we have defined the environment and common tools, we define how data
enters and leaves the system. The inputs for our package will be configurations
that define the stress tests to perform and the outputs will be our telemetry
data gathered during the test.

## Inputs

First, we need to define what a "test" actually looks like. This should be
serializable (JSON) so the controller can read it and pass it to workers.

```{name="interface_inputs"}
type Method string

const (
    GET    Method = "GET"
    POST   Method = "POST"
    PUT    Method = "PUT"
    DELETE Method = "DELETE"
)

func (m Method) String() string {
    return string(m)
}

type EndpointConfig struct {
    Path    string            `json:"path"`
    Method  Method            `json:"method"`
    Headers map[string]string `json:"headers"`
    Body    []byte            `json:"body"`
    Weight  int               `json:"weight"` // Relative frequency vs other endpoints
}

type ProfileConfig struct {
    BaseUrl           string           `json:"base_url"`
    RequestsPerSecond int              `json:"requests_per_second"`
    DurationSeconds   int              `json:"duration_second"`
    Endpoints         []EndpointConfig `json:"endpoints"`
}
```

## Outputs

To aggregate data efficiently, workers should return small, summarized packets
of data rather than raw logs. These `Metric` payloads will be aggregated into a
final report.

```{name="interface_outputs"}
type Metrics struct {
    Timestamp     time.Time     `json:"timestamp"`
    Latency       time.Duration `json:"latency"`
    StatusCode    int           `json:"status"`
    Error         string        `json:"error,omitempty"`
    BytesReceived int64         `json:"bytes"`
}

// AggregatedReport is what the Controller generates at the end
type AggregatedReport struct {
    TotalRequests int            `json:"total_requests"`
    P95Latency    time.Duration  `json:"p95"`
    SuccessRate   float64        `json:"success_rate"`
    StatusCounts  map[int]int    `json:"status_counts"`
}
```

## Source File

```go {name="interface" filename="interface.go"}
{{include "file_header"}}

import (
    "time"
)

// ╔════════════════════════════════════════════════════════════════════╗
// ║ INPUTS                                                             ║
// ╚════════════════════════════════════════════════════════════════════╝

{{include "interface_inputs"}}

// ╔════════════════════════════════════════════════════════════════════╗
// ║ OUTPUTS                                                            ║
// ╚════════════════════════════════════════════════════════════════════╝

{{include "interface_outputs"}}
```

