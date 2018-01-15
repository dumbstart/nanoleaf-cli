#!/bin/bash 

# set -o errexit
# set -o nounset
# set -ex


# Set Nanoleaf API settings
url=""
port=""
key=""
hass_pass=""
hass_url=""
hass_entity=""
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function getURL() {
  curl -X GET -s "$curl_nano$1"
}

function putURL() {
  [[ "${#}" -eq 3 ]] && data="{ $2: $3}" || data="{$2:{$3:$4}}"
  curl -X PUT -s -d "$data" "$curl_nano$1"
}

function show_effect() {
  if [[ $(getURL "/state/on") = *"false"* ]]; then
    echo "Off"
  else
    current=$(getURL "/effects/select" | tr -d '"')
    hass_effects=$(curl -s -X GET -H "Content-Type: application/json" -H "x-ha-access: $hass_pass" "$hass_url/api/states/$hass_entity" | `pwd`/JSON.sh -s -b)
    state=$(echo "$hass_effects" | egrep '\["state"\]' | cut -d '"' -f4)
    if [ "$state" != "$current" ]; then
      echo "$state"
    else
      echo "$current"
    fi
  fi
}

function update_effects() {
  declare -a list=($(getURL "/effects/effectsList" )) # | tr ',' ' ' | tr -d '[' | tr -d ']'))
  printf -v effects "%s " "${list[@]}"
  effects=$(echo "${effects::-2},"'"'"Off"'"'"]")
  curl -s -X POST -H "Content-Type: application/json" -H "x-ha-access: $hass_pass" -d '{"entity_id":"'"$hass_entity"'","options":'"$effects"'}' "$hass_url/api/services/input_select/set_options" > /dev/null
  power=$(getURL "/state/on" | cut -d':' -f 2 | cut -d'}' -f 1)
  [ "$power" = false ] && effect="Off" || effect=$(curl -X GET -s "${curl_nano}/effects/select" | awk '{ print $0 }')
  effect=$(echo '"'${effect}'"')
  curl -s -X POST -H "Content-Type: application/json" -H "x-ha-access: $hass_pass" -d '{"entity_id":"'"$hass_entity"'","option":'"$effect"'}' "$hass_url/api/services/input_select/select_option" > /dev/null
}

function listEffect() {
  list=""
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
  echo "effect: $effect"
  if [ "$effect" = "Off" ]; then
    putURL "/state" '"on"' '"value"' "false"
  else
    declare -a list=($(getURL "/effects/effectsList" | tr ' ' '_' | tr ',' ' ' | tr -d '[' | tr -d ']' | tr -d '"'))
    for option in "${list[@]}"; do
      item=$(echo "$option" | tr -d '"')
      if [[ "$item" == "$effect" ]]; then
        echo "effect: $effect"                  
        effect=$(echo "$item" | tr "_" " " | awk '"{ print $0 }"')
        echo "effect: $effect"            
        item=$( echo '"'$item'"' | tr "_" " ")
        echo "$item"
        data='{"select" : '"$item"'}'
        echo "data: $data"            
        echo "effect: $effect"            
        curl -X PUT -s -d "$data" "$curl_nano/effects"
        echo "effect: $effect"    
      fi
    done
  fi
  hass_effects=$(curl -s -X GET -H "Content-Type: application/json" -H "x-ha-access: $hass_pass" "$hass_url/api/states/$hass_entity" )
  echo "$hass_effects"
  if [[ "$hass_effects" = *"$effect"* ]]; then
    echo "MATCH"
    echo "effect: $effect"
    curl -X POST -H "Content-Type: application/json" -H "x-ha-access: $hass_pass" -d '{"entity_id":"'"$hass_entity"'","option":"'"$effect"'"}' "$hass_url/api/services/input_select/select_option"
    echo "results: $?"
  else
    update_effects
  fi
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

if [ -z "$url" ]; then
  echo "Please enter the URL of your Nanoleaf lights."
  exit 11
fi
if [ -z "$port" ]; then
  echo "Please enter the port of your Nanoleaf lights, usually 16021."
  exit 12
fi
if [ -z "$key" ]; then
  echo "Please enter the key for your Nanoleaf lights."
  exit 13
fi
if [ -z "$hass_pass" ] || [ -z "$hass_entity" ] || [ -z "$hass_url" ]; then
  echo "Please enter your Home Assistant information for your Nanoleaf lights."
  exit 14
fi
if [[ ! $@ =~ ^\-.+ ]]; then
  show_usage
  exit 15
fi

# Ensure JSON.sh is available, download if it is not
if [ ! -f "$DIR/JSON.sh" ]; then
  read -n 1 -s -r -p "Downloading JSON.sh to $DIR...press any key to continue."
  curl -s -O https://raw.githubusercontent.com/dominictarr/JSON.sh/master/JSON.sh > /dev/null
  echo
  chmod +x $DIR'/JSON.sh'
fi



declare -a list
curl_nano=$url":"$port"/api/v1/"$key
while getopts ":bplfueg:s:" flag
do
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
          putURL "/state/" '"brightness"' '"value"' "$OPTARG"; getURL "/state/brightness/value"
        else
          setEffect
          getURL "/effects/select" | tr -d '"';
        fi
        echo
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