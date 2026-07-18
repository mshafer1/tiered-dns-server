#!/bin/bash -v
set -euo pipefail
apt-get install --no-install-recommends -y ufw


ufw allow ${WIREGUARD_PORT}/udp
ufw default deny incoming
ufw enable
