#!/bin/bash -v
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# doing repo/docker first so that no work is needed after reboot
for file in self system; do
    bash "${SCRIPT_DIR}/update-${file}.sh"
done
