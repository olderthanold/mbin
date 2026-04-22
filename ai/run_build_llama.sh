cd /home/ubun2
nohup "/opt/mbin/ai/build_llama.sh" > aibuild03.log 2>&1 && touch aibuild_script_completed.txt &
echo $!