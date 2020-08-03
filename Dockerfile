FROM openjdk:8-alpine

VOLUME ["/server"]
WORKDIR /server

# upgrade all packages since alpine jre8 base image tops out at 8u212
RUN apk -U --no-cache upgrade

RUN apk -U --no-cache add curl bash sudo jq

ENV SERVER_PORT=25577 ENABLE_RCON=true RCON_PORT=25575
EXPOSE $SERVER_PORT

RUN set -x \
	&& addgroup -g 1000 -S bungeecord \
	&& adduser -u 1000 -D -S -G bungeecord bungeecord \
	&& addgroup bungeecord wheel

# hook into docker BuildKit --platform support
# see https://docs.docker.com/engine/reference/builder/#automatic-platform-args-in-the-global-scope
ARG TARGETOS=linux
ARG TARGETARCH=amd64
ARG TARGETVARIANT=""

ARG EASY_ADD_VER=0.7.1
ADD https://github.com/itzg/easy-add/releases/download/${EASY_ADD_VER}/easy-add_${TARGETOS}_${TARGETARCH}${TARGETVARIANT} /usr/bin/easy-add
RUN chmod +x /usr/bin/easy-add

# Add healthcheck
RUN easy-add --var os=${TARGETOS} --var arch=${TARGETARCH}${TARGETVARIANT} \
 --var version=0.6.0 --var app=mc-monitor --file {{.app}} \
 --from https://github.com/itzg/{{.app}}/releases/download/{{.version}}/{{.app}}_{{.version}}_{{.os}}_{{.arch}}.tar.gz
COPY health.sh /
RUN dos2unix /health.sh && chmod +x /health.sh

# Add rcon
RUN easy-add --var os=${TARGETOS} --var arch=${TARGETARCH}${TARGETVARIANT} \
 --var version=1.4.7 --var app=rcon-cli --file {{.app}} \
 --from https://github.com/itzg/{{.app}}/releases/download/{{.version}}/{{.app}}_{{.version}}_{{.os}}_{{.arch}}.tar.gz
COPY rcon-config.yml /tmp/rcon-config.yml


CMD ["/usr/bin/run-bungeecord.sh"]
HEALTHCHECK --start-period=10s CMD /health.sh

COPY *.sh /usr/bin/
