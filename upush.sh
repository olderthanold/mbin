gpush() {
    echo supply path else runs push for ~/m
    # First argument = repo path, default is $HOME/m if nothing is passed
    local repo="${1:-$HOME/m}"

    echo -e "\e[32m-------------- git add . ------------------------\e[0m"
    git -C "$repo" add .

    echo -e "\e[32m------------ git commit ------------------------\e[0m"
    git -C "$repo" commit -m "ubuntucommit $(date '+%Y-%m-%d %H:%M:%S')"

    echo -e "\e[32m-------------- git push ------------------------\e[0m"
    git -C "$repo" push
}
gpush