ARG BASE_IMAGE=eclipse-temurin:17
FROM ${BASE_IMAGE}

VOLUME ["/server"]
WORKDIR /server

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive \
  apt-get install -y \
    sudo \
    net-tools \
    curl \
    tzdata \
    nano \
    unzip \
    ttf-dejavu \
    && apt-get clean

RUN addgroup --gid 1000 bungeecord \
  && adduser --system --shell /bin/false --uid 1000 --ingroup bungeecord --home /server bungeecord

# hook into docker BuildKit --platform support
# see https://docs.docker.com/engine/reference/builder/#automatic-platform-args-in-the-global-scope
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT

ARG EASY_ADD_VER=0.7.1
ADD https://github.com/itzg/easy-add/releases/download/${EASY_ADD_VER}/easy-add_${TARGETOS}_${TARGETARCH}${TARGETVARIANT} /usr/bin/easy-add
RUN chmod +x /usr/bin/easy-add

# Add mc-monitor
RUN easy-add --var os=${TARGETOS} --var arch=${TARGETARCH}${TARGETVARIANT} \
 --var version=0.10.6 --var app=mc-monitor --file {{.app}} \
 --from https://github.com/itzg/{{.app}}/releases/download/{{.version}}/{{.app}}_{{.version}}_{{.os}}_{{.arch}}.tar.gz
COPY health.sh /

# Add rcon-cli
RUN easy-add --var os=${TARGETOS} --var arch=${TARGETARCH}${TARGETVARIANT} \
 --var version=1.6.0 --var app=rcon-cli --file {{.app}} \
 --from https://github.com/itzg/{{.app}}/releases/download/{{.version}}/{{.app}}_{{.version}}_{{.os}}_{{.arch}}.tar.gz
COPY rcon-config.yml /templates/rcon-config.yml
COPY rcon-velocity-config.toml /templates/rcon-velocity-config.toml 

ARG MC_HELPER_VERSION=1.16.11
ARG MC_HELPER_BASE_URL=https://github.com/itzg/mc-image-helper/releases/download/v${MC_HELPER_VERSION}
RUN curl -fsSL ${MC_HELPER_BASE_URL}/mc-image-helper-${MC_HELPER_VERSION}.tgz \
    | tar -C /usr/share -zxf - \
    && ln -s /usr/share/mc-image-helper-${MC_HELPER_VERSION}/bin/mc-image-helper /usr/bin

ENV SERVER_PORT=25577 RCON_PORT=25575 MEMORY=512m
EXPOSE $SERVER_PORT

CMD ["/usr/bin/run-bungeecord.sh"]
HEALTHCHECK --start-period=10s CMD /health.sh

COPY *.sh /usr/bin/
