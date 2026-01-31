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
# The script performs an automated system cleanup on an Arch-based Linux system.
# The following steps can be executed: cleaning cache directory, emptying Trash,
# removing old temp and logs files, vacuuming the journals, clearing
# the pacman cache, and checking for orphaned packages. The severity of the
# cleanup (normal or "aggressive" level) can be set by command line arguments.
# The script can only properly run with sudo privileges.
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
declare -i no_confirm=0

# Declare cleaning date limits (in days).
readonly NORMAL_DAY_LIMIT=14
readonly AGGRESSIVE_DAY_LIMIT=7

# Declare color escape code constants.
readonly GREEN="\033[0;32m"
readonly YELLOW="\033[1;33m"
readonly RED="\033[0;31m"
readonly NC="\033[0m"

#######################################
# Function to set program mode variables
# in accordance with the script arguments.
# Arguments:
#   Script positional arguments.
# Returns:
#   Exit status.
#######################################
set_mode() {
  for arg in "$@"; do
    case "${arg}" in
      --aggressive|-a)
        aggressive=1
        ;;
      --yes|-y)
        no_confirm=1
        ;;
      --help|-h)
        cat << EOF
Usage: smart_cleanup_arch.sh [OPTIONS]

Performs an automated system cleanup for Arch-based systems.

OPTIONS:
  --aggressive    Run with more severe removal settings
  --yes, -y       Skip confirmation prompts
  --help, -h      Show this help message

EXAMPLES:
  # Normal cleanup with confirmation
  sudo ./smart_cleanup_arch.sh

  # Aggressive cleanup without prompts
  sudo ./smart_cleanup_arch.sh --aggressive --yes

DESCRIPTION:
  Normal mode:     Removes files older than 14 days, keeps the latest three
                   cached packages.
  Aggressive mode: Removes files older than 7 days, removes all pacman cache.
EOF
        return 1
        ;;
      *)
        echo -e "${RED}❌ Unknown argument '${arg}'${NC}"
        echo "Use --help or -h for usage information"
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
# Confirmation prompt loop, skip if non
# interactive mode enabled.
# Arguments:
#   Prompt message string.
# Returns:
#   Exit status (0=yes, 1=no).
#######################################
conf_prompt() {
  local response
  [[ "${no_confirm}" -eq 1 ]] && return 0
  read -rp "$1 (Y/N): " response
  [[ "${response}" =~ ^[Yy]$ ]]
}

#######################################
# Check if commands are available on the
# system.
# Arguments:
#   Commands to be checked.
# Returns:
#   Exit status.
#######################################
chk_deps() {
  local missing=()
  for cmd in "$@"; do
      command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo -e "${RED}   ❌ Missing required commands: ${missing[*]}${NC}}"
    return 1
  fi
  return 0
}

#######################################
# Function to check the size of the target.
# Prints 0 if target does not exist, or is
# inaccessible.
# Arguments:
#   Target path.
#######################################
size_of() {
  [[ -e "$1" ]] || { echo "0"; return; }
  local size
  size=$(du -sb "$1" 2>/dev/null | head -n1 | awk '{print $1}')
  if [[ -n "$size" && "$size" =~ ^[0-9]+$ ]]; then
    echo "$size"
  else
    echo "0"
  fi
}

#######################################
# Calculate and track space freed,
# including total value in MBs.
# Arguments:
#   Size before in bytes.
#   Size after in bytes.
#######################################
track_freed() {
  local -i size_before="$1"
  local -i size_after="$2"
  local -i freed=$((size_before - size_after))
  if [[ "${freed}" -gt 0 ]]; then
    local -i freed_mb=$((freed / 1024 / 1024))
    total_freed=$((total_freed + freed_mb))
    echo "   Freed: ${freed_mb} MB"
  else
    echo "   Freed: 0 MB"
  fi
}

