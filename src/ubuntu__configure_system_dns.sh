#!/bin/bash -v
set -euo pipefail

mkdir -p /etc/systemd/resolved.conf.d

cat <<EOF >/etc/systemd/resolved.conf.d/noresolved.conf
[Resolve]
DNS=1.1.1.3 208.67.222.222
DNSStubListener=no
EOF

systemctl restart systemd-resolved
