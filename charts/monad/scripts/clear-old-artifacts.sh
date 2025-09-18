#!/bin/bash
set -Eeuo pipefail

echo "$(date -Iseconds) Running clear-old-artifacts.sh"

TARGET_DIR="/monad/ledger/"

NEW_FILES=$(find "$TARGET_DIR" -type f -name "*" -mmin -20)
if [ -n "$NEW_FILES" ]
then
  echo "$(date -Iseconds) New files detected. Proceeding to delete old artifacts."

  find /monad/forkpoint/ -type f -name "forkpoint.toml.*" -mmin +60 -delete
  find /monad/ledger/ -type f -name "*.body" -mmin +60 -delete
  find /monad/ledger/ -type f -name "*.header" -mmin +60 -delete
  find /monad/ -type f -name "wal_*" -mmin +60 -delete
else
  echo "$(date -Iseconds) No new files detected. Skipping deletion of .header files."
fi

echo "$(date -Iseconds) Finished running clear-old-artifacts.sh"
