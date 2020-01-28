---
layout: post
title: "APU: Flash Coreboot on APUs using Tiny Core Linux"
date: 2020-01-28
slug: flash-apu-using-tinycore
---

The documentation about setting up Tiny Core Linux to flash a new coreboot version on APU boards is quite outdated.

# Setup Tiny Core Linux on a USB stick

First you need to setup a MSDOS partition table using `fdisk`.

* `fdisk /dev/sdX`

Press 'o' in the menu in order to setup the partition table. After that press 'n' to create a new partition. Then press 'a' to make the partition boottable. 


The next step is to install the syslinux bootloader using your package manager. Then setup the bootloader on the USB stick:

* `syslinux -if /dev/sda1`

After that you need to copy the MBR record:

* `dd conv=notrunc bs=440 count=1 if=/usr/lib/syslinux/bios/mbr.bin of=/dev/sda`

Finally download Tiny Core Linux from pcengines.ch:

* `curl -O http://pcengines.ch/file/apu_tinycore.tar.bz2`

and extract it on the USB stick. Finally download the coreboot image you want to flash from [pcengines.github.io](https://pcengines.github.io/) and also extract it on the stick.

# Flashing the coreboot image

After booting from the USB stick you can flash the firmware using [this guide](https://github.com/pcengines/apu2-documentation/blob/50f7e37d2301cfec232f4e5684160be53481ea9e/docs/firmware_flashing.md).
