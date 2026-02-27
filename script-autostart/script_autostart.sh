#!/usr/bin/env bash
#
# Script autostart utility for Bash
# Created by OperaVaria
# lcs_it@proton.me
#
# Part of the "useful-bash-scripts" project:
# https://github.com/OperaVaria/useful-bash-scripts
# Version 1.0.0
#
# Dependencies: -
#
# Description: This small command line utility helps the user to easily set up
# a script to run automatically at login.
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

#######################################
# Handles and validates run options.
# Arguments:
#   Script positional arguments.
# Returns:
#   Exit status.
#######################################
set_args() {
  local -a pos_args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        show_help
        exit 0
        ;;
      -y|--yes)
        no_confirm=1
        shift
        ;;
      -*)
        echo "❌ Unknown option '$1'" >&2
        return 1
        ;;
      *)
        pos_args+=("$1")
        shift
        ;;
    esac
  done
  if [[ ${#pos_args[@]} -eq 0 ]]; then
    echo "❌ No script file specified" >&2
    return 1
  elif [[ ${#pos_args[@]} -gt 1 ]]; then
    echo "❌ Too many positional arguments" >&2
    return 1
  elif [[ ! -f "${pos_args[0]}" ]]; then
    echo "❌ '${pos_args[0]}' is not a valid file" >&2
    return 1
  else
    script="$(realpath "${pos_args[0]}")"
  fi
  return 0
}

#######################################
# Displays help message.
#######################################
show_help() {
  cat << EOF
Usage: ./script_autostart.sh [OPTIONS] <script_file>

Helps the user to quickly set a script to autorun at user login.

ARGUMENTS:
  script_file               Script file path

OPTIONS:
  -h, --help                Show this help message
  -y, --yes                 Skip confirmation prompts
EOF
}

#######################################
# Validates that the file is a (probable)
# shell script. Checks if file is not
# empty and has a valid-seeming shebang.
# Returns:
#   Exit status.
#######################################
val_script() {
  local first_line
  local -i issues=0
  first_line=$(head -n 1 "${script}" 2>/dev/null || echo "")
  if [[ ! -s "${script}" ]]; then
    echo "⚠️ Warning: Script file is empty" >&2
    ((issues++))
  elif [[ ! "${first_line}" =~ ^#! ]]; then
    echo "⚠️ Warning: No shebang found" >&2
    ((issues++))
  elif [[ ! "${first_line}" =~ (bash|sh|zsh|ksh|fish|dash) ]]; then
    echo "⚠️ Warning: Shebang doesn't reference a known shell: ${first_line}"
    ((issues++))
  fi
  if [[ "${issues}" -gt 0 ]]; then
    conf_prompt "Continue despite warning?" || return 1
  fi
  return 0
}

#######################################
# Makes script file executable.
# Prompt only in interactive mode.
# Returns:
#   Exit status.
#######################################
set_exec() {
  if ! [[ -x "${script}" ]]; then
    conf_prompt "Script is not executable. Change permissions?" || return 0
    chmod +x "${script}"
  fi
  return 0
}

#######################################
# Creates a .desktop file in the user
# autostart directory. Tries to create autostart
# directory, if absent. Prompts if file
# already exists. Error handling included.
# Returns:
#   Exit status.
#######################################
crt_autostart() {
  local autostart_dir script_name desktop_file
  autostart_dir="${HOME}/.config/autostart"
  script_name=$(basename "${script}")
  desktop_file="${autostart_dir}/${script_name}.desktop"
  if ! mkdir -p "${autostart_dir}"; then
    echo "❌ Failed to create autostart directory" >&2
    return 1
  elif [[ -e "${desktop_file}" ]]; then
    conf_prompt "⚠️ Autostart entry already exists. Overwrite?" || return 1
  fi
  if ! cat > "${desktop_file}" <<EOF
[Desktop Entry]
Exec=${script}
Icon=application-x-shellscript
Name=${script_name}
Type=Application
Hidden=false
X-KDE-AutostartScript=true
X-GNOME-Autostart-enabled=true
Comment=Autostart script created by script_autostart.sh
EOF
  then
    echo "❌ Failed to create .desktop file" >&2
    return 1
  fi  
  return 0
}

#######################################
# Confirmation prompt, skip if
# non-interactive mode enabled.
# Arguments:
#   Prompt message string.
# Returns:
#   Exit status (0=yes, 1=no).
#######################################
conf_prompt() {
  [[ "${no_confirm}" -eq 1 ]] && return 0
  read -t 30 -p "$1 (Y/N): " -n 1 -r \
    || { echo -e "\n⏱️ Timed out waiting for response"; return 1; }
  echo
  [[ "${REPLY}" =~ ^[Yy]$ ]]
}

#######################################
# Launches main function.
# Arguments:
#   Script positional arguments (run mode).
# Returns:
#   Exit status.
#######################################
main() {
  declare -g script
  declare -gi no_confirm=0
  set_args "$@" || exit 1
  val_script || exit 1
  set_exec || exit 1
  crt_autostart || exit 1
  echo "✅ Autostart entry created successfully"
  return 0
}

# Launch main function.
main "$@"
