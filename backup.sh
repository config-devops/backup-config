#!/bin/bash
set -e

# ==================================================
# CONFIG
# ==================================================
MC_BIN="/usr/local/bin/mc"
MC_URL="https://dl.min.io/client/mc/release/linux-amd64/mc"

# ==================================================
# CHECK & INSTALL MINIO CLIENT
# ==================================================
echo ">> Checking MinIO Client (mc)..."

if [[ ! -x "$MC_BIN" ]]; then
  echo ">> MinIO Client not found, installing..."

  if ! command -v sudo >/dev/null 2>&1; then
    echo "ERROR: sudo is required to install mc"
    exit 1
  fi

  wget -q "$MC_URL" -O /tmp/mc
  chmod +x /tmp/mc
  sudo mv /tmp/mc "$MC_BIN"

  echo ">> MinIO Client installed at $MC_BIN"
else
  echo ">> MinIO Client already installed"
fi

# ==================================================
# BASIC INPUT
# ==================================================
read -rp "MinIO alias        : " MINIO_ALIAS
read -rp "Custom backup name : " CUSTOM_NAME
read -rp "Exclude folder(s) under /home/devops (comma separated, optional): " EXCLUDE_INPUT

# ==================================================
# STATIC CONFIG
# ==================================================
DATE=$(date +"%Y%m%d")
BACKUP_NAME="${CUSTOM_NAME}-${DATE}.tar.gz"

TMP_DIR="/tmp"
BACKUP_PATH="${TMP_DIR}/${BACKUP_NAME}"

MINIO_BUCKET="bucket-file"
MINIO_PREFIX="backup-baremetal"
MINIO_TARGET="${MINIO_ALIAS}/${MINIO_BUCKET}/${MINIO_PREFIX}"

# ==================================================
# CHECK / SET MINIO ALIAS
# ==================================================
echo ">> Checking MinIO alias..."

NEED_CONFIG=false

if "$MC_BIN" alias ls | awk '{print $1}' | grep -qx "${MINIO_ALIAS}"; then
  echo ">> Alias '${MINIO_ALIAS}' exists, testing connection..."

  if "$MC_BIN" ls "${MINIO_ALIAS}" >/dev/null 2>&1; then
    echo ">> MinIO credential valid"
  else
    echo "!! Alias exists but credential INVALID"
    NEED_CONFIG=true
  fi
else
  echo "!! Alias '${MINIO_ALIAS}' not found"
  NEED_CONFIG=true
fi

if [[ "$NEED_CONFIG" == true ]]; then
  echo ">> Please input MinIO configuration"

  read -rp "MinIO endpoint     : " MINIO_ENDPOINT
  read -rp "MinIO Access Key   : " MINIO_ACCESS_KEY
  read -rsp "MinIO Secret Key  : " MINIO_SECRET_KEY
  echo ""

  "$MC_BIN" alias set \
    "$MINIO_ALIAS" \
    "$MINIO_ENDPOINT" \
    "$MINIO_ACCESS_KEY" \
    "$MINIO_SECRET_KEY"

  echo ">> Alias '${MINIO_ALIAS}' configured successfully"
fi

# ==================================================
# BUILD EXCLUDE PARAMS
# ==================================================
EXCLUDE_PARAMS=()
IFS=',' read -ra EXCLUDES <<< "$EXCLUDE_INPUT"

for dir in "${EXCLUDES[@]}"; do
  dir=$(echo "$dir" | xargs)
  [[ -n "$dir" ]] && EXCLUDE_PARAMS+=( "--exclude=/home/devops/${dir}" )
done

# ==================================================
# CHECK / CREATE BUCKET
# ==================================================
echo ">> Checking bucket..."
"$MC_BIN" ls "${MINIO_ALIAS}/${MINIO_BUCKET}" >/dev/null 2>&1 \
  || "$MC_BIN" mb "${MINIO_ALIAS}/${MINIO_BUCKET}"

# ==================================================
# CREATE BACKUP
# ==================================================
echo ">> Creating backup archive..."

tar -czf "$BACKUP_PATH" \
  "${EXCLUDE_PARAMS[@]}" \
  /home/devops \
  /etc/nginx/nginx.conf \
  /etc/hosts

echo ">> Backup created: $BACKUP_PATH"

# ==================================================
# UPLOAD TO MINIO
# ==================================================
echo ">> Uploading to MinIO..."
"$MC_BIN" cp "$BACKUP_PATH" "${MINIO_TARGET}/"
echo ">> Upload success!"

# ==================================================
# CLEANUP
# ==================================================
rm -f "$BACKUP_PATH"
echo ">> Local backup cleaned up"

echo ">> Done."
