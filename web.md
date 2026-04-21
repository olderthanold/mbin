## 0web execution tree (what is run)

This document describes the run order started by `0web.sh`, including step numbering and script versions as printed by the scripts.

```text
0web.sh v07
├─ Args: <domain> [web_root]
│  ├─ domain is required and must contain "."
│  ├─ -h|--help prints usage and exits
│  └─ child scripts are resolved from ./webi (relative to run directory)
├─ [1/3] webi/web1_webs.sh v05
│  └─ web1_webs.sh v05
│     ├─ [1/6] Ensuring directory exists: /webs
│     ├─ [2/6] Setting owner: www-data:www-data /webs
│     ├─ [3/6] Setting permissions: chmod 777 /webs
│     ├─ [4/6] Ensuring website directory exists: /webs/<domain>
│     ├─ [5/6] If /webs/<domain> has no index.htm and no index.html,
│     │        copy template from webi/index.htm -> /webs/<domain>/index.htm
│     └─ [6/6] Ensuring website directory owner: www-data:www-data
├─ [2/3] webi/web1_cert_nginx.sh v04
│  └─ web1_cert_nginx.sh v04
│     ├─ [1/5] Ensure certbot + python3-certbot-nginx installed
│     ├─ [2/5] Check existing cert files for domain
│     │  └─ if missing: request cert via certbot --nginx (with retry wrapper)
│     ├─ [3/5] Test nginx configuration (nginx -t)
│     ├─ [4/5] Enable/start certbot.timer
│     └─ [5/5] Test cert renewal (certbot renew --dry-run, with retries)
└─ [3/3] webi/web1_entry_nginx.sh v11
   └─ web1_entry_nginx.sh v11
      ├─ resolve domain + web root
      │  ├─ if 0web called with web_root: pass it through
      │  └─ else default to /webs/<domain>
      ├─ idempotency check: if /etc/nginx/sites-available/<domain> exists, exit
      ├─ create web root if missing (owner/perm set)
      ├─ if web root was newly created, seed default index.htm from nginx template
      ├─ write /etc/nginx/sites-available/<domain>
      ├─ enable site in /etc/nginx/sites-enabled/<domain>
      ├─ remove default enabled nginx site link if present
      └─ nginx -t + systemctl reload nginx
```

## Notes

- `0web.sh` requires at least one meaningful argument: a domain containing `.`.
- `0web.sh` executes child scripts from `./webi` relative to the directory where `0web.sh` is run.
- `web1_webs.sh` and `web1_cert_nginx.sh` require root; `web1_entry_nginx.sh` uses `sudo` commands internally.

## Shell scripts in this directory that are not used by 0web flow

- `0ini.sh` and `ini*` / `init_*` scripts — system/user initialization flow.
- `delete_website.sh` — removes Nginx + cert artifacts for a domain.
- `delete_cloned_user.sh` — removes cloned user account with safety checks.
- `mgit_http.sh`, `mgit_ssh.sh`, `mgit_web.sh` — git helper/update scripts.
- `mstats.sh`, `mtest.sh` — utility/testing scripts.
