#!/usr/bin/env bash 

set -o errexit
set -o nounset
# set -ex


# Set Nanoleaf API settings
URL=""
PORT=""
KEY=""

function listEffect() {
  LIST=""
  declare -a LIST=($(getURL "/effects/effectsList" | sed -e "s/ /_/g" | tr ',' ' ' | tr -d '[' | tr -d ']'))
  for OPTION in ${LIST[@]}; do
    OPTION=$(echo $OPTION | tr "_" " ")
    LIST=$(echo "$LIST,$OPTION")
  done
  LIST=$(echo "[$LIST]")
  printf "%s" "$LIST"  
}


function setEffect() {
  declare -a LIST=($(getURL "/effects/effectsList" | tr ' ' '_' | tr ',' ' ' | tr -d '[' | tr -d ']' | tr -d '"'))
  for OPTION in ${LIST[@]}; do
    EFFECT=$(echo $OPTARG | tr -d '"'); ITEM=$(echo $OPTION | tr -d '"')
    if [[ "$ITEM" == "$EFFECT" ]]; then
      EFFECT=$(echo $ITEM | tr "_" " " | awk '"{ print $0 }"')
      ITEM=$( echo $ITEM | tr "_" " ")
      DATA='{"select" : "'${ITEM}'"}'
      curl -X PUT -s -d "$DATA" "$CURL/effects"
    fi
  done
}

function fadeIn() {
  MIN=$(getURL "/state/brightness/value")
  [[ $(getURL "/state/on" | cut -d':' -f 2 | cut -d'}' -f 1) == "false" ]] && MIN=0; putURL "/state/" '"brightness"' '"value"' 0; putURL "/state/on" '"on"' '"value"' "true"
  for (( NUM=$MIN; NUM<=100; NUM+=5 )); do
    putURL "/state/" '"brightness"' '"value"' "$NUM" 
  	sleep 1
  done
}

function fadeOut() {
  MAX=$(getURL "/state/brightness/value")
  for (( NUM=$MAX; NUM>=0; NUM-=5 )); do
    putURL "/state/" '"brightness"' '"value"' "$NUM" 
  	sleep 1
  done
}

function getURL() {
  curl -X GET -s "$CURL$1" | awk '{ print $0 }'
}

function putURL() {
  [[ "${#}" -eq 3 ]] && DATA="{ $2: $3}" || DATA="{$2:{$3:$4}}"
  curl -X PUT -s -d "$DATA" "$CURL$1"
}

function showUsage() {
  echo "Usage: $0 [-s off on in out # effect] [-g power brightness effect] [-f in out] [-b] [-p] [-e] [-l]"
  exit 1
}

MESSAGE=""
[ -z "$URL" ] && echo "Please enter the URL of your Nanoleaf lights."; showUsage
[ -z "$PORT" ] && echo "Please enter the port of your Nanoleaf lights, usually 16021."; showUsage
[ -z "$KEY" ] && echo "Please enter the key for your Nanoleaf lights."; showUsage
[[ ! $@ =~ ^\-.+ ]] && showUsage

CURL=$URL":"$PORT"/api/v1/"$KEY

while getopts ":bplfeg:s:" FLAG
do
  case "$FLAG" in
    s)  # set off/on/fade in/fade out/brightness/effect
        if [[ "$OPTARG" == "off" ]]; then putURL "/state" '"on"' '"value"' "false"; [[ $(getURL "/state/on" | cut -d':' -f 2 | cut -d'}' -f 1) == "false" ]] && echo "off" || echo "on"
        elif [[ "$OPTARG" == "on" ]]; then putURL "/state" '"on"' '"value"' "true"; [[ $(getURL "/state/on" | cut -d':' -f 2 | cut -d'}' -f 1) == "false" ]] && echo "off" || echo "on"
        elif [[ "$OPTARG" == "in" ]]; then fadeIn
        elif [[ "$OPTARG" == "out" ]]; then fadeOut
        elif [ "$OPTARG" -ge 0 ] 2>/dev/null; then putURL "/state/" '"brightness"' '"value"' "$OPTARG"; getURL "/state/brightness/value"
        else setEffect; getURL "/effects/select" | tr -d '"';
        fi;;
    g)  #get power/brightness/effect
        if [[ "$OPTARG" == "power" ]]; then [[ $(getURL "/state/on" | cut -d':' -f 2 | cut -d'}' -f 1) == "false" ]] && echo "off" || echo "on"
        elif [[ "$OPTARG" == "brightness" ]]; then getURL "/state/brightness/value"
        elif [[ "$OPTARG" == "effect" ]]; then getURL "/effects/select" | tr -d '"'
        fi;;
    b)  getURL "/state/brightness/value";; # getBrightness
    e)  getURL "/effects/select" | tr -d '"';; # getCurrentEffect
    f)  [[ $(getURL "/state/on" | cut -d':' -f 2 | cut -d'}' -f 1) == "false" ]] && fadeIn || fadeOut;; #fadeIn or fadeOut based on power state
    l)  listEffect;; # getEffects
    p)  [[ $(getURL "/state/on" | cut -d':' -f 2 | cut -d'}' -f 1) == "false" ]] && echo "off" || echo "on";; # getPower
    *)  showUsage
  esac
done