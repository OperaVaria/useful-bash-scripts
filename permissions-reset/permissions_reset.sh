#!/usr/bin/env bash
#
# File-system permissions reset script for Bash
# Created by OperaVaria
# lcs_it@proton.me
#
# Part of the "useful-bash-scripts" project:
# https://github.com/OperaVaria/useful-bash-scripts
# Version 1.0.0
#
# Dependencies: realpath stat
#
# Description: This script resets the Unix file-system permissions of files and
# directories to their system defaults. Multiple path arguments can be passed,
# directories are scanned recursively.
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

# Converted octal constants.
DIR_DEFAULT=$(printf '%o' $(( 8#777 - 8#$(umask) )))
FILE_DEFAULT=$(printf '%o' $(( 8#666 - 8#$(umask) )))

#######################################
# Handles and validates run options.
# Arguments:
#   Script positional arguments.
# Returns:
#   Exit status.
#######################################
set_args() {
  local -a positional=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        show_help
        exit 0
        ;;
      -e|--executables)
        keep_exec=1
        shift
        ;;
      -*)
        echo "❌ Unknown option '$1'" >&2
        return 1
        ;;
      *)
        positional+=("$1")
        shift
        ;;
    esac
  done
  if [[ ${#positional[@]} -eq 0 ]]; then
    echo "❌ No file or directory specified" >&2
    return 1
  fi
  for item in "${positional[@]}"; do
    if [[ ! -f "${item}" ]] && [[ ! -d "${item}" ]]; then
      echo "❌ '${item}' is not a valid file or directory" >&2
      ((errors++)) || true
    else
      paths+=("${item}")
    fi
  done
  if [[ ${#paths[@]} -eq 0 ]]; then
    echo "❌ No valid file or directory specified" >&2
    return 1
  fi
  return 0
}

#######################################
# Displays help message.
#######################################
show_help() {
  cat << EOF
Usage: ./permissions_reset.sh [OPTIONS] <targets>

Resets file-system permissions to system defaults recursively
for the targeted paths.

ARGUMENTS:
  targets                  Files and directories to reset
                           (multiple paths can be passed)

OPTIONS:
  -e, --executables        Keep permissions for executables
  -h, --help               Show this help message
EOF
}

#######################################
# Resets permissions to global default
# values with set_target function.
# Ignores executables if keep_exec is true.
# Registers find call errors to global counter.
#######################################
reset_defaults() {
  export -f set_permissions
  for path in "${paths[@]}"; do
    find "${path}" -type d -exec \
      bash -c 'set_permissions "$@"' _ "${DIR_DEFAULT}" {} + \
      || { ((errors++)) || true; }
    if [[ ${keep_exec} -eq 1 ]]; then
      find "${path}" -type f ! -perm /111 -exec \
        bash -c 'set_permissions "$@"' _ "${FILE_DEFAULT}" {} + \
        || { ((errors++)) || true; }
    else
      find "${path}" -type f -exec \
        bash -c 'set_permissions "$@"' _ "${FILE_DEFAULT}" {} + \
        || { ((errors++)) || true; }
    fi
  done
}

#######################################
# Sets file-system permissions for target paths.
# Prints changes, warns on chmod errors.
# Arguments:
#   $1 - Chmod mode argument.
#   $2+ - Target paths.
# Returns:
#   Exit status.
#######################################
set_permissions() {
  local mode="$1"
  local -i rc=0
  shift
  for target in "$@"; do
    if ! chmod -c "${mode}" "${target}"; then
      resolved="$(realpath "${target}")"
      echo "❌ Failed to change permissions for '${resolved}'" >&2
      rc=1
    fi
  done
  return "${rc}"
}

#######################################
# Launches main function.
# Arguments:
#   Script positional arguments.
# Returns:
#   Exit status.
#######################################
main() {
  declare -gi errors=0 keep_exec=0
  declare -ga paths=()
  set_args "$@" || exit 1
  reset_defaults || exit 1
  if [[ ${errors} -eq 0 ]]; then
    echo "✅ Process completed successfully"
  else
    echo "⚠️ Process completed with above errors"
  fi
  return 0
}

# Launch main function.
main "$@"
