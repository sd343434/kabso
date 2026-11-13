# LiveKit single-node deployment — Phase 1 runbook (D350)

Status: **PREPARED, not deployed.** No server exists, nothing was bought, no DNS record was added. Everything below
was written and checked locally (§9); every server step is still to be done. Companion documents:
[`TURN_NETWORK_DESIGN.md`](./TURN_NETWORK_DESIGN.md) (ports, 443, TLS), [`PHASE_1_TEST_PLAN.md`](./PHASE_1_TEST_PLAN.md)
(what we test and how), [`SINGLE_NODE_CAPACITY_RESULTS.md`](./SINGLE_NODE_CAPACITY_RESULTS.md) (empty results template),
[`SURGE_AND_OVERFLOW_PLAN.md`](./SURGE_AND_OVERFLOW_PLAN.md) (sudden load), and the Phase-0 documents in this folder.

Labels: **VERIFIED** = read in an official source or run here (named); **OWNER** = the owner's statement;
**ESTIMATE** = reasoning; **TARGET** = an acceptance goal, not a result.

## 1. What Phase 1 is

One **Hetzner EX44** (OWNER: Intel i5-13500, 14 cores / 20 threads, 64 GB DDR4, 2 × 512 GB NVMe, 1 Gbit/s guaranteed,
unlimited traffic, FSN1, Ubuntu 24.04; **$74/month, $0 setup, VAT 0 % on his account, prices in USD**, seen on his
account 2026-11-09) runs **only** LiveKit media: LiveKit v1.13.11 with embedded TURN, a layer-4 TLS front, node_exporter.
The API, PostgreSQL and Redis stay on the current staging server; staging's own LiveKit v1.9.1 keeps running until we
switch, and stays as the rollback.

Goals: (1) prove connectivity on real networks (UDP, TCP fallback, TURN/UDP, TURN/TLS on 443); (2) prove the app's
room lifecycle and webhook against a remote media node; (3) measure one node's ceiling with separate load generators
(numbers go into `SINGLE_NODE_CAPACITY_RESULTS.md`); (4) produce the production values for node limits and the capacity
guard. Production later (OWNER): **5 × EX44 media + 1 × EX63 app/DB** (EX63: $174/month + $84 setup, seen on his
account 2026-11-09).

## 2. Decisions (summary; reasons in TURN_NETWORK_DESIGN.md)

