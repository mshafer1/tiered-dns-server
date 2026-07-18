#!/bin/bash -v
set -euo pipefail

apt-get update && apt-get install -y curl nano ca-certificates

bash src/install_docker.sh
bash src/setup_ufw.sh
bash src/setup_updates.sh
bash src/setup_wg.sh

pushd src
docker compose pull
docker compose up -d
popd
