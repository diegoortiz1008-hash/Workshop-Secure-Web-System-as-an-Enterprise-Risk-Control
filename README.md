# Workshop: Secure Web System as an Enterprise Risk Control

A small web system that turns identity management, authorization, encryption in transit and
audit logging into concrete, verifiable risk controls:

- **React frontend** (Vite) that authenticates users with **Auth0** and obtains an access token.
- **Spring Boot backend** protected as an **OAuth 2.0 Resource Server** that validates the JWT
  (signature, issuer, audience, expiry) and exposes a single protected endpoint.
- **Public HTTPS** address with **Duck DNS + Apache HTTP Server + Let's Encrypt**.

**Deployed URL:** https://YOUR-SUBDOMAIN.duckdns.org

---

## Architecture

```
Browser
  │ login and access token
  ▼
Auth0 ───────────────► React frontend ── Bearer token ──► Spring Boot API
                                                        │
Internet ── Duck DNS ── Apache + TLS ──────────────────┘
```

| Component | Where it runs | Exposure |
|-----------|---------------|----------|
| React SPA (static files) | Apache `/var/www/enterprise-risk-frontend` | 443 (HTTPS) |
| Spring Boot API | systemd service `enterprise-risk-api`, user `riskapi` | `127.0.0.1:8080` only |
| Reverse proxy | Apache `ProxyPass /api/ → 127.0.0.1:8080/api/` | 80 → redirect, 443 |
| TLS certificate | Let's Encrypt via Certbot (auto-renewal) | — |
| DNS | Duck DNS `YOUR-SUBDOMAIN.duckdns.org` | — |

## Repository structure

```
backend/                     Spring Boot 4 / Java 21 resource server
  src/main/java/.../SecurityConfig.java          JWT validation, CORS, deny-by-default
  src/main/java/.../controllers/RiskController.java   GET /api/risk-status
  src/main/resources/application.properties       issuer, audience, loopback binding
  src/test/java/.../RiskControllerSecurityTests.java  401 / 200 / 403 tests
frontend/                    React + Vite + @auth0/auth0-react
  src/main.jsx               Auth0Provider (domain, clientId, audience)
  src/App.jsx                login, call protected API, logout
  .env.example               local variables (copy to .env.local)
  .env.production.example    production variables (copy to .env.production.local)
deploy/
  apache/enterprise-risk.conf                 HTTP virtual host (certbot adds HTTPS)
  apache/enterprise-risk-le-ssl.conf.reference  resulting HTTPS vhost + security headers
  systemd/enterprise-risk-api.service         backend service unit
  scripts/server-setup.sh    packages, firewall (ufw), service user, Apache modules
  scripts/duckdns-update.sh  keeps the Duck DNS record updated (cron)
  scripts/deploy.sh          installs JAR, frontend and Apache vhost on the server
  scripts/verify.sh          Part 7 checklist from any machine
docs/evidence/               screenshots required by the deliverables
```

---

## Part 1 — Auth0 configuration

1. **API** (Applications → APIs): `Enterprise Risk Lab API`, identifier/audience
   `https://enterprise-risk-api`, signing algorithm `RS256`.
2. **Permission**: `read:risk` — *Read the protected risk status*.
3. **SPA** (Applications → Applications): `Enterprise Risk Lab Frontend`, with
   - Allowed Callback URLs: `http://localhost:5173,https://YOUR-SUBDOMAIN.duckdns.org`
   - Allowed Logout URLs: `http://localhost:5173,https://YOUR-SUBDOMAIN.duckdns.org`
   - Allowed Web Origins: `http://localhost:5173,https://YOUR-SUBDOMAIN.duckdns.org`
4. **Grant access**: SPA → APIs → Enterprise Risk Lab API → *User-Delegated Access* →
   Grant `read:risk`. (Client Access is for machine-to-machine apps; it does not authorize a browser login.)
5. **Test user**: Authentication → Database → Users.

Public values used by the client (no client secret in the browser):

```
AUTH0_DOMAIN=dev-fgdtxscrn2rgu4z0.us.auth0.com
AUTH0_CLIENT_ID=<SPA client id>
AUTH0_AUDIENCE=https://enterprise-risk-api
```

## Part 2/3 — Run locally

**Backend** (Java 21):

```bash
cd backend
./mvnw test             # 401 without token, 200 with token, 403 for other paths
./mvnw spring-boot:run
curl -i http://localhost:8080/api/risk-status     # → 401 Unauthorized (expected)
curl http://localhost:8080/actuator/health        # → {"status":"UP"}
```

**Frontend** (Node 20+):

```bash
cd frontend
cp .env.example .env.local      # then set VITE_AUTH0_CLIENT_ID
npm install
npm run dev                     # http://localhost:5173
```

Log in, press **Call protected API**, and the response should be:

```json
{
  "status": "protected",
  "subject": "auth0|...",
  "control": "JWT validation and authenticated access"
}
```

## Part 4 — Server and Duck DNS

1. Create a Duck DNS subdomain and point it to the server's public IP.
2. At the cloud provider / router, allow inbound **TCP 80 and 443 only** (plus SSH restricted to your IP).
3. On the Ubuntu server (non-root user with sudo, default credentials changed):

```bash
./deploy/scripts/server-setup.sh
# Duck DNS updater (token kept in a root-only file, never in the repo)
sudo mkdir -p /opt/duckdns && sudo cp deploy/scripts/duckdns-update.sh /opt/duckdns/
echo "YOUR_DUCKDNS_TOKEN" | sudo tee /opt/duckdns/duckdns.token >/dev/null
sudo chmod 600 /opt/duckdns/duckdns.token && sudo chmod 700 /opt/duckdns/duckdns-update.sh
(sudo crontab -l 2>/dev/null; echo "*/5 * * * * /opt/duckdns/duckdns-update.sh YOUR-SUBDOMAIN") | sudo crontab -
```

