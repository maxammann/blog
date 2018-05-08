---
layout: post
title: "pfSense: Installing on an APUC4"
published: true
---



# Preparation

## Hardware requirements

* An USB stick (2.0 or 3.0 should work both)
* RS232 serial to USB adaptor (chipset PL2303 works fine on linux) (I went with [this](http://www.ugreen.com.cn/product-681-en.html))
* RS232 null modem cable D-Sub (I went with [this](https://www.ebay.de/itm/RS-232-Nullmodem-Kabel-9-polig-D-Sub-1-5m-Lila-Grundpreis-1-33-m/251064020240))
* [APU2C4](https://www.pcengines.ch/apu2c4.htm). I could not get this to work on ALIX devices.

## Software requirements
* dd on linux
* A serial AMD64 pfSense memstick installer image from [here](https://www.pfsense.org/download/)

# Installation
1. First copy the image to your USB stick:
``
gunzip -c pfSense-CE-memstick-serial-***-RELEASE-amd64.img.gz | sudo dd of=/dev/sdx
``
2. Plug the USB stick in the APU2C4.
3. Next connect the null modem cable from the APU2C4 to the serial adaptor and to your pc
4. Unplug the APU2C4 from power.
5. Start screen to connect to the serial device:
``
screen /dev/ttyUSB0 115200 8N1
``.
Because the APU2C4 is disconnected from power you should see a blank screen.
6. Power up the APU2C4 and press F10.
7. You should see now the bootloader and should be able to boot from usb.
8. The installation setup is straight forward and should take approximately 5-10 minutes.
9. After the installation pfSense asks you to reboot. Unplug the USB and answer `yes`.

pfSense is now successfully installed and you can access the web interface by connecting to the LAN port (just try-and-error) and login with `admin` and `pfsense` as password.

The nano-bsd and i386 images are deprecated and shouldn't be used. Better replace your old ALIX with on the of the new APU2 ones :)
