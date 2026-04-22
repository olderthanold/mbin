## 0web execution tree (what is run)

This document describes the run order started by `0web.sh`, including step numbering and script versions as printed by the scripts.

```text
0web.sh v10
├─ Args: <domain> [web_root]
│  ├─ domain is required and must contain "."
│  ├─ -h|--help prints usage and exits
│  └─ child scripts are resolved from webi subdir of 0web.sh location
├─ [1/4] webi/web1_webs.sh v06
│  └─ web1_webs.sh v06
│     ├─ [1/3] Ensure /webs exists
│     ├─ [2/3] Set /webs owner to www-data:www-data
│     └─ [3/3] Set /webs permissions to 777
├─ [2/4] webi/web1_webroot.sh v02
│  └─ web1_webroot.sh v02
│     ├─ resolve web root from arg2:
│     │  ├─ absolute path => use as-is
│     │  ├─ relative value => /webs/<value>
│     │  └─ omitted => /webs/<domain>
│     ├─ if web root exists: leave as-is (do not repopulate content)
│     ├─ if missing: create web root
│     ├─ only for newly created root, if no index.htm/index.html:
│     │  ├─ prefer copy from webi/index.htm
│     │  └─ fallback to /var/www/html/index.nginx-debian.html + personalize heading
│     └─ ensure web root ownership
├─ [3/4] webi/web1_cert_nginx.sh v04
│  └─ web1_cert_nginx.sh v04
│     ├─ [1/5] Ensure certbot + python3-certbot-nginx installed
│     ├─ [2/5] Check existing cert files for domain
│     │  └─ if missing: request cert via certbot --nginx (with retry wrapper)
│     ├─ [3/5] Test nginx configuration (nginx -t)
│     ├─ [4/5] Enable/start certbot.timer
│     └─ [5/5] Test cert renewal (certbot renew --dry-run, with retries)
└─ [4/4] webi/web1_entry_nginx.sh v14
   └─ web1_entry_nginx.sh v14
      ├─ resolve domain + web root (same rules as web1_webroot.sh)
      ├─ autoheal: remove old /etc/nginx/sites-enabled/<domain>
      ├─ autoheal: remove old /etc/nginx/sites-available/<domain>
      ├─ write fresh /etc/nginx/sites-available/<domain>
      ├─ recreate /etc/nginx/sites-enabled/<domain> symlink
      ├─ remove default enabled nginx site link if present
      └─ nginx -t + systemctl reload nginx
```

## Notes

- `0web.sh` prints resolved child script paths and detected versions before running steps.
- Web-root ensure/init is centralized in `web1_webroot.sh` (no duplicate creation in `web1_webs.sh` and `web1_entry_nginx.sh`).
- `web1_webs.sh`, `web1_webroot.sh`, and `web1_cert_nginx.sh` require root.
- `web1_entry_nginx.sh` uses `sudo` commands internally.

## Shell scripts in this directory that are not used by 0web flow

- `0ini.sh` and `ini*` / `init_*` scripts — system/user initialization flow.
- `delete_website.sh` — removes Nginx + cert artifacts for a domain.
- `delete_cloned_user.sh` — removes cloned user account with safety checks.
- `mgit_http.sh`, `mgit_ssh.sh`, `mgit_https.sh` — git helper/update scripts.
- `mstats.sh`, `mtest.sh` — utility/testing scripts.
