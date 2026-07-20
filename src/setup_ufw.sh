#!/bin/bash -v
set -euo pipefail
apt-get install --no-install-recommends -y ufw

WIREGUARD_PORT="${WIREGUARD_PORT:-51820}"
ufw allow ${WIREGUARD_PORT}/udp
ufw default deny incoming
ufw enable
