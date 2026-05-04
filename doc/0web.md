## 0web execution tree (what is run)

This document describes the run order started by `0web.sh`, including step numbering and script versions as printed by the scripts.

## Usage

```bash
sudo bash /m/mbin/0web.sh <domain> [web_root]
```

- `domain` is required and must contain `.`.
- `web_root` is optional.
- If `web_root` is omitted, it defaults to the domain prefix before the first dot.
- The omitted-default target path is `${WEB_BASE_DIR:-/m/webs}/<domain_prefix>`.
- If `web_root` is relative, it resolves under `${WEB_BASE_DIR:-/m/webs}`.
- If `web_root` is absolute, it is used as-is.

## Examples

```bash
# Create/update website for a domain using the default web root: /m/webs/example.
sudo bash /m/mbin/0web.sh example.com

# Create/update website for a domain using relative web root: /m/webs/example.
sudo bash /m/mbin/0web.sh example.com example

# Create/update website for a domain using an absolute web root.
sudo bash /m/mbin/0web.sh example.com /m/webs/example.com

# Use a custom web base for relative/default web roots.
sudo WEB_BASE_DIR=/srv/webs bash /m/mbin/0web.sh example.com example
```

```text
0web.sh v13
|-- Args: <domain> [web_root]
|   |-- domain is required and must contain "."
|   |-- -h|--help prints usage and exits
|   |-- if web_root is omitted: defaults to domain prefix before first dot
|   |-- default web base is /m/webs (override with WEB_BASE_DIR)
|   `-- child scripts are resolved from webi subdir of 0web.sh location
|-- [1/6] webi/web1_webs.sh v10
|   `-- web1_webs.sh v10
|       |-- ensure base dir exists and is traversable: ${M_BASE_DIR:-/m} (755)
|       |-- ensure web base exists: ${WEB_BASE_DIR:-/m/webs}
|       |-- create group www-data if missing
|       |-- ensure deploy user is in group www-data (skip membership change for root)
|       |-- set web base owner/group to <deploy_user_or_root>:www-data
|       `-- set web base permissions to 2775
|-- [2/6] webi/web1_webroot.sh v07
|   `-- web1_webroot.sh v07
|       |-- resolve web root from arg2:
|       |   |-- absolute path => use as-is
|       |   |-- relative value => ${WEB_BASE_DIR:-/m/webs}/<value>
|       |   `-- omitted by caller => 0web.sh passes <domain_prefix>, resolving to ${WEB_BASE_DIR:-/m/webs}/<domain_prefix>
|       |-- if web root exists: leave as-is (do not repopulate content)
|       |-- if missing: create web root as <deploy_user>:www-data with 2755
|       |-- for newly created roots: copy full repo llmweb/ content into web root
|       |-- after llmweb copy: set dirs to 2755 and files to 644
|       |-- fallback only when llmweb/ is unavailable:
|       |   |-- fallback to /var/www/html/index.nginx-debian.html + personalize heading
|       |   `-- if no template exists: skip index init with warning
|       `-- ensure newly created web root ownership
|-- [3/6] webi/web1_adapt_index.sh v01
|   `-- web1_adapt_index.sh v01
|       |-- resolve web root from arg2 using the same rules
|       |-- update target web root index.htm only
|       |-- error if target index.htm is missing
|       |-- refuse to adapt repo source template directory llmweb/ directly
|       |-- set <title> to domain prefix before first dot
|       `-- set or insert <h1 id="page-title"> to <domain> - <public IP> - <private IP>
|-- [4/6] webi/web1_entry_nginx.sh v18
|   `-- web1_entry_nginx.sh v18
|       |-- autoheal: remove existing domain enabled/available entries before recreate
|       |-- if certificate is missing: write HTTP-only server block for certbot
|       |-- if certificate exists: write final HTTP redirect + HTTPS server block
|       |-- expose /_pages/ JSON autoindex for live web-root listing
|       |-- remove default enabled site link when present
|       `-- run systemctl daemon-reload, test nginx config, and reload nginx
|-- [5/6] webi/web1_cert_nginx.sh v04
|   `-- web1_cert_nginx.sh v04
|       |-- [1/5] Ensure certbot + python3-certbot-nginx installed
|       |   `-- runs apt-get update -y before install
|       |-- [2/5] Check existing cert files for domain
|       |   `-- if missing: request cert via certbot --nginx (with retry wrapper + fatal-error detection)
|       |-- [3/5] Test nginx configuration (nginx -t)
|       |-- [4/5] Enable/start certbot.timer
|       `-- [5/5] Test cert renewal (certbot renew --dry-run, with retries + fatal-error detection)
`-- [6/6] webi/web1_entry_nginx.sh v18
    `-- web1_entry_nginx.sh v18
        |-- autoheal/recreate domain Nginx entry after certbot has run
        |-- remove default enabled site link when present
        |-- run systemctl daemon-reload, test nginx config, and reload nginx
        |-- expose /_pages/ JSON autoindex for live web-root listing
        `-- expected final state: HTTP redirect + HTTPS server block when cert files exist
```

## Notes

- `0web.sh` prints resolved child script paths and detected versions before running steps.
- Web-root ensure/init is centralized in `web1_webroot.sh`.
- `web1_webroot.sh` copies the whole `llmweb/` directory only for newly created web roots.
- `web1_adapt_index.sh` edits the copied target `index.htm`, not the repo template in `llmweb/`.
- `web1_entry_nginx.sh` exposes `/_pages/` as a public JSON autoindex for live web-root listing; it includes names, types, modified times, and file sizes from Nginx, but not filesystem capacity/free-space metrics.
- `WEB_BASE_DIR` can override the default `/m/webs`.
- `M_BASE_DIR` can override the default `/m` base used by `web1_webs.sh`; in the normal `0web.sh` flow, set `WEB_BASE_DIR` too if the web base should move away from `/m/webs`.
- `web1_webs.sh`, `web1_webroot.sh`, `web1_adapt_index.sh`, and `web1_cert_nginx.sh` require root.
- `web1_entry_nginx.sh` uses `sudo` commands internally.

## Shell scripts in this directory that are not used by 0web flow

- `0ini.sh` and `ini*` / `init_*` scripts - system/user initialization flow.
- `delete_website.sh` - removes Nginx + cert artifacts for a domain.
- `delete_cloned_user.sh` - removes cloned user account with safety checks.
- `mgit_ssh.sh`, `mgit_https.sh`, `mgit_oldssh.sh`, `mgit_oldhttps.sh` - git helper/update scripts.
- `symlink_m.sh` - creates `/m` layout and compatibility symlinks for legacy paths.
- `mstats.sh`, `mtest.sh` - utility/testing scripts.
