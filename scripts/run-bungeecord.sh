#!/bin/bash

: "${TYPE:=BUNGEECORD}"
: "${DEBUG:=false}"
: "${RCON_JAR_VERSION:=1.0.0}"
: "${RCON_VELOCITY_JAR_VERSION:=1.1}"
: "${SPIGET_PLUGINS:=}"
: "${NETWORKADDRESS_CACHE_TTL:=60}"
: "${INIT_MEMORY:=${MEMORY}}"
: "${MAX_MEMORY:=${MEMORY}}"
: "${SYNC_SKIP_NEWER_IN_DESTINATION:=true}"
: "${GENERIC_PACKS:=${GENERIC_PACK}}"
: "${GENERIC_PACKS_PREFIX:=}"
: "${GENERIC_PACKS_SUFFIX:=}"
: "${REPLACE_ENV_DURING_SYNC:=true}"
: "${REPLACE_ENV_VARIABLES:=false}"
: "${REPLACE_ENV_SUFFIXES:=yml,yaml,txt,cfg,conf,properties,hjson,json,tml,toml}"
: "${REPLACE_ENV_VARIABLE_PREFIX:=${ENV_VARIABLE_PREFIX:-CFG_}}"
: "${REPLACE_ENV_VARIABLES_EXCLUDES:=}"
: "${REPLACE_ENV_VARIABLES_EXCLUDE_PATHS:=}"
: "${MODRINTH_PROJECTS:=}"
: "${MODRINTH_DOWNLOAD_DEPENDENCIES:=required}"
: "${MODRINTH_ALLOWED_VERSION_TYPE:=release}"

BUNGEE_HOME=/server
RCON_JAR_URL=https://github.com/orblazer/bungee-rcon/releases/download/v${RCON_JAR_VERSION}/bungee-rcon-${RCON_JAR_VERSION}.jar
RCON_VELOCITY_JAR_URL=https://github.com/UnioDex/VelocityRcon/releases/download/v${RCON_VELOCITY_JAR_VERSION}/VelocityRcon.jar
download_required=true

set -eo pipefail

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
  if isTrue "${DEBUG}"; then
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

