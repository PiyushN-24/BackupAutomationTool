#!/bin/bash

# ----------------------------------------------------------------------------
# Script: backup_script.sh
# Description: This script performs a backup of a specified directory to a
#              destination directory. It supports optional compression using
#              gzip, bzip2, zip, or xz. The script logs the status of the 
#              backup operation and optionally removes old backups. It can 
#              also copy the backup to a remote server via SCP.
#              
#              The script includes the following features:
#              - Compression of the backup using various methods
#              - Progress display during compression
#              - Logging of backup status, including success and error messages
#              - Automatic removal of backups older than 7 days
#              - Management of log file size to prevent it from growing too large
#              - Cross-server backup via SCP to a remote server
#              
# Usage: backup_script.sh -s <source_dir> -d <dest_dir> [-c <compression_method>] [-r <remote_path>]
# Options:
#  -s <source_dir>       Directory to back up (e.g., /path/to/source)
#  -d <dest_dir>         Directory to store backups (e.g., /path/to/backup)
#  -c <compression_method> Compression method to use: bzip2, gzip, zip, xz (default: gzip)
#  -r <remote_path>      Remote server path in the format username@ipaddress:/path/to/remote/backup (optional)
# ----------------------------------------------------------------------------

# Default values
COMPRESSION_METHOD="gzip"
REMOTE_PATH=""

# Define color codes for status indicators (console output only)
SUCCESS_COLOR='\033[0;32m'  # Green
ERROR_COLOR='\033[0;31m'    # Red
RESET_COLOR='\033[0m'       # Reset to default

# Usage function
usage() {
  echo "Usage: $0 -s <source_dir> -d <dest_dir> [-c <compression_method>] [-r <remote_path>]"
  echo "  -s <source_dir>       Directory to back up (e.g., /path/to/source)"
  echo "  -d <dest_dir>         Directory to store backups (e.g., /path/to/backup)"
  echo "  -c <compression_method> Compression method to use: bzip2, gzip, zip, xz (default: gzip)"
  echo "  -r <remote_path>      Remote server path in the format username@ipaddress:/path/to/remote/backup (optional)"
  exit 1
}

# Parse command-line arguments
while getopts ":s:d:c:r:" opt; do
  case ${opt} in
    s) BACKUP_SRC="${OPTARG}" ;;
    d) BACKUP_DEST="${OPTARG}" ;;
    c) COMPRESSION_METHOD="${OPTARG}" ;;
    r) REMOTE_PATH="${OPTARG}" ;;
    *) usage ;;
  esac
done
shift $((OPTIND -1))

# Validate required arguments
if [ -z "${BACKUP_SRC}" ] || [ -z "${BACKUP_DEST}" ]; then
  echo "Error: Source directory and destination directory are required." >&2
  usage
fi

# Function to install pv if not already installed
install_pv() {
  if ! command -v pv &> /dev/null; then
    echo "pv is not installed. Installing..."
    if command -v apt-get &> /dev/null; then
      sudo apt-get install -y pv
    elif command -v yum &> /dev/null; then
      sudo yum install -y pv
    elif command -v dnf &> /dev/null; then
      sudo dnf install -y pv
    elif command -v pacman &> /dev/null; then
      sudo pacman -Sy pv --noconfirm
    elif command -v zypper &> /dev/null; then
      sudo zypper install -y pv
    else
      echo "Error: Package manager not found. Install pv manually." >&2
      exit 1
    fi
  fi
}

install_pv

# Set log file path
LOG_FILE="$BACKUP_DEST/backup.log"

# Check if the destination directory is writable
if [ ! -w "$BACKUP_DEST" ]; then
  echo "Error: Destination directory is not writable." >&2
  exit 1
fi

# Set backup file name and path
DATE=$(date +'%Y-%m-%d_%H-%M-%S')
BACKUP_FILE="$BACKUP_DEST/$(basename "$BACKUP_SRC")_backup_$DATE"

# Check if the source directory exists
if [ ! -d "$BACKUP_SRC" ]; then
  echo "Error: Source directory '$BACKUP_SRC' does not exist." >&2
  echo "$DATE: ERROR - Backup failed: Source directory does not exist" >> "$LOG_FILE"
  exit 1
fi

