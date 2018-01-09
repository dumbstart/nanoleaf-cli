#!/usr/bin/env bash 

# Set Nanoleaf API settings
URL="http://192.168.1.130"
PORT="16021"
KEY=""



function setEffect() {
  declare -a LIST=($(getURL "/effects/effectsList" | tr ' ' '_' | tr ',' ' ' | tr -d '[' | tr -d ']' | tr -d '"'))
  for OPTION in ${LIST[@]}; do
    EFFECT=$(echo $OPTARG | tr -d '"'); ITEM=$(echo $OPTION | tr -d '"')
    if [[ "$ITEM" == "$EFFECT" ]]; then
      echo "Match"
      EFFECT=$(echo $ITEM | tr "_" " " | awk '"{ print $0 }"')
      echo "final: "$EFFECT
      echo '"'$EFFECT'"'
      ITEM=$( echo $ITEM | tr "_" " ")
      DATA='{"select" : "'${ITEM}'"}'
      echo $DATA
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
        b)  # getBrightness
            getURL "/state/brightness/value";;
        e)  # getCurrentEffect
            getURL "/effects/select" | tr -d '"';;
        f)  [[ $(getURL "/state/on" | cut -d':' -f 2 | cut -d'}' -f 1) == "false" ]] && fadeIn || fadeOut;;
        l)  # getEffects
            LIST=""
            declare -a LIST=($(getURL "/effects/effectsList" | sed -e "s/ /_/g" | tr ',' ' ' | tr -d '[' | tr -d ']'))
#             declare -a LIST=($(getURL "/effects/effectsList" | tr ' ' '_' | tr ',' ' ' | tr -d '[' | tr -d ']' | tr -d '"'))
            for OPTION in ${LIST[@]}; do
              OPTION=$(echo $OPTION | tr "_" " ")
              LIST=$(echo "$LIST,$OPTION")
            done
            LIST=$(echo "[$LIST]")
            echo $LIST
            echo;;
        p)  # getPower
            [[ $(getURL "/state/on" | cut -d':' -f 2 | cut -d'}' -f 1) == "false" ]] && echo "off" || echo "on";;
        *)  echo $"Usage: $0 -s(et) -g(et) -f(ade) -b(rightness) -p(ower) -e(ffect) -l(ist)"; exit 1
  esac
done
