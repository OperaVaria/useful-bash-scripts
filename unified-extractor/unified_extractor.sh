#!/usr/bin/env bash
#
# Unified archive extractor for Bash
# Created by OperaVaria
# lcs_it@proton.me
#
# Part of the "useful-bash-scripts" project:
# https://github.com/OperaVaria/useful-bash-scripts
# Version 1.0.0
#
# The script unifies the different archive extracting commands to a single one
# for convenient use. Best employed aliased to "extract" or added to PATH.
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
# Function to handle and validate run options.
# Arguments:
#   Script positional arguments.
# Returns:
#   Exit status.
#######################################
set_args() {
  local -a positional=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -v|--verbose)
        verbose=1
        shift
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      -*)
        echo "❌ Unknown option '$1'"
        return 1
        ;;
      *)
        positional+=("$1")
        shift
        ;;
    esac
  done
  if [[ ${#positional[@]} -eq 0 ]]; then
    echo "❌ No archive specified"
    return 1
  else
    file="${positional[0]}"
    [[ ! -f "${file}" ]] \
      && { echo "❌ '${file}' is not a file"; return 1; }
    file="$(realpath "${file}")"
  fi
  if [[ ${#positional[@]} -eq 1 ]]; then
    crt_dir
  else
    destination="${positional[1]}"
    mkdir -p "${destination}" || return 1
    destination="$(realpath "${destination}")"
  fi  
  return 0
}

#######################################
# Displays help message.
#######################################
show_help() {
  cat << EOF
Usage: standalone: ./unified_extractor.sh [OPTIONS] <archive> <destination>
       command: extract [OPTIONS] <archive> <destination>

Extracts different types of archive files with a single command.

ARGUMENTS:
  archive                  Archive filename
  destination              Directory to extract to
                           (default: new directory in the location of the
                            archive file with the name of the archive)

OPTIONS:
  -h, --help               Show this help message
  -v, --verbose            Display (more) information prompts during the
                           extraction process
EOF
}

#######################################
# Detects file mimetype and runs proper
# extracting binary.
# Returns:
#   Exit status.
#######################################
run_mime() {
  local args mime
  mime=$(file --mime-type -b "${file}")
  case "${mime}" in
    application/zip)
      chk_cmd unzip
      [[ "${verbose}" -eq 1 ]] && args="-v" || args="-qq"
      unzip "${args}" "${file}" -d "${destination}"
      ;;
    application/x-tar|application/x-gtar)
      chk_cmd tar
      [[ "${verbose}" -eq 1 ]] && args="-xvf" || args="-xf"
      tar "${args}" "${file}" -C "${destination}"
      ;;
    application/gzip|application/x-gzip)
      chk_cmd tar
      [[ "${verbose}" -eq 1 ]] && args="-xvzf" || args="-xzf"
      tar "${args}" "${file}" -C "${destination}"
      ;;
    application/x-bzip2)
      chk_cmd tar
      [[ "${verbose}" -eq 1 ]] && args="-xvjf" || args="-xjf"
      tar "${args}" "${file}" -C "${destination}"
      ;;
    application/x-xz)
      chk_cmd tar
      [[ "${verbose}" -eq 1 ]] && args="-xvJf" || args="-xJf"
      tar "${args}" "${file}" -C "${destination}"
      ;;
    application/zstd)
      chk_cmd tar
      [[ "${verbose}" -eq 1 ]] && args="-xvf" || args="-xf"
      tar --zstd "${args}" "${file}" -C "${destination}"
      ;;
    application/x-7z-compressed)
      chk_cmd 7z
      if [[ "${verbose}" -eq 1 ]]; then
        7z x "${file}" -o"${destination}"
      else
        7z x "${file}" -o"${destination}" -bso0 -bsp0
      fi
      ;;
    application/vnd.rar|application/x-rar)
      chk_cmd unrar
      if [[ "${verbose}" -eq 1 ]]; then
        unrar x "${file}" "${destination}/"
      else
        unrar x -inul "${file}" "${destination}/"
      fi
      ;;
    *)
      echo "❌ Unsupported archive type (${mime})"
      return 1
      ;;
  esac
  return 0
}

#######################################
# Check if command is available on the
# system.
# Arguments:
#   Command to be checked.
# Returns:
#   Exit status.
#######################################
chk_cmd() {
  command -v "$1" >/dev/null 2>&1 \
    || { echo "❌ Required command '$1' not found"; return 1; }
  return 0
}

#######################################
# Create directory path from archive
# path by removing extension. Handles
# *.tar.* files.
# Prompts if already exists.
# Returns:
#   Exit status.
#######################################
crt_dir() {
  if [[ "${file}" == *".tar."* ]];then
    destination="${file%.tar.*}"
  else
    destination="${file%.*}"
  fi
  if [[ -e "${destination}" ]]; then
    echo "⚠️  Directory '$(basename "${destination}")' already exists"
    read -t 30 -p "Continue anyway? (Y/N): " -n 1 -r
    echo
    [[ ! "${REPLY}" =~ ^[Yy]$ ]] && return 1
  fi
  mkdir -p "${destination}" || return 1
  return 0
}

#######################################
# Launches main function.
# Arguments:
#   Script positional arguments.
# Returns:
#   Exit status.
#######################################
extract() {
  local destination file
  local -i verbose=0
  set_args "$@"
  [[ $verbose -eq 1 ]] \
    && echo -e "Extracting: '${file}'\ninto '${destination}/'"
  run_mime
  echo "✅ Completed successfully"
  return 0
}

# Launch main function.
extract "$@"
