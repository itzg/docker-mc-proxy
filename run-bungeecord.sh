#!/bin/bash

: "${TYPE:=BUNGEECORD}"
: "${RCON_JAR_VERSION:=1.0.0}"
: "${RCON_VELOCITY_JAR_VERSION:=1.0}"
: "${ENV_VARIABLE_PREFIX:=CFG_}"
: "${SPIGET_PLUGINS:=}"
: "${NETWORKADDRESS_CACHE_TTL:=60}"
: "${INIT_MEMORY:=${MEMORY}}"
: "${MAX_MEMORY:=${MEMORY}}"

BUNGEE_HOME=/server
RCON_JAR_URL=https://github.com/orblazer/bungee-rcon/releases/download/v${RCON_JAR_VERSION}/bungee-rcon-${RCON_JAR_VERSION}.jar
RCON_VELOCITY_JAR_URL=https://github.com/UnioDex/VelocityRcon/releases/download/v${RCON_VELOCITY_JAR_VERSION}/VelocityRcon.jar
download_required=true

function isTrue() {
  local value=${1,,}

  result=

  case ${value} in
  true | on)
    result=0
    ;;
  *)
    result=1
    ;;
  esac

  return ${result}
}

function isDebugging() {
  if isTrue "${DEBUG:-false}"; then
    return 0
  else
    return 1
  fi
}

function handleDebugMode() {
  if isDebugging; then
    set -x
    extraCurlArgs=(-v)
  fi
}

function log() {
  echo "[init] $*"
}

function containsJars() {
  file=${1?}

  pat='\.jar$'

  while read -r line; do
    if [[ $line =~ $pat ]]; then
      return 0
    fi
  done <<<"$(unzip -l "$file")"

  return 1
}

function getResourceFromSpiget() {
  resource=${1?}
  dest=${2?}

  log "Downloading resource ${resource} ..."

  tmpfile="/tmp/${resource}.zip"
  url="https://api.spiget.org/v2/resources/${resource}/download"
  if ! curl -o "${tmpfile}" -fsSL -H "User-Agent: itzg/minecraft-server" "${extraCurlArgs[@]}" "${url}"; then
    log "ERROR failed to download resource '${resource}' from ${url}"
    exit 2
  fi

  mkdir -p ${dest}
  if containsJars "${tmpfile}"; then
    log "Extracting contents of resource ${resource} into plugins"
    unzip -o -q -d ${dest} "${tmpfile}"
    rm "${tmpfile}"
  else
    log "Moving resource ${resource} into plugins"
    mv "${tmpfile}" "${dest}/${resource}.jar"
  fi

}

function removeOldMods {
  if [ -d "$1" ]; then
    find "$1" -mindepth 1 -maxdepth ${REMOVE_OLD_MODS_DEPTH:-16} -wholename "${REMOVE_OLD_MODS_INCLUDE:-*}" -not -wholename "${REMOVE_OLD_MODS_EXCLUDE:-}" -delete
  fi
}

handleDebugMode

log "Resolving type given ${TYPE}"
case "${TYPE^^}" in
  BUNGEECORD)
    : ${BUNGEE_BASE_URL:=https://ci.md-5.net/job/BungeeCord}
    : ${BUNGEE_JOB_ID:=lastStableBuild}
    : ${BUNGEE_JAR_URL:=${BUNGEE_BASE_URL}/${BUNGEE_JOB_ID}/artifact/bootstrap/target/BungeeCord.jar}
    : ${BUNGEE_JAR_REVISION:=${BUNGEE_JOB_ID}}
    BUNGEE_JAR=$BUNGEE_HOME/${BUNGEE_JAR:=BungeeCord-${BUNGEE_JAR_REVISION}.jar}
  ;;

  WATERFALL)
    # Doc : https://papermc.io/api
    : ${WATERFALL_VERSION:=latest}
    : ${WATERFALL_BUILD_ID:=latest}

    # Retrieve waterfall version
    if [[ ${WATERFALL_VERSION^^} = LATEST ]]; then
      WATERFALL_VERSION=$(curl -fsSL "https://papermc.io/api/v2/projects/waterfall" -H "accept: application/json" | jq -r '.versions[-1]')
      if [ -z $WATERFALL_VERSION ]; then
        echo "ERROR: failed to lookup PaperMC versions"
        exit 1
      fi
    fi

    # Retrieve waterfall build
    if [[ ${WATERFALL_BUILD_ID^^} = LATEST ]]; then
      WATERFALL_BUILD_ID=$(curl -fsSL "https://papermc.io/api/v2/projects/waterfall/versions/${WATERFALL_VERSION}" -H  "accept: application/json" \
        | jq '.builds[-1]')
      if [ -z $WATERFALL_BUILD_ID ]; then
          echo "ERROR: failed to lookup PaperMC build from version ${WATERFALL_VERSION}"
          exit 1
      fi
    fi

    WATERFALL_JAR=$(curl -fsSL "https://papermc.io/api/v2/projects/waterfall/versions/${WATERFALL_VERSION}/builds/${WATERFALL_BUILD_ID}" \
      -H  "accept: application/json" | jq -r '.downloads.application.name')
    if [ -z $WATERFALL_JAR ]; then
      echo "ERROR: failed to lookup PaperMC download file from version=${WATERFALL_VERSION} build=${WATERFALL_BUILD_ID}"
      exit 1
    fi

    BUNGEE_JAR_URL="https://papermc.io/api/v2/projects/waterfall/versions/${WATERFALL_VERSION}/builds/${WATERFALL_BUILD_ID}/downloads/${WATERFALL_JAR}"
    BUNGEE_JAR=$BUNGEE_HOME/${BUNGEE_JAR:=Waterfall-${WATERFALL_VERSION}-${WATERFALL_BUILD_ID}.jar}
  ;;

  VELOCITY)
    : ${VELOCITY_VERSION:=latest}
    BUNGEE_JAR_URL="https://versions.velocitypowered.com/download/${VELOCITY_VERSION}.jar"
    BUNGEE_JAR=$BUNGEE_HOME/Velocity-${VELOCITY_VERSION}.jar
  ;;

  CUSTOM)
    if [[ -v BUNGEE_JAR_URL ]]; then
      log "Using custom server jar at ${BUNGEE_JAR_URL} ..."
      BUNGEE_JAR=$BUNGEE_HOME/$(basename ${BUNGEE_JAR_URL})
    elif [[ -v BUNGEE_JAR_FILE ]]; then
      BUNGEE_JAR=${BUNGEE_JAR_FILE}
      download_required=false
    else
      echo "ERROR: BUNGEE_JAR_URL is not properly set to a URL or existing jar file"
      exit 2
    fi
  ;;

  *)
      echo "ERROR: Invalid type: '$TYPE'"
      echo "       Must be: BUNGEECORD, WATERFALL, VELOCITY, CUSTOM"
      exit 1
  ;;
