# Module: Testing

This document describes the testing strategy, including unit tests and
integration tests for the module.

## Test Preamble

This is the preamble code that should be placed at the top of each test file.
It will include the needed scaffolding that all test code will need.

```go {name="test_preamble"}
```

## Test Helpers

Helper functions and mocks used to support the test cases. This corresponds to
the **"Support"** logic of your tests.

### Helper Definitions

```go {name="test_helpers"}
```

### Source File

```go {name="test_source" filename="test_helpers.go"}
{{include "file_header"}}

{{include "test_preamble"}}

// ╔════════════════════════════════════════════════════════════════════╗
// ║ TEST HELPERS                                                       ║
// ╚════════════════════════════════════════════════════════════════════╝

{{include "test_helpers"}}
```
