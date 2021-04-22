FROM adoptopenjdk:8-jre-hotspot

VOLUME ["/server"]
WORKDIR /server

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive \
  apt-get install -y \
    sudo \
    net-tools \
    curl \
    jq \
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
 --var version=0.8.0 --var app=mc-monitor --file {{.app}} \
 --from https://github.com/itzg/{{.app}}/releases/download/{{.version}}/{{.app}}_{{.version}}_{{.os}}_{{.arch}}.tar.gz
COPY health.sh /

# Add rcon-cli
RUN easy-add --var os=${TARGETOS} --var arch=${TARGETARCH}${TARGETVARIANT} \
 --var version=1.4.7 --var app=rcon-cli --file {{.app}} \
 --from https://github.com/itzg/{{.app}}/releases/download/{{.version}}/{{.app}}_{{.version}}_{{.os}}_{{.arch}}.tar.gz
COPY rcon-config.yml /tmp/rcon-config.yml

ENV SERVER_PORT=25577 RCON_PORT=25575
EXPOSE $SERVER_PORT

CMD ["/usr/bin/run-bungeecord.sh"]
HEALTHCHECK --start-period=10s CMD /health.sh

COPY *.sh /usr/bin/
