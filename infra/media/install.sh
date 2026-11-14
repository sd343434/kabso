#!/usr/bin/env bash
# Kabso Live — bootstrap a fresh Ubuntu 24.04 Hetzner EX44 as a LiveKit media node (D350, Phase 1).
# Runbook: docs/infrastructure/LIVEKIT_SINGLE_NODE_DEPLOYMENT.md. Read this script before running it.
#
#   bash install.sh [--dry-run] [--skip-ssh-hardening]
#
# Idempotent and non-interactive: run it again after any change. It contains NO secret; it reads
# /etc/kabso-media/media.env, which the owner fills ON the server (copy of .env.example, mode 600).
#
#   1. packages: Docker Engine + compose plugin from Docker's official apt repository, ufw, fail2ban,
#      unattended-upgrades, python3, openssl, curl;
#   2. kernel: /etc/sysctl.d/99-kabso-media.conf (UDP buffers etc.), open-file limits, time sync (systemd-timesyncd);
#   3. security: SSH key-only (no passwords, root by key only) — only if an authorized key exists, so nobody is locked
#      out; fail2ban on sshd; security-only unattended upgrades WITHOUT automatic reboot and WITHOUT Docker packages
#      (a Docker/containerd upgrade or a reboot would cut every live; those are done by hand with update-media.sh);
#   4. the bundle → /opt/kabso-media, /etc/kabso-media (700); media.env created from .env.example if missing, then STOP
#      until it is filled;
#   5. with a filled media.env: render-config.sh, firewall.sh, pull the pinned images, start the stack, install the
#      health timer. There is deliberately no update timer.
# --dry-run prints every command that would change the system and changes nothing.
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib.sh
. "$HERE/lib.sh"

DRY=0
SKIP_SSH=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --skip-ssh-hardening) SKIP_SSH=1; shift ;;
    -h | --help) sed -n '2,21p' "$0"; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

BUNDLE=/opt/kabso-media
ETC=${KABSO_MEDIA_ETC:-/etc/kabso-media}
run() { if [ "$DRY" -eq 1 ]; then printf '+ %s\n' "$*"; else "$@"; fi; }
put() { # put FILE MODE < content   (writes only when the content changed)
  local content
  content=$(cat)
  if [ "$DRY" -eq 1 ]; then printf '+ write %s (mode %s)\n' "$1" "$2"; return 0; fi
  if [ ! -f "$1" ] || [ "$(cat "$1")" != "$content" ]; then
    printf '%s\n' "$content" >"$1.tmp" && chmod "$2" "$1.tmp" && mv "$1.tmp" "$1"
  fi
}

[ "$DRY" -eq 1 ] || [ "$(id -u)" -eq 0 ] || die "run as root"
. /etc/os-release
[ "${ID:-}" = ubuntu ] || die "this script targets Ubuntu (found ${ID:-unknown})"
[ "${VERSION_ID:-}" = "24.04" ] || echo "WARNING: written for Ubuntu 24.04, found ${VERSION_ID:-?}" >&2
export DEBIAN_FRONTEND=noninteractive

log "1/5 Packages"
run apt-get update -q
run apt-get install -y -q ca-certificates curl gnupg openssl python3 ufw fail2ban unattended-upgrades
if ! dpkg -s docker-ce >/dev/null 2>&1; then
  # https://docs.docker.com/engine/install/ubuntu/ (official repository; Ubuntu's docker.io is not used).
  run install -m 0755 -d /etc/apt/keyrings
  run curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  run chmod a+r /etc/apt/keyrings/docker.asc
  put /etc/apt/sources.list.d/docker.list 644 <<EOF
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable
EOF
  run apt-get update -q
  run apt-get install -y -q docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
run install -m 0755 -d /etc/docker
# live-restore: restarting dockerd (e.g. a manual Docker upgrade) keeps containers — and lives — running.
put /etc/docker/daemon.json 644 <<'EOF'
{
  "live-restore": true,
  "log-driver": "json-file",
  "log-opts": { "max-size": "50m", "max-file": "5" }
}
EOF
run systemctl enable --now docker
# live-restore is reloadable (SIGHUP); log options apply to containers created afterwards.
if [ "$DRY" -eq 0 ]; then systemctl reload docker; fi

log "2/5 Kernel, limits, time"
run install -m 644 "$HERE/sysctl/99-kabso-media.conf" /etc/sysctl.d/99-kabso-media.conf
run sysctl --system -q
put /etc/security/limits.d/99-kabso-media.conf 644 <<'EOF'
# Kabso Live media node (D350): open files for operators' tools (lk load-test needs 65535). The LiveKit container
# gets its own limit from docker-compose.yml (ulimits.nofile).
*    soft nofile 1048576
*    hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
EOF
run timedatectl set-ntp true

