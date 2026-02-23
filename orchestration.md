# Orchestration

This is the conclusion of the document. It ties everything together.

## Main Execution

The `main()` function is the high-level script that calls the loaders, runs the
algorithms, and saves the output.

```{name="main_execution"}
func main() {

	// ╔════════════════════════════════════════════════════════════════════╗
	// ║ Parse command line arguments                                       ║
	// ╚════════════════════════════════════════════════════════════════════╝

	var options struct {
	    Mode          string
	    Port          string
	    ConfigPath    string
	    ControllerUrl string
	    WorkerId      string
	}

    flag.StringVar(&options.Mode, "mode", "worker", "Run as 'controller' or 'worker'")
    flag.StringVar(&options.Port, "port", "8080", "Port to listen on")
    flag.StringVar(&options.ConfigPath, "config", "config.json", "Path to load test config (Controller only)")
    flag.StringVar(&options.ControllerUrl, "controller-url", "localhost", "URL of the controller (Worker only)")
    flag.StringVar(&options.WorkerId, "id", "worker-"+uuid.NewString()[:8], "Unique ID for this worker")
    
    flag.Parse()

	// ╔════════════════════════════════════════════════════════════════════╗
	// ║ Validate options                                                   ║
	// ╚════════════════════════════════════════════════════════════════════╝

	if options.Mode != "controller" && options.Mode != "worker" {
        log.Fatalf("Invalid mode: '%s'. Must be 'controller' or 'worker'", options.Mode)
    }

    if options.Mode == "worker" && options.ControllerUrl == "" {
        log.Fatal("Worker mode requires --controller-url")
    }
    
	// ╔════════════════════════════════════════════════════════════════════╗
	// ║ Setup environment                                                  ║
	// ╚════════════════════════════════════════════════════════════════════╝

    ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
    defer cancel()

    InitializeLogging() 

	transport := NewHTTPTransport(options.Port)
	defer transport.Stop(ctx)

	// ╔════════════════════════════════════════════════════════════════════╗
	// ║ Run the controller/worker                                          ║
	// ╚════════════════════════════════════════════════════════════════════╝

	switch options.Mode {
	case "controller":
	case "worker":
	}
}
```

## Source File

```go {name="main" filename="main.go"}
{{include "file_header"}}

import (
	"context"
	"flag"
    "log"
	"os"
	"os/signal"
	"syscall"

	"github.com/google/uuid"
)

// ╔════════════════════════════════════════════════════════════════════╗
// ║ MAIN                                                               ║
// ╚════════════════════════════════════════════════════════════════════╝

{{include "main_execution"}}
```
