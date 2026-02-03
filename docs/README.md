# Useful Bash Scripts

A set of miscellaneous Bash shell scripts which are mainly centered around task automation.

## rclone-automount

Helps the Linux user to automate mounting cloud storages via the [rclone](https://rclone.org/) command line application.
It is recommended to be used as a startup script. All configuration is handled by the included .conf file.

## smart-cleanup

Performs an automated system cleanup on Linux OSs.
The following steps can be executed:

- Cleaning the cache directory
- Emptying the Trash
- Removing older temp and logs files
- Vacuuming the journals
- Clearing the package manager cache
- Checking for orphaned packages

The severity of the cleanup ("normal" or "aggressive" level) can be set by command line arguments (none or -a|--aggressive).
Both Arch and Debian versions are available. The script requires sudo privileges to run properly.

## git-project-initializer

Creates a boilerplate Git project repository by executing the following steps:

- Create project directory
- Create recommended subdirectories
- Create license, readme, changelog, and gitignore template files
- Initialize Git repository

It supports a wide range of licenses which can be selected via command line arguments (default: gnu-gpl-v3.0).

The markdown templates are downloaded from the following repositories:

- Licenses: [IQAndreas/markdown-licenses](https://github.com/IQAndreas/markdown-licenses) - Unlicense
- Readme: [me-and-company/readme-template](https://github.com/me-and-company/readme-template) - MIT
- Changelog: [olivierlacan/keep-a-changelog](https://github.com/olivierlacan/keep-a-changelog) - MIT

## unified-extractor

Unifies the different archive extracting commands into a single one for convenient use.
Recommended to be copied manually or by the attached script (add_to_bin.sh) to /usr/local/bin/ to enable the "extract" command in the shell.

Currently supported archive formats: **7z, bzip2, gzip, rar, tar, xz, zip, zstd.**

---
The coding format of the scripts adhere to the [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html).

**Tested on:** CachyOS, GNU bash, 5.3.9(1)-release, and MX Linux 23.5, GNU bash, 5.2.15(1)-release.

---

**[Contact](mailto:lcs_it@proton.me)**

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
