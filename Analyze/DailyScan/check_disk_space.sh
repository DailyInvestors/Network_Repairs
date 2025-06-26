#!/bin/bash

# Script to check disk space and send an email notification

# --- Configuration ---
RECIPIENT_EMAIL="your_email@example.com" # <--- IMPORTANT: Change this to your email address
THRESHOLD_PERCENT=80                  # <--- Percentage at which to send a warning email
LOG_FILE="/var/log/disk_space_check.log" # Log file for script execution
DATE=$(date +"%Y-%m-%d %H:%M:%S")

# --- Functions ---

# Function to log messages
log_message() {
    echo "[$DATE] $1" >> "$LOG_FILE"
}

# --- Main Script ---

log_message "Starting disk space check..."

# Get disk usage for all mounted filesystems, excluding squashfs, tmpfs, devtmpfs, and overlay
# -h: human-readable format
# -x: don't cross filesystems on different mount points
# awk '{print $5, $1}' selects the Usage% and Filesystem columns
# grep -v '%$' removes the header line
DISK_USAGE=$(df -h -x squashfs -x tmpfs -x devtmpfs -x overlay | awk '{print $5, $1}' | grep -v '%$' )

ALERT_MESSAGE=""
DISK_WARNING=false

while IFS= read -r line; do
    USAGE_PERCENT=$(echo "$line" | awk '{print $1}' | sed 's/%//')
    FILESYSTEM=$(echo "$line" | awk '{print $2}')

    if (( USAGE_PERCENT >= THRESHOLD_PERCENT )); then
        ALERT_MESSAGE+="Disk usage for $FILESYSTEM is at ${USAGE_PERCENT}% (THRESHOLD: ${THRESHOLD_PERCENT}%).\n"
        DISK_WARNING=true
    fi
done <<< "$DISK_USAGE"

if [ "$DISK_WARNING" = true ]; then
    SUBJECT="Disk Space ALERT on $(hostname) - High Usage Detected!"
    EMAIL_BODY="
    The following filesystems have reached or exceeded the ${THRESHOLD_PERCENT}% usage threshold:

    $ALERT_MESSAGE

    Current Disk Usage Summary:
    $(df -h -x squashfs -x tmpfs -x devtmpfs -x overlay)

    This alert was generated on $(hostname) at $(date).
    "
    echo -e "$EMAIL_BODY" | mail -s "$SUBJECT" "$RECIPIENT_EMAIL"
    log_message "High disk usage detected. Email sent to $RECIPIENT_EMAIL."
else
    SUBJECT="Disk Space Check on $(hostname) - OK"
    EMAIL_BODY="
    All monitored filesystems are below the ${THRESHOLD_PERCENT}% usage threshold.

    Current Disk Usage Summary:
    $(df -h -x squashfs -x tmpfs -x devtmpfs -x overlay)

    This report was generated on $(hostname) at $(date).
    "
    # Send an email even if everything is OK, but you could comment this out
    # if you only want alerts for high usage.
    echo -e "$EMAIL_BODY" | mail -s "$SUBJECT" "$RECIPIENT_EMAIL"
    log_message "Disk space is normal. Email sent to $RECIPIENT_EMAIL."
fi

log_message "Disk space check finished."
