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
# Dependencies: bc journalctl pacman paccache
#
# Description: The script performs an automated system cleanup on Arch-based
# Linux OSs. The severity of the cleanup (normal or "aggressive" level) can
# be configured by command line arguments. The script can only properly run
# with sudo privileges.
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

# Declare cleaning date limits (in days).
readonly NORMAL_DAY_LIMIT=14 AGGRESSIVE_DAY_LIMIT=7

#######################################
# Handles and validates run options.
# Arguments:
#   Script positional arguments.
# Returns:
#   Exit status.
#######################################
set_mode() {
  for arg in "$@"; do
    case "${arg}" in
      -h|--help)
        show_help
        exit 0
        ;;
      -a|--aggressive)
        aggressive=1
        ;;
      -y|--yes)
        no_confirm=1
        ;;
      *)
        echo -e "❌ Unknown argument '${arg}'" >&2
        return 1
        ;;
    esac
  done
  return 0
}

#######################################
# Displays help message.
#######################################
show_help() {
  cat << EOF
Usage: ./smart_cleanup_arch.sh [OPTIONS]

Performs an automated system cleanup for Arch-based systems.

OPTIONS:
  -a, --aggressive      Run with more severe removal settings
  -h, --help            Show this help message
  -y, --yes             Skip confirmation prompts

DESCRIPTION:
  Normal mode:          Removes files older than 14 days, keeps the latest
                        three cached packages.
  Aggressive mode:      Removes files older than 7 days, clears the entire
                        pacman cache.
EOF
}

#######################################
# Displays initial warning and sets
# variables in accordance with
# aggressiveness option.
# Returns:
#   Exit status.
#######################################
set_aggress() {
  if [[ "${aggressive}" -eq 1 ]]; then
    echo -e "   ⚠️ Running in AGGRESSIVE mode"
    day_limit="${AGGRESSIVE_DAY_LIMIT}"
    conf_prompt "This will remove more data than normal mode. Continue?" \
      || return 1
  else
    echo "   Running in normal mode"
    day_limit="${NORMAL_DAY_LIMIT}"
    conf_prompt "Proceed with normal cleanup?" || return 1
  fi
  return 0
}

#######################################
# Cleans the ~/.cache directory.
# Deletes empty directories and files
# older than global limit.
# Returns:
#   Exit status.
#######################################
cln_cache() {
  echo "🗑  Cleaning cached files older than ${day_limit} days"
  if [[ ! -d "${HOME}/.cache" ]]; then
    echo "   ⚠️ ~/.cache does not exist, skipping" >&2
    return 0
  fi
  find "${HOME}/.cache" -mindepth 1 -type f -mtime +"${day_limit}" \
    -delete 2>/dev/null || true
  find "${HOME}/.cache" -type d -empty -delete 2>/dev/null || true
  return 0
}

#######################################
# Empties the Trash directory.
# Returns:
#   Exit status.
#######################################
cln_trash() {
  local trash="${HOME}/.local/share/Trash"
  echo "🗑  Emptying the Trash"
  if [[ ! -d "${trash}" ]]; then
    echo "   ⚠️ Trash directory not found, skipping" >&2
    return 0
  fi
  rm -rf "${trash}/files/"* "${trash}/info/"* 2>/dev/null || true
  return 0
}

#######################################
# Cleans the /tmp directory.
# Deletes empty directories and files
# older than global limit.
# Returns:
#   Exit status.
#######################################
cln_tmp() {
  echo "🗑  Cleaning temp files older than ${day_limit} days"
  sudo find /tmp -mindepth 1 -type f ! -xtype s -mtime +"${day_limit}" \
    -delete 2>/dev/null || true
  sudo find /tmp -type d -empty -delete 2>/dev/null || true
  return 0
}

