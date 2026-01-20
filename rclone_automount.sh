#!/bin/bash
#
# rclone automount script for Bash
# Version 1.0.0
# Created by OperaVaria
# lcs_it@proton.me
#
# Project repository: https://github.com/OperaVaria/useful-bash-scripts
#
# This script helps the Linux user to automate mounting cloud storages via
# the rclone command line application. The template is meant to be filled out
# with the proper details and best used as a startup script.
#
# Tested on: CachyOS, GNU bash, 5.3.9(1)-release
#
# Licence:
# Copyright © 2026, OperaVaria
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <https://www.gnu.org/licenses/>

# Exit on error, undefined variables, and pipe failures.
set -euo pipefail

# CONSTANTS:

# Recommended rclone config arguments.
readonly RCLONE_ARGS=(--vfs-cache-mode full --links --daemon)

# Path constants, modify to fit needs.
readonly CLOUD_DIR="${HOME}/Cloud"
readonly LOG_DIR="${HOME}/.config/rclone/logs"

# Config array constants.
readonly REMOTES=(
# Add your remote paths here.
# Examples:
#   "MEGA:/"
#   "OneDrivePersonal:/"
#   "OneDriveBusiness:/"
#   "GoogleDrive:/"
#   "GooglePhotos:/"
)
readonly MOUNTS=(
# Add the desired mount directory names here in the same order.
# Examples:
#   "MEGA"
#   "OneDrive Personal"
#   "OneDrive Business"
#   "Google Drive"
#   "Google Photos"
)
readonly LOG_FILES=(
# Add the desired log file names here in the same order.
# Examples:
#   "mega.log"
#   "onedrive_personal.log"
#   "onedrive_business.log"
#   "google_drive.log"
#   "google_photos.log"
)

# FUNCTIONS:

#######################################
# Error message handling function.
# Arguments:
#   Error message string.
#######################################
err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*." >&2
}

#######################################
# Validates that all configuration arrays
# have the same length.
# Returns:
#   Exit status int.
#######################################
validate_config() {
  if [[ ${#REMOTES[@]} -ne ${#MOUNTS[@]} ]] \
    || [[ ${#REMOTES[@]} -ne ${#LOG_FILES[@]} ]]; then
    err "Configuration error:  config arrays must have the same length"
    err "REMOTES: ${#REMOTES[@]}, MOUNTS: ${#MOUNTS[@]}, LOG_FILES: ${#LOG_FILES[@]}"
    return 1
  fi
  
  if [[ ${#REMOTES[@]} -eq 0 ]]; then
    err "Configuration error: No remotes defined"
    return 1
  fi
  
  return 0
}

#######################################
# Checks if rclone is installed.
# Returns:
#   Exit status int.
#######################################
check_rclone() {
  if ! command -v rclone &>/dev/null; then
    err "rclone is not installed or not in PATH"
    return 1
  fi
  return 0
}

#######################################
# Checks and creates log and mount
# directories if they do not exist.
# Returns:
#   Exit status int.
#######################################
chk_dir() {
  if ! mkdir -p "${LOG_DIR}"; then
    err "Failed to create log directory: ${LOG_DIR}"
    return 1
  fi
  
  for mount in "${MOUNTS[@]}"; do
    if ! mkdir -p "${CLOUD_DIR}/${mount}"; then
      err "Failed to create mount directory: ${CLOUD_DIR}/${mount}"
      return 1
    fi
  done
  
  return 0
}

#######################################
# Function to check if remote is already
# mounted.
# Arguments:
#   Directory path string.
# Returns:
#   Exit status int.
#######################################
is_mounted() {
	mountpoint -q "$1" 2>/dev/null
}

#######################################
# rclone command creation and execution loop.
#######################################
command_loop() {
  # Declare local variables.
  local mount_path
  local log_path
  local -i i
  local -i success_count=0
  local -i skip_count=0
  local -i fail_count=0

  for ((i=0; i<${#REMOTES[@]}; i++)); do
    # Create mount and log paths.
    mount_path="${CLOUD_DIR}/${MOUNTS[$i]}"
    log_path="${LOG_DIR}/${LOG_FILES[$i]}"

    # Skip remote if already mounted.
    if is_mounted "${mount_path}"; then
      echo "⚠️  ${MOUNTS[$i]} is already mounted, skipping..."
      ((skip_count++))
      continue
    fi

    echo "🔧 Mounting ${MOUNTS[$i]}..."

    # Build and execute command.
    if rclone mount "${REMOTES[$i]}" "${mount_path}" --log-file "${log_path}" "${RCLONE_ARGS[@]}"; then
      echo "✅ ${MOUNTS[$i]} mounted successfully."
      ((success_count++))
    else
      err "❌ Failed to mount ${MOUNTS[$i]}"
      ((fail_count++))
    fi
  done
  
  # Print summary.
  echo ""
  echo "📊 Summary:"
  echo "   ✅ Successfully mounted: $success_count."
  echo "   ⚠️ Skipped (already mounted): $skip_count."
  echo "   ❌ Failed: $fail_count."
  
  # Return error if any mounts failed.
  [[ $fail_count -eq 0 ]]
}

#######################################
# Launches main function.
# Arguments:
#   Script positional arguments (unused).
#######################################
main() {
  echo "🚀 Starting rclone automount script..."
  
  # Pre-flight checks.
  check_rclone || exit 1
  validate_config || exit 1
  
  # Create directories.
  chk_dir || exit 1
  
  # Mount remotes.
  if command_loop; then
    echo "🎉 Mount script completed successfully!"
    exit 0
  else
    err "Mount script completed with errors"
    exit 1
  fi
}

# Launch main function.
main "$@"
