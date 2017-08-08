FROM openjdk:8u131-jre-alpine

ENV BUNGEE_HOME=/server \
    BUNGEE_BASE_URL=https://ci.md-5.net/job/BungeeCord \
    MEMORY=512m

COPY *.sh /usr/bin/

RUN apk --no-cache add curl bash

EXPOSE 25577

# RUN set -x \
# 	&& addgroup -g 1000 -S bungeecord \
# 	&& adduser -u 1000 -D -S -G bungeecord bungeecord

VOLUME ["/server", "/plugins"]
WORKDIR /server

ENTRYPOINT ["/usr/bin/run-bungeecord.sh"]
