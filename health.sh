#!/bin/bash

: ${HEALTH_USE_PROXY:=false}

args=()
if [[ "${HEALTH_USE_PROXY^^}" = TRUE ]]; then
  args+="--use-proxy"
fi

mc-monitor status --host ${HEALTH_HOST:-localhost} --port $SERVER_PORT ${args[@]}
exit $?
