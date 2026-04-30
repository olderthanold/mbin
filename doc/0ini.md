## 0ini execution tree (what is run)

This document describes the run order started by `0ini.sh`, including step numbering and script versions as printed by the scripts.

```text
0ini.sh v07
|-- [1/2] ini1sys.sh v15
|   `-- ini1sys.sh v15
|       |-- resolves child scripts from: <repo>/initi/
|       |-- 1.[1/7] ini2sys_update_inst.sh v05
|       |   `-- apt update/upgrade and install mc
|       |-- 1.[2/7] ini2sys_swap.sh v02
|       |   `-- create/enable 5G swap and persist in fstab
|       |-- 1.[3/7] ini2sys_ssh_passwd_auth.sh v05
|       |   `-- enable SSH password + keyboard-interactive auth (PAM)
|       |-- 1.[4/7] ini2sys_paaswordles_sudo.sh v02
|       |   `-- ensure %sudo has NOPASSWD rule
|       |-- 1.[5/7] ini2sys_global_path_profile.sh v06
|       |   `-- configure /m/mbin in user/root/sudo PATH
|       |-- 1.[6/7] ini2sys_network_iptables.sh v04
|       |   `-- configure UFW firewall
|       `-- 1.[7/7] ini2sys_network_connect.sh v03
|           `-- install/check nginx and run connectivity checks
`-- [2/2] inu1user.sh v08
    `-- inu1user.sh v08
        |-- resolves child scripts from: <repo>/initi/
        |-- 2.[1/2] inu2_clone_user.sh v01
        |   `-- runs only when 0ini.sh is called with a target username
        `-- 2.[2/2] mgit_https.sh v08
            `-- refresh local repository via HTTPS, default target /m/mbin
```

## Notes

- `0ini.sh` always runs `ini1sys.sh` first, then `inu1user.sh`.
- `inu2_clone_user.sh` is conditionally executed only if a username argument is passed to `0ini.sh`.
- `mgit_https.sh` is the final `inu1user.sh` step.
- Stage-2 init scripts are stored under `initi/`.

## Shell scripts in this directory that are not used by 0ini flow

- `delete_cloned_user.sh` - removes a cloned user account safely, with guardrails (`--force`, `--dry-run`, sudo-member safety check).
- `delete_website.sh` - removes Nginx site entry and cert artifacts for a domain, leaving web content untouched.
- `0web.sh` - wrapper that runs web root + cert + Nginx entry workflow under `/m/webs`.
- `symlink_m.sh` - creates `/m` layout and compatibility symlinks for legacy paths.
