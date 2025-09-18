#!/bin/bash
set -Eeuo pipefail

## Note: This script requires TimeZone data to be installed in the container.
## By default, ubuntu containers do not have this data installed but debian containers do.

## This script is based off of the Monad provided script found at:
# https://bucket.monadinfra.com/scripts/testnet/download-forkpoint.sh

# printline prints a timestamped message
function printline() {
  echo "$(date -Iseconds) $1"
}

download_forkpoint() {
  # Install curl to fetch the file
  if ! command -v curl >/dev/null 2>&1
  then
    printline "curl is not installed. Installing it now..."
    apt-get update && apt-get install -y curl
  fi

  BASE_URL="https://bucket.monadinfra.com/forkpoint/testnet" #Forkpoint url folder
  CURRENT_TIME=$(TZ="America/New_York" date -d "-2 minutes" +"%Y%m%d%H%M")
  FILE_NAME="forkpoint_${CURRENT_TIME}01.toml"
  FULL_URL="${BASE_URL}/${FILE_NAME}"

  if curl --head --silent --fail "$FULL_URL"
  then
    printline "Downloading forkpoint file"
    curl -o /monad/forkpoint/forkpoint.toml "${FULL_URL}"
    printline "Forkpoint file downloaded - ${FULL_URL}"
  else
    printline "Forkpoint file not found - ${FULL_URL}, skipping download"
  fi
}

# If no forkpoint.toml file exists, download it
if [[ ! -e /monad/forkpoint/forkpoint.toml ]]
then
  printline "No forkpoint file found, downloading..."

  # Ensure the directory exists
  mkdir -p /monad/forkpoint
  download_forkpoint

  exit 0
fi

# Check if sentinel file set to re-download forkpoint.toml
if [ -e /monad/SOFT_RESET_SENTINEL_FILE ]
then
  printline "Sentinel file found, re-downloading forkpoint.toml"
  cp /monad/forkpoint/forkpoint.toml /monad/forkpoint/forkpoint.toml.bak
  download_forkpoint

  # Remove the sentinel file
  rm /monad/SOFT_RESET_SENTINEL_FILE

  exit 0
fi

printline "No need to download forkpoint.toml, skipping..."
