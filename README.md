## Backup Script

## Description

The `backup_script.sh` script is designed to perform backups of a specified directory with optional compression. It supports various compression methods including gzip, bzip2, zip, and xz. 
The script logs the status of the backup operation and optionally removes old backups. Additionally, it can send an email notification about the backup status and supports cross-server backup functionality.

## Features

- **Compression Options**: Supports gzip, bzip2, zip, and xz compression methods.
- **Logging**: Logs backup status and errors to a log file.
- **Old Backup Removal**: Optionally removes backups older than 7 days.
- **Email Notifications**: Sends an email notification about backup status (email functionality can be removed as needed).
- **Cross-Server Backup**: Optionally copies the backup to a remote server via SCP.

## Usage
./backup_script.sh -s <source_dir> -d <dest_dir> [-c <compression_method>] [-e <email>] [-r <remote_path>]

## Parameters

    -s <source_dir>: Directory to back up (e.g., /path/to/source).
    -d <dest_dir>: Directory to store backups (e.g., /path/to/backup).
    -c <compression_method>: Compression method to use (options: gzip, bzip2, zip, xz; default: gzip).
    -e <email>: Email address to send notifications (optional).
    -r <remote_path>: Remote server path in the format username@ipaddress:/path/to/remote/backup (optional).

## Example

./backup.sh -s /home/user/documents -d /home/user/backups -c gzip -e user@example.com -r user@remote:/backups

## Dependencies

    pv: For progress visualization during compression.
    sendmail (if email notifications are used).
    ssh and scp (for cross-server backups).

## Installation

    Install Dependencies: Ensure that pv, sendmail, ssh, and scp are installed on your system.
    Make Script Executable:

    chmod +x backup.sh

## Notes

    Make sure the destination directory is writable.
    Verify that the source directory exists before running the script.
    The script manages log file size by rotating logs when they exceed 10MB.
