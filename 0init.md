## init_0_main execution tree (what is run)

This document describes the run order started by `init_0_main.sh`, including step numbering and script versions as printed by the scripts.

```text
init_0_main.sh v03
├─ [1/2] init_1_system.sh v11
│  └─ init_1_system.sh v11
│     ├─ 1.[1/6] init_2_system_update_inst.sh v03
│     │  └─ init_2_system_update_inst.sh v03
│     │     ├─ 1.[1/6].a apt_update_upgrade v03
│     │     └─ 1.[1/6].b install_mc v03
│     ├─ 1.[2/6] init_2_system_ssh_passwd_auth.sh v04
│     │  └─ init_2_system_ssh_passwd_auth.sh
│     │     ├─ check_1_before: list non-commented hits/values for 3 directives
│     │     ├─ compliance_check: exit with no changes unless --force
│     │     ├─ enforce on /etc/ssh/sshd_config
│     │     ├─ enforce on /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
│     │     └─ check_2_after: list non-commented hits/values for 3 directives
│     ├─ 1.[3/6] init_2_system_paaswordles_sudo.sh v01
│     │  └─ init_2_system_paaswordles_sudo.sh v01
│     ├─ 1.[4/6] init_2_system_global_path_profile.sh v04
│     │  └─ init_2_system_global_path_profile.sh v04
│     ├─ 1.[5/6] init_2_system_network_iptables.sh v01
│     │  └─ init_2_system_network_iptables.sh v01
│     └─ 1.[6/6] init_2_system_network_connect.sh v01
│        └─ init_2_system_network_connect.sh v01
│           ├─ network_connect.[1/3] nginx_install_check v01
│           ├─ network_connect.[2/3] outbound_check v01
│           └─ network_connect.[3/3] http_https_check v01
└─ [2/2] init_1_user.sh v05
   └─ init_1_user.sh v05
      └─ 2.[1/1] init_2_user_clone_user.sh v02
         └─ init_2_user_clone_user.sh v01
            (runs only when init_0_main.sh is called with a target username)
```

## Notes

- `init_0_main.sh` always runs `init_1_system.sh` first, then `init_1_user.sh`.
- `init_2_user_clone_user.sh` is conditionally executed only if a username argument is passed to `init_0_main.sh`.
- Some banner versions printed by parent scripts (`v02`) differ from the called script internal banner (`v01`); tree keeps both so runtime output and file content are both visible.

## Shell scripts in this directory that are not used by init_0_main flow

- `create_nginx_website.sh` — creates and enables a dedicated Nginx site config for a fixed domain and suggests running certbot.
- `delete_cloned_user.sh` — removes a cloned user account safely, with guardrails (`--force`, `--dry-run`, sudo-member safety check).
- `git_mbin.sh` — updates `/opt/mbin` via git pull, and if pull fails, recreates repository by fresh clone.
- `mbin_path.sh` — legacy per-user mbin path helper (superseded by global `/etc/profile.d/mbin.sh`).
- `testm.sh` — minimal test script that prints `test passed`.
- `web_1_entry_nginx.sh` — creates Nginx site entry for a domain and web root.
- `web_1_cert_nginx.sh` — obtains/tests auto-renewable certbot certificate for Nginx.
- `delete_website.sh` — removes Nginx site entry and cert artifacts for a domain, leaving web content untouched.
- `web_0_main.sh` — wrapper that runs web cert + web entry workflow.