cd /home/ubun2
nohup sudo -E bash -c "export PATH=$PATH; /opt/mbin/ai/buildrun_ai.sh" > /home/ubun2/aibuild.log 2>&1 && touch aibuild_script_completed.txt &
echo $!