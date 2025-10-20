#!/bin/bash
set -Eeuo pipefail

echo "$(date -Iseconds) Running clear-old-artifacts.sh"

TARGET_DIR="/monad/ledger/"

NEW_FILES=$(find "$TARGET_DIR" -type f -name "*" -mmin -20)
if [ -n "$NEW_FILES" ]
then
  echo "$(date -Iseconds) New files detected. Proceeding to delete old artifacts."

  find /monad/forkpoint/ -type f -name "forkpoint.toml.*" -mmin +300 -delete
  find /monad/validators/ -type f -name "validators.toml.*" -mmin +30 -delete
  find /monad/ledger/headers -type f -mmin +600 -delete
  find /monad/ledger/bodies -type f -mmin +600 -delete
  find /monad/ -type f -name "wal_*" -mmin +300 -delete
else
  echo "$(date -Iseconds) No new files detected. Skipping deletion of .header files."
fi

echo "$(date -Iseconds) Finished running clear-old-artifacts.sh"
