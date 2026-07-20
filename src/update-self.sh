#!/bin/bash -v
set -euo pipefail

pushd "$(realpath "$(dirname "$0")")"
git pull --ff-only

# primarily concerned with updating docker-compose file
docker compose pull
docker compose down
docker compose up -d
popd