log "3/5 SSH, fail2ban, unattended upgrades"
keys_ok=0
for f in /root/.ssh/authorized_keys /home/*/.ssh/authorized_keys; do
  [ -s "$f" ] && grep -qE '^(ssh-(ed25519|rsa)|ecdsa-sha2-|sk-)' "$f" && keys_ok=1
done
if [ "$SKIP_SSH" -eq 1 ]; then
  echo "SSH hardening skipped (--skip-ssh-hardening)."
elif [ "$keys_ok" -eq 0 ]; then
  echo "WARNING: no SSH public key found in authorized_keys — SSH hardening SKIPPED so you are not locked out." >&2
  echo "         Add your key (Hetzner Robot key at install time, or ssh-copy-id) and run install.sh again." >&2
else
  put /etc/ssh/sshd_config.d/10-kabso-media.conf 644 <<'EOF'
# Kabso Live media node (D350): key-only SSH. Root may log in with a key only; no password login for anyone.
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
PubkeyAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 3
X11Forwarding no
EOF
  if [ "$DRY" -eq 0 ]; then
    sshd -t || die "sshd rejected the new settings; nothing reloaded"
    systemctl reload ssh 2>/dev/null || systemctl reload sshd
  fi
fi
put /etc/fail2ban/jail.d/kabso-media.local 644 <<'EOF'
[sshd]
enabled = true
backend = systemd
maxretry = 5
findtime = 10m
bantime = 1h
EOF
run systemctl enable --now fail2ban
if [ "$DRY" -eq 0 ]; then systemctl restart fail2ban; fi
put /etc/apt/apt.conf.d/20auto-upgrades 644 <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
put /etc/apt/apt.conf.d/52kabso-media-unattended 644 <<'EOF'
// Kabso Live media node (D350): security updates only, never an automatic reboot, never Docker/containerd
// (either would end every live on the node). Kernel/Docker updates: drain with update-media.sh, then by hand.
Unattended-Upgrade::Allowed-Origins { "${distro_id}:${distro_codename}-security"; "${distro_id}ESMApps:${distro_codename}-apps-security"; "${distro_id}ESM:${distro_codename}-infra-security"; };
Unattended-Upgrade::Package-Blacklist { "docker-ce"; "docker-ce-cli"; "containerd.io"; "docker-compose-plugin"; "docker-buildx-plugin"; };
Unattended-Upgrade::Automatic-Reboot "false";
EOF

log "4/5 Bundle and settings"
if [ "$HERE" != "$BUNDLE" ]; then
  run install -d -m 755 "$BUNDLE" "$BUNDLE/test" "$BUNDLE/systemd" "$BUNDLE/sysctl"
  for f in docker-compose.yml livekit.yaml.tmpl caddy.yaml.tmpl .env.example lib.sh render-config.sh firewall.sh \
    health.sh update-media.sh install.sh test/probe.py test/webhook-sink.py test/load-test.sh \
    systemd/kabso-media-health.service systemd/kabso-media-health.timer sysctl/99-kabso-media.conf; do
    run install -m "$([[ "$f" == *.sh || "$f" == *.py ]] && echo 755 || echo 644)" "$HERE/$f" "$BUNDLE/$f"
  done
fi
run install -d -m 700 "$ETC"
run install -d -m 755 /var/lib/kabso-media/metrics
if [ ! -f "$ETC/media.env" ]; then
  run install -m 600 "$HERE/.env.example" "$ETC/media.env"
  log "Fill $ETC/media.env now (nano $ETC/media.env), then run: bash $BUNDLE/render-config.sh --generate-keys && bash $BUNDLE/install.sh"
  exit 0
fi
[ "$DRY" -eq 1 ] || chmod 600 "$ETC/media.env"

log "5/5 Config, firewall, stack, health timer"
if [ "$DRY" -eq 1 ]; then
  run bash "$BUNDLE/render-config.sh" --etc "$ETC"
  bash "$HERE/firewall.sh" --etc "$ETC" --dry-run
else
  bash "$BUNDLE/render-config.sh" --etc "$ETC"
  bash "$BUNDLE/firewall.sh" --etc "$ETC"
fi
export KABSO_MEDIA_ETC=$ETC KABSO_MEDIA_DIR=$BUNDLE
run media_compose pull
# `up -d` recreates only what changed. On a node with lives, use update-media.sh instead (it drains first).
if [ "$DRY" -eq 0 ] && media_compose ps --status running --services 2>/dev/null | grep -qx livekit; then
  echo "LiveKit is already running: not restarting it here. Use update-media.sh --service config to apply changes."
  run media_compose up -d --no-recreate
else
  run media_compose up -d
fi
run install -m 644 "$BUNDLE/systemd/kabso-media-health.service" /etc/systemd/system/kabso-media-health.service
run install -m 644 "$BUNDLE/systemd/kabso-media-health.timer" /etc/systemd/system/kabso-media-health.timer
run systemctl daemon-reload
run systemctl enable --now kabso-media-health.timer
log "Installed. Check: bash $BUNDLE/health.sh --verbose   (certificates may take a minute after DNS points here)"