esac

if isTrue "$download_required"; then
  if [ -f "$BUNGEE_JAR" ]; then
    zarg=(-z "$BUNGEE_JAR")
  fi
  log "Downloading ${BUNGEE_JAR_URL}"
  if ! curl -o "$BUNGEE_JAR" "${zarg[@]}" -fsSL "$BUNGEE_JAR_URL"; then
      echo "ERROR: failed to download" >&2
      exit 2
  fi
fi

if [ -d /plugins ]; then
    log "Copying BungeeCord plugins over..."
    cp -ru /plugins $BUNGEE_HOME
fi

# If supplied with a URL for a plugin download it.
if [[ "$PLUGINS" ]]; then
for i in ${PLUGINS//,/ }
do
  EFFECTIVE_PLUGIN_URL=$(curl -Ls -o /dev/null -w %{url_effective} $i)
  case "X$EFFECTIVE_PLUGIN_URL" in
    X[Hh][Tt][Tt][Pp]*.jar)
      log "Downloading plugin via HTTP"
      log "  from $EFFECTIVE_PLUGIN_URL ..."
      if ! curl -sSL -o /tmp/${EFFECTIVE_PLUGIN_URL##*/} $EFFECTIVE_PLUGIN_URL; then
        echo "ERROR: failed to download from $EFFECTIVE_PLUGIN_URL to /tmp/${EFFECTIVE_PLUGIN_URL##*/}"
        exit 2
      fi

      mkdir -p $BUNGEE_HOME/plugins
      mv /tmp/${EFFECTIVE_PLUGIN_URL##*/} "$BUNGEE_HOME/plugins/${EFFECTIVE_PLUGIN_URL##*/}"
      rm -f /tmp/${EFFECTIVE_PLUGIN_URL##*/}
      ;;
    *)
      echo "ERROR: Invalid URL given for plugin list: Must be HTTP or HTTPS and a JAR file"
      ;;
  esac
done
fi

if [[ ${SPIGET_PLUGINS} ]]; then
  if isTrue ${REMOVE_OLD_PLUGINS:-false}; then
    removeOldMods $BUNGEE_HOME/plugins
    REMOVE_OLD_PLUGINS=false
  fi

  log "Getting plugins via Spiget"
  IFS=',' read -r -a resources <<<"${SPIGET_PLUGINS}"
  for resource in "${resources[@]}"; do
    getResourceFromSpiget "${resource}" "$BUNGEE_HOME/plugins"
  done
fi

# Download rcon plugin
if [ "${TYPE^^}" = "VELOCITY" ]; then # Download UnioDex/VelocityRcon plugin
  if isTrue "${ENABLE_RCON}" && [[ ! -e $BUNGEE_HOME/plugins/${RCON_VELOCITY_JAR_URL##*/} ]]; then
    log "Downloading Velocity rcon plugin"
    mkdir -p $BUNGEE_HOME/plugins/velocityrcon

    if ! curl -sSL -o "$BUNGEE_HOME/plugins/${RCON_VELOCITY_JAR_URL##*/}" $RCON_VELOCITY_JAR_URL; then
      echo "ERROR: failed to download from $RCON_VELOCITY_JAR_URL to /tmp/${RCON_VELOCITY_JAR_URL##*/}"
      exit 2
    fi

    log "Copy Velocity rcon configuration"
    sed -i 's#${PORT}#'"$RCON_PORT"'#g' /templates/rcon-velocity-config.toml
    sed -i 's#${PASSWORD}#'"$RCON_PASSWORD"'#g' /templates/rcon-velocity-config.toml

    mv /templates/rcon-velocity-config.toml "$BUNGEE_HOME/plugins/velocityrcon/rcon.toml"
    rm -f /templates/rcon-velocity-config.toml
  fi
else # Download orblazer/bungee-rcon plugin
  if isTrue "${ENABLE_RCON}" && [[ ! -e $BUNGEE_HOME/plugins/${RCON_JAR_URL##*/} ]]; then
    log "Downloading Bungee rcon plugin"
    mkdir -p $BUNGEE_HOME/plugins/bungee-rcon

    if ! curl -sSL -o "$BUNGEE_HOME/plugins/${RCON_JAR_URL##*/}" $RCON_JAR_URL; then
      echo "ERROR: failed to download from $RCON_JAR_URL to /tmp/${RCON_JAR_URL##*/}"
      exit 2
    fi

    log "Copy Bungee rcon configuration"
    sed -i 's#${PORT}#'"$RCON_PORT"'#g' /templates/rcon-config.yml
    sed -i 's#${PASSWORD}#'"$RCON_PASSWORD"'#g' /templates/rcon-config.yml

    mv /templates/rcon-config.yml "$BUNGEE_HOME/plugins/bungee-rcon/config.yml"
    rm -f /templates/rcon-config.yml
  fi
fi

if [ -d /config ]; then
    log "Copying BungeeCord configs over..."
    cp -u /config/config.yml "$BUNGEE_HOME/config.yml"

    # Copy other files if avaliable
    # server icon
    if [ -f /config/server-icon.png ]; then
      cp -u /config/server-icon.png "$BUNGEE_HOME/server-icon.png"
    fi
    # custom module list
    if [ -f /config/modules.yml ]; then
      cp -u /config/modules.yml "$BUNGEE_HOME/modules.yml"
    fi
    # Waterfall config
    if [ -f /config/waterfall.yml ]; then
      cp -u /config/waterfall.yml "$BUNGEE_HOME/waterfall.yml"
    fi
    # Velocity config
    if [ -f /config/velocity.toml ]; then
      cp -u /config/velocity.toml "$BUNGEE_HOME/velocity.toml"
    fi
    # Messages
    if [ -f /config/messages.properties ]; then
      cp -u /config/messages.properties "$BUNGEE_HOME/messages.properties"
    fi
fi

if [ -f /var/run/default-config.yml -a ! -f $BUNGEE_HOME/config.yml ]; then
    log "Installing default configuration"
    cp /var/run/default-config.yml $BUNGEE_HOME/config.yml
    if [ $UID == 0 ]; then
        chown bungeecord: $BUNGEE_HOME/config.yml
    fi
fi

# Replace environment variables in config files
if isTrue "${REPLACE_ENV_VARIABLES}"; then
  log "Replacing env variables in configs that match the prefix $ENV_VARIABLE_PREFIX..."
  for name in $(compgen -v $ENV_VARIABLE_PREFIX); do
    if [[ $name = *"_FILE" ]]; then
      value=$(<${!name})
      name="${name%_FILE}"
    else
      value=${!name}
    fi

    log "Replacing $name ..."

    value=${value//\\/\\\\}
    value=${value//#/\\#}

    if isDebugging; then
      findDebug="-print"
    fi

    find /server/ \
        $dirExcludes \
        -type f \
        \( -name "*.yml" -or -name "*.yaml" -or -name "*.toml" -or -name "*.txt" \
          -or -name "*.cfg" -or -name "*.conf" -or -name "*.properties" -or -name "*.hjson" -or -name "*.json" \) \
        $fileExcludes \
        $findDebug \
        -exec sed -i 's#${'"$name"'}#'"$value"'#g' {} \;
  done
fi

if [ $UID == 0 ]; then
  chown -R bungeecord:bungeecord $BUNGEE_HOME
fi

if [[ ${INIT_MEMORY} || ${MAX_MEMORY} ]]; then
  log "Setting initial memory to ${INIT_MEMORY:=${MEMORY}} and max to ${MAX_MEMORY:=${MEMORY}}"
  if [[ ${INIT_MEMORY} ]]; then
    JVM_OPTS="-Xms${INIT_MEMORY} ${JVM_OPTS}"
  fi
  if [[ ${MAX_MEMORY} ]]; then
    JVM_OPTS="-Xmx${MAX_MEMORY} ${JVM_OPTS}"
  fi
fi

if [ $UID == 0 ]; then
  exec sudo -E -u bungeecord $JAVA_HOME/bin/java $JVM_XX_OPTS $JVM_OPTS -jar "$BUNGEE_JAR" "$@"
else
  exec $JAVA_HOME/bin/java $JVM_OPTS -jar "$BUNGEE_JAR" "$@"
fi
