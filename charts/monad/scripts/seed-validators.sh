#!/bin/bash

set -euo pipefail

OUTPUT_DIR="/monad/validators"
SOURCE_FILE="/monad/config/validators.toml"
DEST_FILE="${OUTPUT_DIR}/validators.toml"

mkdir -p "${OUTPUT_DIR}"

if [[ ! -f "${SOURCE_FILE}" ]]; then
  echo "validators.toml missing from ConfigMap at ${SOURCE_FILE}" >&2
  exit 1
fi

if [[ -f "${DEST_FILE}" ]]; then
  echo "validators.toml already present at ${DEST_FILE}, skipping copy." >&2
  exit 0
fi

cp "${SOURCE_FILE}" "${DEST_FILE}"
