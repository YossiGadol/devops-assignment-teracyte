#!/bin/bash
tput civis
mapfile -t dbs < <(mysql -N -e "show databases;" | grep 'test_')
if [ ${#dbs[@]} -eq 0 ]; then
    echo "No databases found matching 'test_'."
    exit 1
fi
highlight=0
n=${#dbs[@]}
draw_menu() {
    clear
    echo "Select a context using up/down arrow keys and press Enter:"
    for i in "${!dbs[@]}"; do
        if [ "$i" -eq $highlight ]; then

            printf " > \e[7m%s\e[0m\n" "${dbs[$i]}"
        else
            printf "   %s\n" "${dbs[$i]}"
        fi
    done
}
while true; do
    draw_menu
    read -rsn1 key
    if [[ $key == $'\x1b' ]]; then
        read -rsn2 key
        if [[ $key == "[A" ]]; then
            ((highlight--))
            if [ $highlight -lt 0 ]; then
                highlight=$((n - 1))
            fi
        elif [[ $key == "[B" ]]; then
            ((highlight++))
            if [ $highlight -ge "$n" ]; then
                highlight=0
            fi
        fi
    elif [[ $key == "" || $key == $'\n' ]]; then
        db="${dbs[$highlight]}"
        break
    fi

done
tput cnorm
printf "\n\e[1;32mRe-importing DB: %s\e[0m\n" "$db"

mysql -e "drop database if exists $db;"
mysql -e "create database $db;"
mysql "$db" </working_example-mysql/working_example-mysql.sql
printf "\n\e[1;32mCompleted re-importing DB: %s\e[0m\n\n" "$db"
