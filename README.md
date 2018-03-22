![HAProxy 1.8](https://img.shields.io/badge/HAProxy-1.8-brightgreen.svg) ![License MIT](https://img.shields.io/badge/license-MIT-blue.svg) [![](https://img.shields.io/docker/stars/gzmaxsum/ha-proxy.svg)](https://hub.docker.com/r/gzmaxsum/ha-proxy 'DockerHub') [![](https://img.shields.io/docker/pulls/gzmaxsum/ha-proxy.svg)](https://hub.docker.com/r/gzmaxsum/ha-proxy 'DockerHub')

This is HAProxy flavor of [nginx-proxy][1]. Please look through the readme before you use, there is some difference in configuration from nginx-proxy. If you came from nginx-proxy, you should see the last capter **Major Difference from nginx-proxy** at last.

HA-proxy sets up a container running HAProxy and [docker-gen][2].  docker-gen generates reverse proxy configs for HAProxy and reloads HAProxy when containers are started and stopped.

See [Automated Nginx Reverse Proxy for Docker][3] for why you might want to use this.

### Usage

To run it:

    $ docker run -d -p 80:80 -v /var/run/docker.sock:/tmp/docker.sock:ro gzmaxsum/ha-proxy

Then start any containers you want proxied with an label `ha-proxy.host=subdomain.youdomain.com`

    $ docker run -l ha-proxy.host=foo.bar.com  ...

The containers being proxied must [expose](https://docs.docker.com/engine/reference/run/#expose-incoming-ports) the port to be proxied, either by using the `EXPOSE` directive in their `Dockerfile` or by using the `--expose` flag to `docker run` or `docker create`.

Provided your DNS is setup to forward foo.bar.com to the host running HA-proxy, the request will be routed to a container with the ha-proxy.host label set.

### Image variants

The HA-proxy images are available in only one flavors. Debian version is not succeeded in this flavor.

#### gzmaxsum/ha-proxy:latest

This image is based on the HAProxy:alpine image. 

    $ docker pull gzmaxsum/ha-proxy

### Docker Compose

```yaml
version: '2'
services:
  ha-proxy:
    image: gzmaxsum/ha-proxy
    container_name: ha-proxy
    ports:
      - "80:80"
    volumes:
      - /var/run/docker.sock:/tmp/docker.sock:ro

  whoami:
    image: jwilder/whoami
    labels:
      ha-proxy.host: whoami.local

```

```shell
$ docker-compose up
$ curl -H "Host: whoami.local" localhost
I'm 5b129ab83266
```

### IPv6 support

You can activate the IPv6 support for the HA-proxy container by passing the value `true` to the `ENABLE_IPV6` environment variable:

    $ docker run -d -p 80:80 -e ENABLE_IPV6=true -v /var/run/docker.sock:/tmp/docker.sock:ro gzmaxsum/ha-proxy

### Multiple Ports

If your container exposes multiple ports, HA-proxy will default to the service running on port 80.  If you need to specify a different port, you can set a `ha-proxy.host` label to select a different one.  If your container only exposes one port and it has a `ha-proxy.host` label set, that port will be selected.

[1]: https://github.com/jwilder/nginx-proxy
[2]: https://github.com/jwilder/docker-gen
[3]: http://jasonwilder.com/blog/2014/03/25/automated-nginx-reverse-proxy-for-docker/

### Multiple Hosts

If you need to support multiple virtual hosts for a container, you can separate each entry with commas.  For example, `foo.bar.com,baz.bar.com,bar.com` and each host will be setup the same.

### Wildcard Hosts (different from nginx-proxy)

You can also use wildcards **at the beginning**, like `*.bar.com` or `*www.foo.com`. Or even a regular expression, which can be very useful in conjunction with a wildcard DNS service like [xip.io](http://xip.io), using `~^foo\.bar\..*\.xip\.io` will match `foo.bar.127.0.0.1.xip.io`, `foo.bar.10.0.2.2.xip.io` and all other given IPs.

### Multiple Networks

With the addition of [overlay networking](https://docs.docker.com/engine/userguide/networking/get-started-overlay/) in Docker 1.9, your `ha-proxy` container may need to connect to backend containers on multiple networks. By default, if you don't pass the `--net` flag when your `ha-proxy` container is created, it will only be attached to the default `bridge` network. This means that it will not be able to connect to containers on networks other than `bridge`.

If you want your `ha-proxy` container to be attached to a different network, you must pass the `--net=my-network` option in your `docker create` or `docker run` command. At the time of this writing, only a single network can be specified at container creation time. To attach to other networks, you can use the `docker network connect` command after your container is created:

```console
$ docker run -d -p 80:80 -v /var/run/docker.sock:/tmp/docker.sock:ro \
    --name my-ha-proxy --net my-network gzmaxsum/ha-proxy
$ docker network connect my-other-network my-ha-proxy
```

In this example, the `my-ha-proxy` container will be connected to `my-network` and `my-other-network` and will be able to proxy to other containers attached to those networks.

### Internet vs. Local Network Access (different from nginx-proxy)

If you allow traffic from the public internet to access your `ha-proxy` container, you may want to restrict some containers to the internal network only, so they cannot be accessed from the public internet.  On containers that should be restricted to the internal network, you should set the label `ha-proxy.network_access=internal`.  By default, the *internal* network is defined as `127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16`. **Currently, no custom settings for internal network is available.**

When internal-only access is enabled, external clients with be denied with an `HTTP 403 Forbidden`

### Connection Control (Additional feature)

**This is an additional feature that does not exist in nginx-proxy.**

You can control the connection behavior in different virtual hosts.

There are 4 modes of connection:

1. Tunnel
This mode disables any HTTP processing past the first request and the first response. Therefor, the connection would not be actively closed by HAProxy and will maintained forever unless closed by any terminal. If the client request to upgrade to WebSocket, HAProxy will switch to this mode.
To use this mode explicitly, set the label `ha-proxy.connection=tunnel`.
2. Keep-Alive
In this mode, HAProxy will try to persist connection. For each connection it processes each request and response, and leaves the connection idle on both sides between the end of a response and the start of a new request. However, there is a timeout to disconnect if the connection is idle for a set period of time.
To use this mode explicitly, set the label `ha-proxy.connection=keep-alive`.
3. Server-Close (Default)
This mode close connections on the server side immediately while keeping the ability to support HTTP keep-alive and pipelining on the client side. This provides the lowest latency on the client side (slow network) and the fastest session reuse on the server side to save server resources. This is the default mode in HA-proxy.
To use this mode explicitly, set the label `ha-proxy.connection=server-close`.
4. Close
In this mode, HAProxy would check if a "Connection: close" header is already set in each direction, and will add one if missing. Each end should react to this by actively closing the TCP connection after each transfer, thus resulting in a switch to the HTTP close mode.
To use this mode explicitly, set the label `ha-proxy.connection=close`.

These modes are an extension of `option http-tunnel`, `option http-keep-alive`, `option http-server-close` and `option httpclose` in HAProxy configuration. Check [HAProxy](https://cbonte.github.io/haproxy-dconv/1.8/configuration.html#option%20http-server-close) document to have further understanding on different modes.

### SSL Backends

If you would like the reverse proxy to connect to your backend using HTTPS instead of HTTP, set `ha-proxy.proto=https` on the backend container.

> Note: If you use `ha-proxy.proto=https` and your backend container exposes port 80 and 443, `nginx-proxy` will use HTTPS on port 80.  This is almost certainly not what you want, so you should also include `ha-proxy.port=443`.


### Default Host

To set the default host for HAProxy use the env var `DEFAULT_HOST=foo.bar.com` for example

    $ docker run -d -p 80:80 -e DEFAULT_HOST=foo.bar.com -v /var/run/docker.sock:/tmp/docker.sock:ro gzmaxsum/ha-proxy

> Note: Default host support only regular domain. Multiple host, regular expression and wildcard domain is not supported. If you have used regular expression or wildcard in container and want to use it as default host, an additional plain domain is need to set on the container. Default host should exactly match (one of) the host. 

### Separate Containers (different from nginx-proxy)

HA-proxy can also be run as two separate containers using the [jwilder/docker-gen](https://index.docker.io/u/jwilder/docker-gen/)
image and the official [HAProxy](https://registry.hub.docker.com/_/haproxy/) image.

You may want to do this to prevent having the docker socket bound to a publicly exposed container service.

You can demo this pattern with docker-compose:

```console
$ docker-compose --file docker-compose-separate-containers.yml up
$ curl -H "Host: whoami.local" localhost
I'm 5b129ab83266
```

To run nginx proxy as a separate container you'll need to have [haproxy.tmpl](https://github.com/max-sum/ha-proxy/blob/master/templates/haproxy.tmpl), [certs.tmpl](https://github.com/max-sum/ha-proxy/blob/master/templates/certs.tmpl) and [docker-gen-separate.conf](https://github.com/max-sum/ha-proxy/blob/master/docker-gen-separate.conf) on your host system.

**Note: starting order is different from nginx-proxy**
First start the docker-gen container with a volume, templates (stored in ./templates/) and the config file:
```
$ docker run \
    -v /tmp/HAProxy:/etc/haproxy \
    -v /var/run/docker.sock:/tmp/docker.sock:ro \
    -v $(pwd)/docker-gen-separate.conf:/etc/docker-gen/docker-gen.conf:ro \
    -v $(pwd)/templates:/etc/docker-gen/templates:ro \
    -t jwilder/docker-gen -config /etc/docker-gen/docker-gen.conf
```

Then start haproxy with the shared volume:

    $ docker run -d -p 80:80 --name haproxy -v /tmp/haproxy:/etc/haproxy -t haproxy:alpine

Finally, start your containers with `ha-proxy.host` label.
Finally, start your containers with `ha-proxy.host` label.

    $ docker run -l ha-proxy.host=foo.bar.com  ...

### SSL Support using letsencrypt (different from nginx-proxy)

HA-proxy provides a hook for ACME-compatible clients. Any container that has the label `ha-proxy.acme-provider` set would receive requests for /.well-known/acme-challenge/ URL. ACME provider container could also set `ha-proxy.proto` and `ha-proxy.port` like normal ones.

### SSL Support (different from nginx-proxy)

SSL is supported using single host, wildcard and SNI certificates using naming conventions forcertificates or optionally specifying a cert name (for SNI) as an environment variable.

To enable SSL:

    $ docker run -d -p 80:80 -p 443:443 -v /path/to/certs:/etc/haproxy/certs -v /var/run/docker.sock:/tmp/docker.sock:ro gzmaxsum/ha-proxy

The contents of `/path/to/certs` should contain the certificates and private keys **concatenated in one file** for any virtual hosts in use. See [HAProxy](https://cbonte.github.io/haproxy-dconv/1.8/configuration.html#5.1-crt) document to get more informantion.
The certificate and keys should be named after the virtual host with **a `.pem` extension**.
For example, a container with `ha-proxy.host=foo.bar.com` should have a `foo.bar.com.pem` file in the certs directory.

> Note: If you have muliple certificates for different cipher suites (RSA, DSA, ECDSA) used by one virtual host, you should name them with `.pem.rsa`, `.pem.dsa` or `.pem.ecdsa` accordingly. Noted that the suffix after `.pem` is not recognized as a part of `CERT_NAME`. See the SNI part below.

If you are running the container in a virtualized environment (Hyper-V, VirtualBox, etc...), /path/to/certs must exist in that environment or be made accessible to that environment.
By default, Docker is not able to mount directories on the host machine to containers running in a virtual machine.

#### Diffie-Hellman Groups (different from nginx-proxy)

Diffie-Hellman groups are enabled by default.
You can place a different `dhparam.pem` file at `/etc/haproxy/certs/dhparam.pem` to override the default cert.
To use custom `dhparam.pem` files per-virtual-host, **you should concatenate it together with the certificate and key**.
For example, a container with `ha-proxy.host=foo.bar.com` should have a **`foo.bar.com.pem`** file in the `/etc/haproxy/certs`  directory, **containing certificate, key and dhparam in the file**. **If you have RSA and ECDSA version of certificate, both should add `dhparam.pem` in the file.**

The file format would be (ECDSA version shown):
```
-----BEGIN CERTIFICATE-----
MIIGjTCCBXWgAwIBAgIMIwQ2xOJA3Mcu8FfLMA0GCSqGSIb3DQEBCwUAMEwxCzAJ
...
aYLwHBknM7WNqKmiFYbM2Chjd5tZDu9I/2h+HgHZjmwBmYR2HrHw==
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIIETTCCAzWgAwIBAgILBAAAAAABRE7wNjEwDQYJKoZIhvcNAQELBQAwVzELMAkG
...
Uw==
-----END CERTIFICATE-----
-----BEGIN EC PARAMETERS-----
...
-----END EC PARAMETERS-----
-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIB7/vJT61Rj...2yolCapg2j0BE9YNuDKZW++3GgBEojkOhA==
-----END EC PRIVATE KEY-----
-----BEGIN DH PARAMETERS-----
MIIBCAKCAQEAgpepBiSgggPt0sxN2swUq3Zj4nepuHIBDFJFR+FH7f1yh+rXoKHI
...
Qh/Dqggb+cpucC5S4yAmz2f4+FKxPhoa4wIBAg==
-----END DH PARAMETERS-----
```

> NOTE: If you don't have a `dhparam.pem` file at `/etc/haproxy/dhparam/dhparam.pem`, **HAProxy would generate one automantically**.

> COMPATIBILITY WARNING: The default generated `dhparam.pem` key is 2048 bits for A+ security.  Some 
> older clients (like Java 6 and 7) do not support DH keys with over 1024 bits.  In order to support these
> clients, you must either provide your own `dhparam.pem`, or tell `HA-proxy` to generate a 1024-bit
> key on startup by passing `-e DHPARAM_BITS=1024`.

In the separate container setup, **the offical [HAProxy](https://registry.hub.docker.com/_/haproxy/) image will generate a
`dhparam` by its own. And you can also pass `DHPARAM_BITS` to the coresponding `docker-gen` container.**

#### Wildcard Certificates

Wildcard certificates and keys should be named after the domain name with a `.pem` extension.
For example `ha-proxy.host=foo.bar.com` would use cert name `bar.com.pem`.

#### SNI (different from nginx-proxy)

If your certificate(s) supports multiple domain names, you can start a container with `CERT_NAME=<name>` to identify the certificate to be used.  For example, a certificate for `*.foo.com` and `*.bar.com` could be named **`shared.pem`**.  A container running with `ha-proxy.host=foo.bar.com` and **`ha-proxy.cert_name=shared.pem`** will then use this shared cert.

**Difference from nginx-proxy**

If you have multiple version of shared certificated for RSA, DSA or/and ECDSA, you only need to care about the common name. For example, if you have certificates named `shared.pem.rsa` and `shared.pem.ecdsa`, you only need to set `CERT_NAME=shared.pem` to use both.
You can see the [HAProxy](https://cbonte.github.io/haproxy-dconv/1.8/configuration.html#5.1-crt) document for bundled certificate settings.

#### How SSL Support Works

The default SSL cipher configuration is based on the [Mozilla intermediate profile](https://wiki.mozilla.org/Security/Server_Side_TLS#Intermediate_compatibility_.28default.29) which
should provide compatibility with clients back to Firefox 1, Chrome 1, IE 7, Opera 5, Safari 1,
Windows XP IE8, Android 2.3, Java 7.  Note that the DES-based TLS ciphers were removed for security.
The configuration also enables HSTS, PFS, OCSP stapling and SSL session caches.  Currently TLS 1.0, 1.1 and 1.2
are supported.  TLS 1.0 is deprecated but its end of life is not until June 30, 2018.  It is being
included because the following browsers will stop working when it is removed: Chrome < 22, Firefox < 27,
IE < 11, Safari < 7, iOS < 5, Android Browser < 5.

If you don't require backward compatibility, you can use the [Mozilla modern profile](https://wiki.mozilla.org/Security/Server_Side_TLS#Modern_compatibility)
profile instead by including the label `ha-proxy.ssl_policy=Mozilla-Modern` to your container.
This profile is compatible with clients back to Firefox 27, Chrome 30, IE 11 on Windows 7,
Edge, Opera 17, Safari 9, Android 5.0, and Java 8.

Other policies available through the `ha-proxy.ssl_policy` label are [`Mozilla-Old`](https://wiki.mozilla.org/Security/Server_Side_TLS#Old_backward_compatibility)
and the [AWS ELB Security Policies](https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/elb-security-policy-table.html)
`AWS-TLS-1-2-2017-01`, `AWS-TLS-1-1-2017-01`, `AWS-2016-08`, `AWS-2015-05`, `AWS-2015-03` and `AWS-2015-02`.

Note that the `Mozilla-Old` policy should use a 1024 bits DH key for compatibility but this container generates
a 2048 bits key. The [Diffie-Hellman Groups](#diffie-hellman-groups) section details different methods of bypassing
this, either globally or per virtual-host.

The default behavior for the proxy when port 80 and 443 are exposed is as follows:

* If a container has a usable cert, port 80 will redirect to 443 for that container so that HTTPS
is always preferred when available.
* If the container does not have a usable cert, a 503 will be returned.

Note that in the latter case, a browser may get an connection error as no certificate is available
to establish a connection.  A self-signed or generic cert named `default.crt` and `default.key`
will allow a client browser to make a SSL connection (likely w/ a warning) and subsequently receive
a 500.

To serve traffic in both SSL and non-SSL modes without redirecting to SSL, you can include thelabel `ha-proxy.https_method=noredirect` (the default is `ha-proxy.https_method=redirect`).  You can also disable the non-SSL site entirely with `ha-proxy.https_method=nohttp`, or disable the HTTPS site with `ha-proxy.https_method=nohttps`. `ha-proxy.https_method` must be specified on each container for which you want to override the default behavior.  If `ha-proxy.https_method=noredirect` is used, Strict Transport Security (HSTS) is disabled to prevent HTTPS users from being redirected by the client.  If you cannot get to the HTTP site after changing this setting, your browser has probably cached the HSTS policy and is automatically redirecting you back to HTTPS.  You will need to clear your browser's HSTS cache or use an incognito window / different browser.

By default, [HTTP Strict Transport Security (HSTS)](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Strict-Transport-Security) 
is enabled with `max-age=31536000` for HTTPS sites.  You can disable HSTS with the label `ha-proxy.hsts=off` or use a custom HSTS configuration like `HSTS=max-age=31536000; includeSubDomains; preload`.  
*WARNING*: HSTS will force your users to visit the HTTPS version of your site for the `max-age` time - even if they type in `http://` manually.  The only way to get to an HTTP site after receiving an HSTS response is to clear your browser's HSTS cache.

### Basic Authentication Support (different from nginx-proxy)

**There is no basic authentication support in HA-proxy now.**

### Custom HAProxy Configuration (different from nginx-proxy)

**Currently, you cannot add custom HAProxy configurations.**
However, you can manually moddify the templates `haproxy.tmpl` and `certs.tmpl` to change the default bahaviors.

### Contributing

Before submitting pull requests or issues, please check github to make sure an existing issue or pull request is not already open.

#### Running Tests Locally

To run tests, you need to prepare the docker image to test which must be tagged `gzmaxsum/ha-proxy:test`:

    docker build -f Dockerfile -t gzmaxsum/ha-proxy:test .  # build the Alpline variant image

and call the [test/pytest.sh](test/pytest.sh) script again.


If your system has the `make` command, you can automate those tasks by calling:

    make test

You can learn more about how the test suite works and how to write new tests in the [test/README.md](test/README.md) file.
You can learn more about how the test suite works and how to write new tests in the [test/README.md](test/README.md) file.

### Major difference from nginx-proxy

Due to the HAProxy configuration, some of behavior of HA-proxy is different from nginx-proxy.

Feature added:

- Connection option
- Health check (HAProxy nature)

Feature removed:

- Custom configuration (per host / default location / proxy)
- Wildcard host (Only support wildcard in the beginning)
- Let's Encrypt (developing)

Behavior difference:

- Use labels instead of environment variables (except for ha-proxy container)
See the table below
- Format of SSL/TLS Certifiate and DH parm is different.

#### Comparison Tabel

| nginx-proxy        | HA-proxy                      |
| ------------------ | ----------------------------- |
| Env.VIRTUAL_HOST   | Label.ha-proxy.host           |
| Env.VIRTUAL_PORT   | Label.ha-proxy.port           |
| Env.VIRTUAL_PROTO  | Label.ha-proxy.proto          |
| Env.HTTPS_METHOD   | Label.ha-proxy.https_method   |
| Env.HSTS           | Label.ha-proxy.hsts           |
| Env.CERT_NAME      | Label.ha-proxy.cert_name      |
| Env.SSL_POLICY     | Label.ha-proxy.ssl_policy     |
| Env.NETWORK_ACCESS | Label.ha-proxy.network_access |
| N/A                | Label.ha-proxy.connection     |
| Env.ENABLE_IPV6    | Env.ENABLE_IPV6               |
| Env.DEFAULT_HOST   | Env.DEFAULT_HOST              |

