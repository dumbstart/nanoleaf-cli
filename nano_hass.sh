#!/usr/bin/env bash 

readonly nano_port=16021

function finish() {
  [[ -n "$pid" ]] && kill $pid >/dev/null
}
trap finish EXIT

function show_progress() { while true; do sleep 1; printf "."; done; }

function nanoleaf_request() {
  local count=0
  while [ -z "$nano_token" ] || [ "$count" -ge 14 ]; do
    unset nano_response
    count=$((count+1))
    echo -n "Attempt #$count. Requesting"
    show_progress &
    pid=$!
    disown
    sleep 8
    nano_response=$(curl -s -X POST "http://$nano_ip:16021/api/v1/new")
    if [ -z "$nano_response" ]; then
      echo "no response"
    else
      echo "$nano_response" | grep "auth_token"
      nano_token=$(echo "$nano_response" | grep "auth_token" | cut -d '"' -f 4 )
      if [ -z "$nano_token" ]; then
        unset nano_token
        echo "invalid response"
      else
        echo "success"
        nano_token=$(echo "$nano_response" | grep "auth_token" | cut -d '"' -f 4 )
      fi
    fi
    kill $pid >/dev/null
    unset pid
  done
}

function nanoleaf_search() {
  info=($(curl -sS -N -X GET -H "x-ha-access: Radio$100.7" -H "Content-Type: application/json" http://hassio/homeassistant/api/error_log 2>/dev/null | grep -m 1 "nanoleaf_aurora" ))
  for each in "${!info[@]}"; do
    [[ "${info[$each]}" = "{'host':" ]] && { nano_ip=$(echo "${info[$((each+1))]}" | tr -d ','); break; }
  done
}

echo
nanoleaf_search
echo; echo "Nanoleaf IP address: $nano_ip"; echo
echo "Please read instructions as they require specific timing."
echo
echo "You will need to press and hold the power button on your"
echo "Nanoleaf light panels for 5-7 seconds until the LED is flashing."
echo "When the LED begins flashing it will then accept incoming request"
echo "for the following 30 seconds."; echo
echo "You will have two minutes to press and hold the Nanoleaf light"
echo "panel power button before this script times out."; echo
read -p "Press [enter] when you are ready to continue. "
echo
nanoleaf_request
if [ -n "$nano_token" ]; then
  echo; echo "Nanoleaf information:"
  echo "IP address: $nano_ip"
  echo 'Access token: "'$nano_token'"'
  read -p "Would you like to save information to 'nano_info'? [y/n]" nano_create_file
  if [ "$nano_create_file" = "y" ]; then
    echo 'readonly url="http://'$nano_ip'"' > "$(pwd)/nano_info"
    echo 'readonly port="'$nano_port'"' >> "$(pwd)/nano_info"
    echo 'readonly key="'$nano_token'"' >> "$(pwd)/nano_info"
    echo "File 'nano_info' saved."
  fi
else
  echo; echo "Unable to retrieve access token."
fi