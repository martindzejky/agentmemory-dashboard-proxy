# agentmemory-dashboard-proxy

AuthCrunch/Caddy proxy in front of the private AgentMemory dashboard.

Public traffic lands on `memory-dashboard.martinjakubik.com`. Visitors who are not signed in get a username/password form. After login, a signed session cookie keeps the browser authenticated, and the proxy forwards requests to AgentMemory over Railway private networking at `http://agentmemory.railway.internal:3113`.

After authentication, upstream `Authorization` is overwritten with `Bearer $AGENTMEMORY_VIEWER_PROXY_SECRET`. Do not reuse the main AgentMemory API/HMAC secret here.

AgentMemory itself stays in [`martindzejky/agentmemory`](https://github.com/martindzejky/agentmemory). This service is only the auth edge.

## Behavior

1. Caddy listens on Railway's `PORT` (admin API and automatic HTTPS off; Railway terminates TLS).
2. `GET /healthz` is public for Railway health checks.
3. AuthCrunch serves `/auth*` and issues a session cookie signed with `JWT_SHARED_KEY`.
4. Authorized requests go to `UPSTREAM_URL` with the viewer-proxy bearer.
5. Responses set HSTS, `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, a restrictive referrer policy, and a permissions policy.

Credentials and shared secrets come from environment variables only. Nothing sensitive lives in the image or in git. `/data` (AuthCrunch user DB) is gitignored.

## Security

- Session cookies last 24 hours; AuthCrunch accepts tokens from cookies only (not query params or request headers).
- Protected dashboard/API responses and `/auth*` set `Cache-Control: no-store` and `Pragma: no-cache`. `/healthz` stays public and is not given those cache headers.
- Login (`redirect_url`) and logout (`redirect_uri`) targets are trusted only for the exact `COOKIE_DOMAIN` host, with paths under `/`. Suffix, partial, wildcard, and external-domain redirects are rejected.
- Upstream `Authorization` is overwritten with the viewer-proxy bearer; AgentMemory is not exposed publicly.

## Environment

| Variable | Purpose |
| --- | --- |
| `AUTHP_ADMIN_USER` | Local admin username |
| `AUTHP_ADMIN_EMAIL` | Local admin email |
| `AUTHP_ADMIN_PASSWORD_HASH` | AuthCrunch password hash (`bcrypt:<cost>:<hash>`) |
| `JWT_SHARED_KEY` | Shared secret for session tokens |
| `AGENTMEMORY_VIEWER_PROXY_SECRET` | Bearer sent to the AgentMemory viewer |
| `COOKIE_DOMAIN` | Cookie domain (`memory-dashboard.martinjakubik.com`) |
| `UPSTREAM_URL` | Backend (`http://agentmemory.railway.internal:3113`) |
| `PORT` | Listen port (Railway sets this) |

Generate the password hash with AuthCrunch's `authdbctl` ([docs](https://docs.authcrunch.com/docs/authenticate/local/static-users)):

```bash
authdbctl generate password hash --cost 10
```

Copy `.env.example` for local runs. Keep real values out of git.

## Container

Pinned Caddy `2.11.4` + caddy-security `v1.1.64`, runs as non-root:

```bash
docker build -t agentmemory-dashboard-proxy .
docker run --rm -p 8080:8080 --env-file .env agentmemory-dashboard-proxy
```

## Layout

- `Caddyfile` — login portal, authorization, cache/redirect hardening, reverse proxy
- `Dockerfile` — pinned xcaddy build, non-root user
- `railway.json` — `/healthz` health check
- `.cursor/` — Cursor cloud agent environment (Docker-in-Docker + agentfiles refresh)

## Railway

Own Railway service at `memory-dashboard.martinjakubik.com`. AgentMemory stays private on the internal network. Only this proxy is public.
