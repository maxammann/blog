---
layout: post
title: "Docking Rule for ThinkPad Thunderbolt 3 Dock Gen 2"
date: 2020-04-11
slug: thinkpad-dock-multi-monitor

resources:
- src: "*.jpg"

keywords: [ thinkpad, udev, linux, multimonitor ]
---


It is very convenient to switch between different monitor layouts when using a laptop with multiple external monitors.
A very good guide can be found on [GitHub Gist by seanf](https://web.archive.org/web/20200411145137/https://gist.github.com/seanf/e3be5bf745395d50e975).
This post should contain the necessary information for getting it to work on a ThinkPad Thunderbolt Dock.

# Udev Hook for Triggering the Switch

Fist create a new udev rule at `/etc/udev/rules.d/81-thinkpad-dock.rules`:

```sh
SUBSYSTEM=="input", ACTION=="add|remove", ENV{ID_VENDOR_ID}=="17ef", ENV{ID_MODEL_ID}=="3083", TAGS=="power-switch", RUN+="/etc/sbin/thinkpad-dock.sh"
```

Now reload the udev rules using `sudo udevadm control --reload-rules && sudo udevadm trigger`.

The rule triggers the script as soon as the power button on the dock is recognized.

# Script for Switching Between Layouts

The following snippet shows the script I'm using. Therefore, you have to change the `username` variable. You may have to adjust the `sleep` delays manually. There is currently no way to determine when the dock is ready to switch on the external monitors.

```sh
#!/bin/sh -e

# Save this file as /etc/sbin/thinkpad-dock.sh

# NB: you will need to modify the username and tweak the xrandr
# commands to suit your setup.

# wait for the dock state to change
sleep 1

username=max

if [[ "$ACTION" == "add" ]]; then
  DOCKED=1
  logger -t DOCKING "Detected condition: docked"
elif [[ "$ACTION" == "remove" ]]; then
  DOCKED=0
  logger -t DOCKING "Detected condition: un-docked"
else
  logger -t DOCKING "Detected condition: unknown"
  echo Please set env var \$ACTION to 'add' or 'remove'
  exit 1
fi


function switch_to_local {
  export DISPLAY=$1

  su $username -c '
	xrandr --output eDP1 --auto --primary \
		--output HDMI1 --off \
		--output HDMI2 --off \
		--output DP1 --off \
		--output DP2 --off \
		--output DP2-1 --off \
		--output DP2-2 --off \
		--output DP2-3 --off
    '
}

function switch_to_external {
  export DISPLAY=$1

  su $username -c '
	xrandr --output eDP1 --off --primary \
		--output HDMI1 --off \
		--output HDMI2 --off \
		--output DP1 --off --output DP2 --off \
		--output DP2-1 --off \
		--output DP2-2 --primary --auto \
		--output DP2-3 --off
   '

 sleep 1 
  
  su $username -c '
	xrandr --output eDP1 --off \
		--output HDMI1 --off --output HDMI2 --off \
		--output DP1 --off --output DP2 --off \
		--output DP2-1 --off --output DP2-2 --auto \
		--output DP2-3 --right-of DP2-2 --auto
  '

# Switching both external monitors at once can cause "Configure crtc 2 failed"
#  su $username -c '
#	xrandr --output eDP1 --off --primary \
#		--output HDMI1 --off \
#		--output HDMI2 --off \
#		--output DP1 --off --output DP2 --off \
#		--output DP2-1 --off \
#		--output DP2-2 --primary --crtc 1 --mode 1920x1080 --pos 0x0 \
#		--output DP2-3 --right-of DP2-2 --crtc 0 --mode 1920x1080 --pos 1920x0
#	'
}

case "$DOCKED" in
  "0")
    #undocked event
    switch_to_local :0 ;;
  "1")
    #docked event
    switch_to_external :0 ;;
esac
```

If you are using systemd then you can view the logged messages using `journalctl -t DOCKING`.
Note that I'm running `xrandr` twice as I have two external monitors. Switching them in one command causes the error `Configure crtc 2 failed`. I was not able to circumvent this reliably.

It is possible to test the script using:

```bash
ACTION=add /etc/sbin/thinkpad-dock.sh
```
and: 

```bash
ACTION=remove /etc/sbin/thinkpad-dock.sh
```
