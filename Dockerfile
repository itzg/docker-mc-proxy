FROM openjdk:8u131-jre-alpine

VOLUME ["/server", "/plugins"]
WORKDIR /server

COPY *.sh /usr/bin/

RUN apk --no-cache add curl
RUN apk --no-cache add bash

EXPOSE 25577

ENV BUNGEE_HOME=/server \
    BUNGEE_BASE_URL=https://ci.md-5.net/job/BungeeCord \
    MEMORY=512m \
    UID=1000 \
    GID=1000

#ENTRYPOINT ["/usr/bin/run-bungeecord.sh"]
ENTRYPOINT ["/bin/bash"]
