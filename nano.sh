#!/bin/bash 

set -o errexit
set -o nounset
# set -ex

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
declare -a list

# Set Nanoleaf API settings
url=""
port=""
key=""
hass_pass=""
hass_url=""
hass_entity=""

function getURL() {
  curl -X GET -s "$curl_nano$1"
}

function putURL() {
  [[ "${#}" -eq 3 ]] && data="{ $2: $3}" || data="{$2:{$3:$4}}"
  curl -X PUT -s -d "$data" "$curl_nano$1"
}

function show_effect() {
#   echo "show_effect"
  if [[ $(getURL "/state/on") = *"false"* ]]; then
    echo "off"
  else
    current=$(getURL "/effects/select" | tr -d '"')
    hass_effects=$(curl -s -X GET -H "Content-Type: application/json" -H "x-ha-access: $hass_pass" "$hass_url/api/states/$hass_entity" | `pwd`/JSON.sh -s -b)
    state=$(echo "$hass_effects" | egrep '\["state"\]' | cut -d '"' -f4)
    [ "$state" != "$current" ] && echo "$state" || echo "$current"
  fi
}

function update_effects() {
#   echo "update_effects"
  declare -a list=($(getURL "/effects/effectsList" )) # | tr ',' ' ' | tr -d '[' | tr -d ']'))
  printf -v effects "%s " "${list[@]}"
  effects=$(echo "${effects::-2},"'"'"off"'"'"]")
  curl -s -X POST -H "Content-Type: application/json" -H "x-ha-access: $hass_pass" -d '{"entity_id":"'"$hass_entity"'","options":'"$effects"'}' "$hass_url/api/services/input_select/set_options" > /dev/null
  power=$(getURL "/state/on" | cut -d':' -f 2 | cut -d'}' -f 1)
  [ "$power" = false ] && effect="off" || effect=$(curl -X GET -s "${curl_nano}/effects/select" | awk '{ print $0 }')
  effect=$(echo '"'${effect}'"')
  curl -s -X POST -H "Content-Type: application/json" -H "x-ha-access: $hass_pass" -d '{"entity_id":"'"$hass_entity"'","option":'"$effect"'}' "$hass_url/api/services/input_select/select_option" > /dev/null
}

function listEffect() {
#   echo "listEffect"
  declare -a list=($(getURL "/effects/effectsList" | sed -e "s/ /_/g" | tr ',' ' ' | tr -d '[' | tr -d ']'))
  for option in "${list[@]}"; do
    option=$(echo $option | tr "_" " ")
    list=$(echo "$list,$option")
  done
  list=$(echo "[$list]")
  printf "%s" "$list"  
}

function setEffect() {
  effect=$(echo $OPTARG | tr -d '"')
  if [ "$effect" = "off" ]; then
    putURL "/state" '"on"' '"value"' "false"
  else
    declare -a list=($(getURL "/effects/effectsList" | tr ' ' '_' | tr ',' ' ' | tr -d '[' | tr -d ']' | tr -d '"'))
    for option in "${list[@]}"; do
      item=$(echo "$option" | tr -d '"')
      if [[ "$item" == "$effect" ]]; then               
        effect=$(echo "$item" | tr "_" " " | awk '"{ print $0 }"')  
        item=$( echo '"'$item'"' | tr "_" " ")
        data='{"select" : '"$item"'}'
        curl -X PUT -s -d "$data" "$curl_nano/effects"
      fi
    done
  fi
  hass_effects=$(curl -s -X GET -H "Content-Type: application/json" -H "x-ha-access: $hass_pass" "$hass_url/api/states/$hass_entity" )
#   echo "$hass_effects"
  [[ "$hass_effects" = *"$effect"* ]] && curl -X POST -H "Content-Type: application/json" -H "x-ha-access: $hass_pass" -d '{"entity_id":"'"$hass_entity"'","option":"'"$effect"'"}' "$hass_url/api/services/input_select/select_option" || update_effects
}


function set_brightness() {
  putURL "/state/" '"brightness"' '"value"' "$brightness_value";
  if [ "$brightness_value" -eq 0 ]; then
    putURL "/state" '"on"' '"value"' "false"
    curl -s -X POST -H "Content-Type: application/json" -H "x-ha-access: $hass_pass" -d '{"entity_id":"'"$hass_entity"'","option":"off"}' "$hass_url/api/services/input_select/select_option" > /dev/null
  fi
  curl -s -X POST -H "Content-Type: application/json" -H "x-ha-access: $hass_pass" -d '{"entity_id":"'"$hass_entity_brightness"'","value":'"$brightness_value"'}' "$hass_url/api/services/input_number/set_value" > /dev/null
}


