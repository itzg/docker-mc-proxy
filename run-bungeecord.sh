#!/bin/bash

BUNGEE_JAR=$BUNGEE_HOME/BungeeCord.jar

if [[ ! -e $BUNGEE_JAR ]]; then
    echo "Downloading ${BUNGEE_JAR_URL:=${BUNGEE_BASE_URL}/${BUNGEE_JOB_ID:-lastStableBuild}/artifact/bootstrap/target/BungeeCord.jar}"
    if ! curl -o $BUNGEE_JAR -fsSL $BUNGEE_JAR_URL; then
        echo "ERROR: failed to download" >&2
        exit 2
    fi
fi

if [ -d /plugins ]; then
    echo "Copying BungeeCord plugins over..."
    cp -r /plugins $BUNGEE_HOME
fi
  
echo "Setting initial memory to ${INIT_MEMORY:-${MEMORY}} and max to ${MAX_MEMORY:-${MEMORY}}"
JVM_OPTS="-Xms${INIT_MEMORY:-${MEMORY}} -Xmx${MAX_MEMORY:-${MEMORY}} ${JVM_OPTS}"

if [[ -n "$UID" ]]; then
    #    -h DIR          Home directory
    #    -G GRP          Add user to existing group
    #    -S              Create a system user
    #    -D              Don't assign a password
    #    -H              Don't create home directory
    #    -u UID          User id
    #    -k SKEL         Skeleton directory (/etc/skel)
    userAddArgs="-D -S -H -u $UID"

    if [[ -n "$GID" ]]; then
        userAddArgs="$userAddArgs -g $GID"
        addgroup -g ${GID} bungeecord
    fi

    adduser -h ${BUNGEE_HOME} ${userAddArgs} bungeecord

    chown -R bungeecord: ${BUNGEE_HOME}
    sudo -u bungeecord java -- ${JVM_OPTS} -jar $BUNGEE_JAR "$@"
else
    exec java $JVM_OPTS -jar $BUNGEE_JAR "$@"
fi