4. Build on a trusted machine:

```bash
cd frontend && cp .env.production.example .env.production.local   # set client id + domain
npm ci && npm run build
cd ../backend && ./mvnw clean package
```

5. Copy `backend/target/enterprise-risk-api.jar`, `frontend/dist/` and `deploy/` to the server over SSH (`scp`/`rsync`).

## Part 5/6 — Deploy backend, Apache and HTTPS

```bash
./deploy/scripts/deploy.sh YOUR-SUBDOMAIN.duckdns.org
sudo certbot --apache -d YOUR-SUBDOMAIN.duckdns.org    # choose "redirect HTTP to HTTPS"
sudo certbot renew --dry-run
```

`deploy.sh` performs the workshop steps: copies the JAR to `/opt/enterprise-risk-api/app.jar`
owned by `riskapi`, installs and starts the systemd unit, copies the SPA to
`/var/www/enterprise-risk-frontend`, enables the Apache vhost and checks
`curl http://127.0.0.1:8080/actuator/health`.

## Part 7 — Verification checklist

Run `./deploy/scripts/verify.sh YOUR-SUBDOMAIN.duckdns.org` from your laptop.

- [ ] Unauthenticated requests to `/api/risk-status` return **401**.
- [ ] A logged-in user can call `/api/risk-status` from the frontend.
- [ ] The backend validates the JWT **issuer** and **audience**.
- [ ] The application is available at `https://YOUR-SUBDOMAIN.duckdns.org`.
- [ ] The browser shows a valid certificate and HTTPS lock icon.
- [ ] Port **8080 is not reachable** from the public internet.
- [ ] `sudo certbot renew --dry-run` succeeds.

### Evidence

| Deliverable | File |
|-------------|------|
| Successful authenticated API call | `docs/evidence/authenticated-api-call.png` |
| Valid certificate | `docs/evidence/valid-certificate.png` (or `verify.sh` output) |

---

## Risk-control reflection

| Control | Risk reduced | How it is implemented | Evidence |
|---------|--------------|-----------------------|----------|
| Auth0 authentication | Impersonation and weak credential handling | Passwords are never handled by our code; Auth0 Universal Login with Authorization Code + PKCE | Auth0 login flow and user identity in the UI |
| JWT validation at the API | Unauthorized API access | `oauth2ResourceServer().jwt()` checks RS256 signature against the tenant JWKS, `exp`, and `iss`; `/api/**` requires authentication, everything else `denyAll()` | `401` without a valid token; tests in `RiskControllerSecurityTests` |
| Audience validation | Token reuse against another API | `spring.security.oauth2.resourceserver.jwt.audiences=https://enterprise-risk-api` | A token for another audience is rejected with `401` |
| HTTPS with a valid certificate | Credential or token exposure in transit | Let's Encrypt certificate, HTTP→HTTPS redirect, HSTS | Browser certificate details / `openssl s_client` |
| Apache reverse proxy | Direct exposure of the application port | Spring Boot binds to `127.0.0.1:8080`; only `/api/` is proxied; firewall allows 80/443 | `verify.sh` shows port 8080 closed |
| Restricted CORS | Cross-origin abuse of the API from untrusted sites | Exact origins only, `GET` only, no wildcards | Browser blocks calls from other origins |
| Least privilege | Impact of a compromised process | Dedicated `riskapi` system user without shell; systemd hardening (`NoNewPrivileges`, `ProtectSystem`) | `systemctl show enterprise-risk-api -p User` |
| Central service logs | Delayed incident investigation | `AUDIT` log line per access with the token subject (never the token) | `journalctl -u enterprise-risk-api \| grep AUDIT` |

**Authentication vs. authorization.** Authentication answers *who are you?* — Auth0 verifies the
user's credentials and issues tokens. Authorization answers *what may you do?* — the API decides,
from a validated access token issued for its audience, whether the request is allowed. In this
system the API only requires an authenticated token; a natural next step is permission-based
authorization (e.g., `hasAuthority("SCOPE_read:risk")`) once RBAC is enabled in Auth0.

## Security notes

- Never commit `.env.local`, `.env.production.local`, server credentials, Auth0 secrets or Duck DNS tokens (all ignored by `.gitignore`).
- An SPA uses the Auth0 **client ID**, never a client secret.
- CORS is restricted to the exact development and production origins.
- Access tokens are treated as sensitive: not displayed, logged or stored manually (the SDK keeps them in memory).
- Server accounts follow least privilege, and OS updates are applied automatically (`unattended-upgrades`).

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Client "..." is not authorized to access resource server` | Grant **User-Delegated Access** to the SPA (Part 1, step 4). |
| `API returned 401` | `issuer-uri` must include `https://` and the trailing slash; audience must be exactly `https://enterprise-risk-api`; restart the backend. |
| CORS error from `localhost:5173` | Check `app.cors.allowed-origins` and restart the backend. |
| `Callback URL mismatch` in production | Add the HTTPS Duck DNS URL to Callback, Logout and Web Origins in Auth0. |

## References

- [Auth0 React quickstart](https://auth0.com/docs/quickstart/spa/react)
- [Spring Security OAuth 2.0 Resource Server — JWT](https://docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/jwt.html)
- [Certbot documentation](https://eff-certbot.readthedocs.io/)
- [Duck DNS](https://www.duckdns.org/)
