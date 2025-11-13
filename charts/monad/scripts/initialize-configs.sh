#!/bin/bash
set -Eeuo pipefail

NETWORK=testnet

VALIDATORS_CONFIG_PATH=/monad/validators
VALIDATORS_FILE="${VALIDATORS_CONFIG_PATH}/validators.toml"

FORKPOINT_CONFIG_PATH=/monad/forkpoint
FORKPOINT_FILE="${FORKPOINT_CONFIG_PATH}/forkpoint.toml"

## Note: This script requires TimeZone data to be installed in the container.
## By default, ubuntu containers do not have this data installed but debian containers do.

## This script is based off of the Monad provided script found at:
# https://bucket.monadinfra.com/scripts/${NETWORK}/download-forkpoint.sh

# printline prints a timestamped message
function printline() {
  echo "$(date -Iseconds) $1"
}

function check_deps() {
  # Install curl to fetch the file
  if ! command -v curl >/dev/null 2>&1
  then
    printline "curl is not installed. Installing it now..."
    apt-get update && apt-get install -y curl
  fi
}

function download_forkpoint() {
  check_deps

  BASE_URL="https://bucket.monadinfra.com/forkpoint/${NETWORK}" #Forkpoint url folder
  CURRENT_TIME=$(TZ="America/New_York" date -d "-1 minutes" +"%Y%m%d%H%M")
  FILE_NAME="forkpoint_${CURRENT_TIME}01.toml"
  FULL_URL="${BASE_URL}/${FILE_NAME}"

  if curl --head --silent --fail "$FULL_URL"
  then
    printline "Downloading forkpoint file"
    curl -o "${FORKPOINT_FILE}" "${FULL_URL}"
    printline "Forkpoint file downloaded - ${FULL_URL}"
  else
    printline "Forkpoint file not found - ${FULL_URL}, skipping download"
  fi
}

function download_validators() {
  check_deps

  printline "Downloading validators file"
  curl -o "${VALIDATORS_FILE}" "https://bucket.monadinfra.com/validators/${NETWORK}/validators.toml"
  printline "Validators file downloaded"
}

printline "Initializing config files for ${NETWORK}..."

# If no forkpoint.toml file exists, download it
if [[ ! -e "${FORKPOINT_FILE}" ]]
then
  printline "No forkpoint file found, downloading..."

  # Ensure the directory exists
  mkdir -p "${FORKPOINT_CONFIG_PATH}"
  download_forkpoint
fi

if [[ ! -e "${VALIDATORS_FILE}" ]]
then
  printline "No validators.toml file found, downloading..."

  # Ensure directory exists
  mkdir -p "${VALIDATORS_CONFIG_PATH}"
  download_validators

  printline "Successfully downloaded validators.toml"
fi

# Check if sentinel file set to re-download forkpoint.toml
if [ -e /monad/SOFT_RESET_SENTINEL_FILE ]
then
  printline "Sentinel file found, performing soft reset..."
  cp "${FORKPOINT_FILE}" "${FORKPOINT_FILE}.bak"
  cp "${VALIDATORS_FILE}" "${VALIDATORS_FILE}.bak"

  download_forkpoint
  download_validators

  # Remove the sentinel file
  rm /monad/SOFT_RESET_SENTINEL_FILE

  printline "Soft reset completed."
fi

printline "All config files initialized."
