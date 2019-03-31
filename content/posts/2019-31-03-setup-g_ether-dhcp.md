---
layout: post
title: "Setup the ethernet gadget of PI Zero with dnsmasq"
date: 2019-03-31
---

Sometimes it makes sense to connect to the PI Zero by using the g_ether kernel module. This
connection is way more reliable than the WiFi connection in certain environments.

The setup is quite simple. dnsmasq will provide a local DHCP and DNS server.

- echo "dtoverlay=dwc2" | sudo tee -a /boot/config.txt 
- Edit `/boot/cmdline.txt` and add `modules-load=dwc2,g_ether` after `rootwait`
- `sudo apt install dnsmasq`
- Edit `/etc/network/interfaces` and add the following:
  ```
  auto usb0
  iface usb0 inet static
      address 192.168.44.1/24
  ```
- Edit /etc/dnsmasq.conf and add the following:
- `sudo systemctl enable --now dnsmasq`
  ```
  listen-address=192.168.44.1
  dhcp-range=192.168.44.10,192.168.44.20,12h
  ```

After a reboot of the PI you should see that the Ethernet Gadget on the connected USB host.

If you have trouble connecting it check the following:
- Did you use the correct USB port on the PI Zero? Only one offers the possiblity to transfere data.
- Try to reload the kernel module: `sudo modprobe -r g_ether && sudo modprobe g_ether`
- Is a firewall on the PI blocking the DHCP client?


##### Additional information on OTG:

- [HowToOTG.md](https://gist.github.com/gbaman/50b6cca61dd1c3f88f41)