#######################################
# Cleans log files older than global limit.
# Returns:
#   Exit status.
#######################################
cln_logs() {
  echo "📜 Cleaning logs older than ${day_limit} days"
  sudo find /var/log/*.log -type f -mtime +"${day_limit}" \
    -delete 2>/dev/null || true
  return 0
}

#######################################
# Vacuums journals. Checks for dependencies,
# tracks space freed if helper function
# dependency is available (bc).
# Returns:
#   Exit status.
#######################################
vac_journals() {
  echo "📜 Vacuuming journal logs older than ${day_limit} days"
  if ! chk_deps journalctl; then
    echo "   ⚠️ Skipping vacuuming journals"
  elif ! chk_deps bc; then
    echo "   ⚠️ Skipping calculating journals' size"
    sudo journalctl --vacuum-time="${day_limit}d" 2>/dev/null \
      || { echo "   ⚠️ Failed to vacuum journals" >&2; return 1; }
  else
    local -i size_before size_after
    size_before=$(journalctl_bytes) || size_before=0
    sudo journalctl --vacuum-time="${day_limit}d" 2>/dev/null || {
      echo "   ⚠️ Failed to vacuum journals" >&2
      return 1
    }
    size_after=$(journalctl_bytes) || size_after=0
    track_freed "${size_before}" "${size_after}"
  fi
  return 0
}

#######################################
# Helper function to convert journalctl
# disk usage output to byte value.
# Echos value in bytes.
# Returns:
#   Exit status.
#######################################
journalctl_bytes() {
    local journal_size number unit byte_result
    journal_size=$(sudo journalctl --disk-usage 2>/dev/null \
        | grep -oE '[0-9]+\.?[0-9]*[BKMGT]')
    [[ -z "${journal_size}" ]] && return 1
    number="${journal_size::-1}"
    unit="${journal_size: -1}"
    LC_ALL="C"
    case "${unit}" in
        B)
          byte_result="${number}"
          ;;
        K)
          byte_result=$(printf "%.0f" \
          "$(echo "${number} * 1024" | bc)")
          ;;
        M)
          byte_result=$(printf "%.0f" \
          "$(echo "${number} * 1048576" | bc)")
          ;;
        G)
          byte_result=$(printf "%.0f" \
          "$(echo "${number} * 1073741824" | bc)")
          ;;
        T)
          byte_result=$(printf "%.0f" \
          "$(echo "${number} * 1099511627776" | bc)")
          ;;
        *)
          echo "   ⚠️ Unknown file size unit: ${unit}" >&2
          return 1
          ;;
    esac
    echo "${byte_result}"
    return 0
}

#######################################
# Cleans pacman cache.
# Normal mode leaves most recent three
# cached, aggressive removes all.
# Checks for dependencies.
# Returns:
#   Exit status.
#######################################
cln_paccache() {
  echo "📦 Cleaning pacman cache"
  chk_deps paccache \
    || { echo "   ⚠️ Skipping cleaning pacman cache"; return 0; }
  if [[ "${aggressive}" -eq 1 ]]; then
    echo "⚠️  Removing ALL cached packages"
    sudo paccache -rk0 2>/dev/null \
      || { echo "   ⚠️ paccache failed, continuing..." >&2; }
  else
    sudo paccache -rk3 2>/dev/null \
      || { echo "   ⚠️ paccache failed, continuing..." >&2; }
  fi
  return 0
}

#######################################
# Removes orphaned packages.
# Checks for dependencies.
# Returns:
#   Exit status.
#######################################
cln_orph() {
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
        echo "   ⚠️ Failed to remove some orphaned packages" >&2
      }
  fi
  return 0
}

#######################################
# Iterates over cleaning functions and data arrays.
# Displays prompts in normal mode. Tracks freed
# space when possible (exception: vac_journals,
# cln_orph).
# Returns:
#   Exit status.
#######################################
func_loop() {
  local -i size_before size_after
  local -a funcs=("cln_cache"
                  "cln_trash"
                  "cln_tmp"
                  "cln_logs"
                  "vac_journals"
                  "cln_paccache"
                  "cln_orph")
  declare -a prompts=("Clean the cache?"
                      "Empty the Trash?"
                      "Clean the temp directory?"
                      "Clean the logs?"
                      "Vacuum the journals?"
                      "Clean the pacman cache?"
                      "Remove orphaned packages?")
  local -a dirs=("${HOME}/.cache"
                  "${HOME}/.local/share/Trash"
                  "/tmp"
                  "/var/log"
                  ""
                  "/var/cache/pacman/pkg"
                  "")
  for ((i=0; i<${#funcs[@]}; i++)); do
    conf_prompt "${prompts[$i]}" || continue
    if [[ "${funcs[$i]}" == "vac_journals" ]] \
      || [[ "${funcs[$i]}" == "cln_orph" ]]; then
      ${funcs[$i]}
    else
      size_before=$(size_of "${dirs[$i]}") || size_before=0
      ${funcs[$i]}
      size_after=$(size_of "${dirs[$i]}") || size_after=0
      track_freed "${size_before}" "${size_after}"
    fi
    hr
  done
  return 0
}

#######################################
# Function to print horizontal line.
#######################################
hr() { echo "------------------------------------------------------------"; }

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
# Checks if commands are available on the
# system.
# Arguments:
#   Commands to be checked.
# Returns:
#   Exit status.
#######################################
chk_deps() {
  local missing=()
  for cmd in "$@"; do
      command -v "${cmd}" >/dev/null 2>&1 || missing+=("${cmd}")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo -e "   ❌ Missing required commands: ${missing[*]}" >&2
    return 1
  fi
  return 0
}

#######################################
# Checks the size of the target.
# Echos value in bytes.
# Arguments:
#   Target path.
# Returns:
#   Exit status.
#######################################
size_of() {
  local size
  size=$(du -sb "$1" 2>/dev/null | head -n1 | awk '{print $1}')
  if [[ -n "${size}" && "${size}" =~ ^[0-9]+$ ]]; then
    echo "${size}"
    return 0
  else
    return 1
  fi
}

#######################################
# Calculates and tracks space freed,
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
    local -i freed_mb=$((freed / 1048576))
    total_freed=$((total_freed + freed_mb))
    echo "   Freed: ${freed_mb} MB"
  else
    echo "   Freed: 0 MB"
  fi
}

#######################################
# Launches main function.
# Arguments:
#   Script positional arguments (run mode).
# Returns:
#   Exit status.
#######################################
main() {
  # Pre-run steps.
  declare -gi aggressive=0 no_confirm=0 day_limit=0  total_freed=0
  set_mode "$@" || exit 1
  sudo -v || { echo "❌ Sudo authentication failed"; exit 1; }
  echo -e "🧹 Smart Cleanup Script (Arch)"
  set_aggress || exit 1
  hr

  # Run functions.
  func_loop

  # Final Report.
  echo -e "✅ Cleanup complete"
  [[ "${total_freed}" -gt 0 ]] \
    && echo "   Total freed: ${total_freed} MB"

  return 0
}

# Launch main function.
main "$@"
