import subprocess
import time
import datetime
import os

# --- Configuration ---
LOG_DIR = "/var/log/system_monitoring_agent" # Directory for logs
# Ensure this directory exists and is writable by the user running the script (e.g., root if using sudo)
# Log files will be created as: process_monitor.log, ufw_log_monitor.log, etc.

MONITOR_INTERVAL_SECONDS = 5 # General interval for most monitors
UFW_LOG_INTERVAL_SECONDS = 2 # Specific interval for ufw log monitor
IOTOP_INTERVAL_SECONDS = 2 # Specific interval for iotop monitor

# --- Monitoring Tasks ---
# Each task is a dictionary:
# 'name': A unique name for the task (used for log file names)
# 'command': The bash command to execute
# 'interval': How often to run this specific command
# 'requires_sudo': True if the command needs sudo (the script itself should be run with sudo)
# 'enabled': True to run this task, False to disable it
monitoring_tasks = [
    {
        'name': 'top_mem_processes',
        'command': "ps aux --sort=-%mem | head -n 11",
        'interval': MONITOR_INTERVAL_SECONDS,
        'requires_sudo': False,
        'enabled': True
    },
    {
        'name': 'top_cpu_processes',
        'command': "ps aux --sort=-%cpu | head -n 11",
        'interval': MONITOR_INTERVAL_SECONDS,
        'requires_sudo': False,
        'enabled': True
    },
    {
        'name': 'specific_process_monitor', # You need to define 'your_process_name' here
        'command': "ps aux | grep -i 'your_process_name' | grep -v grep",
        'interval': MONITOR_INTERVAL_SECONDS,
        'requires_sudo': False,
        'enabled': True # Set to False if you don't have a specific process to watch
    },
    {
        'name': 'ufw_log_monitor',
        'command': "tail /var/log/ufw.log | grep -i 'deny\\|reject'",
        'interval': UFW_LOG_INTERVAL_SECONDS,
        'requires_sudo': True, # tailing ufw.log usually requires root
        'enabled': True
    },
    {
        'name': 'iotop_monitor',
        'command': "iotop -o -b -n 1", # Assuming iotop is installed
        'interval': IOTOP_INTERVAL_SECONDS,
        'requires_sudo': True, # iotop needs root
        'enabled': True
    },
    {
        'name': 'network_connections',
        'command': "ss -tulpn", # Using ss, as it's modern
        # If ss gives an error, use: "netstat -tulpn"
        'interval': MONITOR_INTERVAL_SECONDS,
        'requires_sudo': True, # ss -p requires root
        'enabled': True
    }
]

# --- Functions ---

def ensure_log_directory_exists():
    """Ensures the log directory exists."""
    if not os.path.exists(LOG_DIR):
        os.makedirs(LOG_DIR, exist_ok=True)
        print(f"Created log directory: {LOG_DIR}")
    # Set permissions if running as root
    if os.geteuid() == 0: # If running as root
        os.chmod(LOG_DIR, 0o755) # drwxr-xr-x

def run_command_and_log(task_name, command_str, log_file_path):
    """Runs a shell command and logs its output to a file."""
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    try:
        # Use shell=True for piping and complex commands
        # Capture stdout and stderr
        result = subprocess.run(
            command_str,
            shell=True,
            capture_output=True,
            text=True,
            check=False # Don't raise exception for non-zero exit codes
        )
        output = result.stdout
        error_output = result.stderr

        with open(log_file_path, "a") as f:
            f.write(f"--- {task_name} Output ({timestamp}) ---\n")
            if output:
                f.write(output.strip() + "\n")
            if error_output:
                f.write(f"--- Error ({timestamp}) ---\n")
                f.write(error_output.strip() + "\n")
            f.write("\n") # Add a newline for separation between entries

    except Exception as e:
        with open(log_file_path, "a") as f:
            f.write(f"--- Error Running {task_name} ({timestamp}) ---\n")
            f.write(f"Exception: {e}\n")
            f.write("\n")

def main_loop():
    """Main loop to run monitoring tasks."""
    print(f"Starting system monitoring agent. Logs will be in {LOG_DIR}")
    ensure_log_directory_exists()

    last_run_times = {task['name']: 0 for task in monitoring_tasks if task['enabled']}

    while True:
        current_time = time.time()
        for task in monitoring_tasks:
            if not task['enabled']:
                continue

            if current_time - last_run_times[task['name']] >= task['interval']:
                log_file_path = os.path.join(LOG_DIR, f"{task['name']}.log")
                print(f"[{timestamp}] Running {task['name']}...")
                run_command_and_log(task['name'], task['command'], log_file_path)
                last_run_times[task['name']] = current_time
        
        time.sleep(1) # Sleep briefly to avoid busy-waiting

# --- Main Execution ---
if __name__ == "__main__":
    # Check if running as root (required for most monitoring commands)
    if os.geteuid() != 0:
        print("This script requires root privileges. Please run with sudo.")
        print("Example: sudo python3 your_monitoring_agent.py")
        exit(1)

    # --- Initial setup for iotop ---
    # This part should ideally be run once manually or as part of a setup script,
    # not every time the agent starts.
    print("Checking for iotop installation...")
    try:
        subprocess.run(["which", "iotop"], check=True, capture_output=True)
        print("iotop is installed.")
    except subprocess.CalledProcessError:
        print("iotop not found. Attempting to install iotop...")
        try:
            # Note: This will block the script until installation is complete.
            # In a production agent, you'd handle this more gracefully or assume pre-installation.
            subprocess.run(["sudo", "apt", "install", "-y", "iotop"], check=True)
            print("iotop installed successfully.")
        except Exception as e:
            print(f"Failed to install iotop. Please install it manually: sudo apt install iotop. Error: {e}")
            # Optionally disable iotop_monitor if installation failed
            for task in monitoring_tasks:
                if task['name'] == 'iotop_monitor':
                    task['enabled'] = False
            
    # --- Check for 'ss' vs 'netstat' (adapt if 'ss' is missing) ---
    try:
        subprocess.run(["which", "ss"], check=True, capture_output=True)
        print("Using 'ss' for network monitoring.")
    except subprocess.CalledProcessError:
        print("'ss' command not found. Falling back to 'netstat' for network monitoring.")
        for task in monitoring_tasks:
            if task['name'] == 'network_connections':
                task['command'] = "netstat -tulpn"


    main_loop()