function get() {
  local flags=()
  if isTrue "${DEBUG_GET:-false}"; then
    flags+=("--debug")
  fi
  mc-image-helper "${flags[@]}" get "$@"
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

function isURL() {
  local value=$1

  if [[ ${value:0:8} == "https://" || ${value:0:7} == "http://" || ${value:0:6} == "ftp://" ]]; then
    return 0
  else
    return 1
  fi
}

function genericPacks() {
  IFS=',' read -ra packs <<< "${GENERIC_PACKS}"

  packFiles=()
  for packEntry in "${packs[@]}"; do
    pack="${GENERIC_PACKS_PREFIX}${packEntry}${GENERIC_PACKS_SUFFIX}"
    if isURL "${pack}"; then
      mkdir -p "${BUNGEE_HOME}/packs"
      log "Downloading generic pack from $pack"
      if ! outfile=$(mc-image-helper get -o "${BUNGEE_HOME}/packs" --output-filename --skip-up-to-date "$pack"); then
        log "ERROR: failed to download $pack"
        exit 2
      fi
      packFiles+=("$outfile")
    else
      packFiles+=("$pack")
    fi
  done

  log "Applying generic pack(s)..."
  original_base_dir="${BUNGEE_HOME}/.tmp/generic_pack_base"
  base_dir=$original_base_dir
  rm -rf "${base_dir}"
  mkdir -p "${base_dir}"
  for pack in "${packFiles[@]}"; do
    unzip -o -q -d "${base_dir}" "${pack}"
  done

  if [ -f "${BUNGEE_HOME}/manifest.txt" ]; then
    log "Manifest exists from older generic pack, cleaning up ..."
    while read -r f; do
      rm -rf "${BUNGEE_HOME:?}/${f}"
    done < "${BUNGEE_HOME}/packs/manifest.txt"
    find "${BUNGEE_HOME}" -mindepth 1 -depth -type d -empty -delete
    rm -f "${BUNGEE_HOME}/manifest.txt"
  fi

  log "Writing generic pack manifest ... "
  find "${base_dir}" -type f -printf "%P\n" > "${BUNGEE_HOME}/manifest.txt"

  log "Applying generic pack ..."
  cp -R -f "${base_dir}"/* "${BUNGEE_HOME}"
  rm -rf $original_base_dir

  if [ $UID == 0 ]; then
    chown -R bungeecord:bungeecord "${BUNGEE_HOME}"
  fi
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

  mkdir -p "${dest}"
  if containsJars "${tmpfile}"; then
    log "Extracting contents of resource ${resource} into plugins"
    unzip -o -q -d "${dest}" "${tmpfile}"
    rm "${tmpfile}"
  else
    log "Moving resource ${resource} into plugins"
    mv "${tmpfile}" "${dest}/${resource}.jar"
  fi

}

function removeOldMods {
  if [ -d "$1" ]; then
    find "$1" -mindepth 1 -maxdepth "${REMOVE_OLD_MODS_DEPTH:-16}" -wholename "${REMOVE_OLD_MODS_INCLUDE:-*}" -not -wholename "${REMOVE_OLD_MODS_EXCLUDE:-}" -delete
  fi
}

function processConfigs {
  if isTrue ${REPLACE_ENV_DURING_SYNC}; then
    subcommand=sync-and-interpolate
  else
    subcommand=sync
  fi

  if [ -d /config ]; then
      log "Copying configs over..."

      mc-image-helper $subcommand \
        --skip-newer-in-destination="${SYNC_SKIP_NEWER_IN_DESTINATION}" \
        --replace-env-file-suffixes="${REPLACE_ENV_SUFFIXES}" \
        --replace-env-excludes="${REPLACE_ENV_VARIABLES_EXCLUDES}" \
        --replace-env-exclude-paths="${REPLACE_ENV_VARIABLES_EXCLUDE_PATHS}" \
        --replace-env-prefix="${REPLACE_ENV_VARIABLE_PREFIX}" \
        /config "$BUNGEE_HOME"
  fi

  if [ -f /var/run/default-config.yml ] && [ ! -f $BUNGEE_HOME/config.yml ]; then
      log "Installing default configuration"
      cp /var/run/default-config.yml $BUNGEE_HOME/config.yml
      if [ $UID == 0 ]; then
          chown bungeecord: $BUNGEE_HOME/config.yml
      fi
  fi

  # Replace environment variables in config files
  if isTrue "${REPLACE_ENV_VARIABLES}"; then
    log "Replacing env variables in configs that match the prefix $REPLACE_ENV_VARIABLE_PREFIX..."
    mc-image-helper interpolate \
      --replace-env-file-suffixes="${REPLACE_ENV_SUFFIXES}" \
      --replace-env-excludes="${REPLACE_ENV_VARIABLES_EXCLUDES}" \
      --replace-env-exclude-paths="${REPLACE_ENV_VARIABLES_EXCLUDE_PATHS}" \
      --replace-env-prefix="${REPLACE_ENV_VARIABLE_PREFIX}" \
      "${BUNGEE_HOME}"

  fi

  if [[ -v PATCH_DEFINITIONS ]]; then
    log "Applying patch definitions from ${PATCH_DEFINITIONS}"
    mc-image-helper patch \
      --patch-env-prefix="${REPLACE_ENV_VARIABLE_PREFIX}" \
      "${PATCH_DEFINITIONS}"
  fi

}

function pruneOlder() {
  prefix=${1?}

  find "$BUNGEE_HOME" -maxdepth 1 -type f -not -wholename "$BUNGEE_JAR" -name "${prefix}-*.jar" -delete
}

function getFromPaperMc() {
  local project=${1?}
  local version=${2?}
  local buildId=${3?}

  # Doc : https://papermc.io/api

  if [[ ${version^^} = LATEST ]]; then
    if ! version=$(get --json-path=".versions[-1]" "https://papermc.io/api/v2/projects/${project}"); then
      echo "ERROR: failed to lookup PaperMC versions"
      exit 1
    fi
  fi

  if [[ ${buildId^^} = LATEST ]]; then
    if ! buildId=$(get --json-path=".builds[-1]" "https://papermc.io/api/v2/projects/${project}/versions/${version}"); then
        echo "ERROR: failed to lookup PaperMC build from version ${version}"
        exit 1
    fi
  fi


  if ! jar=$(get --json-path=".downloads.application.name" "https://papermc.io/api/v2/projects/${project}/versions/${version}/builds/${buildId}"); then
    echo "ERROR: failed to lookup PaperMC download file from version=${version} build=${buildId}"
    exit 1
  fi

  BUNGEE_JAR_URL="https://papermc.io/api/v2/projects/${project}/versions/${version}/builds/${buildId}/downloads/${jar}"
  BUNGEE_JAR=$BUNGEE_HOME/${BUNGEE_JAR:=${project}-${version}-${buildId}.jar}
}

### MAIN

handleDebugMode

if [[ ${GENERIC_PACKS} ]]; then
  genericPacks
fi

log "Resolving type given ${TYPE}"
case "${TYPE^^}" in
  BUNGEECORD)
    : "${BUNGEE_BASE_URL:=https://ci.md-5.net/job/BungeeCord}"
    : "${BUNGEE_JOB_ID:=lastStableBuild}"
    : "${BUNGEE_JAR_URL:=${BUNGEE_BASE_URL}/${BUNGEE_JOB_ID}/artifact/bootstrap/target/BungeeCord.jar}"
    : "${BUNGEE_JAR_REVISION:=${BUNGEE_JOB_ID}}"
    BUNGEE_JAR=$BUNGEE_HOME/${BUNGEE_JAR:=BungeeCord-${BUNGEE_JAR_REVISION}.jar}
    pruningPrefix=BungeeCord
    family=bungeecord
  ;;

  WATERFALL)
    getFromPaperMc waterfall "${WATERFALL_VERSION:-latest}" "${WATERFALL_BUILD_ID:-latest}"
    pruningPrefix=waterfall
    family=bungeecord
 ;;

  VELOCITY)
    getFromPaperMc velocity "${VELOCITY_VERSION:-latest}" "${VELOCITY_BUILD_ID:-latest}"
    pruningPrefix=velocity
    family=velocity
  ;;

  CUSTOM)
    family=bungeecord
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
  if ! get -o "$BUNGEE_JAR" --skip-up-to-date --log-progress-each "$BUNGEE_JAR_URL"; then
      echo "ERROR: failed to download" >&2
      exit 2
  fi
fi

if [ -n "$ICON" ]; then
    if [ ! -e server-icon.png ] || isTrue "${OVERRIDE_ICON}"; then
      log "Using server icon from $ICON..."
      if isURL "$ICON"; then
        # Not sure what it is yet...call it "img"
        if ! get -o /tmp/icon.img "$ICON"; then
          log "ERROR: failed to download icon from $ICON"
          exit 1
        fi
        ICON=/tmp/icon.img
        iconSrc="url"
      elif [ -f "$ICON" ]; then
        iconSrc="file"
      else
        log "ERROR: $ICON does not appear to be a URL or existing file"
        exit 1
      fi
      read -r -a specs < <(identify "$ICON" | awk 'NR == 1 { print $2, $3 }')
      if [ "${specs[0]} ${specs[1]}" = "PNG 64x64" ]; then
        if [ $iconSrc = url ]; then
          mv -f /tmp/icon.img /server/server-icon.png
        else
          cp -f "$ICON" /server/server-icon.png
        fi
      elif [ "${specs[0]}" = GIF ]; then
        log "Converting GIF image to 64x64 PNG..."
        convert "$ICON"[0] -resize 64x64! /server/server-icon.png
      else
        log "Converting image to 64x64 PNG..."
        convert "$ICON" -resize 64x64! /server/server-icon.png
      fi
    fi
fi

if [[ $pruningPrefix ]]; then
  pruneOlder "$pruningPrefix"
fi

if [ -d /plugins ]; then
    log "Copying BungeeCord plugins over..."
    cp -ru /plugins $BUNGEE_HOME
fi

# If supplied with a URL for a plugin download it.
if [[ "$PLUGINS" ]]; then
  mkdir -p "$BUNGEE_HOME/plugins"
  mc-image-helper mcopy \
          --glob=*.jar \
          --scope=var-list \
          --to="$BUNGEE_HOME/plugins" \
          "$PLUGINS"
fi

if [[ ${SPIGET_PLUGINS} ]]; then
  if isTrue "${REMOVE_OLD_PLUGINS:-false}"; then
    removeOldMods $BUNGEE_HOME/plugins
    REMOVE_OLD_PLUGINS=false
  fi

  log "Getting plugins via Spiget"
  IFS=',' read -r -a resources <<<"${SPIGET_PLUGINS}"
  for resource in "${resources[@]}"; do
    getResourceFromSpiget "${resource}" "$BUNGEE_HOME/plugins"
  done
fi

if [[ $MODRINTH_PROJECTS ]]; then
  if ! [[ -v MINECRAFT_VERSION ]]; then
    log "ERROR: plugins via MODRINTH_PROJECTS require MINECRAFT_VERSION to be set to corresponding Minecraft game version"
    exit 1
  fi

  mc-image-helper modrinth \
    --output-directory=/data \
    --projects="${MODRINTH_PROJECTS}" \
    --game-version="${MINECRAFT_VERSION}" \
    --loader="${family}" \
    --download-dependencies="${MODRINTH_DOWNLOAD_DEPENDENCIES}" \
    --allowed-version-type="${MODRINTH_ALLOWED_VERSION_TYPE}"
fi

# Download rcon plugin
if [[ "${family}" == "velocity" ]] || isTrue "${APPLY_VELOCITY_RCON:-false}"; then # Download UnioDex/VelocityRcon plugin
  if isTrue "${ENABLE_RCON}"; then
    log "Downloading Velocity rcon plugin"

    mkdir -p "$BUNGEE_HOME/plugins"
    if ! get -o "$BUNGEE_HOME/plugins" --skip-up-to-date --log-progress-each "$RCON_VELOCITY_JAR_URL"; then
      echo "ERROR: failed to download from $RCON_VELOCITY_JAR_URL"
      exit 1
    fi

    log "Copy Velocity rcon configuration"
    mkdir -p $BUNGEE_HOME/plugins/velocityrcon
    sed -e 's#${PORT}#'"$RCON_PORT"'#g' -e 's#${PASSWORD}#'"$RCON_PASSWORD"'#g' \
      /templates/rcon-velocity-config.toml > "$BUNGEE_HOME/plugins/velocityrcon/rcon.toml"
  fi

# Download orblazer/bungee-rcon plugin
elif [[ "${family}" == "bungeecord" ]] || isTrue "${APPLY_BUNGEECORD_RCON:-false}"; then
  if isTrue "${ENABLE_RCON}" && [[ ! -e $BUNGEE_HOME/plugins/${RCON_JAR_URL##*/} ]]; then
    log "Downloading Bungee rcon plugin"
    mkdir -p $BUNGEE_HOME/plugins/bungee-rcon

    if ! mc-image-helper get -o "$BUNGEE_HOME/plugins/${RCON_JAR_URL##*/}" "$RCON_JAR_URL"; then
      echo "ERROR: failed to download from $RCON_JAR_URL to /tmp/${RCON_JAR_URL##*/}"
      exit 2
    fi

    configFile="$BUNGEE_HOME/plugins/bungee-rcon/config.yml"
    if [ ! -e "$configFile" ]; then
       log "Copy Bungee rcon configuration"
       # shellcheck disable=SC2016
       sed \
         -e 's#${PORT}#'"$RCON_PORT"'#g' \
         -e 's#${PASSWORD}#'"$RCON_PASSWORD"'#g' \
         /templates/rcon-config.yml > "$configFile"
    fi
  fi
