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
    imagemagick \
  && apt-get clean

RUN addgroup --gid 1000 bungeecord \
  && adduser --system --shell /bin/false --uid 1000 --ingroup bungeecord --home /server bungeecord

# hook into docker BuildKit --platform support
# see https://docs.docker.com/engine/reference/builder/#automatic-platform-args-in-the-global-scope
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT

ARG APPS_REV=1
ARG GITHUB_BASEURL=https://github.com

ARG EASY_ADD_VERSION=0.8.2
ADD ${GITHUB_BASEURL}/itzg/easy-add/releases/download/${EASY_ADD_VERSION}/easy-add_${TARGETOS}_${TARGETARCH}${TARGETVARIANT} /usr/bin/easy-add
RUN chmod +x /usr/bin/easy-add

ARG MC_MONITOR_VERSION=0.12.6
RUN easy-add --var os=${TARGETOS} --var arch=${TARGETARCH}${TARGETVARIANT} \
  --var version=${MC_MONITOR_VERSION} --var app=mc-monitor --file {{.app}} \
  --from ${GITHUB_BASEURL}/itzg/{{.app}}/releases/download/{{.version}}/{{.app}}_{{.version}}_{{.os}}_{{.arch}}.tar.gz

ARG RCON_CLI_VERSION=1.6.4
RUN easy-add --var os=${TARGETOS} --var arch=${TARGETARCH}${TARGETVARIANT} \
  --var version=${RCON_CLI_VERSION} --var app=rcon-cli --file {{.app}} \
  --from ${GITHUB_BASEURL}/itzg/{{.app}}/releases/download/{{.version}}/{{.app}}_{{.version}}_{{.os}}_{{.arch}}.tar.gz

COPY --chmod=444 templates/ /templates/

ARG MC_HELPER_VERSION=1.37.0
ARG MC_HELPER_BASE_URL=${GITHUB_BASEURL}/itzg/mc-image-helper/releases/download/${MC_HELPER_VERSION}
# used for cache busting local copy of mc-image-helper
ARG MC_HELPER_REV=1
RUN curl -fsSL ${MC_HELPER_BASE_URL}/mc-image-helper-${MC_HELPER_VERSION}.tgz \
  | tar -C /usr/share -zxf - \
  && ln -s /usr/share/mc-image-helper-${MC_HELPER_VERSION}/bin/mc-image-helper /usr/bin

ENV SERVER_PORT=25577 RCON_PORT=25575 MEMORY=512m
EXPOSE $SERVER_PORT

CMD ["/usr/bin/run-bungeecord.sh"]
HEALTHCHECK --start-period=10s CMD /usr/bin/health.sh

COPY --chmod=755 /scripts/* /usr/bin/
