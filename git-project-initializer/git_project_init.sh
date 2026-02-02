#!/usr/bin/env bash
#
# Git project initializer
# Created by OperaVaria
# lcs_it@proton.me
#
# Part of the "useful-bash-scripts" project:
# https://github.com/OperaVaria/useful-bash-scripts
# Version 1.0.0
#
# The script creates a boilerplate Git project directory by a simple press
# of a key.
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

# Set defaults:
project_dir="$(pwd -P)"

#######################################
# Function to handle run options.
# Arguments:
#   Script positional arguments.
# Returns:
#   Exit status.
#######################################
set_args() {
  local positional=()
  for arg in "$@"; do
    case "${arg}" in
      --help|-h)
        cat << EOF
Usage: git_project_init.sh [project_dir]

Creates a boilerplate Git project directory.

ARGUMENTS:
  project_dir        Target project directory
                     (default: current working directory)

OPTIONS:
  --help, -h         Show this help message
EOF
        exit 0
        ;;
      -*)
        echo "❌ Unknown option '${arg}'"
        echo "Use --help or -h for usage information"
        return 1
        ;;
      *) positional+=("${arg}") ;;
    esac
  done
  if [[ ${#positional[@]} -gt 1 ]]; then
    echo "❌ Too many positional arguments"
    return 1
  elif [[ ${#positional[@]} -eq 1 ]]; then
    project_dir="${positional[0]}"
  fi
  return 0
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
    echo "❌ Refusing to run in root directory"
    return 1
  elif [[ "${resolved}" == "${HOME}" ]]; then
    echo "❌ Refusing to run in home directory"
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
    echo "❌ Missing required commands: ${missing[*]}"
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
    echo "❌ '${project_dir}' exists but is not a directory"
    return 1
  elif [[ -d "${project_dir}" ]]; then
    echo "📁 '${project_dir}' already exists."
    conf_prompt "Create project in this directory?" || return 1
    return 0
  else
    mkdir -p "${project_dir}"
    return 0
  fi
}

#######################################
# Download template files with error handling.
#######################################
dwl_templates() {
  curl -sSLo COPYING.md \
    "https://raw.githubusercontent.com/IQAndreas/markdown-licenses/refs/heads/master/gnu-lgpl-v3.0.md" \
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
    || { echo "⚠️ Git commit failed (user.name / user.email not set)" >&2; }
}

#######################################
# Confirmation prompt.
# Arguments:
#   Prompt message string.
# Returns:
#   Exit status (0=yes, 1=no).
#######################################
conf_prompt() {
  local response
  [[ -t 0 ]] || return 1
  read -rp "$1 (Y/N): " response
  [[ "${response}" =~ ^[Yy]$ ]]
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
  mkdir -p bin docs src tests
  dwl_templates
  crt_gitignore

  # Initialize repository.
  git_steps

  return 0
}

# Launch main function.
main "$@"
