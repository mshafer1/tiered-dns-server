#!/bin/bash -v
#
# <UDF name="hostname" label="Hostname" example="Enter the hostname for your Linode (e.g., bluesky)">
# <UDF name="ClientNames" label="Client Names" example="laptop,phone,tablet" description="Comma-separated list of client names to provision." />
# <UDF name="WIREGUARD_PORT" label="Server Port" example="51820" description="Port for the WireGuard server to listen on." />
# <UDF name="BackupLocation" label="Backup Location" default="/mnt/long-term" example="/mnt/long-term" description="Location to store WireGuard backup files." />
# <UDF name="HTTP_PREFIX" label="HTTP Prefix" default="" example="10" description="HTTP port prefix for the web server. (e.g., 10 for ports 1080 and 10443)" />
# <UDF name="PIHOLE_WEBPASSWORD" label="Pi-hole Web Password" example="your-actually-long-password" description="Password for the Pi-hole web interface." />
# <UDF name="UPSTREAM_DNS" label="Upstream DNS" default="cloudflare-family" example="cloudflare-family" description="Upstream DNS server for Pi-hole. Options: see dnscrypt-proxy list: https://github.com/DNSCrypt/dnscrypt-resolvers/blob/master/v3/public-resolvers.md" />
# <UDF name="TZ" label="Timezone" default="UTC" example="America/New_York" description="Timezone for the server." />

# Exit on error, and log output to /var/log/stackscript.log
set -euo pipefail
trap 'echo "Error occurred on line $LINENO"; exit 1' ERR
exec > >(tee -i /var/log/stackscript.log) 2>&1

_server_public_ip=$(curl -s https://api.ipify.org/)
server_public_ip=${IP_ADDR:-$_server_public_ip}


packages_to_install="apt-transport-https ca-certificates curl figlet git"
. <ssinclude StackScriptID="1">
system_update
system_install_package ${packages_to_install}
ufw_install

# region, do it by hand??
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
apt-get install --no-install-recommends -y ${packages_to_install}
# endregion

# region setup networking
hostnamectl set-hostname $hostname
figlet "Welcome to $hostname !"
echo $server_public_ip $fqdn $hostname >> /etc/hosts
# endregion

# region generate SSH key
ssh-keygen -t ed25519 -C root@$hostname -q -N "" -f /root/.ssh/id_ed25519
echo "SSH pub key is"
cat /root/.ssh/id_ed25519.pub
eval "$(ssh-agent -s)"
ssh-add /root/.ssh/id_ed25519
# endregion


# ================================================================
# Download and install app
# ================================================================
mkdir -p /app/tiered-dns-server
pushd /app/tiered-dns-server
git clone https://github.com/mshafer1/tiered-dns-server.git .
git checkout ${GIT_BRANCH:-main}



cat <<EOF > .env
PIHOLE_WEBPASSWORD='${PIHOLE_WEBPASSWORD}'
WIREGUARD_PORT=${WIREGUARD_PORT}
HTTP_PREFIX=${HTTP_PREFIX}
UPSTREAM_DNS=${UPSTREAM_DNS:-cloudflare-family}
TZ=${TZ:-UTC}
EOF


bash setup.sh

figlet success
