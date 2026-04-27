# mgit_ssh.sh — How It Works

This document explains what `mgit_ssh.sh` does, how arguments are interpreted, and what checks happen before repository update operations.

---

## Purpose

`mgit_ssh.sh` manages a local clone of the `mbin` repository (or another remote you provide), with:

- path resolution (default/absolute/relative)
- SSH-key based git operations for SSH remotes
- key presence + permission checks
- optional user-to-group synchronization (`-n <user>`)
- pull recovery flow (stash/rebase/fallback clone)

---

## Script version source

Inside the script itself:

```bash
SCRIPT_VERSION="v08"
```

So the script version is stored directly in the file, not in a separate version database.

---

## Usage

```bash
bash mgit_ssh.sh [-h|--help] [-n <user>] [local_path] [remote_repo]
```

### Arguments and flags

- `-h`, `--help`
  - print help and exit

- `-n <user>`
  - optional
  - when running with `sudo`, adds an extra user to group-sync checks (in addition to sudo caller)

- `local_path` (optional)
  - if omitted: `/m/mbin`
  - if absolute (starts with `/`): used as-is
  - if relative: resolved under `$HOME`

- `remote_repo` (optional)
  - if omitted: `git@github.com:olderthanold/mbin.git`
  - if provided: used exactly as given

---

## High-level execution flow

1. Parse options/flags (`-h`, `-n`) and positional arguments.
2. Resolve local target path (`MBIN_DIR`).
3. Resolve remote (`GIT_LINK`).
4. If remote is SSH-style (`git@...` or `ssh://...`), validate SSH key file.
5. Check write access for target path (or parent dir when target does not yet exist).
6. If running with `sudo`, sync group membership for sudo caller (and optional `-n` user).
7. Run pull/clone workflow.
8. Restore execute bits on `*.sh` files in target directory.

---

## SSH key handling

Configured key path:

```bash
SSH_KEY_PATH="/home/ubun2/.ssh/old.key"
```

For SSH remotes only, script performs:

1. **Existence check** (`-f`)
   - if missing: prints error and exits

2. **Readability check** (`-r`)
   - if unreadable: prints error and exits

3. **Permission check** (`stat -c '%a'`)
   - expected mode: `600`
   - if different: tries `chmod 600`
   - if fix succeeds: continues
   - if fix fails: prints sudo guidance and exits

Git commands for SSH remotes are executed through:

```bash
GIT_SSH_COMMAND="ssh -i $SSH_KEY_PATH" git ...
```

---

## Write-access checks

- If `MBIN_DIR` exists: it must be writable.
- If `MBIN_DIR` does not exist:
  - its parent directory must exist and be writable.

If not writable, script exits with a message to run with sudo.

---

## Group sync behavior (`sudo` + optional `-n <user>`)

Group sync is performed **only when script is run with `sudo`**.

When running under sudo:

1. Sudo caller user (`SUDO_USER`) is always included.
2. If `-n <user>` is provided, that user is also included.
3. Duplicate users are automatically ignored.

For each selected user, the script ensures membership in:

1. **Parent directory group** of target path.
2. **Target directory group** of target path.
   - If target directory does not yet exist, this is checked again after clone/pull.

If script is not run with sudo:

- group sync is skipped.

Implementation details:

1. Validate user exists (`id <user>`).
2. Read group (`stat -c '%G'`).
3. Check membership (`id -nG ... | grep`).
4. If missing:
   - require root
   - add with `usermod -aG <group> <user>`

---

## Git update/recovery logic

If target is not a git repo yet (`$MBIN_DIR/.git` missing):

- clone main branch from resolved remote.

If repo exists:

1. try `git pull <remote> main`
2. on failure:
   - create stash if local changes exist
   - try `git pull --rebase <remote> main`
3. if rebase also fails:
   - remove target dir
   - fresh clone

After successful workflow:

- run `chmod +x "$MBIN_DIR"/*.sh` (best-effort)

---

## Examples

Use defaults:

```bash
sudo bash mgit_ssh.sh
```

Relative path under HOME:

```bash
sudo bash mgit_ssh.sh mytools/mbin
```

Absolute path + custom remote:

```bash
sudo bash mgit_ssh.sh /m/mbin git@github.com:olderthanold/mbin.git
```

Ensure user is in parent-dir group:

```bash
sudo bash mgit_ssh.sh -n ubun2 /m/mbin
```

Sudo caller is always synced too (with or without `-n`):

```bash
sudo bash mgit_ssh.sh /m/mbin
```

---

## Common failure reasons

- SSH key file missing at configured path
- SSH key permission too open and cannot be fixed (no privileges)
- insufficient write access to target path/parent
- specified `-n` user does not exist
- no root privileges when group modification is required
