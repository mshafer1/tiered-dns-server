#!/bin/bash -v
set -euo pipefail

if [[ ! "$ClientNames" =~ ^[A-Za-z0-9_,-]*$ ]]; then
    echo "Invalid client name in '$ClientNames' (allowed: A-Za-z0-9_-,)" >&2
    exit 1
fi

handleError() {
    echo "An error occurred on line $1"
    exit 1
}
trap 'handleError $LINENO' ERR

apt-get update && apt-get install -y curl nano ca-certificates

# this needs to be early so that the rest of the setup can use it
bash src/setup_rsnapshot.sh

bash src/install_docker.sh
bash src/setup_ufw.sh
bash src/setup_updates.sh
SETUP_WG=${SETUP_WG:-true}
SETUP_WG=${SETUP_WG,,}
export SETUP_WG
if [ "${SETUP_WG}" == "true" ]; then
    bash src/setup_wg.sh
fi

if [ "${BACKUP_TO_RESTORE:-}" != "" ]; then
    # not quoting because it should be two args, the backup name and the snapshot index, separated by a space
    bash /usr/local/bin/restore-backup ${BACKUP_TO_RESTORE}  || exit $?
fi

OS_NAME=$(cat /etc/os-release | grep ^NAME=)
if [ "$OS_NAME" == "NAME=\"Ubuntu\"" ]; then
    bash src/ubuntu__configure_system_dns.sh  || exit $?
fi


pushd src
cat > .env <<EOF
EXTERNAL_NETWORK_INTERFACE=${EXTERNAL_NETWORK_INTERFACE:-}
HTTP_PREFIX=${HTTP_PREFIX:-40}
IP_PREFIX=${IP_PREFIX:-127.0.0}
PIHOLE_WEBPASSWORD=${PIHOLE_WEBPASSWORD}
TZ=${TZ:-UTC}
UPSTREAM_DNS=${UPSTREAM_DNS:-1.0.0.3}
FQDN=${FQDN:-router.lan}
EOF
docker compose pull
docker compose up -d
popd

FQDN="${FQDN:-}" # Default to empty string if FQDN is not set

if [ -z "${FQDN}" ] || [[ "${FQDN}" != *.* ]]; then
    # no dot in FQDN
    echo "FQDN is not set (or not set to a domain), skipping TLS setup"
elif [[ "${FQDN}" == *.lan ]]; then
    echo "FQDN is a local domain (*.lan), skipping TLS setup"
else
    bash src/setup_tls_termination.sh  || exit $?
fi
