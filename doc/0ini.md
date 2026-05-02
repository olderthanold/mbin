## 0ini execution tree (what is run)

This document describes the run order started by `0ini.sh`, including step numbering and script versions as printed by the scripts.

## Usage

```bash
sudo bash /m/mbin/0ini.sh [target_user]
```

- `target_user` is optional.
- When `target_user` is omitted, the user-clone step is skipped.
- When `target_user` is provided, `inu1user.sh` creates that user if missing, then passes it to `mgit_https.sh` as `-n <target_user>`.

## Examples

```bash
# Run server-level setup and user-level repository refresh only.
sudo bash /m/mbin/0ini.sh

# Run setup, clone/create user "emp", then refresh /m/mbin with extra group sync for emp.
sudo bash /m/mbin/0ini.sh emp
```

```text
0ini.sh v07
|-- requires root (use sudo)
|-- Args: [target_user]
|   `-- optional target username is passed to inu1user.sh
|-- resolves child scripts next to 0ini.sh
|-- [1/2] ini1sys.sh v15
|   `-- ini1sys.sh v15
|       |-- requires root (use sudo)
|       |-- resolves child scripts from: <repo>/initi/
|       |-- 1.[1/7] ini2sys_update_inst.sh v05
|       |   |-- apt-get update
|       |   |-- apt-get upgrade -y
|       |   `-- install mc only when missing, then verify package is installed
|       |-- 1.[2/7] ini2sys_swap.sh v02
|       |   |-- create /swapfile as 5G only when not already active
|       |   |-- chmod 600, mkswap, swapon
|       |   |-- persist exact fstab row when missing
|       |   `-- verify with swapon --show and free -h
|       |-- 1.[3/7] ini2sys_ssh_passwd_auth.sh v05
|       |   |-- target /etc/ssh/sshd_config
|       |   |-- target /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
|       |   |-- enforce PasswordAuthentication yes
|       |   |-- enforce KbdInteractiveAuthentication yes
|       |   |-- enforce UsePAM yes
|       |   |-- create missing drop-in file when needed
|       |   |-- create backups before edits and validate with sshd -t
|       |   `-- exit early when both files are already compliant unless --force is used
|       |-- 1.[4/7] ini2sys_paaswordles_sudo.sh v02
|       |   |-- scan /etc/sudoers.d for non-commented %sudo NOPASSWD rule
|       |   |-- append to lexicographically last *mmm file when available
|       |   |-- otherwise create <last_sudoers_filename>mmm or 99-sudo-nopasswdmmm
|       |   `-- chmod 440 and validate drop-in with visudo
|       |-- 1.[5/7] ini2sys_global_path_profile.sh v06
|       |   |-- ensure /m/mbin exists with 755
|       |   |-- write /etc/profile.d/mbin.sh for login shells
|       |   |-- normalize /root/.bashrc mbin PATH line
|       |   |-- reuse passwordless-sudo drop-in file
|       |   `-- normalize sudo secure_path to include /m/mbin
|       |-- 1.[6/7] ini2sys_network_iptables.sh v04
|       |   |-- install ufw with apt-lock retry
|       |   |-- set UFW defaults: reject incoming, allow outgoing
|       |   |-- allow 22/tcp, 80/tcp, and 443/tcp
|       |   |-- enable UFW and remove old legacy INPUT rules
|       |   |-- set OUTPUT policy ACCEPT
|       |   `-- print final iptables and UFW status
|       `-- 1.[7/7] ini2sys_network_connect.sh v03
|           |-- install/check nginx and enable/start service
|           |-- test outbound connectivity, DNS, route, and public IP lookup
|           |-- test HTTP/80 and HTTPS/443 reachability by public IP
|           |-- attempt default-site HTTP repair when needed
|           `-- attempt HTTPS snakeoil/default-site repair when needed
`-- [2/2] inu1user.sh v08
    `-- inu1user.sh v08
        |-- requires root (use sudo)
        |-- resolves child scripts from: <repo>/initi/
        |-- resolves current user from SUDO_USER/logname, fallback ubuntu
        |-- 2.[1/2] inu2_clone_user.sh v01
        |   |-- runs only when 0ini.sh is called with a target username
        |   |-- skipped by inu1user.sh when target user already exists
        |   `-- otherwise clone source user home, sudo membership, and SSH authorized_keys
        `-- 2.[2/2] mgit_https.sh v09
            |-- refresh local repository via HTTPS, default target /m/mbin
            |-- if target username was provided: pass -n <target_user>
            |-- resolve relative local paths under HOME and aliases to GitHub HTTPS URLs
            |-- check/prepare parent and target write permissions
            |-- sync sudo caller and optional -n user into parent/target groups when run under sudo
            |-- clone main when target is not a git repo
            |-- pull main when target is an existing git repo
            |-- on pull failure: stash local changes, try pull --rebase, then fallback recreate+clone
            |-- normalize ownership/permissions pre/post git
            `-- restore executable permission on top-level *.sh files
```

## Notes

- `0ini.sh` always runs `ini1sys.sh` first, then `inu1user.sh`.
- `0ini.sh`, `ini1sys.sh`, and `inu1user.sh` require root/sudo.
- `inu2_clone_user.sh` is conditionally executed only if a username argument is passed to `0ini.sh`.
- If the requested target user already exists, `inu1user.sh` skips the clone step for idempotency.
- `mgit_https.sh` is the final `inu1user.sh` step.
- When a target username is provided to `0ini.sh`, `inu1user.sh` passes it to `mgit_https.sh` as `-n <target_user>` for extra group sync checks.
- Stage-2 init scripts are stored under `initi/`.
- `ini2sys_global_path_profile.sh` expects the passwordless sudo drop-in from `ini2sys_paaswordles_sudo.sh` to exist first.
- Most stages are designed to be safe to re-run where possible, with guarded appends/checks before changing persistent config.

## Selected shell scripts in this directory that are not used by 0ini flow

- `delete_cloned_user.sh` - removes a cloned user account safely, with guardrails (`--force`, `--dry-run`, sudo-member safety check).
- `delete_website.sh` - removes Nginx site entry and cert artifacts for a domain, leaving web content untouched.
- `0web.sh` - wrapper that runs web root + cert + Nginx entry workflow under `/m/webs`.
- `symlink_m.sh` - creates `/m` layout and compatibility symlinks for legacy paths.
