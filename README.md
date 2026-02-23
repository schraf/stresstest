# stresstest

A Go package for facilitating stress tests on REST APIs.

## Context

Currently, development lifecycles typically heavily emphasize functional
testing—ensuring that an endpoint returns the correct data given a specific
input. However, in a production environment, APIs do not operate in a vacuum.
They are subjected to concurrent requests, network latency, database
contention, and fluctuating infrastructure resources.

Historically, performance and stress testing have been treated as an
afterthought—typically relegated to the final stages of a release cycle (e.g.,
in a pre-production staging environment) or skipped entirely until a scaling
issue occurs in production.

### Problem Statement

By deferring stress testing to the late stages of the software development
lifecycle or omitting it entirely, we expose our systems to significant
reliability risks. The lack of proactive, continuous stress testing *during*
development leads to the following critical issues:

* **Late Discovery of Bottlenecks:** Performance flaws—such as memory leaks,
  inefficient database queries, thread pool exhaustion, and race conditions—are
  often only discovered in production under heavy load.

* **Reactive and Expensive Fixes:** Resolving architectural bottlenecks after a
  service has been deployed to production is exponentially more expensive and
  time-consuming than fixing them during active development. It often requires
  emergency hotfixes, rollbacks, or hasty infrastructure scaling.

* **Unpredictable Degradation:** Without establishing a baseline for how an API
  degrades under extreme stress, we cannot guarantee system stability, define
  accurate Service Level Agreements (SLAs), or implement effective circuit
  breakers and rate limits.

* **Development Blind Spots:** Engineers lack immediate feedback on how their
  code changes impact the overall throughput and latency of the service,
  leading to accidental regressions in system performance.

### Scope

This initiative focuses on performance testing, specifically targeting backend
API services during active development, integration, and pre-production phases.

**In-Scope:**

* **Critical Path APIs:** Identification and automated stress testing of
  high-traffic, mission-critical API endpoints 

* **Metrics & Observability:** Connecting test runs with existing
  Application Performance Monitoring (APM) tools to track crucial system
  metrics during load, including p95/p99 latency, throughput (RPS), error
  rates, database locks, and infrastructure resource utilization (CPU/Memory).

* **Data Seeding & Teardown:** Automated scripts to generate, utilize, and
  clean up test data required for executing heavy concurrent loads safely.

**Out-of-Scope:**

* **Frontend / UI Load Testing:** Testing browser rendering performance or
  simulating user clicks in the UI. This framework strictly targets backend API
  request/response cycles.

* **Third-Party Services:** Executing stress tests against external
  dependencies (e.g., payment gateways, external SaaS APIs). Third-party
  endpoints will be mocked to simulate their latency and failure rates without
  violating their terms of service.

* **Chaos Engineering:** Randomly terminating instances, dropping network
  packets, or simulating full availability zone outages. While related to
  reliability, chaos engineering requires a separate strategic approach.

* **Production Load Testing:** Running maximum capacity "stress-to-break" tests
  against live production environments. This solution is scoped specifically to
  pre-production environments to catch regressions *before* they reach the
  customer.

## Literate Programming

This project is written using **Literate Programming**. The documentation and
code are interleaved in Markdown files. The goal is to treat the code as a
piece of literature—a technical essay where the code is merely the illustration
of the thought process.

## License

This project is licensed under the MIT.

```{name="LICENSE" filename="LICENSE"}
MIT License

Copyright (c) 2026 Marc Schraffenberger

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Code Header

Every generated source file should include a standard header with copyright and
license information. We define this header once here and include it in all our
source files.

```{name="file_header"}
// ╔════════════════════════════════════════════════════════════════════╗
// ║ Copyright (c) 2026 Marc Schraffenberger.                           ║
// ║                                                                    ║
// ║ SPDX-License-Identifier: MIT                                       ║
// ║                                                                    ║
// ║ Code generated by literate; DO NOT EDIT.                           ║
// ╚════════════════════════════════════════════════════════════════════╝
package stresstest
```

## Project Structure

This project follows a logical dependency chain:

-  [**Build System**](./build.md): Build system files and instructions.
-  [**Environment**](./environment.md): Configuration, Logging, and Imports.
-  [**Common**](./common.md): Common utilities and helpers.
-  [**Interface**](./interface.md): Input and Output 
-  **Modules**: The core Logic and Data Models. 
    - [**Controller**](./module_controller.md): Coordinates workers and builds final report.
    - [**Worker**](./module_worker.md): Executes the endpoints queries and reports telemetry to controller.
    - [**Transfport**](./module_transport.md): Defines the communication between controller and worker.
-  [**Orchestration**](./orchestration.md): The `main` execution entry point.
-  [**Testing**](./testing.md): Test code helpers.

