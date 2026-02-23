#!/bin/sh

LITERATE_BIN="$(go env GOPATH)/bin/literate"

if [ ! -f "$LITERATE_BIN" ]; then
    curl -fsSL https://raw.githubusercontent.com/schraf/literate/main/install.sh | bash
fi

"$LITERATE_BIN" build.md

