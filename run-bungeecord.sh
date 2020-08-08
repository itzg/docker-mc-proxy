#!/bin/bash

: ${TYPE:=BUNGEECORD}
: ${MEMORY:=512m}
: ${RCON_JAR_VERSION:=1.0.0}
BUNGEE_HOME=/server
RCON_JAR_URL=https://github.com/orblazer/bungee-rcon/releases/download/v${RCON_JAR_VERSION}/bungee-rcon-${RCON_JAR_VERSION}.jar

function isURL {
  local value=$1

  if [[ ${value:0:8} == "https://" || ${value:0:7} == "http://" ]]; then
    return 0
  else
    return 1
  fi
}

echo "Resolving type given ${TYPE}"
case "${TYPE^^}" in
  BUNGEECORD)
    : ${BUNGEE_BASE_URL:=https://ci.md-5.net/job/BungeeCord}
    : ${BUNGEE_JOB_ID:=lastStableBuild}
    : ${BUNGEE_JAR_URL:=${BUNGEE_BASE_URL}/${BUNGEE_JOB_ID}/artifact/bootstrap/target/BungeeCord.jar}
    : ${BUNGEE_JAR_REVISION:=${BUNGEE_JOB_ID}}
    BUNGEE_JAR=$BUNGEE_HOME/${BUNGEE_JAR:=BungeeCord-${BUNGEE_JAR_REVISION}.jar}
  ;;

  WATERFALL)
    : ${WATERFALL_VERSION:=latest}
    : ${WATERFALL_BUILD_ID:=latest}
    if [[ ${WATERFALL_VERSION^^} = LATEST ]]; then
      WATERFALL_VERSION=$(curl -s https://papermc.io/api/v1/waterfall | jq -r '.versions[0]')
    fi
    BUNGEE_JAR_URL="https://papermc.io/api/v1/waterfall/${WATERFALL_VERSION}/${WATERFALL_BUILD_ID}/download"
    BUNGEE_JAR=$BUNGEE_HOME/${BUNGEE_JAR:=Waterfall-${WATERFALL_VERSION}-${WATERFALL_BUILD_ID}.jar}
  ;;

  CUSTOM)
    if isURL ${BUNGEE_JAR_URL}; then
      BUNGEE_JAR=$BUNGEE_HOME/$(basename ${BUNGEE_JAR_URL})
    elif [[ -f ${BUNGEE_JAR_URL} ]]; then
      echo "Using custom server jar at ${BUNGEE_JAR_URL} ..."
      BUNGEE_JAR=${BUNGEE_JAR_URL}
    else
      echo "BUNGEE_JAR_URL is not properly set to a URL or existing jar file"
      exit 2
    fi
  ;;

  *)
      echo "Invalid type: '$TYPE'"
      echo "Must be: BUNGEECORD, WATERFALL, CUSTOM"
      exit 1
  ;;
esac

if [ -f "$BUNGEE_JAR" ]; then
  zarg="-z '$BUNGEE_JAR'"
fi

echo "Downloading ${BUNGEE_JAR_URL}"
if ! curl -o "$BUNGEE_JAR" -fsSL $zarg $BUNGEE_JAR_URL; then
    echo "ERROR: failed to download" >&2
    exit 2
fi

if [ -d /plugins ]; then
    echo "Copying BungeeCord plugins over..."
    cp -r /plugins $BUNGEE_HOME
fi

