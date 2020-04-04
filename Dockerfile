FROM openjdk:8-alpine

VOLUME ["/server"]
WORKDIR /server

RUN apk --no-cache add curl bash sudo

EXPOSE 25577

RUN set -x \
	&& addgroup -g 1000 -S bungeecord \
	&& adduser -u 1000 -D -S -G bungeecord bungeecord \
	&& addgroup bungeecord wheel

CMD ["/usr/bin/run-bungeecord.sh"]

COPY *.sh /usr/bin/
