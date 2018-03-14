## nanoleaf-cli

A basic script to interface with your light panel Nanoleaf lights. I made this to use with Home Assistant and Hassio to ensure I will always have access to my lights.

You will need to enter your Nanoleaf light panel URL, port and API key before using. This script will interact with your light panel as well as your Home Assistant installation if you enter in your URL, password, and create entities to interact with.

To interact with your Home Assistant install you will need to create an Input Select entity for the light panel effects as well as an Input Number to contain the brightness.

If you need to get your Nanoleaf light panel access key you can use one of the scripts in the repository if you are running Hassio (like myself) use the nano_hass.sh otherwise if you have nmap you can use nano_nmap.sh. No guarantees they will work for you but they work great for me.

Usage:

nano.sh [-p on/off] [-b 0-100] [-e "Effect Name"] [-u] [-l] [-d "display file name/animData"] [-a "Effect Name" number of seconds]

  * 'on'/'off' sets the power state of the light panel lights.

  * '0-100' to set the brightness of the light panel lights in percentage.
  
  * "Effect Name" to set the light panel scene. Scene name must be enclosed in double quotes and match the spelling in the Nanoleaf app.

-b(rightness) [0-100]

  * returns brightness in a decimal between 0-100 or with optional integer argument can set brightness from 0 to 100, i.e. 'nano.sh -b 50'
  

-p(ower)

  * return power state as 'on' or 'off' or can set power state with optional argument of on or off, 'nano.sh -p on'

-e(ffect)

  * return current effect name or can set effect to optional argument, 'nano.sh -e "Flames"'

-l(ist)

  * return list of all installed scenes, 'nano.sh -l'

-u(pdate)

  * Updates the effects list in your Home Assistant and sets the current effect, 'nano.sh -u'

-a(lert) "effect name" "number of seconds"

  * Creates an alert setting the light panels to the provided effect for a set number of seconds, 'nano.sh "Sand" 10'

-d(isplay) "animData or display name"

  * Sets the light panels to information provided by animData passed to the command or a name matching a saved animData to the 'display' file.

### Examples:

nano.sh -p

* Returns on or off based on power status

nano.sh -b 70

* Sets lights to 70% brightness

nano.sh -u

* Updates the effects list, brightness, current effect and power status in Home Assistant and displays information in the terminal.

nano.sh -d sunny

* Displays the animData corresponding to the sunny line in the display file.

