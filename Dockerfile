FROM haproxy:1.9-alpine
LABEL maintainer="Max Sum max@lolyculture.com"

# Install wget and install/updates certificates
RUN apk add --no-cache --virtual .run-deps \
    ca-certificates bash wget openssl \
    && update-ca-certificates \
    && mv /usr/local/etc/haproxy /etc/

# Install Forego
ADD https://github.com/jwilder/forego/releases/download/v0.16.1/forego /usr/local/bin/forego
RUN chmod u+x /usr/local/bin/forego

ENV DOCKER_GEN_VERSION 0.7.3

RUN wget --quiet https://github.com/jwilder/docker-gen/releases/download/$DOCKER_GEN_VERSION/docker-gen-alpine-linux-amd64-$DOCKER_GEN_VERSION.tar.gz \
 && tar -C /usr/local/bin -xvzf docker-gen-alpine-linux-amd64-$DOCKER_GEN_VERSION.tar.gz \
 && rm /docker-gen-alpine-linux-amd64-$DOCKER_GEN_VERSION.tar.gz

COPY . /app/
RUN mv /app/haproxy.cnf /etc/haproxy/
WORKDIR /app/

ENV DOCKER_HOST unix:///tmp/docker.sock

VOLUME ["/etc/haproxy/certs"]

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["forego", "start", "-r"]
