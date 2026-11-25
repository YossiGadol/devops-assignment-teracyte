#!/bin/bash

tput civis
mapfile -t options < <(kubectl config get-contexts -o name | grep python-backend)
n=${#options[@]}
if [ "$n" -eq 0 ]; then
  echo "No kubectl contexts found."
  exit 1
fi
highlight=0
draw_menu() {
  clear
  echo "Select a context using up/down arrow keys and press Enter:"
  for i in "${!options[@]}"; do
    if [ "$i" -eq $highlight ]; then

      printf " > \e[7m%s\e[0m\n" "${options[$i]}"
    else
      printf "   %s\n" "${options[$i]}"
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
    chosen="${options[$highlight]}"
    break
  fi
done
tput cnorm
kubectl config use-context "$chosen"
helm repo add cronitor https://cronitorio.github.io/cronitor-kubernetes/
helm uninstall cronitor-kubernetes-0.6.0
kubectl delete secret cronitor-secret
helm repo remove cronitor