function fadeIn() {
  min=$(getURL "/state/brightness/value")
  [[ $(getURL "/state/on" | cut -d':' -f 2 | cut -d'}' -f 1) == "false" ]] && min=0; putURL "/state/" '"brightness"' '"value"' 0; putURL "/state/on" '"on"' '"value"' "true"
  for (( num=$min; num<=100; num+=5 )); do
    putURL "/state/" '"brightness"' '"value"' "$num" 
  	sleep 1
  done
}

function fadeOut() {
  max=$(getURL "/state/brightness/value")
  for (( num=$max; num>=0; num-=5 )); do
    putURL "/state/" '"brightness"' '"value"' "$num" 
  	sleep 1
  done
  putURL "/state" '"on"' '"value"' "false"  
}

function show_usage() {
  echo "Usage: $0 [-s off on in out # effect] [-g power brightness effect] [-f in out] [-b] [-p] [-e] [-l]"
  exit 1
}

if [ -z "$url" ] || [ -z "$port" ] || [ -z "$key" ]; then
  echo "Please enter the your Nanoleaf Aurora light information."
  exit 11
elif [ -z "$hass_pass" ] || [ -z "$hass_entity" ] || [ -z "$hass_url" ]; then
  echo "Please enter your Home Assistant information for your Nanoleaf Aurora lights."
  exit 14
elif [[ ! $@ =~ ^\-.+ ]]; then
  show_usage
  exit 15
fi

# Ensure JSON.sh is available, download if it is not
if [ ! -f "$DIR/JSON.sh" ]; then
  read -n 1 -s -r -p "Downloading JSON.sh to $DIR...press any key to continue."
  curl -s -O https://raw.githubusercontent.com/dominictarr/JSON.sh/master/JSON.sh > /dev/null
  if [ ! -f "$DIR/JSON.sh" ]; then
    echo; echo "Unable to download JSON.sh, please download manually to your Home Assistant configuration folder."  
  else
    chmod +x $DIR'/JSON.sh'
  fi
fi

curl_nano=$url":"$port"/api/v1/"$key
hass_update=True

while getopts ":bplfueg:s:" flag
do
  echo "flag: $GETOPTS"
  case "$flag" in
    s)  
        # set off/on/fade in/fade out/brightness/effect
        if [[ "$OPTARG" == "off" ]]; then 
          putURL "/state" '"on"' '"value"' "false"
          [[ $(getURL "/state/on" | cut -d':' -f 2 | cut -d'}' -f 1) == "false" ]] && echo "off" || echo "on"
        elif [[ "$OPTARG" == "on" ]]; then 
          putURL "/state" '"on"' '"value"' "true"
          update_effects
          [[ $(getURL "/state/on" | cut -d':' -f 2 | cut -d'}' -f 1) == "false" ]] && echo "off" || echo "on"
        elif [[ "$OPTARG" == "in" ]]; 
          then fadeIn
        elif [[ "$OPTARG" == "out" ]]; 
          then fadeOut
        elif [ "$OPTARG" -ge 0 ] 2>/dev/null; then
          brightness_value=$OPTARG
          set_brightness
        else
          putURL "/state" '"on"' '"value"' "true"
          setEffect
          getURL "/effects/select" | tr -d '"';
        fi
        echo "hass_update: $hass_update"
        break;;
    g)  
        #get power/brightness/effect
        if [[ "$OPTARG" == "power" ]]; then
          [[ $(getURL "/state/on" | cut -d':' -f 2 | cut -d'}' -f 1) == "false" ]] && echo "off" || echo "on"
        fi
        if [[ "$OPTARG" == "brightness" ]]; then
          getURL "/state/brightness/value"
        fi
        if [[ "$OPTARG" == "effect" ]]; then
          getURL "/effects/select" | tr -d '"'
        fi
        break;;
    b)  
        getURL "/state/brightness/value"
        echo
        break;;
    e)  
        show_effect
        break;;
    f)  
        [[ $(getURL "/state/on" | cut -d':' -f 2 | cut -d'}' -f 1) == "false" ]] && fadeIn || fadeOut #fadeIn or fadeOut based on power state
        break;;
    l)  
        listEffect # getEffects
        break;;
    u)  
        update_effects # getEffects
        break;;
    p)  
        [[ $(getURL "/state/on" | cut -d':' -f 2 | cut -d'}' -f 1) == "false" ]] && echo "off" || echo "on" # getPower
        break;;
    *)  
        show_usage
        exit

  esac
done