cd /home/ubun2
nohup "/opt/mbin/ai/aibuild.sh" > aibuild02.log 2>&1 && touch aibuild_script_completed.txt &
echo $!