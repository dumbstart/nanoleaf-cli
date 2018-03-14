#!/bin/bash 

####  Manager your Nanoleaf Aurora light through the command line. Interfaces with your Home Assistant installation.
####  Please enter the following variables to connect to your Aurora light as well as your Home Assistant.
####  Usage: nano.sh -b [0-100] -e ["effect name"] -p [on/off] a "effect name" ## -l -u
####  Written by Michael Burks, repo at https://github.com/dumbstart/nanoleaf-cli

# Set Nanoleaf API settings
# readonly url="" # IP address of Nanoleaf light panels
# readonly port="" #Access token port for Nanoleaf, defaults to 16201
# readonly key="" # Access token key for Nanoleaf
# readonly hass_url="" # Url for your Home Assistant
# readonly hass_pass="" # Password for your Home Assistant
# readonly hass_effect="" # Enter the input_select entity_id for your nanoleaf effects, i.e. input_select.nanoleaf_effects
# readonly hass_brightness="" # Enter the input_number entity_id for your nanoleaf brightness, i.e. input_number.nanoleaf_brightness
# set -o errexit
# set -o nounset
# set -ex

# initial check for Nanoleaf API info and Home Assistant info
if [ -z "$url" ] || [ -z "$port" ] || [ -z "$key" ]; then
  echo "Please enter the your Nanoleaf Aurora light information and run this script again"; exit 1
else
  curl_nano=$url":"$port"/api/v1/"$key
fi

# check Home Assistant requirements are met to update
[ -z "$hass_pass" ] || [ -z "$hass_brightness" ] || [ -z "$hass_effect" ] || [ -z "$hass_url" ]  && update_hass=false || update_hass=true

# check to ensure script was run with flags
[[ ! $@ =~ ^\-.+ ]] && nano_usage

nano_send() {
  curl -s -X PUT -d '{"'$1'": '$2'}' "$curl_nano/$3"
}

nano_get() {
  curl -sS -X GET "$curl_nano/$1"
}

hass_send() {
  [[ "$1" = "value" ]] && curl -sS -X POST -H "Content-Type: application/json" -H "x-ha-access: $hass_pass" --data '{"entity_id": "'$hass_brightness'", "'$1'": '$2'}' "$hass_url/api/services/input_number/set_value"  > /dev/null  
  [[ "$1" = "option" ]] && curl -sS -X POST -H "Content-Type: application/json" -H "x-ha-access: $hass_pass" --data '{"entity_id": "'$hass_effect'", "'$1'": '"$2"'}' "$hass_url/api/services/input_select/select_option" > /dev/null
}

show_usage() {
  echo
  echo "Usage:"
  echo 'nano.sh -b [0-100] -e ["effect name"] -p [on/off] a "effect name" ## -l -u'
  echo
  echo "Description:"
  echo "Bash script to interact with your Nanoleaf wall panels."
  echo
  echo "Options:"
  echo "-p [on/off]             Returns power status or can set power with optional argument"
  echo "-b [0-100]              Returns brightness or sets brightness to integer between 0 and 100"
  echo '-e ["effect name"]      Flag -e returns current effect, or changes light panels to an effect'
  echo '-l                      List all effects available on Nanoleaf light panels'
  echo '-a "effect name" ##     Switches light panels to "effect name" for specified number of seconds and then returns to previous'
  echo
  echo 'Instructions:'
  echo 'Enter your Nanoleaf information into the script. To update your Home Assistant configuration you can also enter your Home Assistant password and url'
  echo
  exit 1
}

nano_display() {
  local display=$([[ "$1" = ^-?[0-9]+$ ]] && echo "$1" || grep "$1" "$(pwd)/display" | cut -d ':' -f 2)
  curl -X PUT -d '{"write":{"command":"display","animName":"*Static*","animType":"static","animData":"'"$display"'"}}' "$curl_nano/effects"   
}

nano_brightness() {
  [[ -n "$1" ]] && [[ "$((1))" -ge 0 ]] && [[ "$((1))" -le 100 ]] && nano_send "brightness" $1 "state"
  nano_get "state/brightness/value"
}

nano_power() {
  [[ "${1,,}" = "on"* ]] || [[ "${1,,}" = "true" ]] && nano_send "on" "true" "state"
  [[ "${1,,}" = "off"* ]] || [[ "${1,,}" = "false" ]] && nano_send "on" "false" "state"
  [[ $(nano_get "state/on") = *"true"* ]] && echo "On" || echo "Off"
}

nano_list() {
  local effects=$(nano_get "effects/effectsList")
  effects=$(printf '["Off","*Solid*","*Static*",%s' "${effects:1}")
  echo "$effects"
}

nano_effect() {
  if [ -n "$1" ]; then
    if [ "${1,,}" = "off" ]; then
      nano_power "off"
    elif [[ $(nano_get "effects/effectsList") = *'"'$1'"'* ]]; then
      nano_send "select" '"'$1'"' "effects"
    else
      echo "Effect not found"
      exit 1
    fi
  fi
  [[ $(nano_power) = "Off" ]] && echo "Off" || nano_get "effects/select"
}

nano_alert() {
  local value=$( echo "$1" | tr ' ' '_')
  local effect=$(echo '"'"${value%_*}"'"' | tr '_' ' ')
  local duration="${value##*_}"
  if [[ -n "$duration" ]] && [[ "$duration" -gt 0 ]] && [[ -n "$effect" ]] && [[ $(nano_list) = *"$effect"* ]]; then
    printf -v data '{"command":"displayTemp","duration":%d,"animName":%s}' $duration "$effect"
    curl -s -X PUT -d '{"write": '"$data"'}' "$curl_nano/effects"
    printf 'Alert set for %s seconds with %s effect.\n' "$duration" "$effect"
  else
    printf 'Alert not avavilable expected "effect name" and number of seconds, received %s and %s.\n' "$effect" "$duration"
  fi
}

# find flag
while getopts "d:bplueah" flag; do
  case "$flag" in
    a)  options=$(echo "${@:$OPTIND}" | tr ' ' '_')
        nano_alert "$options"
        [[ "${options:0:1}" != "-" ]] && OPTIND=$((OPTIND+2))
        ;;
    b)  options=$(echo "${@:$OPTIND}")
        response=$(nano_brightness "$options"); echo "$response"
        $update_hass && hass_send "value" "$response"
        [[ "${options:0:1}" != "-" ]] && OPTIND=$((OPTIND+1))
        ;;
    d)  nano_display "$OPTARG"
        ;;
    e)  options=$(echo "${@:$OPTIND}")
        response=$(nano_effect "${options%%-*}"); echo "$response"
        $update_hass && hass_send "option" "$response"
        [[ "${options:0:1}" != "-" ]] && OPTIND=$((OPTIND+1))
        ;;
    l)  nano_list;;
    u)  nano_list; sleep 1;echo; nano_power;nano_effect;echo;nano_brightness;echo ;;
    p)  options=$(echo "${@:$OPTIND}")
        response=$(nano_power "${options%% -*}"); echo "$response";
        effect=$(nano_effect)
        $update_hass && hass_send "option" '"'$effect'"'
        [[ "${options:0:1}" != "-" ]] && OPTIND=$((OPTIND+1))
        ;;
    *)  show_usage
  esac
done
shift $((OPTIND+1))