#######################################
# Function to clean ~/.cache directory.
# Deletes empty directories and files
# older than set limit. Tracks space freed.
# Arguments:
#   File deletion date limit (in days).
# Returns:
#   Exit status.
#######################################
cln_cache() {
  local -i cache_day_limit="$1"
  local -i size_before size_after
  echo "🗑  Cleaning cached files older than ${cache_day_limit} days"
  if [[ ! -d ~/.cache ]]; then
    echo "   ⚠️ ~/.cache does not exist, skipping"
    return 0
  fi
  size_before=$(size_of ~/.cache)
  find ~/.cache -type f -mtime +"${cache_day_limit}" -delete 2>/dev/null || true
  find ~/.cache -type d -empty -delete 2>/dev/null || true
  size_after=$(size_of ~/.cache)
  track_freed "${size_before}" "${size_after}"
  return 0
}

#######################################
# Function to empty the Trash directory.
# Tracks space freed.
# Returns:
#   Exit status.
#######################################
cln_trash() {
  local trash="${HOME}/.local/share/Trash"
  local -i day_limit="${1:-0}" # Limit date currently unused.
  local -i size_before size_after
  echo "🗑  Emptying Trash"
  if [[ ! -d "${trash}" ]]; then
    echo "   ⚠️ Trash directory not found, skipping"
    return 0
  fi
  size_before=$(size_of "${trash}")
  rm -rf "${trash}"/files/* "${trash}"/info/* 2>/dev/null || true
  size_after=$(size_of "${trash}")
  track_freed "${size_before}" "${size_after}"
  return 0
}

#######################################
# Function to clean the /tmp directory.
# Tracks space freed.
# Arguments:
#   File deletion date limit (in days).
# Returns:
#   Exit status.
#######################################
cln_tmp() {
  local -i tmp_limit="$1"
  local -i size_before size_after
  echo "🗑  Cleaning temp files older than ${tmp_limit} days"
  size_before=$(size_of "/tmp")
  sudo find /tmp -mindepth 1 -mtime +"${tmp_limit}" -delete 2>/dev/null || true
  size_after=$(size_of "/tmp")
  track_freed "${size_before}" "${size_after}"
  return 0
}

#######################################
# Function to clean logs.
# Tracks space freed.
# Arguments:
#   File deletion date limit (in days).
# Returns:
#   Exit status.
#######################################
cln_logs() {
  local -i log_limit="$1"
  local -i size_before size_after
  echo "📜 Cleaning logs older than ${log_limit} days"
  size_before=$(size_of /var/log)
  sudo find /var/log -type f -mtime +"${log_limit}" -delete 2>/dev/null || true
  size_after=$(size_of /var/log)
  track_freed "${size_before}" "${size_after}"
  return 0
}

#######################################
# Function to vacuum journals.
# Tracks space freed, if byte value can
# be extracted. Checks for dependencies.
# Arguments:
#   File deletion date limit (in days).
# Returns:
#   Exit status.
#######################################
vac_journals() {
  local -i vac_limit="$1"
  local -i size_before size_after
  echo "📜 Vacuuming journal logs older than ${vac_limit} days"
  chk_deps journalctl \
  || { echo "   ⚠️ Skipping vacuuming journals"; return 0; }
  size_before=$(sudo journalctl --disk-usage 2>/dev/null \
    | grep -oE '[0-9]+B' | grep -oE '[0-9]+' || echo "")
  sudo journalctl --vacuum-time="${vac_limit}d" 2>/dev/null || {
    echo "   ⚠️ Failed to vacuum journals"
    return 1
  }
  size_after=$(sudo journalctl --disk-usage 2>/dev/null \
    | grep -oE '[0-9]+B' | grep -oE '[0-9]+' || echo "")
  if [[ -n "${size_before}" && -n "${size_after}" ]]; then
    track_freed "${size_before}" "${size_after}"
  else
    echo "   ⚠️ Unable to calculate space freed"
  fi
  return 0
}

#######################################
# Function to clean pacman cache.
# Normal mode leaves most recent three
# cached, aggressive removes all.
# Checks for dependencies.
# Arguments:
#   File deletion date limit (in days).
# Returns:
#   Exit status.
#######################################
cln_paccache() {
  local -i day_limit="${1:-0}" # Limit date currently unused.
  local -i size_before size_after
  echo "📦  Cleaning pacman cache"
  chk_deps paccache \
    || { echo "   ⚠️ Skipping cleaning pacman cache"; return 0; }
  size_before=$(size_of /var/cache/pacman/pkg)  
  if [[ "${aggressive}" -eq 1 ]]; then
    echo "⚠️  Removing ALL cached packages"
    sudo paccache -rk0 2>/dev/null \
      || { echo "   ⚠️ paccache failed, continuing..."; }
  else
    sudo paccache -rk3 2>/dev/null \
      || { echo "   ⚠️ paccache failed, continuing..."; }
  fi
  size_after=$(size_of /var/cache/pacman/pkg)
  track_freed "${size_before}" "${size_after}"
  return 0
}

#######################################
# Function to remove orphaned packages.
# Checks for dependencies.
# Arguments:
#   File deletion date limit (in days).
# Returns:
#   Exit status.
#######################################
cln_orph() {
  local -i day_limit="${1:-0}" # Limit date currently unused.
  echo "📦 Removing orphan packages"
  chk_deps pacman \
    || { echo "   ⚠️ Skipping removing orphaned packages"; return 0; }
  local -a orphans
  mapfile -t orphans < <(pacman -Qtdq 2>/dev/null || true)
  if [[ ${#orphans[@]} -eq 0 ]]; then
    echo "   No orphans found"
  else
    echo "   Found ${#orphans[@]} orphaned package(s):"
    printf "   - %s\n" "${orphans[@]}"
    sudo pacman -Rns --noconfirm "${orphans[@]}" 2>/dev/null \
      || {
        echo "   ⚠️ Failed to remove some orphaned packages"
        echo "   They may have dependencies. Check manually."
      }
  fi
  return 0
}

#######################################
# Launches main function.
# Arguments:
#   Script positional arguments (run mode).
# Returns:
#   Exit status.
#######################################
main() {
  # Handle positional arguments.
  set_mode "$@" || exit 1
  # Sudo needed for most steps.
  sudo -v
  # Declare main function variables.
  declare -i day_limit=0 total_freed=0
  # Initial prompt, setup aggressiveness.
  echo -e "${GREEN}🧹 Smart Cleanup Script (Arch)${NC}"
  if [[ "${aggressive}" -eq 1 ]]; then
    echo -e "${YELLOW}   ⚠️ Running in AGGRESSIVE mode${NC}"
    day_limit="${AGGRESSIVE_DAY_LIMIT}"
    if [[ "${no_confirm}" -eq 0 ]]; then
      conf_prompt "   This will remove more data than normal mode. Continue?" \
        || exit 1
    fi
  else
    echo "   Running in normal mode"
    day_limit="${NORMAL_DAY_LIMIT}"
    if [[ "${no_confirm}" -eq 0 ]]; then
      conf_prompt "Proceed with normal cleanup?" || exit 1
    fi
  fi
  hr
  # Run functions, with prompts if no_confirm not enabled.
  declare -A prompts=(
    [cln_cache]="Clean cache directory?"
    [cln_trash]="Empty Trash?"
    [cln_tmp]="Clean temp directory?"
    [cln_logs]="Clean logs?"
    [vac_journals]="Vacuum journals?"
    [cln_paccache]="Clean pacman cache?"
    [cln_orph]="Remove orphaned packages?")
  for func in cln_cache cln_trash cln_tmp cln_logs \
    vac_journals cln_paccache cln_orph; do
    [[ "${no_confirm}" -eq 1 ]] || conf_prompt "${prompts[$func]}" || continue
    ${func} "${day_limit}"
    hr
  done
  # Final Report.
  echo -e "${GREEN}✅  Cleanup complete${NC}"
  if [[ "${total_freed}" -gt 0 ]]; then
    echo "   Total freed: ${total_freed} MB"
  fi
  return 0
}

# Launch main function.
main "$@"
