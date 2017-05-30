#!/bin/bash

BUNGEE_JAR=$BUNGEE_HOME/BungeeCord.jar

if [[ ! -e $BUNGEE_JAR ]]; then
  echo "Downloading ${BUNGEE_JAR_URL:=${BUNGEE_BASE_URL}/${BUNGEE_JOB_ID:-lastStableBuild}/artifact/bootstrap/target/BungeeCord.jar}"
  if ! curl -o $BUNGEE_JAR -fsSL $BUNGEE_JAR_URL; then
    echo "ERROR: failed to download" >&2
    exit 2
  fi
fi

echo "Setting initial memory to ${INIT_MEMORY:-${MEMORY}} and max to ${MAX_MEMORY:-${MEMORY}}"
JVM_OPTS="-Xms${INIT_MEMORY:-${MEMORY}} -Xmx${MAX_MEMORY:-${MEMORY}} ${JVM_OPTS}"

userAddArgs=
if [[ -n $UID ]]; then
  userAddArgs="$userAddArgs --uid $UID"
fi
if [[ -n $GID ]]; then
  userAddArgs="$userAddArgs --gid $GID"
fi

if [[ -n $UID ]]; then
  useradd --home-dir=$BUNGEE_HOME --no-create-home $userAddArgs bungeecord
  chown -R bungeecord: $BUNGEE_HOME
  runuser -u bungeecord /usr/bin/java -- $JVM_OPTS -jar $BUNGEE_JAR "$@"
else
  exec java $JVM_OPTS -jar $BUNGEE_JAR "$@"
fi
