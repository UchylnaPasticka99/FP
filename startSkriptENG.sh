#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Directory for PID files
PID_DIR_BASENAME="pids"
PID_DIR="${SCRIPT_DIR}/${PID_DIR_BASENAME}"

# --- Logging Configuration ---
# Base name for the directory holding logs of the current run
CURRENT_LOG_DIR_BASENAME="lastLog"
# Full path to the directory for current logs
CURRENT_LOG_PATH="${SCRIPT_DIR}/${CURRENT_LOG_DIR_BASENAME}"

# Main directory for archived logs
MAIN_LOG_ARCHIVE_DIR_BASENAME="logArchive"
MAIN_LOG_ARCHIVE_PATH="${SCRIPT_DIR}/${MAIN_LOG_ARCHIVE_DIR_BASENAME}"
# --------------------------

# Your Python script names
DETECTOR_SCRIPT_FILENAME="detektor.py"
MOVER_SCRIPT_FILENAME="photoMover.py"
EMAIL_SCRIPT_FILENAME="email_provider.py"

PYTHON_EXECUTABLE="python3 -u"

DETECTOR_LOG_FILE="${CURRENT_LOG_PATH}/detector.log"
MOVER_LOG_FILE="${CURRENT_LOG_PATH}/photoMover.log"
EMAIL_LOG_FILE="${CURRENT_LOG_PATH}/email_provider.log"

DETECTOR_PID_FILE_PATH="${PID_DIR}/detector.pid"
MOVER_PID_FILE_PATH="${PID_DIR}/photoMover.pid"
EMAIL_PID_FILE_PATH="${PID_DIR}/email_provider.pid"

TAIL_PROCESS_PID=""
PID_FILE_PATHS=("$DETECTOR_PID_FILE_PATH" "$MOVER_PID_FILE_PATH" "$EMAIL_PID_FILE_PATH")

cleanup_and_exit() {
    echo ""
    echo "Signal caught. Terminating all running processes and cleaning up..."

    if [ -n "$TAIL_PROCESS_PID" ] && kill -0 "$TAIL_PROCESS_PID" 2>/dev/null; then
        echo "Terminating tail process (PID: $TAIL_PROCESS_PID)..."
        kill "$TAIL_PROCESS_PID"; wait "$TAIL_PROCESS_PID" 2>/dev/null
    fi

    echo "Terminating Python processes..."
    for pid_fpath in "${PID_FILE_PATHS[@]}"; do
        if [ -f "$pid_fpath" ]; then
            pid_to_kill=$(cat "$pid_fpath")
            if [ -n "$pid_to_kill" ] && kill -0 "$pid_to_kill" 2>/dev/null; then
                echo "  Sending SIGTERM to process with PID $pid_to_kill (from $pid_fpath)..."
                kill "$pid_to_kill"
            fi
        fi
    done

    if [ -d "$PID_DIR" ]; then
        echo "Deleting PID directory: ${PID_DIR}..."
        rm -rf "${PID_DIR}"
    fi

    echo "Current logs are stored in: ${CURRENT_LOG_PATH}"
    echo "All processes should be terminated and cleanup completed."
    exit 0
}

trap 'cleanup_and_exit' INT TERM EXIT

echo "---------------------------------------------"
echo "Preparing directories for logging and PID files..."

# Create the main log archive directory if it doesn't exist
mkdir -p "${MAIN_LOG_ARCHIVE_PATH}"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create main log archive directory ${MAIN_LOG_ARCHIVE_PATH}. Exiting."
    exit 1
fi

