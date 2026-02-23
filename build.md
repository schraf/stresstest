# Build System

To build this project, we use a `Makefile` to orchestrate the build steps. The
build process relies on the [literate](https://github.com/schraf/literate) tool
to generate the source code from these Markdown files.

## Bootstrap

In order to create the initial Build System files we use a `bootstrap.sh` shell
script to download, build, and install the `literate` tool. We then run the
literate tool on the `build.md` file to create the build system.

## Dependencies

We provide a convenient way to install the `literate` tool using a shell script.

```makefile {name="makefile" filename="Makefile"}
MARKDOWN_SRC := $(wildcard *.md)

.PHONY: all build clean deps test

all: build test

deps:
	curl -fsSL https://raw.githubusercontent.com/schraf/literate/main/install.sh | bash

generate: $(MARKDOWN_SRC)
	$$(go env GOPATH)/bin/literate $(MARKDOWN_SRC)
	go mod tidy
	go fmt ./...

build: generate
	go build ./...

test: build
	go vet ./...
	go test ./...

clean:
	rm -f *.go stresstest

distclean: clean
	rm -f go.mod go.sum Makefile LICENSE
```

