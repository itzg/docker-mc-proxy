FROM openjdk:8u131-jre-alpine

VOLUME ["/server", "/plugins"]
WORKDIR /server

ENV BUNGEE_HOME=/server \
    BUNGEE_BASE_URL=https://ci.md-5.net/job/BungeeCord \
    MEMORY=512m \
    UID=1000 \
    GID=1000

COPY *.sh /usr/bin/

RUN apk --no-cache add curl
RUN apk --no-cache add bash

EXPOSE 25577

RUN set -x \
	&& addgroup -g 1000 -S bungeecord \
	&& adduser -u 1000 -D -S -G bungeecord bungeecord

USER bungeecord

ENTRYPOINT ["/usr/bin/run-bungeecord.sh"]