| Topic | Decision |
|---|---|
| LiveKit version | **v1.13.11** (latest stable, 2026-10-25), digest-pinned. Staging's v1.9.1 is not touched (§8) |
| Docker networking | host networking for every service (LiveKit's recommendation) |
| Signalling | `wss://media1.<domain>` → Caddy-L4 on 443 (TLS for SNI `media1.`) → 127.0.0.1:7880 |
| TURN/TLS | `turns:turn1.<domain>:443` → Caddy-L4 on the **same** 443 (TLS for SNI `turn1.`) → 127.0.0.1:5349 + PROXY v2; LiveKit `turn.external_tls` + `turn.proxy_protocol` |
| TURN/UDP | **443/udp** (3478 optional) |
| ICE | TCP 7881; UDP mux range **7882-7901** (one port per thread) |
| Certificates | issued and renewed by Caddy (ACME) for both names; no certbot, no hook |
| Keys | generated on the server (`render-config.sh --generate-keys`) into `/etc/kabso-media/media.env` (600); reach LiveKit as `LIVEKIT_KEYS` env (600); never in git, chat or the yaml |
| Webhook | `https://api.<domain>/livekit/webhook` (new, signed, flag `LIVEKIT_PUBLIC_WEBHOOK_ENABLED`, default off) |
| Metrics | LiveKit `prometheus.port: 6789` + node_exporter 9100, bound to 127.0.0.1 (Phase 2: + private IP, firewalled) |
| Updates | manual, drain-safe (`update-media.sh`); no timer; unattended upgrades security-only, no Docker, no reboot |

## 3. Files (`infra/media/`)

| File | Purpose |
|---|---|
| `docker-compose.yml` | livekit, caddy (livekit/caddyl4), node-exporter; host network; `stop_grace_period: 3h` |
| `livekit.yaml.tmpl`, `caddy.yaml.tmpl` | templates, no secret |
| `.env.example` | every setting, documented → `/etc/kabso-media/media.env` |
| `render-config.sh` | parses (never sources) media.env, validates, `--generate-keys`, `--dry-run`; writes livekit.yaml, caddy.yaml, compose.env, livekit.env |
| `install.sh` | idempotent bootstrap of a fresh Ubuntu 24.04 (`--dry-run`) |
| `firewall.sh` | ufw rules from media.env (`--dry-run`, `--reset`); refuses to lock out the current SSH client |
| `health.sh` + `systemd/kabso-media-health.*` | every-minute probe; writes `kabso_media_probe_ok{probe=…}` for node_exporter |
| `update-media.sh` | drain-safe manual update / rollback of LiveKit, Caddy, node-exporter or config |
| `sysctl/99-kabso-media.conf` | UDP buffers etc. (ESTIMATE, checked in the load test) |
| `test/probe.py` | STUN over UDP / TLS+SNI, RoomService list (stdlib only) |
| `test/webhook-sink.py` | webhook receiver that verifies LiveKit's signature like the API does |
| `test/load-test.sh` | one load-test stage (SOLO/PK/MULTI/AUDIO rooms) from a generator machine |
| `cloud/` | emergency Hetzner Cloud node (cloud-init + `hcloud` scripts, dry-run by default), SURGE plan |

## 4. What the OWNER does (Hetzner Robot, DNS) — nothing secret goes into chat

1. **Order** one EX44 in **FSN1** (Robot → Order → Dedicated → EX44), Ubuntu 24.04 if offered as a pre-install.
2. **SSH key**: Robot → Key management → add your **public** key (`~/.ssh/id_ed25519.pub`; create it with
   `ssh-keygen -t ed25519` if needed) and select it in the order. Also add the operator's public key if we will log in
   (public keys are not secret). Without a key, `install.sh` skips SSH hardening on purpose.
3. **Operating system** (only if not pre-installed): Robot → Server → Rescue → activate Linux 64-bit rescue with your
   key → reset → `ssh root@<IP>` → `installimage` → choose **Ubuntu 24.04** → keep the default software RAID 1 over
   both NVMe → hostname `media1` → F10 to save → `reboot`.
4. **Note** the server's **IPv4** (Robot → Server → IPs). Optional: enable Robot's stateless firewall later; ufw on the
   server is the primary firewall (TURN_NETWORK_DESIGN §6).
5. **DNS** at the domain's DNS provider (we never touch DNS; TTL 300 is fine, 60 while testing):

   | Name | Type | Value | Purpose |
   |---|---|---|---|
   | `media1.<domain>` (e.g. `media1.kabsolive.com`) | A | `<EX44 IPv4>` | wss signalling (and ACME) |
   | `turn1.<domain>` | A | `<EX44 IPv4>` | TURN/TLS on 443 + TURN/UDP |

   No AAAA records in Phase 1 (IPv4 only; IPv6 is an open question, §11). No change to `live.`, `api.` or the others.
6. **Tell us** (in chat, nothing secret): the IPv4, that both names resolve (`dig +short media1.<domain>`), your SSH
   source IP if static (for `SSH_ALLOW_CIDRS`), and whether we may log in with our key.
7. **Hetzner support** (optional, from Phase 0): ask in writing whether sustained ~80 % use of the guaranteed 1 Gbit port
   during load tests is fine.

## 5. What WE do on the server (over SSH, as root)

```bash
# 5.1 get the bundle (public repository; only infra/media is checked out)
apt-get update && apt-get install -y git
git clone --depth 1 --filter=blob:none --sparse --branch <branch-with-D350> https://github.com/sd343434/kabso.git /opt/kabso-src
git -C /opt/kabso-src sparse-checkout set infra/media
less /opt/kabso-src/infra/media/install.sh          # read it
bash /opt/kabso-src/infra/media/install.sh --dry-run # see every change
bash /opt/kabso-src/infra/media/install.sh           # packages, kernel, SSH, fail2ban; stops: "fill media.env"

# 5.2 settings (on the server; the secret is generated here and never printed)
nano /etc/kabso-media/media.env      # MEDIA_DOMAIN, TURN_DOMAIN, ACME_EMAIL, NODE_IP, SSH_ALLOW_CIDRS …; leave the key empty
bash /opt/kabso-media/render-config.sh --generate-keys
bash /opt/kabso-media/install.sh     # renders config, ufw, pulls pinned images, starts, enables the health timer

# 5.3 check
bash /opt/kabso-media/health.sh --verbose     # all "ok" once DNS points here and Caddy has the certificates
docker compose --project-directory /opt/kabso-media --env-file /etc/kabso-media/compose.env logs caddy | grep -i "certificate obtained"
```

Expected at the end: `containers, http, wss, cert_days, turn_tls, turn_udp, rooms, metrics` all `ok`.
From outside: `curl https://media1.<domain>/` → `OK`; `python3 -I probe.py stun-tls turn1.<domain> 443 turn1.<domain>`
and `probe.py stun-udp <IP> 443` from a laptop succeed. Then run PHASE_1_TEST_PLAN.md T1–T4 **before** any switch.

## 6. Moving staging onto the node (only after T1–T4 pass, and only with the owner's go)

The API image must contain D350 (`LIVEKIT_PUBLIC_WEBHOOK_ENABLED`), i.e. this branch merged to `staging`. On the
**staging** server:

1. Copy the media node's key pair to the API without chat (§7).
2. In `/etc/kabso/kabso.env` (keep a copy: `cp kabso.env kabso.env.before-d350`):
   ```
   LIVEKIT_URL='wss://media1.<domain>'
   LIVEKIT_API_KEY='<from media.env>'
   LIVEKIT_API_SECRET='<from media.env>'
   LIVEKIT_PUBLIC_WEBHOOK_ENABLED='true'
   KABSO_ADMIN_MEDIA_ORIGINS='wss://media1.<domain> https://media1.<domain>'
   KABSO_STUDIO_MEDIA_ORIGINS='wss://media1.<domain> https://media1.<domain>'
   ```
   (`LIVEKIT_API_URL` stays unset in Phase 1: the API reaches the node through `https://media1.` like the apps. In
   Phase 2 it becomes the node's private address.)
3. On the media node set `LIVEKIT_WEBHOOK_URL=https://api.<domain>/livekit/webhook` in media.env and run
   `bash /opt/kabso-media/update-media.sh --service config` (no lives on it yet, so the drain is instant).
4. On staging: `docker compose -f /opt/kabso/infra/deploy/docker-compose.yml up -d --force-recreate api caddy` (CSP and
   env are read at start). Lives already running on the old LiveKit keep running there until they end; new lives get
   the new URL in their media token.
5. Run PHASE_1_TEST_PLAN.md T5 (room lifecycle and webhook through the API) and T6 (hidden viewer / permissions).

No app release is needed: clients connect to the URL the API returns (Phase 0 §1.1).

**Rollback** (any time): restore `kabso.env.before-d350` and recreate `api caddy`. Staging's LiveKit v1.9.1 was never
stopped, so the old URL works at once. Lives that started on the EX44 continue there until they end or the host leaves.

## 7. Moving the key pair to the API server without chat

From the operator's or owner's machine, which can SSH into both servers (nothing is printed on the screen):

```bash
ssh root@<EX44> "grep -E '^LIVEKIT_API_(KEY|SECRET)=' /etc/kabso-media/media.env" \
  | ssh root@<staging> "umask 077; cat > /etc/kabso/livekit-media1.env"
```
Then on staging, edit `/etc/kabso/kabso.env` and paste the two values from `/etc/kabso/livekit-media1.env` (an editor
over SSH; the values never leave the two servers), then `shred -u /etc/kabso/livekit-media1.env`. Rotation: run
`render-config.sh` with emptied key lines and `--generate-keys`, then repeat this step and §6.4.

## 8. LiveKit version: why v1.13.11, and compatibility

Staging runs **v1.9.1** (2025-09-05). The node pins **v1.13.11** (2026-10-25, the latest release; VERIFIED: Docker Hub
tags API and `CHANGELOG.md` of livekit/livekit at the tag). Staging is not changed by this branch.

Why not stay on 1.9.x — the items that matter for this node (VERIFIED, CHANGELOG.md):

| Version | Change | Impact for Kabso |
|---|---|---|
| 1.9.10 | "Please do not use this release … causes the server to panic" (fixed in 1.9.11) | avoid the 1.9.10 line |
| 1.10.0 | log key `pID` → `participantID` | log searches only |
| **1.12.0** | **TURN credentials get a TTL; TURN refuses to relay to private IPs by default** (`allow_restricted_peer_cidrs`) | we are turning TURN on now: without this, TURN creds never expire and TURN could relay into the private vSwitch of Phase 2 |
| 1.13.0 | backward compatibility for TURN auth without TTL removed | clients get fresh credentials at every join; nothing to do |
| 1.13.6 | H.264 baseline `42001f` removed from default codecs; auth token no longer logged / echoed on invalid-token errors | Kabso publishes **VP8** (Flutter `livekit_client` 2.13.1 `defaultVideoCodec = 'vp8'`, `lib/src/utils.dart:717`; studio `videoCodec: 'vp8'`, `apps/studio/src/studio-live.ts:108`) |
| **1.13.7** | **TURN accepts the PROXY protocol on its TCP listener** (#4852); SDP unmarshal hardening | required by the single-IP 443 layout (TURN sees the real client address) |
| 1.13.8 | the deprecated `prometheus_port` key removed (#4928) | the template uses `prometheus.port` |
| 1.13.11 | built with Go 1.27.3 / patched Alpine (eMudhra CA compromise); per-track retransmission cap; fixes | current |

Compatibility with the repo's clients and SDKs:

| Component | Version in repo | Evidence |
|---|---|---|
| Server SDK `livekit-server-sdk` | 2.19.1 (`apps/api/package.json:71`) | **VERIFIED here:** the API's opt-in real-server specs (`kl063-livekit-real`, `d195-pk-livekit-real`, `d201-live-tools-livekit-real`, `d250-live-moderation-livekit-real`: tokens, hidden viewers, RoomService permissions/metadata/data, webhooks, PK cross-room watch, second camera, staff observer) ran against v1.13.11 started with this bundle's rendered config: **11 tests, 10 passed, 1 failed on a stale assertion unrelated to LiveKit** (the taps score now also has `roomCherries: 0`, added by D259 after that opt-in spec was written); with that one expectation patched locally (not committed) all 7 tests of that file passed. |
| `@livekit/rtc-node` (test clients) | 1.1.0 | same run (publishes synthetic camera/microphone, subscribes) |
| Flutter `livekit_client` | 2.13.1 (`apps/mobile/pubspec.yaml:60`) | ESTIMATE: LiveKit keeps the signal protocol backward compatible and the client negotiates its version (`ProtocolVersion.v16` default, `options.dart:225`); nothing in the 1.10–1.13 notes drops a client version. **Must be proven on devices: PHASE_1_TEST_PLAN T1** |
| JS `livekit-client` (studio, admin) | 2.22.4 | ESTIMATE as above; **T1 (browser studio and admin watch)** |
| `lk` CLI (load tests) | v2.19.3 | VERIFIED here: `lk load-test` 1 publisher + 3 subscribers against v1.13.11, 0 % loss |

Upgrading staging's own v1.9.1 is **out of scope** (separate task once Phase 1 has passed T1 on devices).

## 9. What was checked locally (no server) — 2026-11-09

| Check | Result |
|---|---|
| `docker compose config -q` on `infra/media/docker-compose.yml` | OK |
| `render-config.sh` on `.env.example` | refuses the empty key (as designed); `--generate-keys` writes a pair into media.env (600), renders 4 files (livekit.env 600) |
| LiveKit v1.13.11 with the rendered `livekit.yaml` | starts; log shows explicit node IP, TURN `portTLS 5349, externalTLS true, proxyProtocol true, portUDP 443`, `rtc.portUDP 7882-7901`, prometheus 6789, region, bind 127.0.0.1 |
| `caddy validate --adapter yaml` (livekit/caddyl4 v2.11.3) on the rendered `caddy.yaml` | Valid configuration; :80 answers 308 to https. ACME issuance itself not testable here (no public DNS; the ACME directory was not reachable through the sandbox proxy) |
| Full stack (compose, host network) with Caddy's internal CA instead of ACME | `https://media1…/` → LiveKit `OK` over HTTP/1.1; WebSocket upgrade to `/rtc` reaches LiveKit (401 without token); RoomService via 443 → 401 without token; **TURN/TLS via SNI `turn1…` → STUN Binding success, XOR-MAPPED port = the client's own port (PROXY v2 reached TURN)**; TURN/UDP 443 → Binding success |
| `health.sh --verbose` | all probes ok except `cert_days` (Caddy's internal test certificates live 12 h — expected); textfile metrics exported by node_exporter |
| Webhook | `webhook-sink.py` received and **verified** `room_started`, `participant_joined/left`, `track_published/unpublished` from v1.13.11 (`Content-Type: application/webhook+json`); its self-test rejects tampered body / wrong key / wrong secret / expired token |
| Drain | room with 1 publisher + 2 subscribers; `docker compose stop -t 120 livekit` returned after **40 s = exactly when the room ended**, 0 % packet loss; log: "waiting for participants to exit" then "closing room … SERVER_SHUTDOWN". `update-media.sh` end-to-end: pull → drain → restart → health (every probe ok except `cert_days`, the sandbox's 12 h certificate, so the script ended with its "health check failed" message as designed) |
| `load-test.sh` | dry run prints one `lk load-test` per room; refuses to run against an address of the machine itself |
| shellcheck 0.11.0 (`-x -S style`) on all scripts | clean (one real bug fixed: `record` returned 1 when not verbose, so `A && B || C` would have recorded a failure) |
| API (D350 code) | §10 |

Not checkable here: Let's Encrypt issuance (needs public DNS), ufw/fail2ban/sshd/unattended-upgrades (sandbox), the
docker apt repository (download.docker.com not reachable), real NIC, real networks, devices. The sandbox also refused
`ulimits.nofile 1048576` and the `rslave` mount; a local, uncommitted compose override was used for those two only.

## 10. API changes (D350, flag-guarded; defaults keep staging identical)

Today the API uses **one** `LIVEKIT_URL` for the URL it gives clients **and** for its RoomService calls, and the
webhook arrives on the docker-internal `http://api:3000/internal/livekit/webhook` (Caddy answers `/internal/*` with 404
publicly).

| Setting | Default | Effect |
|---|---|---|
| `LIVEKIT_URL` | (required with hosting) | unchanged: the **public** URL returned in every media token response. Not renamed to `LIVEKIT_PUBLIC_URL`: it already has that meaning, and a rename would touch install.sh, every env file and runbook for no behaviour change |
| `LIVEKIT_API_URL` (new) | unset → `LIVEKIT_URL` | where the API calls RoomService (`http(s)`/`ws(s)`; production: https/wss, or plain http to a private IPv4 only — the Phase 2 vSwitch address) |
| `LIVEKIT_PUBLIC_WEBHOOK_ENABLED` (new) | `false` → `POST /livekit/webhook` answers 404 `NOT_FOUND` | `true`: the same handler as the internal route on the public path; LiveKit's signature (JWT with the API secret, issuer = key, `exp` required, sha256 of the raw body) is the authentication; anything else 401. Rate limiting is skipped as on the internal route (a node sends bursts from one IP); the check is one HMAC |

Code: `env.schema.ts`, `app-config.ts`, `livekit-media.provider.ts` (4th constructor argument), `live.module.ts`,
`live.controller.ts` (`LiveMediaPublicWebhookController`), `app.setup.ts` (path outside `/api/v1`). Contract notes:
CONVENTIONS §10.8 (no client-visible change; machine-to-machine path, not in openapi like the internal one).
Tests: `app-config.spec.ts` (+2), `media/livekit-media.provider.spec.ts` (new: control calls go to `apiUrl`, ws→http,
default = old behaviour, webhook signature cases), `test/d350-livekit-public-webhook.e2e-spec.ts` (new: off → 404 and
internal route unchanged; on → real-signature join recorded, 5 kinds of bad signature → 401, not under `/api/v1`).
Checks run: §9 table + the commit message.

Later (design, not implemented): an optional Caddy matcher on `api.` limiting `/livekit/webhook` to the media nodes'
IPs (`KABSO_MEDIA_NODE_IPS`) — left out so the staging Caddyfile, and with it a Caddy restart, is not touched now.

## 11. Open questions

1. Branch to install from on the server until D350 is merged (§5.1): this branch, or wait for the merge?
2. Domain names: `media1.` / `turn1.kabsolive.com` OK? (Phase 0 proposed `turn1…4.`.)
3. IPv6: the EX44 gets a /64. Advertise IPv6 candidates in Phase 1 (more config, AAAA records), or IPv4 only? Proposed: IPv4 only now.
4. SSH source IPs of the owner and operator (for `SSH_ALLOW_CIDRS`), and whether the operator gets a key on the node.
5. Monitoring: where Prometheus/Grafana will run (Phase 2 app server?). Until then metrics are read over SSH.
6. Load-generator machines (PHASE_1_TEST_PLAN §4.3): hourly Hetzner dedicated/Cloud machines need the owner's approval and cost.
7. Hetzner's answer on sustained port use (Phase 0 question, still open).
