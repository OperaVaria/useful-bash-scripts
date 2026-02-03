#!/usr/bin/env bash
#
# A Small script to add unified_extractor.sh to /usr/local/bin/ as "extract",
# so that it could be used as a built-in like command.
#
set -euo pipefail
read -t 30 -p \
    "Are you sure you want to add 'extract' to usr/local/bin? (Y/N):" \
    -n 1 -r
echo
[[ ! "${REPLY}" =~ ^[Yy]$ ]] && exit 1
chmod +x unified_extractor.sh
sudo cp unified_extractor.sh /usr/local/bin/extract
echo "Completed"