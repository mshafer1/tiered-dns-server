#!/bin/bash -v
set -euo pipefail
apt-get install --no-install-recommends -y ufw

ufw default deny incoming
(ufw --force enable || true)
(ufw status || true)
