# mgit_ssh.sh - How It Works

This document explains what `mgit_ssh.sh` does, how arguments are interpreted, and what checks happen before repository update operations.

## Purpose

`mgit_ssh.sh` manages a local clone of the `mbin` repository (or another remote you provide), with:

- path resolution (default/absolute/relative)
- SSH-key based git operations for SSH remotes
- key presence, permission, and parseability checks
- recursive repository ownership/permission checks, including `.git/FETCH_HEAD`
- optional user-to-group synchronization (`-n <user>`)
- pull recovery flow for git/rebase problems
- no recovery/recreate flow for SSH key/authentication failures

## Script Version Source

Inside the script itself:

```bash
SCRIPT_VERSION="v11"
```

## Usage

```bash
bash mgit_ssh.sh [-h|--help] [-n <user>] [local_path] [remote_repo]
```

- `local_path` omitted: `/m/mbin`
- `remote_repo` omitted: `git@github.com:olderthanold/mbin.git`
- bare remote alias such as `mbin`: expands to `git@github.com:olderthanold/mbin.git`

If the parent directory for `local_path` does not exist, the script attempts to create it before running git operations. When running as root, it assigns the parent directory to the resolved owner and group, then grants owner/group read, write, and execute permissions. If the directory cannot be created or prepared, the script exits with a sudo-related error.

## SSH Key Handling

Configured key path:

```bash
SSH_KEY_PATH="/home/ubun2/.ssh/old.key"
```

For SSH remotes only, the script checks:

- key file exists and is readable
- mode is `600`; if not, the script tries `chmod 600`
- `ssh-keygen -y -f "$SSH_KEY_PATH"` can parse the private key

If parsing fails, the script exits before git touches `/m/mbin`. If CRLF bytes are detected, it prints a safe fix.

## Recovery Guard

If `git pull` fails with SSH/key/auth output such as:

- `Load key ... error in libcrypto`
- `Permission denied (publickey)`
- `Could not read from remote repository`
- `Host key verification failed`

the script exits immediately. It does not stash, rebase, remove, or recreate `/m/mbin`.

Recovery is still used for normal git problems where the SSH key worked but the pull/rebase failed.

## Fix CRLF In Key

Run this on the VM:

```bash
cp -p ~/.ssh/old.key ~/.ssh/old.key.bak_$(date +%Y%m%d_%H%M%S)
sed -i 's/\r$//' ~/.ssh/old.key
chmod 600 ~/.ssh/old.key
ssh-keygen -y -f ~/.ssh/old.key >/tmp/old.pub
```

If `ssh-keygen` still fails after that, the key content is not a valid OpenSSH private key on that host.

## Common Failure Reasons

- SSH key file missing at configured path
- SSH key has Windows CRLF line endings
- SSH key is incomplete, pasted incorrectly, or not an OpenSSH private key
- SSH key permission too open and cannot be fixed
- insufficient permission to create or write to target path/parent
- specified `-n` user does not exist
- no root privileges when group modification is required
