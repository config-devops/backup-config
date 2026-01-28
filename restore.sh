#!/bin/bash
set -e

# ==================================================
# CONFIG
# ==================================================
MC_BIN="/usr/local/bin/mc"
MC_URL="https://dl.min.io/client/mc/release/linux-amd64/mc"

MINIO_BUCKET="bucket-file"
MINIO_PREFIX="backup-baremetal"

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
read -rp "Backup file name  : " BACKUP_FILE

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
# DOWNLOAD BACKUP FILE
# ==================================================
SOURCE_PATH="${MINIO_ALIAS}/${MINIO_BUCKET}/${MINIO_PREFIX}/${BACKUP_FILE}"
LOCAL_PATH="./${BACKUP_FILE}"

echo ">> Downloading backup file..."
"$MC_BIN" cp "$SOURCE_PATH" "$LOCAL_PATH"

echo ">> Backup file downloaded: $LOCAL_PATH"

# ==================================================
# CONFIRM RESTORE
# ==================================================
echo ""
echo "⚠️  WARNING"
echo "This will EXTRACT backup to root filesystem (/)"
echo "Files may be overwritten:"
echo "  - /home/devops"
echo "  - /etc/nginx/nginx.conf"
echo "  - /etc/hosts"
echo ""

read -rp "Continue restore? (yes/no): " CONFIRM
[[ "$CONFIRM" != "yes" ]] && echo ">> Restore aborted" && exit 0

# ==================================================
# RESTORE (UNTAR)
# ==================================================
echo ">> Restoring backup (sudo required)..."

sudo tar -xzp -f "$LOCAL_PATH" -C /

echo ">> Restore completed successfully"

# ==================================================
# CLEANUP
# ==================================================
read -rp "Remove downloaded backup file? (y/n): " CLEANUP
if [[ "$CLEANUP" == "y" ]]; then
  rm -f "$LOCAL_PATH"
  echo ">> Local backup file removed"
fi

echo ">> Done."
