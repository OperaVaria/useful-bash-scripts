#!/usr/bin/env bash
#
# rclone automount script for Bash
# Created by OperaVaria
# lcs_it@proton.me
#
# Part of the "useful-bash-scripts" project:
# https://github.com/OperaVaria/useful-bash-scripts
# Version 1.0.0
#
# Dependencies: rclone
#
# Description: This script helps the Linux user to automate mounting cloud
# storages via the rclone command line application. All configuration is
# handled by the included .conf file.
#
# Tested on: CachyOS (rolling), GNU bash, 5.3.9(1)-release
#
# License:
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

# Default config path.
CONFIG_FILE="${HOME}/.config/rclone/automount.conf"

#######################################
# Handles and validates run options.
# Arguments:
#   Script positional arguments.
# Returns:
#   Exit status.
#######################################
set_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        show_help
        exit 0
        ;;
      -c|--config)
        if [[ $# -ge 2 ]]; then
          CONFIG_FILE="$2"
        else
          err "-c/--config requires an argument"
          return 1
        fi
        shift 2
        ;;
      -*)
        err "Unknown option '$1'"
        return 1
        ;;
      *)
        err "Unknown argument '$1'"
        return 1
        ;;
    esac
  done
  if [[ $# -gt 0 ]]; then
    err "Too many positional arguments"
    return 1
  fi
  return 0
}

#######################################
# Displays help message.
#######################################
show_help() {
  cat << EOF
Usage: ./rclone_automount.sh [OPTIONS]

Automates mounting cloud storages via the rclone application.

OPTIONS:
  -c, --config <config_file>    Set config file location
  -h, --help                    Show this help message
EOF
}

#######################################
# Error message handling function.
# Arguments:
#   Error message string.
#######################################
err() {
  echo "❌ [$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*." >&2
}

#######################################
# Checks if rclone is installed.
# Returns:
#   Exit status int.
#######################################
chk_rclone() {
  if ! command -v rclone &>/dev/null; then
    err "rclone is not installed or not in PATH"
    return 1
  fi
  return 0
}

#######################################
# Validates and loads config file.
# Returns:
#   Exit status int.
#######################################
load_cfg() {
  if [[ ! -f "${CONFIG_FILE}" ]]; then
    err "Config file not found: ${CONFIG_FILE}"
    return 1
  else
    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"
  fi
  return 0
}

#######################################
# Validates configuration variables.
# Returns:
#   Exit status int.
#######################################
val_var() {
  # Strings
  [[ -n "${CLOUD_DIR:-}" ]] || { err "Missing CLOUD_DIR in config"; return 1; }
  [[ -n "${LOG_DIR:-}" ]]   || { err "Missing LOG_DIR in config"; return 1; }

  # Arrays
  declare -p REMOTES >/dev/null 2>&1     \
  || { err "Missing REMOTES array"; return 1; }
  declare -p MOUNTS >/dev/null 2>&1      \
  || { err "Missing MOUNTS array"; return 1; }
  declare -p LOG_FILES >/dev/null 2>&1   \
  || { err "Missing LOG_FILES array"; return 1; }
  declare -p REMOTE_ARGS >/dev/null 2>&1 \
  || { err "Missing REMOTE_ARGS array"; return 1; }

  # Recommended rclone args set if not defined in config.
  if ! declare -p RCLONE_ARGS &>/dev/null; then
    RCLONE_ARGS=(--vfs-cache-mode full --links --daemon)
  fi

  return 0
}

#######################################
# Checks if items in the REMOTES array
# actually exist as rclone remotes.
# Returns:
#   Exit status int.
#######################################
val_remotes() {
  local configured_remotes
  configured_remotes=$(rclone listremotes)
  for remote in "${REMOTES[@]}"; do
    if ! grep -q "^${remote%%:*}:$" <<< "$configured_remotes"; then
      err "Remote '${remote%%:*}' not configured in rclone"
      return 1
    fi
  done
  return 0
}


#######################################
# Checks for configuration array length
# mismatches which indicate incomplete
# config data.
# Returns:
#   Exit status int.
#######################################
val_arr() {
  if [[ ${#REMOTES[@]} -ne ${#MOUNTS[@]} ]] \
    || [[ ${#REMOTES[@]} -ne ${#LOG_FILES[@]} ]] \
    || [[ ${#REMOTES[@]} -ne ${#REMOTE_ARGS[@]} ]]; then
    err "Configuration error: config arrays must have the same length"
    err "REMOTES: ${#REMOTES[@]}, MOUNTS: ${#MOUNTS[@]}," \
        "LOG_FILES: ${#LOG_FILES[@]}, REMOTE_ARGS: ${#REMOTE_ARGS[@]}"
    return 1
  elif [[ ${#REMOTES[@]} -eq 0 ]]; then
    err "Configuration error: No remotes defined"
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
# rclone command creation and execution
# loop.
# Returns:
#   Exit status int.
#######################################
command_loop() {
  # Declare local variables.
  local mount_path log_path
  local -i i success_count=0 skip_count=0 fail_count=0

  for ((i=0; i<${#REMOTES[@]}; i++)); do
    # Create mount and log paths.
    mount_path="${CLOUD_DIR}/${MOUNTS[$i]}"
    log_path="${LOG_DIR}/${LOG_FILES[$i]}"

    # Validate mount dirs.
    if mountpoint -q "${mount_path}" 2>/dev/null ; then
      echo "⚠️  ${MOUNTS[$i]} already mounted, skipping"
      ((fail_count++))
      continue
    elif [[ -d "${mount_path}" \
      && -n "$(ls -A "${mount_path}" 2>/dev/null)" ]]; then
      err "Mount dir not empty: ${mount_path}"
      ((fail_count++))
      continue
    fi

    echo "🔧 Mounting ${MOUNTS[$i]}..."

    # Add per-remote arguments, if any.
    local -a args
    args=("${RCLONE_ARGS[@]}")
    if [[ -n "${REMOTE_ARGS[$i]}" ]]; then
      args+=("${REMOTE_ARGS[$i]}")
    fi

    # Build and execute command.
    if rclone mount \
      "${REMOTES[$i]}" \
      "${mount_path}" \
      --log-file "${log_path}" \
      "${args[@]}"; then
      echo "✅ ${MOUNTS[$i]} mounted successfully."
      ((success_count++))
    else
      err "Failed to mount ${MOUNTS[$i]}"
      ((fail_count++))
    fi
  done

  # Print summary.
  echo ""
  echo "📊 Summary:"
  echo "   ✅ Successfully mounted: ${success_count}."
  echo "   ⚠️ Skipped (already mounted): ${skip_count}."
  echo "   ❌ Failed: ${fail_count}."
  echo ""

  # Return error if any mounts failed.
  [[ $fail_count -eq 0 ]]
}

#######################################
# Launches main function.
# Arguments:
#   Script positional arguments.
# Returns:
#   Exit status int.
#######################################
main() {
  # Loading and validation.
  set_args "$@" || exit 1
  chk_rclone || exit 1
  load_cfg || exit 1
  val_var || exit 1
  val_remotes || exit 1
  val_arr || exit 1

  echo "🚀 Starting rclone automount script..."

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
