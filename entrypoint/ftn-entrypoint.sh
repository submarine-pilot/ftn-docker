#!/bin/sh

ENTRYPOINTD=/etc/ftn-entrypoint.d

if [ -d "$ENTRYPOINTD" ]; then
    /bin/run-parts --regex='^.*\.sh$' "$ENTRYPOINTD"
fi

exec "$@"
