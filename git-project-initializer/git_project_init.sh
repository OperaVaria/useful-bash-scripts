#!/usr/bin/env bash
#
# Git project initializer script for Bash
# Created by OperaVaria
# lcs_it@proton.me
#
# Part of the "useful-bash-scripts" project:
# https://github.com/OperaVaria/useful-bash-scripts
# Version 1.0.0
#
# Dependencies: curl git realpath
#
# Description: The script creates a boilerplate Git project by creating the
# recommended directories, adding file templates, and initializing the Git
# repository.
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

# Set defaults:
project_dir="$(pwd -P)"
license="gnu-gpl-v3.0"
declare -a SUBDIRS=(bin docs src tests)
declare -a VALID_LICENSES=(artistic-v2.0 bsd-2 bsd-3 epl-v1.0 gnu-agpl-v3.0
                           gnu-fdl-v1.3 gnu-gpl-v1.0 gnu-gpl-v2.0 gnu-gpl-v3.0
                           gnu-lgpl-v2.1 gnu-lgpl-v3.0 mit mpl-v2.0 unlicense)

#######################################
# Function to handle and validate run options.
# Arguments:
#   Script positional arguments.
# Returns:
#   Exit status.
#######################################
set_args() {
  local positional=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        show_help
        exit 0
        ;;
      -l|--license)
        if [[ $# -ge 2 ]]; then
          license="${2,,}"
          if ! in_array "${license}" "${VALID_LICENSES[@]}"; then
              echo "❌ Unsupported license '${license}'" >&2
              return 1
          fi
        else
          echo "❌ -l/--license requires an argument" >&2
          return 1
        fi
        shift 2
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
  if [[ ${#positional[@]} -gt 1 ]]; then
    echo "❌ Too many positional arguments" >&2
    return 1
  elif [[ ${#positional[@]} -eq 1 ]]; then
    project_dir="${positional[0]}"
  fi
  return 0
}

#######################################
# Displays help message.
#######################################
show_help() {
  cat << EOF
Usage: ./git_project_init.sh [OPTIONS] <project_dir>

Creates a boilerplate Git project directory.

ARGUMENTS:
  project_dir              Target project directory
                           (default: current working directory)

OPTIONS:
  -h, --help               Show this help message

  -l, --license LICENSE    Set project license (default: gnu-gpl-v3.0)
                           Supported: artistic-v2.0, bsd-2, bsd-3, epl-v1.0,
                           gnu-agpl-v3.0, gnu-fdl-v1.3, gnu-gpl-v1.0,
                           gnu-gpl-v2.0, gnu-gpl-v3.0, gnu-lgpl-v2.1,
                           gnu-lgpl-v3.0, mit, mpl-v2.0, unlicense
EOF
}

#######################################
# Check if a value exists in an array.
# Arguments:
#   $1 - Value to search for.
#   $@ - Array elements.
# Returns:
#   0 if found, 1 if not.
#######################################
in_array() {
  local item
  local needle="$1"
  shift  
  for item in "$@"; do
    [[ "${item}" == "${needle}" ]] && return 0
  done
  return 1
}

#######################################
# Check project_dir, refuse root or home
# directory.
# Returns:
#   Exit status.
#######################################
chk_dir() {
  local resolved
  resolved="$(realpath -m "${project_dir}")"
  if [[ "${resolved}" == "/" ]]; then
    echo "❌ Refusing to run in root directory" >&2
    return 1
  elif [[ "${resolved}" == "${HOME}" ]]; then
    echo "❌ Refusing to run in home directory" >&2
    return 1
  fi
  return 0
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
    echo "❌ Missing required commands: ${missing[*]}" >&2
    return 1
  fi
  return 0
}

#######################################
# Create project directory with error
# handling if it already exists.
# Returns:
#   Exit status.
#######################################
crt_dir() {
  if [[ -e "${project_dir}" && ! -d "${project_dir}" ]]; then
    echo "❌ '${project_dir}' exists but is not a directory" >&2
    return 1
  elif [[ -d "${project_dir}" ]]; then    
    echo "📁 '${project_dir}' already exists."
   read -t 30 -p "Continue anyway? (Y/N): " -n 1 -r \
    || { echo -e "\n⏱️ Timed out waiting for response"; return 1; }
    echo
    [[ ! "${REPLY}" =~ ^[Yy]$ ]] && return 1    
  else
    mkdir -p "${project_dir}"
  fi
  return 0
}

#######################################
# Download template files with error handling.
#######################################
dwl_templates() {
  curl -sSLo COPYING.md \
    "https://raw.githubusercontent.com/IQAndreas/markdown-licenses/refs/heads/master/${license}.md" \
      || echo "⚠️ Failed to download COPYING.md" >&2
  curl -sSLo docs/CHANGELOG.md \
    "https://raw.githubusercontent.com/olivierlacan/keep-a-changelog/refs/heads/main/CHANGELOG.md" \
      || echo "⚠️ Failed to download CHANGELOG.md" >&2
  curl -sSLo docs/README.md \
    "https://raw.githubusercontent.com/me-and-company/readme-template/refs/heads/master/README.md" \
      || echo "⚠️ Failed to download README.md" >&2
}

#######################################
# Create the .gitignore file.
#######################################
crt_gitignore() {
  cat > .gitignore << EOF
.idea/
.vscode/
temp/
*.swp
*.log
.env
.venv
EOF
}

#######################################
# Perform initial git commands with error
# handling. Only commit if repository is not
# empty.
#######################################
git_steps() {
  git init
  git add .
  git diff --cached --quiet \
    || git -c commit.gpgsign=false commit -m "Initial project structure" \
    || { 
      echo "⚠️ Git commit failed (user.name / user.email not set)" >&2
      echo "💡 Can be fixed by running:" >&2
      echo "git config --global user.name 'Your Name'" >&2
      echo "git config --global user.email 'you@example.com'" >&2
    }
}

#######################################
# Launches main function.
# Arguments:
#   Script positional arguments.
# Returns:
#   Exit status.
#######################################
main() {
  # Handle positional arguments and pre-run checks.
  set_args "$@" || exit 1
  chk_dir || exit 1
  chk_deps curl git realpath

  # Create directories and files.
  crt_dir || exit 1
  cd "${project_dir}"
  mkdir -p "${SUBDIRS[@]}"
  dwl_templates
  crt_gitignore

  # Initialize repository.
  git_steps

  echo "✅ Project initialized successfully in '${project_dir}'"

  return 0
}

# Launch main function.
main "$@"
