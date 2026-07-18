#!/bin/bash -v
set -euo pipefail

sed -E -e 's/#?DNSStubListener=.*/DNSStubListener=no/' -i /etc/systemd/resolved.conf

mv /etc/resolv.conf /etc/resolv.conf.bak

cat <<EOF > /etc/resolv.conf
nameserver 1.1.1.3
nameserver 208.67.222.222
EOF

systemctl restart systemd-resolved
