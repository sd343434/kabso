# TURN and network design — LiveKit media node (D350)

Status: **DESIGN, validated locally** (LIVEKIT_SINGLE_NODE_DEPLOYMENT.md §9). Applies to the Phase 1 EX44 and, unchanged
per node, to the Phase 2 media nodes. Labels as in the runbook (VERIFIED / OWNER / ESTIMATE).

## 1. How a client connects (LiveKit's order, VERIFIED: docs + source)

1. **Signalling**: WebSocket `wss://media1.<domain>/rtc` (TLS). The API returns this URL in every media token response.
2. **ICE/UDP** to the node's IP on the UDP mux range (fastest; most networks).
3. **ICE/TCP** on 7881 "when the client could not connect via UDP (e.g. VPN, corporate firewalls)" (ports docs).
4. **TURN/UDP** (embedded TURN; "When enabled, it also serves as a STUN server").
5. **TURN/TLS on 443** for networks that allow only HTTPS: "To firewalls, TLS traffic looks no different from regular
   HTTPS traffic … the broadest coverage" (deployment docs). LiveKit sends both TURN URLs, with credentials, inside the
   signal connection: "only clients that have already established a signal connection could connect to our TURN server".
   `allow_tcp_fallback` (default true) moves an unstable UDP session to TCP/TURN-TLS.

**Source fact that decides the 443 layout (VERIFIED, livekit v1.13.11 `pkg/service/roommanager.go`,
`iceServersForParticipant`):** the TURN/TLS URL is always built as `turns:<turn.domain>:443?transport=tcp` whenever
`turn.tls_port > 0` — **the advertised port is 443 regardless of `tls_port`**. TURN/UDP is advertised as
`turn:<node_ip>:<turn.udp_port>?transport=udp`. So TURN/TLS must answer on **443 of the TURN name**; "TURN-TLS on 5349"
as a public port does not work with the embedded server.

## 2. Port 443 on a single-IP EX44 — the options

The EX44 has one IPv4 (an additional IPv4 costs extra and needs a reason; Phase 0 §4). Signalling (HTTPS/WSS) and
TURN/TLS both want 443/tcp.

| | Layout | Works with `turns:…:443`? | Signalling latency | Complexity / risk | Verdict |
|---|---|---|---|---|---|
| A | Caddy terminates `media1.` on 443; TURN/TLS on 5349 | **No** (clients are told 443) | direct | low | rejected |
| B | LiveKit binds TURN/TLS on 443 itself (`cert_file`/`key_file`); signalling proxied by the **app server's** Caddy (`live.` → node:7880 over the internet) | yes | **+1 hop** through the staging VPS (1 vCPU) for every join/reconnect; 7880 must be exposed to the app server or tunnelled; in Phase 1 the load generators' signalling would also cross the staging box | medium: certbot (or Caddy elsewhere) + a renewal hook that restarts LiveKit (drops every live) | not chosen |
| **C** | **Caddy layer 4 on 443 splits by SNI**: `media1.` → TLS here → 127.0.0.1:7880; `turn1.` → TLS here → 127.0.0.1:5349 with PROXY v2; LiveKit `turn.external_tls: true`, `turn.proxy_protocol: true` | **yes** | direct; L4 proxy on loopback (ESTIMATE: well under 1 ms) | medium: LiveKit's own `livekit/caddyl4` image; certificates renewed by Caddy without touching LiveKit | **chosen** |
| D | Second IPv4: TURN/TLS on 443 of IP 2, signalling on IP 1 | yes | direct | an extra IP per node (€1.70/month + €4.90 setup listed for AX in Phase 0; EX price not checked) and its routing | fallback if C fails on a real network |

C is the layout of LiveKit's own VM recipe ("443 - primary HTTPS and TURN/TLS" on one instance, Caddy in front;
docs `self-hosting/vm`; image `livekit/caddyl4` with the `layer4` module — VERIFIED: `caddy list-modules` of v2.11.3
shows `layer4.matchers.tls`, `layer4.handlers.tls`, `layer4.handlers.proxy`). The PROXY v2 header matters because
LiveKit's TURN otherwise sees Caddy's 127.0.0.1 and echoes it as XOR-MAPPED-ADDRESS, which Firefox rejects
(config-sample `turn.proxy_protocol`, added in 1.13.7). Verified locally: a STUN Binding over TLS via SNI `turn1.` got
the client's own port back.

## 3. Port map (per node)

