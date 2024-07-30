#!/bin/bash

set -euo pipefail

if id ubuntu > /dev/null 2>&1; then
  deluser ubuntu
fi

addgroup --gid 1000 bungeecord

adduser --system --shell /bin/false --uid 1000 --ingroup bungeecord --home /server bungeecord