# Runs ociamp.sh in the background through sudo, saves its log, and creates a completion marker after success.
nohup sudo -E bash -c "export PATH=$PATH; ociamp.sh" > ociamp.log 2>&1 && touch ociamp_script_completed.txt &
echo $!
