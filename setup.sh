#!/bin/bash -v
set -euo pipefail

if [[ ! "$ClientNames" =~ ^[A-Za-z0-9_,-]*$ ]]; then
    echo "Invalid client name in '$ClientNames' (allowed: A-Za-z0-9_-,)" >&2
    exit 1
fi

apt-get update && apt-get install -y curl nano ca-certificates

# this needs to be early so that the rest of the setup can use it
bash src/setup_rsnapshot.sh  || exit $?

bash src/install_docker.sh  || exit $?
bash src/setup_ufw.sh  || exit $?
bash src/setup_updates.sh  || exit $?
bash src/setup_wg.sh  || exit $?

if [ "${BACKUP_TO_RESTORE:-}" != "" ]; then
    # not quoting because it should be two args, the backup name and the snapshot index, separated by a space
    bash /usr/local/bin/restore-backup ${BACKUP_TO_RESTORE}  || exit $?
fi

OS_NAME=$(cat /etc/os-release | grep ^NAME=)
if [ "$OS_NAME" == "NAME=\"Ubuntu\"" ]; then
    bash src/ubuntu__configure_system_dns.sh  || exit $?
fi


pushd src
docker compose pull
docker compose up -d
popd

if [ "${{FQDN//./}}" == "${FQDN}" ]; then
    echo "FQDN is not set (or not set to a domain), skipping TLS setup"
else
    bash src/setup_tls_termination.sh  || exit $?
fi
