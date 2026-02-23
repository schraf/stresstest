# Environment

This section handles package defintions, global imports, configuration, and
logging.

## Module

The go module file is require to build and properly maintain this package's
version and dependencies.

```go {name="go.mod" filename="go.mod"}
module github.com/schraf/stresstest

go 1.24.0

{{include "requirements"}}
```

## Requirements

We gather external libraries here.

* `testify` is used for our tests.

```go {name="requirements"}
require (
	github.com/stretchr/testify v1.11.1
)
```

## Global Configuration

Define constants, file paths, and hyperparameters here.

```{name="configuration"}
```

## Logging Strategy

We define our logging (log levels, formats) immediately so it is consistent for
every subsequent function.

```{name="logging"}
func InitializeLogging() {
	// Determine log level based on DEBUG environment variable
	level := slog.LevelInfo
	if os.Getenv("DEBUG") != "" {
		level = slog.LevelDebug
	}

	// Create JSON handler writing to stdout
	jsonHandler := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: level,
	})

	// Create and set the logger as default
    logger := slog.New(jsonHandler)
    slog.SetDefault(logger)
}
```

## Source File

We combine these into the environment source file.

```go {name="environment" filename="environment.go"}
{{include "file_header"}}

import (
    "log/slog"
    "os"
)

// ╔════════════════════════════════════════════════════════════════════╗
// ║ CONFIGURATION                                                      ║
// ╚════════════════════════════════════════════════════════════════════╝

{{include "configuration"}}

// ╔════════════════════════════════════════════════════════════════════╗
// ║ LOGGING                                                            ║
// ╚════════════════════════════════════════════════════════════════════╝

{{include "logging"}}
```
