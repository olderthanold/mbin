sudo bash
cd /home/ubun2
nohup "/opt/mbin/ai/aibuild.sh" > /home/ubun2/aibuild.log 2>&1 && touch aibuild_script_completed.txt &
echo $!