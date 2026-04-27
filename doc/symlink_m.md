## symlink_m.sh

`symlink_m.sh` prepares the `/m` runtime layout and creates compatibility symlinks for older paths.

## What it creates

```text
/m
|-- mbin
|-- webs
`-- llama.cpp
```

Compatibility symlinks:

```text
/opt/mbin                 -> /m/mbin
/webs                     -> /m/webs
/home/<user>/mbin         -> /m/mbin
/home/<user>/ai/llama.cpp -> /m/llama.cpp
```

Private SSH keys stay in `~/.ssh`; the script does not move or link them.

## Permissions

- `/m` is created with mode `755` so Nginx can traverse to `/m/webs`.
- `/m/mbin` and `/m/llama.cpp` are owned by the selected legacy user when that user exists.
- `/m/webs` is owned by `root:www-data` with mode `2755`.
- The selected legacy user is added to `www-data` so they can maintain web content.

## Usage

```bash
sudo bash symlink_m.sh
sudo bash symlink_m.sh --dry-run
sudo bash symlink_m.sh --force
sudo bash symlink_m.sh --user ubun2
```

`--force` moves existing non-symlink legacy paths aside to `*.bak_<timestamp>` before creating symlinks.

## Environment overrides

```bash
M_BASE_DIR=/m
MBIN_DIR=/m/mbin
WEB_BASE_DIR=/m/webs
LLAMA_DIR=/m/llama.cpp
LEGACY_USER=ubun2
WEB_GROUP=www-data
```
