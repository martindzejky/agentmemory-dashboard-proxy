# agentmemory-dashboard-proxy

AuthCrunch/Caddy proxy in front of the private AgentMemory dashboard.

Public traffic lands on `memory-dashboard.martinjakubik.com`. Visitors who are not signed in get a username/password form. After login, a signed session cookie keeps the browser authenticated, and the proxy forwards requests to AgentMemory over Railway private networking at `http://agentmemory.railway.internal:3113`.

AgentMemory itself stays in [`martindzejky/agentmemory`](https://github.com/martindzejky/agentmemory). This service is only the auth edge.

## Behavior

1. Caddy listens on Railway's `PORT`.
2. AuthCrunch serves `/auth*` and issues a session cookie signed with `JWT_SHARED_KEY`.
3. Authorized requests go to `UPSTREAM_URL`.

Credentials and shared secrets come from environment variables only. Nothing sensitive lives in the image or in git.

## Environment

| Variable | Purpose |
| --- | --- |
| `AUTHP_ADMIN_USER` | Bootstrap admin username when `/data/users.json` is missing |
| `AUTHP_ADMIN_EMAIL` | Bootstrap admin email |
| `AUTHP_ADMIN_SECRET` | Bootstrap admin password |
| `JWT_SHARED_KEY` | Shared secret for session tokens |
| `COOKIE_DOMAIN` | Cookie domain (`memory-dashboard.martinjakubik.com`) |
| `UPSTREAM_URL` | Backend (`http://agentmemory.railway.internal:3113`) |
| `PORT` | Listen port (Railway sets this) |

Copy `.env.example` for local runs. Keep real values out of git.

## Container

The image builds Caddy with AuthCrunch (`caddy-security`) pinned:

- Caddy `2.11.4`
- caddy-security `v1.1.64`

```bash
docker build -t agentmemory-dashboard-proxy .
docker run --rm -p 8080:8080 --env-file .env agentmemory-dashboard-proxy
```

## Layout

- `Caddyfile` — login portal, authorization policy, reverse proxy
- `Dockerfile` — pinned xcaddy build
- `.cursor/` — Cursor cloud agent environment (agentfiles refresh only)

## Railway

This repo runs as its own Railway service with the custom domain `memory-dashboard.martinjakubik.com`. AgentMemory stays private on the internal network. Only this proxy is public.
