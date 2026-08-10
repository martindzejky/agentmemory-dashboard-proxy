# Production image for the AgentMemory dashboard auth proxy.
# Pins match the AuthCrunch upstream container (caddy + caddy-security).

ARG CADDY_VERSION=2.11.4
ARG CADDY_SECURITY_VERSION=v1.1.64

FROM caddy:${CADDY_VERSION}-builder AS builder

ARG CADDY_SECURITY_VERSION

RUN xcaddy build \
    --with github.com/greenpau/caddy-security@${CADDY_SECURITY_VERSION}

FROM caddy:${CADDY_VERSION}

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
COPY Caddyfile /etc/caddy/Caddyfile

# Official caddy image runs as root; create a dedicated user for Railway
# (PORT is unprivileged). /data holds AuthCrunch users.json.
RUN set -eux; \
    addgroup -S -g 1000 caddy; \
    adduser -S -u 1000 -G caddy -H -D -s /sbin/nologin caddy; \
    mkdir -p /data /config/caddy /data/caddy; \
    chown -R caddy:caddy /data /config /etc/caddy

USER caddy

EXPOSE 8080

CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
