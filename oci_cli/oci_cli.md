# ==== PROCESSES ====================================================
top
ps all
ps -f
## ==== nohup 
### Run in background even if console closes
```bash
# mine that works
nohup sudo -E bash -c "export PATH=$PATH; ociamp.sh" > ociamp.log 2>&1 && touch ociamp_script_completed.txt &
echo $!

# by chatgpt
nohup bash -c 'sudo -E bash -c "export PATH=$PATH; ociamp.sh" && touch ociamp_script_completed.txt' > ociamp.log 2>&1 &
echo $!
```

nohup bash -c 'sudo -E bash -c "export PATH=$PATH; ociamp.sh" && touch ociamp_script_completed.txt' > ociamp.log 2>&1 &
echo $!

### Check later:
```bash
ps -fp <PID>
tail -f ociamp02.log
```
### Access process output
/proc
tail -f /proc/<pid>/fd/1

# ==== tmux ================================================
# install tmux (only once)
sudo apt install tmux
# start a new tmux session named "build"
tmux new -s ociclim
# inside tmux: run your build script
/opt/mbin/ai/aibuild.sh
# detach from tmux (leave build running)
## press: Ctrl+b then d
# later: list tmux sessions
tmux ls
# reattach to the session
tmux attach -t build
# (optional) kill the session when done
tmux kill-session -t build

# ==== OCI instance =================================================
https://docs.oracle.com/en-us/iaas/Content/Compute/tutorials/first-linux-instance/overview.htm
## tenancy: okderthanold
ocid1.tenancy.oc1..aaaaaaaayd6mxebdj7xpp25xyftvuba2dme5vubiohg3irybx2sitkq2yjna
## user
ocid1.user.oc1..aaaaaaaabdu6itjzjdme5r3i5duc5ww2nf7bubg67lca7aumgsxcmjmptifq
## api key location
/home/ubun2/.config/oldapi.pem
## linux install (AI made setup_oci_cli_ubuntu.sh)
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"
oci --version