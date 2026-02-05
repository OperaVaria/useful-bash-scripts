#!/usr/bin/env bash
#
# Smart cleanup script for Bash (Debian version)
# Created by OperaVaria
# lcs_it@proton.me
#
# Part of the "useful-bash-scripts" project:
# https://github.com/OperaVaria/useful-bash-scripts
# Version 1.0.0
#
# Dependencies: apt-get bc deborphan journalctl
#
# Description: The script performs an automated system cleanup on Debian-based
# Linux OSs. The severity of the cleanup (normal or "aggressive" level) can
# be configured by command line arguments. The script can only properly run
# with sudo privileges.
#
# Tested on: MX Linux 23.5, GNU bash, 5.2.15(1)-release
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
# Function to handle and validate run options.
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
Usage: ./smart_cleanup_deb.sh [OPTIONS]

Performs an automated system cleanup for Debian-based systems.

OPTIONS:
  -a, --aggressive      Run with more severe removal settings
  -h, --help            Show this help message
  -y, --yes             Skip confirmation prompts

DESCRIPTION:
  Normal mode:          Removes files older than 14 days, runs apt-get
                        autoclean.
  Aggressive mode:      Removes files older than 7 days, runs apt-get clean,
                        clears the entire APT cache.
EOF
}

#######################################
# Display initial warning and set
# variables in accordance with
# aggressiveness.
# Returns:
#   Exit status.
#######################################
set_aggress() {
  if [[ "${aggressive}" -eq 1 ]]; then
    echo -e "   ⚠️ Running in AGGRESSIVE mode"
    day_limit="${AGGRESSIVE_DAY_LIMIT}"
    if [[ "${no_confirm}" -eq 0 ]]; then
      conf_prompt "This will remove more data than normal mode. Continue?" \
        || return 1
    fi
  else
    echo "   Running in normal mode"
    day_limit="${NORMAL_DAY_LIMIT}"
    if [[ "${no_confirm}" -eq 0 ]]; then
      conf_prompt "Proceed with normal cleanup?" || return 1
    fi
  fi
  return 0
}

#######################################
# Function to clean ~/.cache directory.
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
  find ~/.cache -mindepth 1 -type f -mtime +"${day_limit}" \
    -delete 2>/dev/null || true
  find ~/.cache -type d -empty -delete 2>/dev/null || true
  return 0
}

#######################################
# Function to empty the Trash directory.
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
  rm -rf "${trash}"/files/* "${trash}"/info/* 2>/dev/null || true
  return 0
}

#######################################
# Function to clean the /tmp directory.
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
# Function to clean logs.
# Returns:
#   Exit status.
#######################################
cln_logs() {
  echo "📜 Cleaning logs older than ${day_limit} days"
  sudo find /var/log -type f -mtime +"${day_limit}" \
    -delete 2>/dev/null || true
  return 0
}

#######################################
# Function to vacuum journals.
# Checks for dependencies, tracks space freed.
# Returns:
#   Exit status.
#######################################
vac_journals() {
  local -i size_before size_after
  echo "📜 Vacuuming journal logs older than ${day_limit} days"
  chk_deps bc journalctl \
    || { echo "   ⚠️ Skipping vacuuming journals"; return 0; }
  size_before=$(journalctl_bits)
  sudo journalctl --vacuum-time="${day_limit}d" 2>/dev/null || {
    echo "   ⚠️ Failed to vacuum journals" >&2
    return 1
  }
  size_after=$(journalctl_bits)
  track_freed "${size_before}" "${size_after}"
  return 0
}

#######################################
# Helper function to convert journalctl
# disk usage output to byte value.
# Returns:
#   Exit status.
#######################################
journalctl_bits() {
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
# Function to clean APT cache.
# Normal mode uses autoclean, aggressive
# uses clean to remove all cached packages.
# Checks for dependencies.
# Returns:
#   Exit status.
#######################################
cln_aptcache() {
  echo "📦 Cleaning APT cache"
  chk_deps apt-get || { echo "   ⚠️ Skipping cleaning APT cache"; return 0; }
  if [[ "${aggressive}" -eq 1 ]]; then
    echo "⚠️  Removing ALL cached packages"
    sudo apt-get clean 2>/dev/null \
      || { echo "   ⚠️ apt-get clean failed, continuing..."; }
  else
    sudo apt-get autoclean 2>/dev/null \
      || { echo "   ⚠️ apt-get autoclean failed, continuing..."; }
  fi
  return 0
}

#######################################
# Function to remove orphaned packages.
# Uses deborphan if available, otherwise
# falls back to apt-get autoremove.
# Checks for dependencies.
# Returns:
#   Exit status.
#######################################
cln_orph() {
  echo "📦 Removing orphan packages"
  chk_deps apt-get \
    || { echo "   ⚠️ Skipping removing orphaned packages"; return 0; }
  if chk_deps deborphan; then
    local -a orphans
    mapfile -t orphans < <(sudo deborphan 2>/dev/null || true)
    if [[ ${#orphans[@]} -eq 0 ]]; then
      echo "   No orphans found (deborphan)"
    else
      echo "   Found ${#orphans[@]} orphaned package(s) via deborphan:"
      printf "   - %s\n" "${orphans[@]}"
      sudo apt-get purge "${orphans[@]}" 2>/dev/null \
        || echo "   ⚠️ Failed to remove some orphaned packages"
    fi
  fi
  echo "   Running apt-get autoremove..."
  sudo apt-get autoremove --yes 2>/dev/null \
    || echo "   ⚠️ autoremove encountered issues"
  return 0
}

#######################################
# Function to iterate over cleaning functions.
# Displays prompts in normal mode. Tracks freed
# space when possible.
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
                  "cln_aptcache"
                  "cln_orph")
  declare -a prompts=("Clean the cache?"
                      "Empty the Trash?"
                      "Clean the temp directory?"
                      "Clean the logs?"
                      "Vacuum the journals?"
                      "Clean the APT cache?"
                      "Remove orphaned packages?")
  local -a dirs=("${HOME}/.cache"
                  "${HOME}/.local/share/Trash"
                  "/tmp"
                  "/var/log"
                  ""
                  "/var/cache/apt/archives"
                  "")
  for ((i=0; i<${#funcs[@]}; i++)); do
    [[ "${no_confirm}" -eq 1 ]] || conf_prompt "${prompts[$i]}" || continue
    if [[ "${funcs[$i]}" == "vac_journals" ]] \
      || [[ "${funcs[$i]}" == "cln_orph" ]]; then
      ${funcs[$i]}
    else
      size_before=$(size_of "${dirs[$i]}")
      ${funcs[$i]}
      size_after=$(size_of "${dirs[$i]}")
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
      command -v "${cmd}" >/dev/null 2>&1 || missing+=("${cmd}")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo -e "   ❌ Missing required commands: ${missing[*]}" >&2
    return 1
  fi
  return 0
}

#######################################
# Function to check the size of the target.
# Prints 0 if value is empty or non-number.
# Arguments:
#   Target path.
#######################################
size_of() {
  local size
  size=$(du -sb "$1" 2>/dev/null | head -n1 | awk '{print $1}')
  if [[ -n "${size}" && "${size}" =~ ^[0-9]+$ ]]; then
    echo "${size}"
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
  sudo -v
  echo -e "🧹 Smart Cleanup Script (Debian)"
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
