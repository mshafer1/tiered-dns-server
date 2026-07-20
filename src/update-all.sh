#!/bin/bash -v
set -euo pipefail

SCRIPT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"

# doing repo/docker first so that no work is needed after reboot
for file in self system; do
    bash "${SCRIPT_DIR}/update-${file}.sh"
done
