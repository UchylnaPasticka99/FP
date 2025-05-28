#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Directory for PID files (as per the new launcher)
PID_DIR_NAME="PIDy" # This is the actual name of the directory on disk
PID_DIR_PATH="${SCRIPT_DIR}/${PID_DIR_NAME}"

# Paths to PID files (as per the new launcher)
DETECTOR_PID_FILE="${PID_DIR_PATH}/detector.pid"
MOVER_PID_FILE="${PID_DIR_PATH}/photoMover.pid"
EMAIL_PID_FILE="${PID_DIR_PATH}/email_provider.pid"

echo "---------------------------------------------"
echo "Attempting to terminate scripts..."
echo "---------------------------------------------"

# Function to terminate a process and clean up its PID file
kill_and_cleanup() {
    local process_name=$1
    local pid_file=$2

    echo ""
    if [ -f "${pid_file}" ]; then
        PID_TO_KILL=$(cat "${pid_file}")
        if ps -p "${PID_TO_KILL}" > /dev/null; then # Checks if the process with the given PID is still running
            echo "Terminating ${process_name} (PID: ${PID_TO_KILL})..."
            kill "${PID_TO_KILL}" # Sends SIGTERM (standard termination signal)
            # You can add a short pause and then SIGKILL if SIGTERM is not enough
            # sleep 1 # Short pause to allow the process to terminate gracefully
            # if ps -p "${PID_TO_KILL}" > /dev/null; then
            #   echo "Process ${process_name} (PID: ${PID_TO_KILL}) is still running after SIGTERM, sending SIGKILL..."
            #   kill -9 "${PID_TO_KILL}"
            # fi
            rm "${pid_file}"
            echo "PID file ${pid_file} deleted."
        else
            echo "Process ${process_name} (PID: ${PID_TO_KILL} from ${pid_file}) is no longer running."
            rm "${pid_file}"
            echo "PID file ${pid_file} deleted (process was not running)."
        fi
    else
        echo "File ${pid_file} not found. Process ${process_name} is likely not running or was not started this way."
    fi
}

# Terminate individual processes
# Process names are kept consistent with the script and PID file names
kill_and_cleanup "detektor.py" "${DETECTOR_PID_FILE}"
kill_and_cleanup "photoMover.py" "${MOVER_PID_FILE}"
kill_and_cleanup "email_provider.py" "${EMAIL_PID_FILE}"

echo ""
echo "---------------------------------------------"
echo "Termination process completed."
# Note: This script does not delete the PID directory itself (PIDy).
# The main launcher script handles the deletion of the PID_DIR_PATH.
# If this kill script were to run independently and needed to clean up an empty PID directory,
# you could add something like this:
# if [ -d "${PID_DIR_PATH}" ] && [ -z "$(ls -A "${PID_DIR_PATH}")" ]; then
#     echo "Directory ${PID_DIR_PATH} is empty, removing it..."
#     rmdir "${PID_DIR_PATH}"
# elif [ -d "${PID_DIR_PATH}" ]; then
#     echo "Directory ${PID_DIR_PATH} is not empty, not removing it."
# fi
echo "---------------------------------------------"