# If the directory for current logs exists from a previous run, archive it
if [ -d "${CURRENT_LOG_PATH}" ]; then
    TIMESTAMP_DIR_NAME=$(date +%Y-%m-%d_%H-%M-%S)
    # Target directory for archiving will be inside MAIN_LOG_ARCHIVE_PATH
    TARGET_ARCHIVE_SUBDIR="${MAIN_LOG_ARCHIVE_PATH}/${TIMESTAMP_DIR_NAME}"

    echo "Found existing log directory '${CURRENT_LOG_DIR_BASENAME}'."
    echo "Creating archive subdirectory: '${TARGET_ARCHIVE_SUBDIR}'..."
    mkdir -p "${TARGET_ARCHIVE_SUBDIR}" # Create the target directory for the move
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to create target archive subdirectory ${TARGET_ARCHIVE_SUBDIR}. Exiting."
        exit 1
    fi

    echo "Moving content from '${CURRENT_LOG_PATH}' to '${TARGET_ARCHIVE_SUBDIR}'..."
    # Move the content, not the whole folder, so CURRENT_LOG_PATH can be easily recreated/emptied
    if [ -n "$(ls -A "${CURRENT_LOG_PATH}")" ]; then # Check if directory is not empty
        find "${CURRENT_LOG_PATH}" -mindepth 1 -maxdepth 1 -exec mv -t "${TARGET_ARCHIVE_SUBDIR}" {} +
        if [ $? -eq 0 ]; then
            echo "Content of '${CURRENT_LOG_DIR_BASENAME}' successfully archived to '${TARGET_ARCHIVE_SUBDIR}'."
            # Now we can remove the original (now empty) CURRENT_LOG_PATH if it still exists
            rm -rf "${CURRENT_LOG_PATH}"
        else
            echo "ERROR: Failed to move content from '${CURRENT_LOG_PATH}'."
            echo "Please check ${CURRENT_LOG_PATH} and ${TARGET_ARCHIVE_SUBDIR} manually."
        fi
    else
        echo "Directory '${CURRENT_LOG_PATH}' is empty, nothing to archive."
        rm -rf "${CURRENT_LOG_PATH}" # Remove it so a new clean one is created
    fi
fi

# Create (new) directory for current logs
echo "Creating directory for current logs: ${CURRENT_LOG_PATH}..."
mkdir -p "${CURRENT_LOG_PATH}"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create directory ${CURRENT_LOG_PATH}. Exiting."
    exit 1
fi

# Create PID directory
echo "Creating PID directory: ${PID_DIR}..."
mkdir -p "${PID_DIR}"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create directory ${PID_DIR}. Exiting."
    exit 1
fi

# Initialize/empty log files inside CURRENT_LOG_PATH
echo "Initializing log files in ${CURRENT_LOG_PATH}..."
> "${DETECTOR_LOG_FILE}"
> "${MOVER_LOG_FILE}"
> "${EMAIL_LOG_FILE}"

echo "---------------------------------------------"
echo "Starting scripts..."
# (rest of the script remains the same)
# ...
# Start Detector script
echo ""
echo "Starting ${DETECTOR_SCRIPT_FILENAME}..."
${PYTHON_EXECUTABLE} "${SCRIPT_DIR}/${DETECTOR_SCRIPT_FILENAME}" > "${DETECTOR_LOG_FILE}" 2>&1 &
echo $! > "${DETECTOR_PID_FILE_PATH}"
echo "${DETECTOR_SCRIPT_FILENAME} started with PID $(cat ${DETECTOR_PID_FILE_PATH}). Output in ${DETECTOR_LOG_FILE}"

# Start Mover script
echo ""
echo "Starting ${MOVER_SCRIPT_FILENAME}..."
${PYTHON_EXECUTABLE} "${SCRIPT_DIR}/${MOVER_SCRIPT_FILENAME}" > "${MOVER_LOG_FILE}" 2>&1 &
echo $! > "${MOVER_PID_FILE_PATH}"
echo "${MOVER_SCRIPT_FILENAME} started with PID $(cat ${MOVER_PID_FILE_PATH}). Output in ${MOVER_LOG_FILE}"

# Start Email script
echo ""
echo "Starting ${EMAIL_SCRIPT_FILENAME}..."
${PYTHON_EXECUTABLE} "${SCRIPT_DIR}/${EMAIL_SCRIPT_FILENAME}" > "${EMAIL_LOG_FILE}" 2>&1 &
echo $! > "${EMAIL_PID_FILE_PATH}"
echo "${EMAIL_SCRIPT_FILENAME} started with PID $(cat ${EMAIL_PID_FILE_PATH}). Output in ${EMAIL_LOG_FILE}"

echo ""
echo "---------------------------------------------"
echo "All scripts have been started."
echo "Now starting to monitor all log files from ${CURRENT_LOG_PATH}."
echo "Press Ctrl+C to terminate this script AND ALL PROCESSES IT STARTED."
echo "The PID directory (${PID_DIR}) will be deleted upon exit."
echo "The current log directory (${CURRENT_LOG_PATH}) will BE PRESERVED."
echo "Previous logs (if any) have been archived to ${MAIN_LOG_ARCHIVE_PATH}/[datetime_stamp]."
echo "---------------------------------------------"
echo ""
echo "Monitoring logs (Press Ctrl+C to stop everything):"

tail -f "${DETECTOR_LOG_FILE}" "${MOVER_LOG_FILE}" "${EMAIL_LOG_FILE}" &
TAIL_PROCESS_PID=$!

wait "$TAIL_PROCESS_PID"

echo "Tail process (PID: $TAIL_PROCESS_PID) has ended (or was terminated)."