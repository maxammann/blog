---
layout: post
title: "Shorewall: Shape traffic for daily computing"
published: true
---

*Shorewall is an open source firewall tool for Linux that builds upon the Netfilter (iptables/ipchains) system built into the Linux kernel, making it easier to manage more complex configuration schemes by providing a higher level of abstraction for describing rules using text files.*

# Problem

For some reason my connection was completly stuffed while downloading large files with full speed. Aparently this happend after my upgrade to a **Intel® Ethernet Connection I218-V** network card. I'm not exactly sure whether traffic shaping is somehow hardware supported or just enabled on the driver side, but I had serious troubles.
While downloads were running my Skype call dropped. I lost the connection to the Teamspeak and was unable to load any more **http** traffic.

# Solution

So I look for these so called ["traffic shapers"](https://en.wikipedia.org/wiki/Traffic_shaping) and was a bit confused first as it seems overly complex. The linux kernel already supports traffic shaping but it's not that easy to [configure](https://wiki.archlinux.org/index.php/Advanced_traffic_control).



