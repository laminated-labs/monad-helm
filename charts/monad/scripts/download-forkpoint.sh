# This script is based off of the Monad provided script found at:
# https://bucket.monadinfra.com/scripts/testnet/download-forkpoint.sh
# It has been modified to fit the structure of this Helm chart at points
#
# NETWORK: TESTNET
#!/bin/bash

# Enable strict error handling
set -euo pipefail

# Configuration
# This value is modified from the upstream location to match the overall chart structure
LOCAL_FORKPOINT_DIR="/monad/forkpoint"
LOCAL_FORKPOINT_FILE="forkpoint.toml"
LOCAL_FORKPOINT="${LOCAL_FORKPOINT_DIR}/${LOCAL_FORKPOINT_FILE}"
REMOTE_BASE_URL="https://bucket.monadinfra.com/forkpoint/testnet/"

# Command line options
VERBOSE=false
DRY_RUN=false

# Help function
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Downloads the remote forkpoint file for the network if it's newer than the local version.

Options:
  -h, --help     Show this help message
  -v, --verbose  Enable verbose output
  -d, --dry-run  Show what would be done without making changes
EOF
    exit 0
}

# Logging function
log() {
    if [ "$VERBOSE" = true ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
    fi
}

# Parse command line options
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
done

# Platform-specific date command with consistent timezone
if [[ "$OSTYPE" == "darwin"* ]]; then
    CURRENT_TIME=$(TZ="America/New_York" date -v -1M +"%Y%m%d%H%M")
else
    CURRENT_TIME=$(TZ="America/New_York" date -d "-1 minutes" +"%Y%m%d%H%M")
fi

REMOTE_FILE_NAME="forkpoint_${CURRENT_TIME}01.toml"
REMOTE_FULL_URL="${REMOTE_BASE_URL}${REMOTE_FILE_NAME}"

# Function to extract round from forkpoint file
extract_round() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        echo "0"
        return
    fi
    
    local round
    # Try Qc variant first
    round=$(awk '/\[high_certificate\.Qc\.info\]/{flag=1; next} /\[/{flag=0} flag && /^round[[:space:]]*=/{print $3; exit}' "$file")
    
    if [[ -n "$round" && "$round" =~ ^[0-9]+$ ]]; then
        echo "$round"
        return
    fi
    
    # Try Tc variant if Qc not found
    round=$(awk '/\[high_certificate\.Tc\]/{flag=1; next} /\[/{flag=0} flag && /^round[[:space:]]*=/{print $3; exit}' "$file")
    
    if [[ -n "$round" && "$round" =~ ^[0-9]+$ ]]; then
        echo "$round"
    else
        echo "0"
    fi
}

# Check if the remote file exists
log "Checking remote file: $REMOTE_FULL_URL"
if ! curl --head --silent --fail "$REMOTE_FULL_URL" > /dev/null; then
    echo "File not found: $REMOTE_FULL_URL"
    exit 1
fi

# Download remote file to temporary location for comparison
TEMP_FILE=$(mktemp)
trap 'rm -f "$TEMP_FILE"' EXIT

log "Downloading remote file for comparison"
if ! curl -s -o "$TEMP_FILE" "$REMOTE_FULL_URL"; then
    echo "Failed to download remote file for comparison"
    exit 1
fi

# Extract rounds from both files
REMOTE_ROUND=$(extract_round "$TEMP_FILE")
if ! [[ "$REMOTE_ROUND" =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid remote round: $REMOTE_ROUND"
    exit 1
fi

LOCAL_ROUND=0
if [ -f "$LOCAL_FORKPOINT" ]; then
    LOCAL_ROUND=$(extract_round "$LOCAL_FORKPOINT")
    if ! [[ "$LOCAL_ROUND" =~ ^[0-9]+$ ]]; then
        echo "Error: Invalid local round: $LOCAL_ROUND"
        exit 1
    fi
fi

log "Remote round: $REMOTE_ROUND"
log "Local round: $LOCAL_ROUND"

# Compare rounds
if [ "$REMOTE_ROUND" -le "$LOCAL_ROUND" ] && [ "$LOCAL_ROUND" -ne 0 ]; then
    echo "Remote forkpoint (round $REMOTE_ROUND) is not newer than local forkpoint (round $LOCAL_ROUND). Skipping download."
    exit 0
fi

if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would download and install: $REMOTE_FILE_NAME (round $REMOTE_ROUND)"
    exit 0
fi

# Backup existing file and replace with new one
if [ -f "$LOCAL_FORKPOINT" ]; then
    cp "$LOCAL_FORKPOINT" "${LOCAL_FORKPOINT}.bak.$(date +%Y%m%d%H%M%S)"
    log "Backed up existing forkpoint file"
fi

mv "$TEMP_FILE" "$LOCAL_FORKPOINT"
chown monad:monad "$LOCAL_FORKPOINT"
echo "Downloaded and installed newer forkpoint file: $REMOTE_FILE_NAME (round $REMOTE_ROUND)"