| Port | Proto | Listener | Exposed | Why |
|---|---|---|---|---|
| 22 | tcp | sshd | `SSH_ALLOW_CIDRS` (else rate-limited + fail2ban) | admin, keys only |
| 80 | tcp | Caddy | everyone | ACME HTTP-01, redirect |
| 443 | tcp | Caddy-L4 | everyone | `media1.` wss signalling + `turn1.` TURN/TLS (SNI) |
| 443 | udp | LiveKit TURN/UDP | everyone | TURN/UDP on the port that QUIC-only networks allow ("recommended to 443 if not running HTTP3/QUIC server", config-sample) — the node runs no HTTP/3 |
| 7881 | tcp | LiveKit ICE/TCP | everyone | TCP fallback (cannot be behind TLS or a proxy, config-sample) |
| 7882–7901 | udp | LiveKit ICE/UDP mux | everyone | 20 ports = 20 threads ("a range of ports greater or equal to the number of vCPUs", config-sample); `port_range_*` unset |
| 5349 | tcp | LiveKit TURN (plain, PROXY required) | **loopback only** (not opened; non-loopback senders are closed by `proxy_protocol_trusted_cidrs`) | behind Caddy |
| 7880 | tcp | LiveKit HTTP/WS | 127.0.0.1 (Phase 2: + private IP, from the app server only) | behind Caddy |
| 6789 | tcp | LiveKit Prometheus | same bind as 7880 (LiveKit opens it on `bind_addresses`, `pkg/service/server.go`) | from `MONITORING_IPS` only |
| 9100 | tcp | node_exporter | 127.0.0.1 (Phase 2: private IP) | from `MONITORING_IPS` only |
| 30000–40000 | udp | TURN relay sockets | not opened (relay talks to the SFU on the node's own address, via lo) | |

**UDP mux vs a 10 000-port range:** the range (`50000-60000`, "each participant … will use two ports") needs a wide
firewall hole and gives no capacity benefit on a 20-thread box; a single mux port serialises on one socket. A 20-port mux
range is LiveKit's stated optimum and keeps the firewall small. `RTC_UDP_PORT=7882` (single) is a one-line change.

**`node_ip` instead of STUN discovery:** the EX44's public IPv4 is on its NIC, so `use_external_ip: false` +
`node_ip: <IPv4>` (config-sample: `use_external_ip` takes precedence, so it must be false) avoids a start-up
dependency on external STUN and a wrong guess. `rtc.ips.includes: [<IPv4>/32]` stops docker0/bridge addresses being
offered as candidates (host networking).

## 4. TLS and certificates

- Two names per node: `media<N>.<domain>` (signalling) and `turn<N>.<domain>` (TURN; "a separate TURN domain and SSL
  cert will be needed", deployment docs). Both A records → the node IP.
- Caddy obtains and renews both (ACME, Let's Encrypt; HTTP-01 on :80 or TLS-ALPN-01 on :443). LiveKit never reads a
  certificate file (`external_tls`), so **renewal never restarts LiveKit**. Certificates live in the `caddy_data`
  volume; losing it only means re-issuing (rate limits: avoid re-creating nodes many times a day with the same name).
- `health.sh` alerts below 14 days left (`kabso_media_cert_days`).
- Signalling is HTTP/1.1 only (ALPN) so the WebSocket upgrade passes the L4 proxy.

## 5. Webhook and control path

| Phase | LiveKit → API webhook | API → LiveKit (RoomService) | Clients → LiveKit |
|---|---|---|---|
| staging today | `http://api:3000/internal/livekit/webhook` (docker network) | `LIVEKIT_URL` (`wss://live.` → http) | `wss://live.<domain>` |
| **Phase 1** | `https://api.<domain>/livekit/webhook` (public, signed; `LIVEKIT_PUBLIC_WEBHOOK_ENABLED=true`) | `LIVEKIT_URL` = `wss://media1.<domain>` (public, TLS) | `wss://media1.<domain>` |
| Phase 2 | the app server's private address, e.g. `http://10.0.1.2:3000/livekit/webhook` over the vSwitch, or the public route | `LIVEKIT_API_URL=http://<node private IP>:7880` (allowed in production only for a private IPv4) | `wss://media.<domain>` (any node; LiveKit routes to the room's node) |

LiveKit signs every webhook (JWT in `Authorization`, issuer = key, sha256 of the body); "no guarantees around
delivery" (webhooks docs) — the API's 15 s sweeper already reconciles (Phase 0 §1.2).

## 6. Firewall layers

1. **ufw on the node** (`firewall.sh`), the primary filter: host networking means ufw sees the real sockets.
2. **Hetzner Robot stateless firewall** (optional, free on 1 Gbit servers): can mirror §3 as defence in depth. It is
   stateless, so "established" return traffic needs an explicit rule for the ephemeral port range; easy to get wrong
   for UDP — recommended only after T1–T4 have passed with ufw alone.
3. LiveKit itself: TURN only for authenticated participants, credential TTL 300 s, no relay to private/loopback peers
   (v1.12+ default), per-user relay allocation limit 12 (default).

## 7. Phase 2 deltas (not built now)

Redis for LiveKit on the app server (separate instance, private IP, password via `REDIS_PASSWORD` env), the `redis:`
block and `node_selector: sysload` uncommented, `PRIVATE_IP` set (adds 7880/6789/9100 on the vSwitch), one public
signalling name for the cluster (DNS round robin or the app server's L4 proxy — to decide in Phase 2), TURN names stay
per node (`turn<N>.`; a client's TURN must reach the node hosting its room).
