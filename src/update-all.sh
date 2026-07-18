#!/bin/bash -v
set -euo pipefail

# doing repo/docker first so that no work is needed after reboot
for file in self system; do
    bash src/update-${file}.sh
done