# If supplied with a URL for a plugin download it.
if [[ "$PLUGINS" ]]; then
for i in ${PLUGINS//,/ }
do
  EFFECTIVE_PLUGIN_URL=$(curl -Ls -o /dev/null -w %{url_effective} $i)
  case "X$EFFECTIVE_PLUGIN_URL" in
    X[Hh][Tt][Tt][Pp]*.jar)
      echo "Downloading plugin via HTTP"
      echo "  from $EFFECTIVE_PLUGIN_URL ..."
      if ! curl -sSL -o /tmp/${EFFECTIVE_PLUGIN_URL##*/} $EFFECTIVE_PLUGIN_URL; then
        echo "ERROR: failed to download from $EFFECTIVE_PLUGIN_URL to /tmp/${EFFECTIVE_PLUGIN_URL##*/}"
        exit 2
      fi

      mkdir -p $BUNGEE_HOME/plugins
      mv /tmp/${EFFECTIVE_PLUGIN_URL##*/} "$BUNGEE_HOME/plugins/${EFFECTIVE_PLUGIN_URL##*/}"
      rm -f /tmp/${EFFECTIVE_PLUGIN_URL##*/}
      ;;
    *)
      echo "Invalid URL given for plugin list: Must be HTTP or HTTPS and a JAR file"
      ;;
  esac
done
fi

# Download rcon plugin
if [ "${ENABLE_RCON^^}" = "TRUE" ] && [[ ! -e $BUNGEE_HOME/plugins/${RCON_JAR_URL##*/} ]]; then
  echo "Downloading rcon plugin"
  mkdir -p $BUNGEE_HOME/plugins/bungee-rcon

  if ! curl -sSL -o "$BUNGEE_HOME/plugins/${RCON_JAR_URL##*/}" $RCON_JAR_URL; then
    echo "ERROR: failed to download from $RCON_JAR_URL to /tmp/${RCON_JAR_URL##*/}"
    exit 2
  fi

  echo "Copy rcon configuration"
  sed -i 's#${PORT}#'"$RCON_PORT"'#g' /tmp/rcon-config.yml
  sed -i 's#${PASSWORD}#'"$RCON_PASSWORD"'#g' /tmp/rcon-config.yml

  mv /tmp/rcon-config.yml "$BUNGEE_HOME/plugins/bungee-rcon/config.yml"
  rm -f /tmp/rcon-config.yml
fi

if [ -d /config ]; then
    echo "Copying BungeeCord configs over..."
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
fi

if [ -f /var/run/default-config.yml -a ! -f $BUNGEE_HOME/config.yml ]; then
    echo "Installing default configuration"
    cp /var/run/default-config.yml $BUNGEE_HOME/config.yml
    if [ $UID == 0 ]; then
        chown bungeecord: $BUNGEE_HOME/config.yml
    fi
fi

# Replace environment variables in config files
if [ "${REPLACE_ENV_VARIABLES^^}" = "TRUE" ]; then
  echo "Replacing env variables in configs that match the prefix $ENV_VARIABLE_PREFIX..."
  while IFS='=' read -r name value ; do
    # check if name of env variable matches the prefix
    # sanity check environment variables to avoid code injections
    if [[ "$name" = $ENV_VARIABLE_PREFIX* ]] \
        && [[ $value =~ ^[0-9a-zA-Z_:/=?.+\-]*$ ]] \
        && [[ $name =~ ^[0-9a-zA-Z_\-]*$ ]]; then
      # Read content from file
      if [[ $name = *"_FILE" ]] && [[ -f $value ]]; then
        name="${name/_FILE/}"
        value=$(<$value)
      fi

      echo "Replacing $name with $value ..."
      find $BUNGEE_HOME -type f \
          \( -name "*.yml" -or -name "*.yaml" -or -name "*.txt" -or -name "*.cfg" \
          -or -name "*.conf" -or -name "*.properties" \) \
          -exec sed -i 's#${'"$name"'}#'"$value"'#g' {} \;
    fi
  done < <(env)
fi

if [ $UID == 0 ]; then
  chown -R bungeecord:bungeecord $BUNGEE_HOME
fi

echo "Setting initial memory to ${INIT_MEMORY:-${MEMORY}} and max to ${MAX_MEMORY:-${MEMORY}}"
JVM_OPTS="-Xms${INIT_MEMORY:-${MEMORY}} -Xmx${MAX_MEMORY:-${MEMORY}} ${JVM_OPTS}"

if [ $UID == 0 ]; then
  exec sudo -u bungeecord java $JVM_OPTS -jar $BUNGEE_JAR "$@"
else
  exec java $JVM_OPTS -jar $BUNGEE_JAR "$@"
fi
