#!/usr/bin/env python3
"""Kabso Live — media node probes (D350). Standard library only; run with `python3 -I`.

  probe.py stun-udp HOST PORT                    STUN Binding over UDP to LiveKit's TURN/UDP listener
  probe.py stun-tls HOST PORT SNI [--insecure]   TLS to HOST:PORT with SNI (Caddy-L4 → TURN), then a STUN Binding
  probe.py rooms URL                             RoomService ListRooms with a short-lived admin JWT (key/secret from
                                                 LIVEKIT_API_KEY / LIVEKIT_API_SECRET in the environment)

A STUN Binding success proves the listener is LiveKit's TURN; for stun-tls, the XOR-MAPPED-ADDRESS equals the
caller's own address only when the PROXY v2 header from Caddy reached TURN (turn.proxy_protocol). Exit code 0 = ok.
"""
import base64
import hashlib
import hmac
import json
import os
import socket
import ssl
import struct
import sys
import time
import urllib.request

MAGIC = 0x2112A442


def stun_request() -> tuple[bytes, bytes]:
    tid = os.urandom(12)
    return struct.pack("!HHI12s", 0x0001, 0, MAGIC, tid), tid


def stun_parse(data: bytes, tid: bytes) -> str:
    if len(data) < 20:
        raise ValueError("short STUN reply")
    typ, length, cookie = struct.unpack("!HHI", data[:8])
    if cookie != MAGIC or data[8:20] != tid:
        raise ValueError("not a reply to this request")
    if typ != 0x0101:
        raise ValueError(f"STUN reply type {typ:#06x} (want 0x0101 Binding Success)")
    off = 20
    while off + 4 <= 20 + length:
        attr, alen = struct.unpack("!HH", data[off:off + 4])
        val = data[off + 4:off + 4 + alen]
        if attr == 0x0020 and alen >= 8 and val[1] == 0x01:
            port = struct.unpack("!H", val[2:4])[0] ^ (MAGIC >> 16)
            ip = socket.inet_ntoa(bytes(a ^ b for a, b in zip(val[4:8], struct.pack("!I", MAGIC))))
            return f"{ip}:{port}"
        off += 4 + alen + (-alen % 4)
    raise ValueError("no XOR-MAPPED-ADDRESS")


def stun_udp(host: str, port: int) -> str:
    msg, tid = stun_request()
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        s.settimeout(5)
        s.sendto(msg, (host, port))
        return stun_parse(s.recv(2048), tid)


def stun_tls(host: str, port: int, sni: str, insecure: bool) -> str:
    ctx = ssl.create_default_context()
    if insecure:
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
    msg, tid = stun_request()
    with socket.create_connection((host, port), timeout=5) as raw, ctx.wrap_socket(raw, server_hostname=sni) as s:
        s.sendall(msg)
        mapped = stun_parse(s.recv(2048), tid)
        local = s.getsockname()
        cert = s.getpeercert() or {}
    note = "" if insecure else f", certificate valid until {cert.get('notAfter', '?')}"
    return f"{mapped} (local {local[0]}:{local[1]}{note})"


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def admin_token(key: str, secret: str) -> str:
    now = int(time.time())
    header = b64url(json.dumps({"alg": "HS256", "typ": "JWT"}).encode())
    claims = b64url(json.dumps({"iss": key, "nbf": now - 5, "exp": now + 60, "video": {"roomList": True}}).encode())
    sig = hmac.new(secret.encode(), f"{header}.{claims}".encode(), hashlib.sha256).digest()
    return f"{header}.{claims}.{b64url(sig)}"


def rooms(url: str) -> str:
    key, secret = os.environ.get("LIVEKIT_API_KEY", ""), os.environ.get("LIVEKIT_API_SECRET", "")
    if not key or not secret:
        raise ValueError("LIVEKIT_API_KEY / LIVEKIT_API_SECRET not set")
    base = url.replace("wss://", "https://").replace("ws://", "http://").rstrip("/")
    req = urllib.request.Request(f"{base}/twirp/livekit.RoomService/ListRooms", data=b"{}", method="POST",
                                 headers={"Content-Type": "application/json",
                                          "Authorization": f"Bearer {admin_token(key, secret)}"})
    with urllib.request.urlopen(req, timeout=5) as resp:  # noqa: S310 (fixed scheme above)
        body = json.loads(resp.read() or b"{}")
    listed = body.get("rooms", [])
    participants = sum(int(r.get("num_participants", 0)) for r in listed)
    return f"{len(listed)} room(s), {participants} participant(s)"


def main(argv: list[str]) -> int:
    try:
        if len(argv) >= 3 and argv[0] == "stun-udp":
            print("TURN/UDP ok, mapped", stun_udp(argv[1], int(argv[2])))
        elif len(argv) >= 4 and argv[0] == "stun-tls":
            print("TURN/TLS ok, mapped", stun_tls(argv[1], int(argv[2]), argv[3], "--insecure" in argv))
        elif len(argv) >= 2 and argv[0] == "rooms":
            print("RoomService ok,", rooms(argv[1]))
        else:
            print(__doc__)
            return 2
    except (OSError, ValueError, ssl.SSLError) as e:
        print(f"FAIL {argv[0]}: {e}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
