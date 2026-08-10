# agentmemory-dashboard-proxy

AuthCrunch/Caddy proxy in front of the private AgentMemory dashboard.

Public traffic lands on `memory-dashboard.martinjakubik.com`. Visitors who are not signed in get a username/password form. After login, a signed session cookie keeps the browser authenticated, and the proxy forwards requests to AgentMemory over Railway private networking at `http://agentmemory.railway.internal:3113`.

Authenticated upstream calls overwrite `Authorization` with `Bearer $AGENTMEMORY_VIEWER_PROXY_SECRET`. That value is a dedicated viewer-proxy secret — never the main AgentMemory API/HMAC secret.

AgentMemory itself stays in [`martindzejky/agentmemory`](https://github.com/martindzejky/agentmemory). This service is only the auth edge.

## Behavior

1. Caddy listens on Railway's `PORT` with admin API and automatic HTTPS disabled (Railway terminates TLS).
2. `GET /healthz` is public for Railway health checks.
3. AuthCrunch serves `/auth*` and issues a session cookie signed with `JWT_SHARED_KEY`.
4. Authorized requests go to `UPSTREAM_URL` with the viewer-proxy bearer header.
5. Responses include HSTS, frame denial, MIME-sniffing protection, a restrictive referrer policy, and a locked-down permissions policy.

Credentials and shared secrets come from environment variables only. Nothing sensitive lives in the image or in git. Generated AuthCrunch user databases under `/data` are gitignored.

## Environment

| Variable | Purpose |
| --- | --- |
| `AUTHP_ADMIN_USER` | Local admin username |
| `AUTHP_ADMIN_EMAIL` | Local admin email |
| `AUTHP_ADMIN_PASSWORD_HASH` | AuthCrunch password hash (`bcrypt:<cost>:<hash>`), not plaintext |
| `JWT_SHARED_KEY` | Shared secret for session tokens |
| `AGENTMEMORY_VIEWER_PROXY_SECRET` | Bearer token sent to the AgentMemory viewer (not `AGENTMEMORY_SECRET`) |
| `COOKIE_DOMAIN` | Cookie domain (`memory-dashboard.martinjakubik.com`) |
| `UPSTREAM_URL` | Backend (`http://agentmemory.railway.internal:3113`) |
| `PORT` | Listen port (Railway sets this) |

Generate the password hash with AuthCrunch's `authdbctl` ([docs](https://docs.authcrunch.com/docs/authenticate/local/static-users)):

```bash
authdbctl generate password hash --cost 10
```

Set `AUTHP_ADMIN_PASSWORD_HASH` to the full `bcrypt:<cost>:<hash>` value. Copy `.env.example` for local runs; keep real values out of git.

## Container

Pinned build, non-root runtime user:

- Caddy `2.11.4`
- caddy-security `v1.1.64`

```bash
docker build -t agentmemory-dashboard-proxy .
docker run --rm -p 8080:8080 --env-file .env agentmemory-dashboard-proxy
```

## Layout

- `Caddyfile` — login portal, authorization policy, security headers, reverse proxy
- `Dockerfile` — pinned xcaddy build, non-root runtime user
- `railway.json` — Dockerfile builder + `/healthz` health check
- `.cursor/` — Cursor cloud agent environment (agentfiles refresh only)

## Railway

This repo runs as its own Railway service with the custom domain `memory-dashboard.martinjakubik.com`. AgentMemory stays private on the internal network. Only this proxy is public. `railway.json` points health checks at `/healthz`.
