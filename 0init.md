## 0init execution tree (what is run)

This document describes the run order started by `0init.sh`, including step numbering and script versions as printed by the scripts.

```text
0init.sh v03
├─ [1/2] initinst.sh v11
│  └─ initinst.sh v11
│     ├─ 1.[1/6] update_inst.sh v03
│     │  └─ update_inst.sh v03
│     │     ├─ 1.[1/6].a apt_update_upgrade v03
│     │     └─ 1.[1/6].b install_mc v03
│     ├─ 1.[2/6] ssh_passwd_auth.sh v02
│     │  └─ ssh_passwd_auth.sh
│     │     ├─ check_1_before: list non-commented hits/values for 3 directives
│     │     ├─ compliance_check: exit with no changes unless --force
│     │     ├─ enforce on /etc/ssh/sshd_config
│     │     ├─ enforce on /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
│     │     └─ check_2_after: list non-commented hits/values for 3 directives
│     ├─ 1.[3/6] paaswordles_sudo.sh v01
│     │  └─ paaswordles_sudo.sh v01
│     ├─ 1.[4/6] global_path_profile.sh v04
│     │  └─ global_path_profile.sh v04
│     ├─ 1.[5/6] network_iptables.sh v01
│     │  └─ network_iptables.sh v01
│     └─ 1.[6/6] network_connect.sh v01
│        └─ network_connect.sh v01
│           ├─ network_connect.[1/3] nginx_install_check v01
│           ├─ network_connect.[2/3] outbound_check v01
│           └─ network_connect.[3/3] http_https_check v01
└─ [2/2] initusr.sh v05
   └─ initusr.sh v05
      └─ 2.[1/1] clone_user.sh v02
         └─ clone_user.sh v01
            (runs only when 0init.sh is called with a target username)
```

## Notes

- `0init.sh` always runs `initinst.sh` first, then `initusr.sh`.
- `clone_user.sh` is conditionally executed only if a username argument is passed to `0init.sh`.
- Some banner versions printed by parent scripts (`v02`) differ from the called script internal banner (`v01`); tree keeps both so runtime output and file content are both visible.

## Shell scripts in this directory that are not used by 0init flow

- `create_nginx_website.sh` — creates and enables a dedicated Nginx site config for a fixed domain and suggests running certbot.
- `delete_cloned_user.sh` — removes a cloned user account safely, with guardrails (`--force`, `--dry-run`, sudo-member safety check).
- `git_mbin.sh` — updates `/opt/mbin` via git pull, and if pull fails, recreates repository by fresh clone.
- `mbin_path.sh` — legacy per-user mbin path helper (superseded by global `/etc/profile.d/mbin.sh`).
- `testm.sh` — minimal test script that prints `test passed`.
- `web_entry_nginx.sh` — creates Nginx site entry for a domain and web root.
- `web_cert_nginx.sh` — obtains/tests auto-renewable certbot certificate for Nginx.
- `web_cleanup.sh` — removes Nginx site entry and cert artifacts for a domain, leaving web content untouched.
- `0web.sh` — wrapper that runs web cert + web entry workflow.