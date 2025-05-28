import os
import subprocess
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def audit_files_with_clamav(start_path):
    """
    Audits each file in the given path and its subdirectories using ClamAV.

    Args:
        start_path (str): The starting directory to scan.
                          BE CAREFUL: Setting this to '/' will scan your entire system.
    """
    if not os.path.isdir(start_path):
        logging.error(f"Error: The provided path '{start_path}' is not a valid directory.")
        return

    logging.info(f"Starting ClamAV audit of: {start_path}")

    # Use a set to keep track of directories that are inaccessible,
    # to avoid repeated permission errors.
    inaccessible_dirs = set()

    for root, dirs, files in os.walk(start_path):
        # Skip directories we know are inaccessible
        if root in inaccessible_dirs:
            dirs[:] = [] # Don't traverse into this directory or its subdirectories
            continue

        try:
            # Modify dirs in-place to prune search
            # For example, you might want to skip system directories like /proc, /sys, /dev
            # if 'proc' in dirs: dirs.remove('proc')
            # if 'sys' in dirs: dirs.remove('sys')
            # if 'dev' in dirs: dirs.remove('dev')

            for file_name in files:
                file_path = os.path.join(root, file_name)

                # Basic check if the file is a regular file (not a symlink, pipe, etc.)
                if not os.path.isfile(file_path):
                    continue

                logging.debug(f"Scanning: {file_path}")
                try:
                    # Construct the clamscan command
                    # -v for verbose output (optional)
                    # --no-summary to avoid the final summary line from clamscan
                    command = ['clamscan', '--no-summary', file_path]

                    # Execute the command
                    # capture_output=True captures stdout and stderr
                    # text=True decodes stdout/stderr as text
                    # check=False prevents an exception for non-zero exit codes (e.g., infected files)
                    process = subprocess.run(
                        command,
                        capture_output=True,
                        text=True,
                        check=False
                    )

                    # Check the return code
                    # 0: No virus found
                    # 1: Virus found
                    # 2: Some other error
                    if process.returncode == 0:
                        logging.info(f"CLEAN: {file_path}")
                    elif process.returncode == 1:
                        logging.warning(f"INFECTED: {file_path}")
                        # You can parse process.stdout to get more details about the infection
                        logging.warning(f"  ClamAV Output: {process.stdout.strip()}")
                    else:
                        logging.error(f"ERROR scanning {file_path} (Return Code: {process.returncode})")
                        logging.error(f"  ClamAV Stderr: {process.stderr.strip()}")

                except FileNotFoundError:
                    logging.error("ClamAV (clamscan) not found. Please ensure ClamAV is installed and in your system's PATH.")
                    return
                except Exception as e:
                    logging.error(f"An unexpected error occurred while scanning {file_path}: {e}")

        except PermissionError:
            logging.warning(f"Permission denied to access directory: {root}. Skipping this directory.")
            inaccessible_dirs.add(root)
            dirs[:] = [] # Stop os.walk from entering this directory's subdirectories
        except Exception as e:
            logging.error(f"An error occurred during directory traversal in {root}: {e}")

    logging.info("ClamAV audit completed.")

if __name__ == "__main__":
    # !!! IMPORTANT: CHANGE THIS PATH CAREFULLY !!!
    # For testing, you can use a small directory like:
    # scan_directory = "/tmp"
    # To scan your entire system, set it to:
    scan_directory = "/"
    # Be aware that scanning the entire system will take a very long time
    # and require appropriate permissions.

    audit_files_with_clamav(scan_directory)
