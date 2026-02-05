# Useful Bash Scripts

A set of miscellaneous Bash shell scripts which are mainly centered around task automation.

## Usage

```bash
chmod +x script_file.sh
./script_file.sh
```

Access help by typing:

```bash
./script_file.sh -h
```

or

```bash
./script_file.sh --help
```

## Scripts

### git-project-initializer

Creates a boilerplate Git project repository by executing the following steps:

- Create project directory
- Create recommended subdirectories
- Create license, readme, changelog, and gitignore template files
- Initialize Git repository

The markdown templates are downloaded from the following repositories:

- Licenses: [IQAndreas/markdown-licenses](https://github.com/IQAndreas/markdown-licenses) - Unlicense
- Readme: [me-and-company/readme-template](https://github.com/me-and-company/readme-template) - MIT
- Changelog: [olivierlacan/keep-a-changelog](https://github.com/olivierlacan/keep-a-changelog) - MIT

Currently supported licenses **(default: gnu-gpl-v3.0)**:

- artistic-v2.0, bsd-2, bsd-3, epl-v1.0, gnu-agpl-v3.0,
gnu-fdl-v1.3, gnu-gpl-v1.0, gnu-gpl-v2.0, gnu-gpl-v3.0, gnu-lgpl-v2.1,
gnu-lgpl-v3.0, mit, mpl-v2.0, unlicense

These can be selected via the -l or --license command line option, such as:

```bash
./git_project-init.sh -l mit
```

### rclone-automount

Helps the Linux user to automate mounting cloud storages via the [rclone](https://rclone.org/) command line application.
All configuration is handled by the included [.conf file](/rclone-automount/automount.conf).
It is recommended to be run as an autostart script (see bellow).

### script-autostart

Sets a shell script to autostart on user login.

### smart-cleanup

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

### unified-extractor

Unifies the different archive extracting commands into a single one for convenient use.
Recommended to be copied to /usr/local/bin to make an "extract" command available at all times.
This can be done by executing:

```bash
./git_project-init.sh -a
```

or

```bash
./git_project-init.sh --add
```

Currently supported archive formats: **7z, bzip2, gzip, rar, tar, xz, zip, zstd.**

## Other

The coding format of the scripts adhere to the [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html).

**Tested on:** CachyOS, GNU bash, 5.3.9(1)-release, and MX Linux 23.5, GNU bash, 5.2.15(1)-release.

---

**[Contact](mailto:lcs_it@proton.me)**

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
