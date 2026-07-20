#!/bin/bash -v
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get upgrade -y

# check if reboot is required
if [ -f /var/run/reboot-required ]; then
    echo "Reboot required. Rebooting now..."
    reboot
fi
