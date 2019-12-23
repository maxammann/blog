---
layout: post
title: "Lenovo T490: Using the new Synaptics firmware for the Fingerprint Reader"
date: 2019-12-23
slug: t490-fingerprint
---

The firmware and drivers for the Fingerprint Reader for Linux are finally ready [as promised a few months ago](https://forums.lenovo.com/t5/Other-Linux-Discussions/Linux-on-T495/m-p/4474320#M13440). I'm not sure whether this was an accomplishment of Lenovo of [the open-source community](https://gitlab.freedesktop.org/libfprint/libfprint/issues/181) ¯\_(ツ)_/¯.
I suggest to wait until the frimware reached a stable state. But if you are feeling adventurous you can get it working right now!

You can check whether you have the reader I'm talking about by using `lsusb`. Make sure to have a device with the id `06cb:00bd`.

# Installing the latest fimrware

You have the install the following two firmwares from LVFS:
  * [Synaptics Inc. Prometheus Fingerprint Reader](https://fwupd.org/lvfs/devices/com.synaptics.prometheus.firmware)
  * [Synaptics Inc. Prometheus Fingerprint Reader Configuration](https://fwupd.org/lvfs/devices/com.synaptics.prometheus.config)


You can install these using `fwupdmgr install <fw.cab>` or enable the testing remote using `fwupdmgr enable-remote lvfs-testing` as root user.
Power off your laptop and start it again.

# Getting the lastest libfprint

The `libfprint` which is packaged for most distributions is not ready for the firmwares yet. You can clone the latest `libfprint` though to communicate with the fingerprint reader:
* `git clone https://gitlab.freedesktop.org/libfprint/libfprint.git`
* `git checkout b8e558452a97ac5cd026456b4e5a514d628b6747`
* `cd libfprint && meson builddir`
* `cd builddir && ninja`

You now use `examples/enroll` and `examples/verify` to test your fingerprint reader! The latest version of this library and its daemon is also packaged on Arch Linux: [fprintd-libfprint2](https://aur.archlinux.org/packages/fprintd-libfprint2/) and [libfprint-git](https://aur.archlinux.org/packages/libfprint-git/)
