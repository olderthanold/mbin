## 0init execution tree (what is run)

This document describes the run order started by `0init.sh`, including step numbering and script versions as printed by the scripts.

```text
0init.sh v03
├─ [1/2] initinst.sh v05
│  └─ initinst.sh v05
│     ├─ 1.[1/5] update_inst.sh v03
│     │  └─ update_inst.sh v03
│     │     ├─ 1.[1/4].a apt_update_upgrade v03
│     │     └─ 1.[1/4].b install_mc v03
│     ├─ 1.[2/5] ssh_passwd_auth.sh v02
│     │  └─ ssh_passwd_auth.sh
│     │     ├─ check_1_before: list non-commented hits/values for 3 directives
│     │     ├─ compliance_check: exit with no changes unless --force
│     │     ├─ enforce on /etc/ssh/sshd_config
│     │     ├─ enforce on /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
│     │     └─ check_2_after: list non-commented hits/values for 3 directives
│     ├─ 1.[3/5] network.sh v02
│     │  └─ network.sh v02
│     │     ├─ 1.[3/4].a nginx_install v01
│     │     ├─ 1.[3/4].b iptables_config v01
│     │     ├─ 1.[3/4].c outbound_check v01
│     │     └─ 1.[3/4].d http_https_check v01
│     ├─ 1.[4/5] root_path_bashrc.sh v01
│     │  └─ root_path_bashrc.sh v01
│     └─ 1.[5/5] root_path_sudoers.sh v01
│        └─ root_path_sudoers.sh v01
└─ [2/2] initusr.sh v04
   └─ initusr.sh v04
      ├─ 2.[1/2] mbin_path.sh v02
      │  └─ mbin_path.sh v01
      └─ 2.[2/2] clone_user.sh v02
         └─ clone_user.sh v01
            (runs only when 0init.sh is called with a target username)
```

## Notes

- `0init.sh` always runs `initinst.sh` first, then `initusr.sh`.
- `clone_user.sh` is conditionally executed only if a username argument is passed to `0init.sh`.
- Some banner versions printed by parent scripts (`v02`) differ from the called script internal banner (`v01`); tree keeps both so runtime output and file content are both visible.