FROM openjdk:8u131-jre-alpine

VOLUME ["/server", "/plugins"]
WORKDIR /server

COPY *.sh /usr/bin/

EXPOSE 25577

ENV BUNGEE_HOME=/server \
    BUNGEE_BASE_URL=https://ci.md-5.net/job/BungeeCord \
    MEMORY=512m

ENTRYPOINT ["/usr/bin/run-bungeecord.sh"]
