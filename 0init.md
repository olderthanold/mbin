## 0init execution tree (what is run)

This document describes the run order started by `0init.sh`, including step numbering and script versions as printed by the scripts.

```text
0init.sh v03
├─ [1/2] initinst.sh v04
│  └─ initinst.sh v04
│     ├─ 1.[1/4] update_inst.sh v03
│     │  └─ update_inst.sh v03
│     │     ├─ 1.[1/4].a apt_update_upgrade v03
│     │     └─ 1.[1/4].b install_mc v03
│     ├─ 1.[2/4] ssh_passwd_auth.sh v02
│     │  └─ ssh_passwd_auth.sh
│     │     ├─ 1.[2/4].a write_override v03
│     │     ├─ 1.[2/4].a write_fallback v03 (only if fallback block missing)
│     │     ├─ 1.[2/4].b validate_sshd v03
│     │     └─ 1.[2/4].c verify_effective_settings v03
│     ├─ 1.[3/4] network.sh v02
│     │  └─ network.sh v02
│     │     ├─ 1.[3/4].a nginx_install v01
│     │     ├─ 1.[3/4].b iptables_config v01
│     │     ├─ 1.[3/4].c outbound_check v01
│     │     └─ 1.[3/4].d http_https_check v01
│     └─ 1.[4/4] root_path_bashrc.sh v01
│        └─ root_path_bashrc.sh v01
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