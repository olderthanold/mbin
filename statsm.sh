echo -e "\033[0;32m =---------- ps -la ----------= \033[0m"
ps -la
echo -e "\033[0;32m =---------- echo -e ----------= \033[0m"
swapon --show
echo -e "\033[0;32m =---------- free -h ----------= \033[0m"
free -h
echo -e "\033[0;32m =---------- df -h /dev/sda1 ----------= \033[0m"
df -h /dev/sda1
echo -e "\033[1;33m =---------- .bashrc done ----------= \033[0m"