#!/bin/bash

set -Eeuo pipefail

stop=0
sleep_pid=""

trap '
    stop=1
    if [ -n "$sleep_pid" ]; then
        kill "$sleep_pid" 2>/dev/null || true
    fi
' TERM INT

echo "$(date -Iseconds) Running clear-old-artifacts.sh"

TARGET_DIR="/monad/ledger/"

# Retention times in minutes
RETENTION_FORKPOINT=${RETENTION_FORKPOINT:-300}      # 5 hours (forkpoint.rlp.* and forkpoint.toml.*)
RETENTION_VALIDATORS=${RETENTION_VALIDATORS:-43200}  # 30 days (validators.toml.*)
RETENTION_LEDGER=${RETENTION_LEDGER:-600}            # 10 hours (headers and bodies)
RETENTION_WAL=${RETENTION_WAL:-300}                  # 5 hours (wal_* files)

function clear_artifacts() {
  echo "$(date -Iseconds) Cleanup script started: RETENTION_LEDGER=${RETENTION_LEDGER}min, RETENTION_WAL=${RETENTION_WAL}min, RETENTION_FORKPOINT=${RETENTION_FORKPOINT}min, RETENTION_VALIDATORS=${RETENTION_VALIDATORS}min"

  NEW_FILES=$(find "$TARGET_DIR" -type f -name "*" -mmin -20)
  if [ -n "$NEW_FILES" ]
  then
    echo "$(date -Iseconds) New files detected. Proceeding to delete old artifacts."

    if [ -d /monad/forkpoint ]
    then
        echo "$(date -Iseconds) clearing forkpoints"
        find /monad/forkpoint/ -type f -name "forkpoint.rlp.*" -mmin +${RETENTION_FORKPOINT} -delete 2>/dev/null
        find /monad/forkpoint/ -type f -name "forkpoint.toml.*" -mmin +${RETENTION_FORKPOINT} -delete 2>/dev/null
    fi

    if [ -d /monad/validators ]
    then
        echo "$(date -Iseconds) clearing validators"
        find /monad/validators/ -type f -name "validators.toml.*" -mmin +${RETENTION_VALIDATORS} -delete 2>/dev/null
    fi

    if [ -d /monad/ledger/headers ]
    then
        echo "$(date -Iseconds) clearing ledger headers"
        find /monad/ledger/headers -type f -mmin +${RETENTION_LEDGER} -delete 2>/dev/null
    fi

    if [ -d /monad/ledger/bodies ]
    then
        echo "$(date -Iseconds) clearing ledger bodies"
        find /monad/ledger/bodies -type f -mmin +${RETENTION_LEDGER} -delete 2>/dev/null
    fi

    find /monad/ -type f -name "wal_*" -mmin +${RETENTION_WAL} -delete 2>/dev/null

    echo "$(date -Iseconds) Cleanup completed successfully"
  else
    echo "$(date -Iseconds) No new files detected. Skipping deletion of ledger files."
  fi
}

while [ "$stop" -eq 0 ]
do
  clear_artifacts

  sleep_pid=""
  sleep 600 &
  sleep_pid="$!"

  # wait may exit non-zero because we killed sleep; ignore it
  wait "$sleep_pid" || true
done
