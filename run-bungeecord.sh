#!/bin/bash

BUNGEE_JAR=/usr/lib/BungeeCord.jar

if [[ ! -e $BUNGEE_JAR ]]; then
  echo "Downloading ${BUNGEE_JAR_URL:=${BUNGEE_BASE_URL}/${BUNGEE_JOB_ID:-lastStableBuild}/artifact/bootstrap/target/BungeeCord.jar}"
  if ! curl -o $BUNGEE_JAR -fsSL $BUNGEE_JAR_URL; then
    echo "ERROR: failed to download" >&2
    exit 2
  fi
fi

echo "Setting initial memory to ${INIT_MEMORY:-${MEMORY}} and max to ${MAX_MEMORY:-${MEMORY}}"
JVM_OPTS="-Xms${INIT_MEMORY:-${MEMORY}} -Xmx${MAX_MEMORY:-${MEMORY}} ${JVM_OPTS}"

exec java $JVM_OPTS -jar $BUNGEE_JAR "$@"
