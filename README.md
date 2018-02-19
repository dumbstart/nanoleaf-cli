## nanoleaf-cli

A basic script to interface with your Aurora Nanoleaf lights. I made this to use with Home Assistant and Hassio to ensure I will always have access to my lights.

You will need to enter your Nanoleaf Aurora URL, port and API key before using. This script will interact with your Aurora as well as your Home Assistant installation if you enter in your URL, password, and create entities to interact with.

To interact with your Home Assistant install you will need to create an Input Select entity for the Aurora effects as well as an Input Number to contain the brightness.

Usage:

nano.sh [-s on/off/0-100/"Effect Name"]/[-b]/[-p]/[-e]/[-l]/[-u]

-s(et):

  * 'on'/'off' sets the power state of the Aurora lights.

  * '0-100' to set the brightness of the Aurora lights in percentage.
  
  * "Effect Name" to set the Aurora scene. Scene name must be enclosed in double quotes and match the spelling in the Nanoleaf app.

-b(rightness)

  * returns brightness in a decimal between 0-100

-p(ower)

  * return power state as 'on' or 'off'

-e(ffect)

  * return current scene name as found in the Nanoleaf app

-l(ist)

  * return list of all installed scenes

-u(pdate)

  * Updates the effects list in your Home Assistant and sets the current effect.


### Examples:

nano.sh -p

* Returns on or off based on power status

nano.sh -s 70

* Sets lights to 70% brightness

nano.sh -s "Flames"

* Activates Flames theme on your Nanoleaf Aurora lights

nano.sh -u

* Updates the effects list, brightness, current effect and power status in Home Assistant. This has no use if you are only managing it from the command line.

