#!/bin/bash

: "${HEALTH_USE_PROXY:=false}"

args=()
if [[ "${HEALTH_USE_PROXY^^}" = TRUE ]]; then
  args+=("--use-proxy")
fi

function resolveServerPort() {
  if [[ ${TYPE^^} = VELOCITY ]]; then
    if [[ -f velocity.toml ]]; then
      bind="$(mc-image-helper toml-path --file=velocity.toml '.bind')"
      if [[ $bind ]]; then
        echo "${bind##*:}"
        return
      fi
    fi
    echo 25565
  else
    echo 25577
  fi
}

: "${SERVER_PORT:=$(resolveServerPort)}"

mc-monitor status --host "${HEALTH_HOST:-localhost}" --port "$SERVER_PORT" "${args[@]}"
exit $?
