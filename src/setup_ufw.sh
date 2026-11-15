#!/bin/bash -v
set -euo pipefail
apt-get install --no-install-recommends -y ufw

if [ "${SETUP_WG:-true,,}" == "true" ]; then
    WIREGUARD_PORT="${WIREGUARD_PORT:-51820}"
    ufw allow ${WIREGUARD_PORT}/udp
fi
ufw default deny incoming
ufw enable