fi

processConfigs

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

JVM_OPTS="${JVM_OPTS} -Dlog4j2.formatMsgNoLookups=true"

if isTrue "${ENABLE_JMX}"; then
  : "${JMX_PORT:=7091}"
  JVM_OPTS="${JVM_OPTS}
  -Dcom.sun.management.jmxremote.local.only=false
  -Dcom.sun.management.jmxremote.port=${JMX_PORT}
  -Dcom.sun.management.jmxremote.rmi.port=${JMX_PORT}
  -Dcom.sun.management.jmxremote.authenticate=false
  -Dcom.sun.management.jmxremote.ssl=false
  -Dcom.sun.management.jmxremote.host=${JMX_BINDING:-0.0.0.0}
  -Djava.rmi.server.hostname=${JMX_HOST:-localhost}"

  log "JMX is enabled. Make sure you have port forwarding for ${JMX_PORT}"
fi

if [ $UID == 0 ]; then
  exec sudo -E -u bungeecord "$JAVA_HOME/bin/java" $JVM_XX_OPTS $JVM_OPTS -jar "$BUNGEE_JAR" "$@"
else
  exec "$JAVA_HOME/bin/java" $JVM_XX_OPTS $JVM_OPTS -jar "$BUNGEE_JAR" "$@"
fi
