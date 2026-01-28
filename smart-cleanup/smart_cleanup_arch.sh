#!/usr/bin/env bash
#
# Smart cleanup script for Bash (Arch version)
# Created by OperaVaria
# lcs_it@proton.me
#
# Part of the "useful-bash-scripts" project:
# https://github.com/OperaVaria/useful-bash-scripts
# Version 1.0.0
#
# The script performs an automated system cleanup on an Arch-based Linux system,
# by executing the following steps: cleaning cache directory, emptying Trash,
# and removing older temp files, logs, and journals. It also clears the pacman
# cache, and can check for orphaned packages, if needed. The severity of the
# cleanup is set by command line arguments. The script can only properly run
# with sudo privileges.
#
# Tested on: CachyOS (rolling), GNU bash, 5.3.9(1)-release
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

# Declare script mode "booleans".
declare -i aggressive=0
declare -i no_pacman=0

# Declare cleaning date limits (in days).
readonly NORMAL_DAY_LIMIT=7
readonly AGGRESSIVE_DAY_LIMIT=14

# Declare color escape code constants.
readonly GREEN="\033[0;32m"
# readonly YELLOW="\033[1;33m"
readonly RED="\033[0;31m"
readonly NC="\033[0m"

#######################################
# Function to set program mode variables
# in accordance with the script arguments.
# Arguments:
#   Script positional arguments.
# Returns:
#   Exit status int.
#######################################
set_mode() {
  for arg in "$@"; do
    case "${arg}" in
      --aggressive) aggressive=1 ;;
      --no-pacman) no_pacman=1 ;;
      --help)
        echo "Usage: smart-clean.sh [--aggressive] [--no-pacman]"
        echo "Performs an automated system cleanup."
        echo
        echo "OPTIONS:"
        echo "  --aggressive    Run with more severe removal settings."
        echo "  --no-pacman     Skip package cleanup."
        echo "  --help          Show this help."
        return 1
        ;;
      *)
        echo -e "${RED}Unknown argument '${arg}'${NC}"
        return 1
        ;;
    esac
  done
  return 0
}

#######################################
# Function to print horizontal line.
#######################################
hr() {
  echo "------------------------------------------------------------"
}

#######################################
# Function to check the size of the target.
# Prints 0 if target does not exist.
# Arguments:
#   Target path
#######################################
size_of() {
  [[ -e "$1" ]] || { echo "0"; return; }
  du -sh "$1" 2>/dev/null | awk '{print $1}'
}

#######################################
# Function to clean ~/.cache directory.
#######################################
cln_cache() {
  shopt -s nullglob
  echo "🗑 Cleaning ~/.cache"
  echo "  Size before: $(size_of ~/.cache)"
  rm -rf ~/.cache/*
  shopt -u nullglob
  echo "  Size after:  $(size_of ~/.cache)"  
}

#######################################
# Function to empty the Trash, if found.
#######################################
cln_trash() {
  local trash="${HOME}/.local/share/Trash"
  if [[ -d "${trash}" ]]; then
    shopt -s nullglob
    echo "🗑 Emptying Trash"
    echo "  Size before: $(size_of "${trash}")"
    rm -rf "${trash}"/files/* "${trash}"/info/*
    shopt -u nullglob
    echo "  Size after:  $(size_of "${trash}")"
  fi
}

#######################################
# Function to clean temp directory, file
# removal date limit set by run mode.
#######################################
cln_tmp() {
  local -i tmp_limit=${NORMAL_DAY_LIMIT}
  if [[ "${aggressive}" -eq 1 ]]; then
    tmp_limit=${AGGRESSIVE_DAY_LIMIT}
  fi
  echo "🗑 Cleaning temp files older than ${tmp_limit} days"
  sudo find /tmp -mindepth 1 -mtime +${tmp_limit} -delete || true
}

#######################################
# Function to clean logs, log removal
# date limit set by run mode.
#######################################
cln_logs() {
  local -i log_limit=${NORMAL_DAY_LIMIT}
  if [[ "${aggressive}" -eq 1 ]]; then
    log_limit=${AGGRESSIVE_DAY_LIMIT}
  fi
  echo "📜 Cleaning logs older than ${log_limit} days"
  sudo find /var/log -type f -mtime +${log_limit} -delete || true
}

#######################################
# Function to clean pacman cache and
# orphaned packages. Normal mode leaves
# most recent three cached, aggressive
# removes all.
#######################################
cln_pacman() {
  echo "📦 Cleaning pacman cache"    
  if [[ "${aggressive}" -eq 1 ]]; then
    echo "📦 Removing ALL cached packages"
    sudo paccache -rk0
  else
    sudo paccache -rk3
  fi
  hr
  echo "📦 Removing orphan packages"
  orphans=$(pacman -Qtdq || true)
  if [[ -n "${orphans}" ]]; then
    sudo pacman -Rns -- ${orphans}
  else
    echo "   No orphans found."
  fi
}

#######################################
# Function to vacuum journals. Removal
# date limit set by run mode.
#######################################
vac_journals() {
  local -i vac_limit=${NORMAL_DAY_LIMIT}
  if [[ "${aggressive}" -eq 1 ]]; then
    vac_limit=${AGGRESSIVE_DAY_LIMIT}
  fi
  echo "📜 Vacuuming journal logs older than ${vac_limit} days"
  sudo journalctl --vacuum-time="${vac_limit}d"
}

#######################################
# Launches main function.
# Arguments:
#   Script positional arguments (run mode).
# Returns:
#   Exit status int.
#######################################
main() {
  # Handle positional arguments.
  set_mode "$@" || exit 1

  # Sudo needed for most steps.
  sudo -v

  # Initial prompt.
  space_before=$(df -h / | awk 'NR==2{print $4}')
  echo -e "${GREEN}🧹 Smart Cleanup Script (Arch)${NC}"
  echo "Free space before: $space_before"
  hr

  # Run functions.
  cln_cache
  hr
  cln_trash
  hr
  cln_tmp
  hr
  cln_logs
  hr
  if [[ "${no_pacman}" -eq 0 ]]; then
    cln_pacman
    hr
  fi
  vac_journals
  hr
  
  # Final Report.
  space_after=$(df -h / | awk 'NR==2{print $4}')
  echo -e "${GREEN}✅ Cleanup complete${NC}"
  echo "Free space before: ${space_before}"
  echo "Free space after:  ${space_after}"
  return 0
}

# Launch main function.
main "$@"
