## 0web execution tree (what is run)

This document describes the run order started by `0web.sh`, including step numbering and script versions as printed by the scripts.

```text
0web.sh v13
|-- Args: <domain> [web_root]
|   |-- domain is required and must contain "."
|   |-- -h|--help prints usage and exits
|   |-- default web base is /m/webs
|   `-- child scripts are resolved from webi subdir of 0web.sh location
|-- [1/6] webi/web1_webs.sh v09
|   `-- web1_webs.sh v09
|       |-- ensure /m exists and is traversable (755)
|       |-- ensure /m/webs exists
|       |-- ensure deploy user is in group www-data
|       |-- set /m/webs owner/group to <deploy_user>:www-data
|       `-- set /m/webs permissions to 2775
|-- [2/6] webi/web1_webroot.sh v05
|   `-- web1_webroot.sh v05
|       |-- resolve web root from arg2:
|       |   |-- absolute path => use as-is
|       |   |-- relative value => /m/webs/<value>
|       |   `-- omitted => /m/webs/<domain>
|       |-- if web root exists: leave as-is (do not repopulate content)
|       |-- if missing: create web root as <deploy_user>:www-data with 2755
|       |-- for newly created roots: copy full repo llmweb/ content into web root
|       |-- fallback only when llmweb/ is unavailable:
|       |   |-- prefer copy from webi/index.htm
|       |   `-- fallback to /var/www/html/index.nginx-debian.html + personalize heading
|       `-- ensure newly created web root ownership
|-- [3/6] webi/web1_adapt_index.sh v01
|   `-- web1_adapt_index.sh v01
|       |-- resolve web root from arg2 using the same rules
|       |-- update target web root index.htm only
|       |-- set <title> to domain prefix before first dot
|       `-- set <h1 id="page-title"> to <domain> - <public IP> - <private IP>
|-- [4/6] webi/web1_entry_nginx.sh v16
|   `-- web1_entry_nginx.sh v16
|       |-- if certificate is missing: write HTTP-only server block for certbot
|       `-- if certificate exists: write final HTTP redirect + HTTPS server block
|-- [5/6] webi/web1_cert_nginx.sh v04
|   `-- web1_cert_nginx.sh v04
|       |-- [1/5] Ensure certbot + python3-certbot-nginx installed
|       |-- [2/5] Check existing cert files for domain
|       |   `-- if missing: request cert via certbot --nginx (with retry wrapper)
|       |-- [3/5] Test nginx configuration (nginx -t)
|       |-- [4/5] Enable/start certbot.timer
|       `-- [5/5] Test cert renewal (certbot renew --dry-run, with retries)
`-- [6/6] webi/web1_entry_nginx.sh v16
    `-- web1_entry_nginx.sh v16
        |-- recreate domain Nginx entry after certbot has run
        `-- expected final state: HTTP redirect + HTTPS server block
```

## Notes

- `0web.sh` prints resolved child script paths and detected versions before running steps.
- Web-root ensure/init is centralized in `web1_webroot.sh`.
- `web1_webroot.sh` copies the whole `llmweb/` directory only for newly created web roots.
- `web1_adapt_index.sh` edits the copied target `index.htm`, not the repo template in `llmweb/`.
- `WEB_BASE_DIR` can override the default `/m/webs`.
- `web1_webs.sh`, `web1_webroot.sh`, `web1_adapt_index.sh`, and `web1_cert_nginx.sh` require root.
- `web1_entry_nginx.sh` uses `sudo` commands internally.

## Shell scripts in this directory that are not used by 0web flow

- `0ini.sh` and `ini*` / `init_*` scripts - system/user initialization flow.
- `delete_website.sh` - removes Nginx + cert artifacts for a domain.
- `delete_cloned_user.sh` - removes cloned user account with safety checks.
- `mgit_ssh.sh`, `mgit_https.sh`, `mgit_oldssh.sh`, `mgit_oldhttps.sh` - git helper/update scripts.
- `symlink_m.sh` - creates `/m` layout and compatibility symlinks for legacy paths.
- `mstats.sh`, `mtest.sh` - utility/testing scripts.
