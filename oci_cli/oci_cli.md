# ==== PROCESSES ====================================================
top
ps all
ps -f
## ==== nohup 
### Run in background even if console closes
```bash
nohup bash -c 'sudo -E bash -c "export PATH=$PATH; ociamp.sh" && touch ociamp_script_completed.txt' > ociamp.log 2>error.log &
echo $!
# ----- or ------
nohup sudo -E bash -c "export PATH=$PATH; ociamp.sh" > ociamp.log 2>&1 && touch ociamp_script_completed.txt &
echo $!
```
### Check later:
```bash
ps -fp <PID>
tail -f clone.log
```
### Access process output
/proc
tail -f /proc/<pid>/fd/1

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