# nanoleaf-cli

A basic script to interface with your Aurora Nanoleaf lights. I made this to use with Home Assistant and Hassio to ensure I will always have access to my lights.

You will need to enter your Nanoleaf Aurora url, port and key before using. You will also need to enter your Home Assistant URL, password and entity_id for your input_select of Nanoleaf Aurora effects.

Usage:

nano.sh [-s off on in out # effect] [-g power brightness effect] [-f in out] [-b] [-p] [-e] [-l]

-s(et):

  'off' turn off
  
  'on' turn on
  
  'in' fade in
  
  'out' fade out
  
  '##' set brightness
  
  'effect' set the theme

-g(et)

  'power' return power state
  
  'brightness' return brightness
  
  'effect' return effect

-f(ade)

  'in' fade in to 100% brightness
  
  'out' fade out to 0% brightness

-b(rightness)

  return brightness

-p(ower)

  return power state

-e(ffect)

  return current effect

-l(ist)

  return list of available effects


You will need to get the IP address, port number, and key before using this script.
