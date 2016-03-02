#!/bin/sh
#
# CPU Load Meter for NU801 Devices
# Copyright (C) 2016 Chris Blake <chrisrblake93@gmail.com>
#

# Do we want to log debug output to a file?
#LOGFILE=/tmp/nu801-load.log

# Enable this to output debug info to console when ran
#DEBUG=1

# How often do we update? (in seconds)
REFRESH=5

##################################
### Start Function Definitions ###
##################################

# Used for printing debug output & logging to file
PrintDebug() {
	OUTPUT="DEBUG: $@"
	if [ "$DEBUG" ]; then
		echo "$OUTPUT"
	fi
	if [ "$LOGFILE" ]; then
		echo "$OUTPUT" >> "$LOGFILE"
	fi
}

# Used to search for a NU801 on the board
NU801Scan() {
	if [ -d "/sys/devices/platform/leds-nu801" ]; then
		return 1
	else
		return 0
	fi
}

# Used to set the triggers on all NU801 LEDs
NU801SetTrigger() {
	board=$1
	trigger=$2
	for color in red green blue
	do
	  PrintDebug "NU801SetTrigger() setting $color to trigger $trigger"
	  echo "$trigger" > /sys/class/leds/$board:$color:tricolor0/trigger
	done
}

# Used to manually set a brightness to all LEDs
NU801SetBrightness() {
	board=$1
	value=$2
	for color in red green blue
	do
	  PrintDebug "NU801SetBrightness() setting $color to $value"
	  echo "$value" > /sys/class/leds/$board:$color:tricolor0/brightness
	done
}

# Used to take a CPU load, convert to color, and set said color
NU801SetLoadColor() {
	board=$1
	load=$(echo $2 | sed 's/\.//g')

	PrintDebug "NU801SetLoadColor() CPU is at $load%"
	# So plan is to have Load work as follows
	# B -> G -> R

	# Will do a fade as we go, so for example:
	# CPU 0% = B=100,G=0,R=0
	# CPU 25% = 100,100,0
	# CPU 50% = 0,100,0
	# CPU 75% = 0,100,100
	# CPU 100% = 0,0,100

	# Used to set the color options
	BLUE="0"
	GREEN="0"
	RED="0"

	# In each bracket there is 10.2~ between 0 and 255, so we round this to 10
	if [ "$load" -le "025" ]; then
		BLUE="255"
		GREEN="$(expr $load \* 10)"
	elif [ "$load" -ge "025" ] && [ "$load" -lt "050" ]; then
		load=$(expr $load - 25) # Do this to reset to base scale
		BLUE="$(expr 255 - $(expr $load \* 10))"
		GREEN="255"
	elif [ "$load" -ge "050" ] && [ "$load" -lt "075" ]; then
		load=$(expr $load - 50) # Do this to reset to base scale
		GREEN="255"
		RED="$(expr $load \* 10)"
	elif [ "$load" -ge "075" ] && [ "$load" -lt "100" ]; then
		load=$(expr $load - 75) # Do this to reset to base scale
		GREEN="$(expr 255 - $(expr $load \* 10))"
		RED="255"
	else
		# We are 100%+
		RED="255"
	fi

	# Set our new values
	PrintDebug "NU801SetLoadColor() setting G,B,R to $GREEN,$BLUE,$RED"
	echo "$BLUE" > /sys/class/leds/$board:blue:tricolor0/brightness
	echo "$GREEN" > /sys/class/leds/$board:green:tricolor0/brightness
	echo "$RED" > /sys/class/leds/$board:red:tricolor0/brightness
}

####################
### Start script ###
####################

PrintDebug "Starting CPU Load LED Script!"

# Set board name
BOARDNAME=$(cat /tmp/sysinfo/board_name)

# Do we have an NU801?
NU801Scan && PrintDebug "LED's not found on platform $BOARDNAME!" && exit 1

# LEDs are found, let's reset any active triggers so we own the LEDs
NU801SetTrigger "$BOARDNAME" "none"
NU801SetBrightness "$BOARDNAME" "0"

# Are we in test mode? If so, go through the colors
if [ "$1" == "test" ]; then
	PrintDebug "Entering Test Mode!"
	while true; do
		for i in $(seq 0 100); do
			NU801SetLoadColor "$BOARDNAME" "$i"
		done
		for i in $(seq 99 -1 1); do
			NU801SetLoadColor "$BOARDNAME" "$i"
		done
	done
fi

# Start the service in a infinite loop
while true; do
	# Send CPU load to set function
	NU801SetLoadColor "$BOARDNAME" "$(cat /proc/loadavg | awk '{ print $1 }')"
	# sleep like we are suppose to
	sleep $REFRESH
done
