# Useful Bash Scripts

A set of miscellaneous Bash shell scripts to be used on a Linux system, mainly centered around task automation. The coding format of the scripts adhere to the [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html).

**Uploading in progress**

## rclone-automount

Helps the Linux user to automate mounting cloud storages via the [rclone](https://rclone.org/) command line application.
It is recommended to be used as a startup script. All configuration is handled by the included .conf file.

## smart-cleanup

Performs an automated system cleanup on a Linux system.
The following steps can be executed: cleaning the cache directory, emptying the Trash, removing old temp and logs files, vacuuming the journals, clearing the pacman cache, and checking for orphaned packages.
The severity of the cleanup (normal or "aggressive" level) can be set by command line arguments.
The script can only properly run with sudo privileges. Both an Arch and a Debian version is available.

## git-project-initializer

The script creates a boilerplate Git project directory by executing the following steps:
create directory, create recommended subdirectories, create license, readme, changelog, and gitignore template files, initialize Git repository.
It supports a wide range of licenses that can be selected via a command line argument (default: gnu-gpl-v3.0).

---

**Tested on:** CachyOS, GNU bash, 5.3.9(1)-release, and MX Linux 23.5, GNU bash, 5.2.15(1)-release.

---

**[Contact](mailto:lcs_it@proton.me)**

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
