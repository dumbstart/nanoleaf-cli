#!/bin/bash 

####  Manager your Nanoleaf Aurora light through the command line. Interfaces with your Home Assistant installation.
####  Please enter the following variables to connect to your Aurora light as well as your Home Assistant.
####  Usage: $0 [-s off/on/#/"Effect Name"] [-b] [-p] [-e] [-l] [-u]
####  Written by Michael Burks, repo at https://github.com/dumbstart/nanoleaf-cli

# Set Nanoleaf API settings
readonly url=""
readonly port=""
readonly key=""
readonly hass_url=""
readonly hass_pass=""
readonly hass_effect=""
readonly hass_brightness=""

get_list() {
  declare -a list
  value_power=false
  set_power
  list=($(curl -sS -X GET "$curl_nano/effects/effectsList" ))
  printf -v effects "%s " "${list[@]}"
  effects=$(echo "["'"'"Off"'"'",${effects:1}")
  $update_hass && curl -s -X POST -H "Content-Type: application/json" -H "x-ha-access: $hass_pass" -d '{"entity_id":"'"$hass_effect"'","options":'"$effects"'}' "$hass_url/api/services/input_select/set_options" > /dev/null
  [[ $(curl -sS -X GET "$curl_nano/state/on" | cut -d ":" -f 2 | tr -d "}" ) == "false" ]] && return_value="Off" || return_value=$(curl -X GET -s "${curl_nano}/effects/select")
  $update_hass && curl -s -X POST -H "Content-Type: application/json" -H "x-ha-access: $hass_pass" -d '{"entity_id":"'"$hass_effect"'","option":'"$return_value"'}' "$hass_url/api/services/input_select/select_option" > /dev/null
  return_value=$(echo "$effects" | tr ',' '\n' | tr -d '[' | tr -d ']' | tr -d '"')
}

set_brightness() {
  printf -v data '{"%s":{"%s":%d}}' 'brightness' 'value' "$value_bright"
  curl -s -X PUT -d "$data" "$curl_nano/state"
  return_value=$(curl -sS -X GET "$curl_nano/state/brightness/value")
  $update_hass && curl -s -X POST -H "Content-Type: application/json" -H "x-ha-access: $hass_pass" -d '{"entity_id":"'"$hass_brightness"'","value":'"$return_value"'}' "$hass_url/api/services/input_number/set_value" > /dev/null
}

get_brightness() {
  return_value=$(curl -sS -X GET "$curl_nano/state/brightness/value")
  $update_hass && curl -s -X POST -H "Content-Type: application/json" -H "x-ha-access: $hass_pass" -d '{"entity_id":"'"$hass_brightness"'","value":'"$return_value"'}' "$hass_url/api/services/input_number/set_value" > /dev/null
}

set_power() {
  printf -v data '{"%s":{"%s":%s}}' 'on' 'value' "$value_power"
  curl -s -X PUT -d "$data" "$curl_nano/state"
  if [ "$value_power" = true ]; then
    value_effect=$(curl -sS -X GET "$curl_nano/effects/select")
  else
    value_effect='Off'
  fi
  $update_hass && curl -s -X POST -H "Content-Type: application/json" -H "x-ha-access: $hass_pass" -d '{"entity_id":"'"$hass_effect"'","option":'$value_effect'}' "$hass_url/api/services/input_select/select_option" > /dev/null
  return_value=$([[ $(curl -sS -X GET "$curl_nano/state/on" | cut -d ":" -f 2 | tr -d "}" ) == "false" ]] && echo "Off" || echo "On")
}

get_power() {
  [[ $(curl -sS -X GET "$curl_nano/state/on" | cut -d ":" -f 2 | tr -d "}" ) == "false" ]] && return_value="Off" || return_value=$(curl -sS -X GET "$curl_nano/effects/select" | tr -d '"')
  $update_hass && curl -s -X POST -H "Content-Type: application/json" -H "x-ha-access: $hass_pass" -d '{"entity_id":"'"$hass_effect"'","option":'"$return_value"'}' "$hass_url/api/services/input_select/select_option" > /dev/null
  [ "$return_value" != "Off" ] && return_value="On"
}

set_effect() {
  effects=$(curl -sS -X GET "$curl_nano/effects/effectsList" | tr -d '[' | tr -d ']' | tr ',' '\n')
  results=$(echo "$effects" | grep '"'"${value_effect}"'"' )
  if [ "$results" != "" ]; then
    printf -v data '{"%s":"%s"}' 'select' "$value_effect"
    curl -s -X PUT -d "$data" "$curl_nano/effects"
    return_value=$(curl -sS -X GET "$curl_nano/effects/select")
    $update_hass && curl -s -X POST -H "Content-Type: application/json" -H "x-ha-access: $hass_pass" -d '{"entity_id":"'"$hass_effect"'","option":'"$return_value"'}' "$hass_url/api/services/input_select/select_option" > /dev/null
  elif [ "$value_effect" == "Off" ]; then
    value_power=false
    set_power
  else
    return_value=$(printf "Effect \"%s\" not available" "$value_effect")
  fi
}

get_effect() {
  [[ $(curl -sS -X GET "$curl_nano/state/on" | cut -d ":" -f 2 | tr -d "}" ) == "false" ]] && return_value="Off" || return_value=$(curl -sS -X GET "$curl_nano/effects/select" | tr -d '"')
  $update_hass && curl -s -X POST -H "Content-Type: application/json" -H "x-ha-access: $hass_pass" -d '{"entity_id":"'"$hass_effect"'","option":'"$return_value"'}' "$hass_url/api/services/input_select/select_option" > /dev/null
}

show_usage() {
  echo 'Usage: $0 [-s off on # "Effect Name"] [-b] [-p] [-e] [-l] [-u] [-h]'
  exit 1
}

# initial check for Nanoleaf API info and Home Assistant info
if [ -z "$url" ] || [ -z "$port" ] || [ -z "$key" ]; then
  echo "Please enter the your Nanoleaf Aurora light information and run this script again"
  exit 1
else
  curl_nano=$url":"$port"/api/v1/"$key
fi

# check Home Assistant requirements are met to update
[ -z "$hass_pass" ] || [ -z "$hass_brightness" ] || [ -z "$hass_effect" ] || [ -z "$hass_url" ]  && update_hass=false || update_hass=true

# check to ensure script was run with flags
[[ ! $@ =~ ^\-.+ ]] && show_usage

# find flag
while getopts ":bplues:" flag
do
  case "$flag" in
    s)  if [ "$OPTARG" = "off" ]; then
          value_power=false; set_power
        elif [ "$OPTARG" = "on" ]; then 
          value_power=true; set_power
        elif [ "$OPTARG" -ge 0 ] 2>/dev/null; then
          value_bright=$OPTARG; set_brightness
        else
          value_effect="$OPTARG"; set_effect
        fi
        break;;
    b)  get_brightness; break;;
    e)  get_effect; break;;
    l)  get_list; break;;
    u)  if [ $update_hass ]; then
          get_power; get_list; get_brightness; return_value="Update complete"; 
        fi
        break;;
    p)  get_power; break;;
    *)  show_usage
  esac
done
# output of the results of the Nanoleaf request
echo "$return_value"

unset value_power
unset value_bright
unset value_effect
unset return_value
unset list
