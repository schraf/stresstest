# Common

These are the small helpers that don't deserve their own chapter but are
necessary for the heavy lifting. Placing them here prevents interrupting the
flow of the "good stuff" later.

## Conversion Helpers

Boring but necessary code for converting between data formats.

```go {name="common_conversions"}
```

## Generic Utilities

For errors with config types we will define a generic `ErrInvalidConfig` type
that can be used to call out the variable name and why the value was invalid.

```go {name="common_error_invalid_config"}
type ErrInvalidConfig struct {
    VariableName string
    Message string
}

func InvalidConfigError(variable string, reason string) error {
    return &ErrInvalidConfig{
        VariableName: variable,
        Message:      reason,
    }
}

func (e *ErrInvalidConfig) Error() string {
    return fmt.Sprintf("invalid config for '%s': %s", e.VariableName, e.Message)
}
```

Simple calculations or wrappers used in multiple places.

```go {name="common_utilities"}

{{include "common_error_invalid_config"}}
```

## Source File

```go {name="common" filename="common.go"}
{{include "file_header"}}

import (
    "fmt"
)

// ╔════════════════════════════════════════════════════════════════════╗
// ║ COMMON CONVERSION FUNCTIONS                                        ║
// ╚════════════════════════════════════════════════════════════════════╝

{{include "common_conversions"}}

// ╔════════════════════════════════════════════════════════════════════╗
// ║ COMMON UTILITY FUNCTIONS                                           ║
// ╚════════════════════════════════════════════════════════════════════╝

{{include "common_utilities"}}
```
