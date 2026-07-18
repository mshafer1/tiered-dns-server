#!/bin/bash -v
set -euo pipefail

mkdir -p /etc/cron.d
echo "0 3 * * 6 root bash $(dirname "$0")/update-all.sh >> /var/log/update-all.log 2>&1" > /etc/cron.d/weekly-updates
