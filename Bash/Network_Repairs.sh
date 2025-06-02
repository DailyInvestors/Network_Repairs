#!/bin/bash

# --- Configuration ---
LOG_FILE="/var/log/network_repair.log"
DATE_TIME=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="/etc/network_backup_$DATE_TIME"

# --- Functions ---

log_message() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_message "ERROR: This script must be run as root. Exiting."
        exit 1
    fi
}

backup_network_configs() {
    log_message "INFO: Backing up network configuration files to $BACKUP_DIR..."
    sudo mkdir -p "$BACKUP_DIR" || { log_message "ERROR: Failed to create backup directory. Exiting."; exit 1; }

    # Common network configuration directories/files - adjust for your distro
    sudo cp -rp /etc/network "$BACKUP_DIR/" 2>/dev/null
    sudo cp -rp /etc/netplan "$BACKUP_DIR/" 2>/dev/null
    sudo cp -rp /etc/sysconfig/network-scripts "$BACKUP_DIR/" 2>/dev/null
    sudo cp -rp /etc/NetworkManager "$BACKUP_DIR/" 2>/dev/null
    sudo cp -rp /etc/resolv.conf "$BACKUP_DIR/" 2>/dev/null
    sudo cp -rp /etc/hosts "$BACKUP_DIR/" 2>/dev/null

    if [ $? -eq 0 ]; then
        log_message "INFO: Network configuration backup completed."
    else
        log_message "WARNING: Some network configuration files might not have been backed up."
    fi
    echo "" | tee -a "$LOG_FILE"
}

# --- Network Repair Stage ---
# This stage attempts to diagnose and restart network services.
# ADJUST COMMANDS BASED ON YOUR LINUX DISTRIBUTION AND NETWORK SETUP!
network_repair_stage() {
    log_message "--- Starting Network Repair Stage ---"

    log_message "INFO: Attempting to restart networking services..."

    # Common commands for restarting network services. Use the one(s) applicable to your distro.
    # Ubuntu/Debian with systemd/netplan:
    log_message "INFO: Attempting 'netplan apply' if using Netplan..."
    sudo netplan try && sudo netplan apply &>> "$LOG_FILE"
    if [ $? -ne 0 ]; then
        log_message "WARNING: 'netplan apply' failed or is not applicable. Continuing."
    fi

    log_message "INFO: Restarting NetworkManager service..."
    sudo systemctl restart NetworkManager &>> "$LOG_FILE"
    if [ $? -eq 0 ]; then
        log_message "INFO: NetworkManager restarted successfully."
    else
        log_message "WARNING: NetworkManager restart failed or is not applicable. Trying networking.service..."
        sudo systemctl restart networking.service &>> "$LOG_FILE"
        if [ $? -eq 0 ]; then
            log_message "INFO: networking.service restarted successfully."
        else
            log_message "WARNING: networking.service restart failed or is not applicable. Trying legacy methods..."
            # Old methods for SysVinit systems or if systemctl fails
            sudo /etc/init.d/networking restart &>> "$LOG_FILE"
            if [ $? -eq 0 ]; then
                log_message "INFO: Legacy networking service restarted successfully."
            else
                log_message "WARNING: All known networking service restarts failed."
            fi
        fi
    fi

    log_message "INFO: Attempting to bring down and up network interfaces (be cautious on remote systems!)..."
    # DANGEROUS ON REMOTE SYSTEMS IF YOU DON'T HAVE OUT-OF-BAND ACCESS!
    # Identify active interfaces (excluding loopback)
    ACTIVE_INTERFACES=$(ip -o link show | awk -F': ' '$2 != "lo" {print $2}')
    for IFACE in $ACTIVE_INTERFACES; do
        log_message "INFO: Bringing down and up interface: $IFACE"
        sudo ip link set "$IFACE" down &>> "$LOG_FILE"
        sudo ip link set "$IFACE" up &>> "$LOG_FILE"
        sudo dhclient -r "$IFACE" &>> "$LOG_FILE" # Release DHCP lease
        sudo dhclient "$IFACE" &>> "$LOG_FILE"    # Renew DHCP lease
        if [ $? -eq 0 ]; then
            log_message "INFO: Interface $IFACE refreshed."
        else
            log_message "WARNING: Failed to refresh interface $IFACE."
        fi
    done

    log_message "INFO: Checking network connectivity..."
    ping -c 3 8.8.8.8 &>> "$LOG_FILE"
    if [ $? -eq 0 ]; then
        log_message "INFO: Ping to 8.8.8.8 (Google DNS) successful."
    else
        log_message "WARNING: Ping to 8.8.8.8 failed. Network might still be down or issues remain."
    fi

    log_message "--- Network Repair Stage Completed ---"
    echo "" | tee -a "$LOG_FILE"
}

