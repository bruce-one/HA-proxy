FROM haproxy:1.8-alpine
LABEL maintainer="Max Sum max@lolyculture.com"

COPY . /app/
WORKDIR /app/
# Install wget and install/updates certificates
RUN apk add --no-cache --virtual .run-deps \
    ca-certificates bash wget openssl \
    && update-ca-certificates \
    && mv /usr/local/etc/haproxy /etc/ \
    && mv /app/haproxy.cfg /etc/haproxy/ \
    && mv /app/acme-webroot.lua /etc/haproxy/

ENV DOCKER_GEN_VERSION 0.7.3

RUN wget --quiet https://github.com/jwilder/docker-gen/releases/download/$DOCKER_GEN_VERSION/docker-gen-alpine-linux-amd64-$DOCKER_GEN_VERSION.tar.gz \
 && tar -C /usr/local/bin -xvzf docker-gen-alpine-linux-amd64-$DOCKER_GEN_VERSION.tar.gz \
 && rm docker-gen-alpine-linux-amd64-$DOCKER_GEN_VERSION.tar.gz

ENV DOCKER_HOST unix:///tmp/docker.sock

VOLUME ["/etc/haproxy/certs"]

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["docker-gen", "-config", "/app/docker-gen.conf"]
