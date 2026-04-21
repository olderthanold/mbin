## 0ini execution tree (what is run)

This document describes the run order started by `0ini.sh`, including step numbering and script versions as printed by the scripts.

```text
0ini.sh v06
├─ [1/2] ini1sys_.sh v13
│  └─ ini1sys_.sh v13
│     ├─ resolves child scripts from: <repo>/initi/
│     ├─ 1.[1/7] ini2sys_update_inst.sh v05
│     │  └─ ini2sys_update_inst.sh v05
│     │     ├─ 1.[1/7].a apt_update_upgrade v05
│     │     └─ 1.[1/7].b install_mc v05
│     ├─ 1.[2/7] ini2sys_swap.sh v02
│     │  └─ ini2sys_swap.sh v02
│     ├─ 1.[3/7] ini2sys_ssh_passwd_auth.sh v05
│     │  └─ ini2sys_ssh_passwd_auth.sh
│     │     ├─ check_1_before: list non-commented hits/values for 3 directives
│     │     ├─ compliance_check: exit with no changes unless --force
│     │     ├─ enforce on /etc/ssh/sshd_config
│     │     ├─ enforce on /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
│     │     └─ check_2_after: list non-commented hits/values for 3 directives
│     ├─ 1.[4/7] ini2sys_paaswordles_sudo.sh v02
│     │  └─ ini2sys_paaswordles_sudo.sh v02
│     ├─ 1.[5/7] ini2sys_global_path_profile.sh v05
│     │  └─ ini2sys_global_path_profile.sh v05
│     ├─ 1.[6/7] ini2sys_network_iptables.sh v02
│     │  └─ ini2sys_network_iptables.sh v02
│     └─ 1.[7/7] ini2sys_network_connect.sh v02
│        └─ ini2sys_network_connect.sh v02
│           ├─ network_connect.[1/3] nginx_install_check v01
│           ├─ network_connect.[2/3] outbound_check v01
│           └─ network_connect.[3/3] http_https_check v01
└─ [2/2] inu1user.sh v07
   └─ inu1user.sh v07
      ├─ resolves child scripts from: <repo>/initi/
      └─ 2.[1/1] inu2_clone_user.sh v01
         └─ inu2_clone_user.sh v01
            (runs only when 0ini.sh is called with a target username)
```

## Notes

- `0ini.sh` always runs `ini1sys_.sh` first, then `inu1user.sh`.
- `inu2_clone_user.sh` is conditionally executed only if a username argument is passed to `0ini.sh`.
- Stage-2 init scripts are now stored under `initi/`.

## Shell scripts in this directory that are not used by 0ini flow

- `delete_cloned_user.sh` — removes a cloned user account safely, with guardrails (`--force`, `--dry-run`, sudo-member safety check).
- `delete_website.sh` — removes Nginx site entry and cert artifacts for a domain, leaving web content untouched.
- `web1_entry_nginx.sh` — creates Nginx site entry for a domain and web root.
- `web1_cert_nginx.sh` — obtains/tests auto-renewable certbot certificate for Nginx.
- `0web.sh` — wrapper that runs web cert + web entry workflow.