# --- Autoremove Packages Stage ---
autoremove_stage() {
    log_message "--- Starting Autoremove Packages Stage ---"

    if command -v apt >/dev/null 2>&1; then
        log_message "INFO: Running 'apt autoremove' for unused packages (Debian/Ubuntu)."
        sudo apt autoremove -y &>> "$LOG_FILE"
        if [ $? -eq 0 ]; then
            log_message "INFO: 'apt autoremove' completed successfully."
        else
            log_message "WARNING: 'apt autoremove' encountered issues."
        fi
    elif command -v dnf >/dev/null 2>&1; then
        log_message "INFO: Running 'dnf autoremove' for unused packages (Fedora/RHEL)."
        sudo dnf autoremove -y &>> "$LOG_FILE"
        if [ $? -eq 0 ]; then
            log_message "INFO: 'dnf autoremove' completed successfully."
        else
            log_message "WARNING: 'dnf autoremove' encountered issues."
        fi
    elif command -v yum >/dev/null 2>&1; then
        log_message "INFO: Running 'yum autoremove' for unused packages (Older CentOS/RHEL)."
        sudo yum autoremove -y &>> "$LOG_FILE"
        if [ $? -eq 0 ]; then
            log_message "INFO: 'yum autoremove' completed successfully."
        else
            log_message "WARNING: 'yum autoremove' encountered issues."
        fi
    else
        log_message "WARNING: No known package manager for autoremove found (apt, dnf, yum)."
    fi

    log_message "--- Autoremove Packages Stage Completed ---"
    echo "" | tee -a "$LOG_FILE"
}

# --- Clean DNS Cache Stage ---
clean_dns_stage() {
    log_message "--- Starting Clean DNS Cache Stage ---"

    log_message "INFO: Checking for and restarting DNS caching services..."

    # Systemd-resolved (common on Ubuntu, Fedora, etc.)
    if sudo systemctl is-active --quiet systemd-resolved; then
        log_message "INFO: Found systemd-resolved. Attempting to flush DNS cache."
        sudo systemd-resolve --flush-caches &>> "$LOG_FILE"
        if [ $? -eq 0 ]; then
            log_message "INFO: systemd-resolved cache flushed successfully."
        else
            log_message "WARNING: Failed to flush systemd-resolved cache. Attempting restart."
            sudo systemctl restart systemd-resolved &>> "$LOG_FILE"
            if [ $? -eq 0 ]; then
                log_message "INFO: systemd-resolved restarted."
            else
                log_message "ERROR: Failed to restart systemd-resolved. Manual intervention may be needed."
            fi
        fi
    else
        log_message "INFO: systemd-resolved not found or not active."
    fi

    # dnsmasq (if installed and running)
    if sudo systemctl is-active --quiet dnsmasq; then
        log_message "INFO: Found dnsmasq. Attempting to restart for cache clear."
        sudo systemctl restart dnsmasq &>> "$LOG_FILE"
        if [ $? -eq 0 ]; then
            log_message "INFO: dnsmasq restarted (cache cleared)."
        else
            log_message "WARNING: Failed to restart dnsmasq."
        fi
    else
        log_message "INFO: dnsmasq not found or not active."
    fi

    # nscd (Name Service Cache Daemon - older systems/specific setups)
    if sudo systemctl is-active --quiet nscd; then
        log_message "INFO: Found nscd. Attempting to restart for cache clear."
        sudo systemctl restart nscd &>> "$LOG_FILE"
        if [ $? -eq 0 ]; then
            log_message "INFO: nscd restarted (cache cleared)."
        else
            log_message "WARNING: Failed to restart nscd."
        fi
    else
        log_message "INFO: nscd not found or not active."
    fi

    # Manual /proc/sys/net/ipv4/route/flush (for routing table cache, not strictly DNS but related)
    if [ -f "/proc/sys/net/ipv4/route/flush" ]; then
        log_message "INFO: Flushing kernel routing cache."
        sudo sysctl net.ipv4.route.flush=1 &>> "$LOG_FILE"
        if [ $? -eq 0 ]; then
            log_message "INFO: Kernel routing cache flushed."
        else
            log_message "WARNING: Failed to flush kernel routing cache."
        fi
    fi

    log_message "--- Clean DNS Cache Stage Completed ---"
    echo "" | tee -a "$LOG_FILE"
}

# --- Main Execution ---

main() {
    check_root
    log_message "--- Linux Maintenance Workflow Started: $DATE_TIME ---"
    echo "" | tee -a "$LOG_FILE"

    backup_network_configs

    # Execute stages sequentially
    network_repair_stage
    autoremove_stage
    clean_dns_stage

    log_message "--- Linux Maintenance Workflow Completed: $DATE_TIME ---"
    log_message "Please review $LOG_FILE for details."
    echo "" | tee -a "$LOG_FILE"
}

main "$@"

