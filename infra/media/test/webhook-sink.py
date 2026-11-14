#!/usr/bin/env python3
"""Kabso Live — LiveKit webhook test receiver (D350). Standard library only.

Listens on HOST:PORT, checks every POST the way the API's WebhookReceiver does (livekit-server-sdk):
  * Authorization is a JWT signed HS256 with the API secret, issuer (iss) = the API key, not expired;
  * its `sha256` claim equals base64(sha256(raw body)).
Prints one line per event: verdict, event name, room, participant identity. Answers 200 for a valid
webhook and 401 otherwise, so LiveKit's own retry/log shows the result too.

Usage (on a test/generator machine, never on a production API host):
  LIVEKIT_API_KEY=... LIVEKIT_API_SECRET=... python3 -I webhook-sink.py --port 8099 [--log events.jsonl]
The key and secret come from the environment (never on the command line, so they stay out of `ps`).
`--self-test` signs a sample body and checks the verifier without opening a port.
"""
import argparse
import base64
import hashlib
import hmac
import json
import os
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def b64url_decode(part: str) -> bytes:
    return base64.urlsafe_b64decode(part + "=" * (-len(part) % 4))


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def verify(body: bytes, authorization: str, key: str, secret: str, now: float | None = None) -> tuple[bool, str]:
    token = authorization.strip()
    if token.lower().startswith("bearer "):
        token = token[7:].strip()
    parts = token.split(".")
    if len(parts) != 3:
        return False, "authorization is not a JWT"
    try:
        header = json.loads(b64url_decode(parts[0]))
        claims = json.loads(b64url_decode(parts[1]))
        signature = b64url_decode(parts[2])
    except (ValueError, json.JSONDecodeError):
        return False, "malformed JWT"
    if header.get("alg") != "HS256":
        return False, f"unexpected alg {header.get('alg')!r}"
    expected = hmac.new(secret.encode(), f"{parts[0]}.{parts[1]}".encode(), hashlib.sha256).digest()
    if not hmac.compare_digest(signature, expected):
        return False, "bad signature"
    if claims.get("iss") != key:
        return False, "issuer is not the configured API key"
    t = time.time() if now is None else now
    if "exp" in claims and t > float(claims["exp"]) + 10:
        return False, "token expired"
    if "nbf" in claims and t + 10 < float(claims["nbf"]):
        return False, "token not yet valid"
    digest = base64.b64encode(hashlib.sha256(body).digest()).decode()
    if claims.get("sha256") != digest:
        return False, "body sha256 does not match the token"
    return True, "ok"


def sign(body: bytes, key: str, secret: str, ttl: int = 300) -> str:
    header = b64url(json.dumps({"alg": "HS256", "typ": "JWT"}).encode())
    now = int(time.time())
    claims = {"iss": key, "nbf": now, "exp": now + ttl, "sha256": base64.b64encode(hashlib.sha256(body).digest()).decode()}
    payload = b64url(json.dumps(claims).encode())
    sig = hmac.new(secret.encode(), f"{header}.{payload}".encode(), hashlib.sha256).digest()
    return f"{header}.{payload}.{b64url(sig)}"


def self_test(key: str, secret: str) -> int:
    body = b'{"event":"room_started","room":{"name":"self-test"}}'
    good = sign(body, key, secret)
    checks = [
        ("valid", verify(body, good, key, secret)[0] is True),
        ("tampered body", verify(body + b" ", good, key, secret)[0] is False),
        ("wrong secret", verify(body, sign(body, key, secret + "x"), key, secret)[0] is False),
        ("wrong key", verify(body, sign(body, key + "x", secret), key, secret)[0] is False),
        ("expired", verify(body, good, key, secret, now=time.time() + 3600)[0] is False),
        ("not a JWT", verify(body, "nope", key, secret)[0] is False),
    ]
    for name, ok in checks:
        print(f"{'PASS' if ok else 'FAIL'} {name}")
    return 0 if all(ok for _, ok in checks) else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8099)
    parser.add_argument("--log", help="append each verified event as one JSON line")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    key = os.environ.get("LIVEKIT_API_KEY", "")
    secret = os.environ.get("LIVEKIT_API_SECRET", "")
    if not key or not secret:
        print("LIVEKIT_API_KEY and LIVEKIT_API_SECRET must be set in the environment", file=sys.stderr)
        return 2
    if args.self_test:
        return self_test(key, secret)

    class Handler(BaseHTTPRequestHandler):
        def do_POST(self) -> None:  # noqa: N802 (http.server API)
            length = int(self.headers.get("Content-Length") or 0)
            body = self.rfile.read(length)
            ok, why = verify(body, self.headers.get("Authorization", ""), key, secret)
            event = {}
            try:
                event = json.loads(body)
            except json.JSONDecodeError:
                pass
            room = (event.get("room") or {}).get("name", "")
            ident = (event.get("participant") or {}).get("identity", "")
            print(f"{'VALID' if ok else 'REJECTED'} {why} event={event.get('event', '?')} room={room} identity={ident} "
                  f"content-type={self.headers.get('Content-Type', '')}", flush=True)
            if ok and args.log:
                with open(args.log, "a", encoding="utf-8") as f:
                    f.write(json.dumps({"received": time.time(), **event}) + "\n")
            self.send_response(200 if ok else 401)
            self.end_headers()

        def log_message(self, *_: object) -> None:
            pass

    print(f"listening on {args.host}:{args.port}", flush=True)
    ThreadingHTTPServer((args.host, args.port), Handler).serve_forever()
    return 0


if __name__ == "__main__":
    sys.exit(main())