# Get source directory size
SOURCE_SIZE=$(du -sb "$BACKUP_SRC" | awk '{print $1}')

# Compress with progress
compress_with_progress() {
  local method="$1"
  local src="$2"
  local dest="$3"
  local size="$4"

  case ${method} in
    gzip)  tar -cf - -C "$src" . | pv --size "$size" | gzip > "$dest.tar.gz" ;;
    bzip2) tar -cf - -C "$src" . | pv --size "$size" | bzip2 > "$dest.tar.bz2" ;;
    xz)    tar -cf - -C "$src" . | pv --size "$size" | xz > "$dest.tar.xz" ;;
    zip)   (cd "$src" && zip -r - .) | pv --size "$size" > "$dest.zip" ;;
    *) echo "Error: Invalid compression method: $method" >&2; exit 1 ;;
  esac
}

compress_with_progress "$COMPRESSION_METHOD" "$BACKUP_SRC" "$BACKUP_FILE" "$SOURCE_SIZE"

# Check the exit status of the compression command
if [ $? -ne 0 ]; then
    echo "$DATE: ERROR - Compression failed for method $COMPRESSION_METHOD" >> "$LOG_FILE"
    echo -e "${ERROR_COLOR}Compression failed for method $COMPRESSION_METHOD${RESET_COLOR}" >&2
    exit 1
fi

# Determine the correct file extension based on compression method
case ${COMPRESSION_METHOD} in
  gzip)  BACKUP_FILE="$BACKUP_FILE.tar.gz" ;;
  bzip2) BACKUP_FILE="$BACKUP_FILE.tar.bz2" ;;
  xz)    BACKUP_FILE="$BACKUP_FILE.tar.xz" ;;
  zip)   BACKUP_FILE="$BACKUP_FILE.zip" ;;
  *) echo "Error: Invalid compression method: $COMPRESSION_METHOD" >&2; exit 1 ;;
esac

# Verify the backup file was created successfully and is not empty
if [ -f "$BACKUP_FILE" ] && [ -s "$BACKUP_FILE" ]; then
    echo "$DATE: SUCCESS - Backup successful: $BACKUP_FILE" >> "$LOG_FILE"
    echo -e "${SUCCESS_COLOR}Backup successful: $BACKUP_FILE${RESET_COLOR}"
else
    echo "$DATE: ERROR - Backup failed: $BACKUP_FILE" >> "$LOG_FILE"
    echo -e "${ERROR_COLOR}Backup failed: $BACKUP_FILE${RESET_COLOR}" >&2
    exit 1
fi

# Optional: Remove backups older than 7 days
find "$BACKUP_DEST" -type f \( -name "*.tar.gz" -o -name "*.tar.bz2" -o -name "*.tar.xz" -o -name "*.zip" \) -mtime +7 -exec rm {} \;

# Manage log file size
LOG_FILE_SIZE=$(du -k "$LOG_FILE" | cut -f1)
MAX_LOG_SIZE=10240  # 10MB in KB

if [ "$LOG_FILE_SIZE" -ge "$MAX_LOG_SIZE" ]; then
    mv "$LOG_FILE" "$LOG_FILE.old"
    touch "$LOG_FILE"
fi

# Cross-server backup
if [ -n "$REMOTE_PATH" ]; then
  echo "Verifying remote server availability..."
  if ssh -q -o BatchMode=yes -o ConnectTimeout=5 "${REMOTE_PATH%%:*}" exit; then
      echo "Copying backup to remote server..."
      scp "$BACKUP_FILE" "$REMOTE_PATH"
      if [ $? -eq 0 ]; then
          echo "$DATE: SUCCESS - Successfully copied backup to remote server." >> "$LOG_FILE"
          echo -e "${SUCCESS_COLOR}Successfully copied backup to remote server.${RESET_COLOR}"
      else
          echo "$DATE: ERROR - Failed to copy backup to remote server." >> "$LOG_FILE"
          echo -e "${ERROR_COLOR}Failed to copy backup to remote server.${RESET_COLOR}" >&2
          exit 1
      fi
  else
      echo "$DATE: ERROR - Remote server is not reachable." >> "$LOG_FILE"
      echo -e "${ERROR_COLOR}Remote server is not reachable.${RESET_COLOR}" >&2
      exit 1
  fi
fi
