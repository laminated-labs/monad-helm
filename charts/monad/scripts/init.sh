#! /bin/bash

set -Eeuo pipefail

# printline prints a timestamped message
function printline() {
  echo "$(date -Iseconds) $1"
}

HAS_UPDATED=false

# check_dependency checks if a command is available, and installs it if not
function check_dependency() {
  if ! command -v "$1" >/dev/null 2>&1
  then
    printline "$1 is not installed. Installing it now..."
    
    if [ "$HAS_UPDATED" = false ]
    then
      printline "Updating package lists..."
      apt-get update
      HAS_UPDATED=true
    fi
    
    if [ -n "${2:-}" ]
    then
      apt-get install -y "$2"
    else
      apt-get install -y "$1"
    fi
  fi
}

# reset performs a hard reset of the Monad filesystem.
# This is a destructive operation that will delete all local block data.
# This function is based on the Monad provided script found at:
# https://pub-b0d0d7272c994851b4c8af22a766f571.r2.dev/scripts/testnet/reset-workspace.sh
function reset() {
  check_dependency rsync

  mkdir -p /monad/empty-dir
  rsync -r --delete /monad/empty-dir/ /monad/ledger/
  rsync -r --delete /monad/empty-dir/ /monad/forkpoint/
  rsync -r --delete /monad/empty-dir/ /monad/validators/
  touch /monad/ledger/wal
  rm -rf /monad/empty-dir
  rm -rf /monad/snapshots
  rm -f /monad/mempool.sock
  rm -f /monad/controlpanel.sock
  rm -f /monad/wal_*
  rm -rf /monad/blockdb
  monad-mpt --storage /dev/triedb --truncate --yes

  # Remove the reset file
  rm -rf /monad/HARD_RESET_SENTINEL_FILE
  # Remove the MPT sentinel file to force initialization
  rm -rf /monad/MPT_SENTINEL_FILE
  # Set sentinel file to restore from snapshot
  touch /monad/RESTORE_FROM_SNAPSHOT_SENTINEL_FILE
}

# initialize_triedb initializes the Monad TrieDB.
function initialize_triedb() {
  monad-mpt --storage /dev/triedb --create

  # include the time the MPT was created
  date --iso-8601=seconds > /monad/MPT_SENTINEL_FILE

  # If triedb is being created, we should try to restore from snapshot
  touch /monad/RESTORE_FROM_SNAPSHOT_SENTINEL_FILE
}

# restore_from_snapshot downloads the latest snapshot and restores the Monad TrieDB.
# Based on the Monad provided script found at:
# https://pub-b0d0d7272c994851b4c8af22a766f571.r2.dev/scripts/testnet/restore_from_snapshot.sh
function restore_from_snapshot() {
  CLOUDFRONT_URL={{ .Values.node.snapshots.url | quote }}
  DEST_FOLDER="/monad/snapshots"

  check_dependency aria2c aria2
  check_dependency curl
  check_dependency zstd

  mkdir -p "$DEST_FOLDER"

  latest=$(curl -s "$CLOUDFRONT_URL/latest.txt")
  if [[ -z "$latest" ]]
  then
    printline "latest.txt is empty or not accessible"
    exit 1
  fi

  printline "Latest file: $latest"
  base="${latest%.tar.zst}"

  cd "$DEST_FOLDER" || exit 10

  block_id=$(echo "$latest" | awk -F'-' '{split($2,a,"."); print a[1]}')
  printline "$block_id"

  # Download .tar.zst and .checksum
  for ext in tar.zst checksum
  do
    file="$base.$ext"

    if [ -e "$file" ]
    then
      printline "$file already exists, skipping download"
      continue
    fi

    printline "Downloading $base.$ext"
    if ! aria2c -x 8 -s 8 "$CLOUDFRONT_URL/$file"
    then
      printline "Failed to download $file"
      exit 1
    fi
  done

  # Verify checksum
  printline "Verifying checksum..."
  if sha256sum -c "$base.checksum"
  then
    printline "Checksum verified successfully."
  else
    printline "Checksum verification failed. You may need to remove existing snapshots"
    exit 2
  fi

  unzstd -c "$DEST_FOLDER/$latest.tar.zst" | tar -xf - -C "$DEST_FOLDER"

  monad-cli --db /dev/triedb --load_binary_snapshot /monad/snapshots --version "$block_id" --sq_thread_cpu 15

  rm /monad/RESTORE_FROM_SNAPSHOT_SENTINEL_FILE
}

printline "Starting Monad initialization script..."

# Perform filesystem reset if the sentinel file is present
if [ -e /monad/HARD_RESET_SENTINEL_FILE ]
then
  printline "Reset sentinel file found, doing reset"
  reset
  printline "Reset completed"
else
  printline "No reset sentinel file found, skipping reset"
fi

# Initialize the TrieDB system if the MPT sentinel file does not exist
if [ ! -f /monad/MPT_SENTINEL_FILE ]; then
  printline "Creating MPT"
  initialize_triedb
  printline "MPT created"
else
  printline "MPT already completed, skipping"
fi

# Restore from snapshot if the sentinel file is present
if [ -e /monad/RESTORE_FROM_SNAPSHOT_SENTINEL_FILE ]
then
  {{- if .Values.node.snapshots.enabled }}
  printline "Restoring from snapshot"
  restore_from_snapshot
  printline "Extract completed, you can start the node by fetching a new forkpoint and run docker compose up -d"
  {{- else }}
  printline "Snapshot restore requested but snapshot restore is disabled in configuration, skipping restore"
  rm /monad/RESTORE_FROM_SNAPSHOT_SENTINEL_FILE
  {{- end }}
else
  printline "No restore-from-snapshot sentinel file found, skipping restore"
fi

printline "Monad initialization script completed successfully."
