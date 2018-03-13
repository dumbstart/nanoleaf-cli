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
# set -o errexit
# set -o nounset
# set -ex

get_list() {
#   list=$(curl -sS -X GET "$curl_nano/effects/effectsList" | tr " " "_" | tr "," "\n" | tr -d '"' | tr -d '[' | tr -d ']')
  effects=$(nano_get "effects/effectsList"); effects=$(echo "["'"'"Off"'"'","'"'"*Solid*"'"'","'"'"*Static*"'"'",${effects:1}")
  return_value=$(echo "$effects" | tr "," "\n" | tr -d "[" | tr -d "]")
  $update_hass && curl -s -X POST -H "Content-Type: application/json" -H "x-ha-access: $hass_pass" -d '{"entity_id":"'"$hass_effect"'","options":'"$effects"'}' "$hass_url/api/services/input_select/set_options" > /dev/null
  current_effect=$(nano_send "select" "${value_effect}" "effects" "effects/select")
  hass_send "option" "$current_effect"
}

nano_send() {
  [[ $2 =~ ^-?[0-9]+$ ]] || [[ "$1" = "on" ]] && curl -s -X PUT -d '{"'$1'": '$2'}' "$curl_nano/$3" || curl -s -X PUT -d '{"'$1'": "'"$2"'"}' "$curl_nano/$3"
  [[ -n "$4" ]] && nano_get "$4"
}

nano_get() {
  curl -sS -X GET "$curl_nano/$1"
}

hass_send() {
  echo '{"entity_id": "'$hass_effect'", "'$1'": '"'"$2"'"'}' "$hass_url/api/services/input_select/select_option"  > /dev/null
  $update_hass && [[ "$1" = "value" ]] && curl -sS -X POST -H "Content-Type: application/json" -H "x-ha-access: $hass_pass" --data '{"entity_id": "'$hass_brightness'", "'$1'": '$2'}' "$hass_url/api/services/input_number/set_value"  > /dev/null
  $update_hass && [[ "$1" = "option" ]] && curl -sS -X POST -H "Content-Type: application/json" -H "x-ha-access: $hass_pass" --data '{"entity_id": "'$hass_effect'", "'$1'": '"$2"'}' "$hass_url/api/services/input_select/select_option"  > /dev/null
}

# set_brightness() {
#   return_value=$(nano_send "brightness" "${value_bright}" "state" "state/brightness/value"); hass_send "value" "$return_value"
# }

get_brightness() {
  return_value=$(nano_get "state/brightness/value")
  hass_send "value" "$return_value"
}

set_power() {
  return_value=$(nano_send "on" "${value_power}" "state" "state/on")
  [[ "$return_value" = *"true"* ]] && return_value="On" || return_value="Off"
  send_effect=$([[ "$return_value" = "On" ]] && nano_get "effects/select" || echo '"Off"'); hass_send "option" "$send_effect"
}

get_power() {
  return_value=$([[ $(nano_get "state/on") = *"true"* ]] && echo "On" || echo "Off")
  hass_send "option" $([[ "$return_value" = "On" ]] && nano_get "effects/select" || echo '"Off"')
}

set_effect() {
  return_value=$(nano_send "select" "${value_effect}" "effects" "effects/select")
  hass_send "option" "$return_value"
}

get_effect() {
  return_value=$([[ $(nano_get "state/on") = *"true"* ]] && nano_get "effects/select" || echo "Off")
  hass_send "option" "$return_value"
}

show_usage() {
  echo 'Usage: nano.sh [-s off on # "Effect Name"] [-b] [-p] [-e] [-l] [-u] [-h]'
  exit 1
}

# initial check for Nanoleaf API info and Home Assistant info
if [ -z "$url" ] || [ -z "$port" ] || [ -z "$key" ]; then
  echo "Please enter the your Nanoleaf Aurora light information and run this script again"; exit 1
else
  curl_nano=$url":"$port"/api/v1/"$key
fi

# check Home Assistant requirements are met to update
[ -z "$hass_pass" ] || [ -z "$hass_brightness" ] || [ -z "$hass_effect" ] || [ -z "$hass_url" ]  && update_hass=false || update_hass=true

# check to ensure script was run with flags
[[ ! $@ =~ ^\-.+ ]] && show_usage

# find flag
while getopts ":bplues:a:" flag
do
  case "$flag" in
    a)  if [ -n "$2" ] && [ -n "$3" ]; then
          return_value="Turn on $2 for $3 seconds"
          curl -s -X PUT -d '{"write":{"command": "displayTemp", "duration": '$3', "animName": "'"$2"'" }}' "$curl_nano/effects"
        fi
        ;;
    s)  if [ "$OPTARG" = "off" ] || [ "$OPTARG" = "Off" ] || [ "$OPTARG" = "false" ]; then
          return_value=$([[ $(nano_send "on" "false" "state" "state/on") = *"true"* ]] && echo "On" || echo "Off")
          nano_current=$([[ "$return_value" = "On" ]] && nano_get "effects/select" || echo '"Off"'); hass_send "option" "$nano_current"
        elif [ "$OPTARG" = "on" ] || [ "$OPTARG" = "true" ]; then 
          return_value=$([[ $(nano_send "on" "true" "state" "state/on") = *"true"* ]] && echo "On" || echo "Off")
          nano_current=$([[ "$return_value" = "On" ]] && nano_get "effects/select" || echo '"Off"'); hass_send "option" "$nano_current"
        elif [ "$OPTARG" -ge 0 ] 2>/dev/null; then
          return_value=$(nano_send "brightness" "${OPTARG}" "state" "state/brightness/value")
          hass_send "value" "$return_value"
        else
          return_value=$(nano_send "select" "${OPTARG}" "effects" "effects/select"); hass_send "option" "$return_value"
        fi
        ;;
    b)  return_value=$(nano_get "state/brightness/value")
        hass_send "value" "$return_value"
        ;;
    e)  return_value=$([[ $(nano_get "state/on") = *"true"* ]] && nano_get "effects/select" || echo "Off")
        hass_send "option" "$return_value"
        ;;
    l)  get_list;;
    u)  if [ $update_hass ]; then
          get_power; get_list; get_brightness; return_value="Update complete"; 
        fi
        ;;
    p)  return_value=$([[ $(nano_get "state/on") = *"true"* ]] && echo "On" || echo "Off")
        nano_current=$([[ "$return_value" = "On" ]] && nano_get "effects/select" || echo '"Off"'); hass_send "option" "$nano_current"
        ;;
    *)  show_usage
  esac
done
shift $((OPTIND-1))
# output of the results of the Nanoleaf request
echo "$return_value"

unset value_power
unset value_bright
unset value_effect
unset return_value
unset list
