---
layout: post
title: "Routing network of docker container over a specific host interface like a VPN"
date: 2020-04-02
slug: routing-docker-container-over-vpn

resources:
- src: "*.jpg"

keywords: [ vpn, docker, routing]
---

A docker setup can be very helpful when trying to separate services if they are not packaged otherwise.
We don't only want to separate configuration in this post, but also the network configuration.

As docker has its own network stack we can route the traffic from containers. Usually it is difficult to tell a specific process to use only a specific interface. Most of the time a proxy within the Virtual Private Network is [used to achieve this](https://mullvad.net/en/help/socks5-proxy/). This has also the benefit that, if the network interface does down and the routing rules are reset, then the traffic is not sent though some other default interface.


In this post we take the "proxy idea" to the next level. We will route the traffic of a whole docker container though a specific interface. If the interface goes down then the docker container is not allowed to communicate through any other interface.

# Configuration of docker

First configure docker such that it does not get into our way in `/etc/docker/daemon.json`:

```json
{
    "dns": ["1.1.1.1"]
}
```

Depending on your docker setup you may not need this.

# Configuration of docker network

First we create a new docker network such that we can use proper interface names in our configuration and previously installed containers are not affected.

```bash
docker network create \
            -d bridge \
            -o 'com.docker.network.bridge.name'='vpn' \
            --subnet=172.18.0.1/16 vpn
```

The `network create` action creates a new interface on the host with `172.18.0.1/16` as subnet. It will be called `vpn` within docker and Linux. 
You can validate the settings by checking `ip a`:

```text
2: vpn: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default 
    link/ether 02:42:d8:16:bd:f4 brd ff:ff:ff:ff:ff:ff
    inet 172.18.0.1/16 brd 172.18.255.255 scope global vpn
       valid_lft forever preferred_lft forever
    inet6 fe80::42:d8ff:fe16:bdf4/64 scope link 
       valid_lft forever preferred_lft forever
```

The docker host gets the IP `172.18.0.1`.

# Setting up a docker container

Next we will create docker contains within the created subnet.
```bash
docker pull ubuntu
docker create \
            --name=network_jail \
            --network vpn \
            --ip 172.18.0.2 \
            -t -i \
            ubuntu
```

Now lets chroot into the container:

```bash
docker start -i network_jail
apt update && apt install curl iproute2
ip a
```

and look at the configuration:

```text
67: eth0@if68: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default 
    link/ether 02:42:ac:12:00:02 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 172.18.0.2/16 brd 172.18.255.255 scope global eth0
       valid_lft forever preferred_lft forever
```

We can also test the connection to the internet with `curl -4 ifconfig.co`.


# Routing a docker container through a OpenVPN network

The next step is to setup the routes which traffic from 172.18.0.0/16 through a vpn. We use OpenVPN here as it is wildly used. OpenVPN offers a way to setup routes with a `--up` and `--down` script. First we tell OpenVPN not to mess with the routing in any way with `pull-filter ignore redirect-gateway`. Here is a sample OpenVPN config to use with this setup:

```plain {hl_lines=[9,"11-12"]}
client
dev tun0
proto udp
remote example.com 1194

auth-user-pass /etc/openvpn/client/auth
auth-retry nointeract

pull-filter ignore redirect-gateway
script-security 3 
up /etc/openvpn/client/vpn-up.sh
down /etc/openvpn/client/vpn-down.sh
```

The `vpn-up.sh` script has several parameters.

| Pararmeter | Description | Example |
|---|---|---|
| `docker_net` | The vpn docker subnet | `172.18.0.0/16` |
| `local_net`  | Some local network you want to route over eth0 | `192.168.178.0/24` |
| `local_gateway`  | The gateway of the local network | `192.168.178.1` |
| `trusted_ip`  | Set by OpenVPN to the IP of the OpenVPN endpoint | `11.11.11.11` |
| `dev`  | Set by OpenVPN to OpenVPN interface | `tun0` |

Note that `eth0` is used here as interface over which OpenVPN makes a connection. Furthermore in my setup a private LAN is behind `eth0`.

```sh {hl_lines=[8,"14-15", "18-19", "21-22", "27-29", "31-32", "34-35"]}
#!/bin/sh
docker_net=172.18.0.0/16
local_net=192.168.178.0/24
local_gateway=192.168.178.1

# Checks to see if there is an IP routing table named 'vpn', create if missing
if [ $(cat /etc/iproute2/rt_tables | grep vpn | wc -l) -eq 0 ]; then
	echo "100     vpn" >> /etc/iproute2/rt_tables
fi

# Remove any previous routes in the 'vpn' routing table
/bin/ip rule | /bin/sed -n 's/.*\(from[ \t]*[0-9\.\/]*\).*vpn/\1/p' | while read RULE
    do
	    /bin/ip rule del ${RULE}
	    /bin/ip route flush table vpn 
    done

    # Add route to the VPN endpoint
    /bin/ip route add $trusted_ip via dev eth0

    # Traffic coming FROM the docker network should go thought he vpn table
    /bin/ip rule add from ${docker_net} lookup vpn

    # Uncomment this if you want to have a default route for the VPN
    # /bin/ip route add default dev ${dev} table vpn

    # Needed for OpenVPN to work
    /bin/ip route add 0.0.0.0/1 dev ${dev} table vpn
    /bin/ip route add 128.0.0.0/1 dev ${dev} table vpn

    # Local traffic should go through eth0
    /bin/ip route add $local_net dev eth0 table vpn

    # Traffic to docker network should go to docker vpn network 
    /bin/ip route add $docker_net dev vpn table vpn

    exit 0
```
<sup>Credits go to [0xacab](https://0xacab.org/snippets/3)</sup>

Here is the explanation for the rules:

| Lines | Explanation | 
|---|---|
| 8 | Creates a tables for packets coming from the docker `vpn` network |
| 14-15 | Resets all the rules coming below by flushing the table |
| 18-19 | Route packets to the OpenVPN endpoint over `eth0`  |
| 21-22 | Route packets coming from the docker `vpn` to the vpn table |
| 27-29 | This is a trick by OpenVPN to get highest priority. [^priority]  |
| 34-35 | Route packets going to docker network to the docker network |

By leaving line 25 commented we only routing traffic from the docker vpn network over the OpenVPN.

The `down.sh` script removes the `$trusted_ip` which was added during setup.

```bash
#!/bin/bash

local_gateway=192.168.178.1

/bin/ip route del $trusted_ip via $local_gateway dev eth0
```

# Setup IPtables to reject packages which fallback to another interface 

Finally, we want to avoid that packets go over over the `eth0` interface if the OpenVPN on `tun0` is down.

```bash
#!/bin/bash
local_network=192.168.178.0/24

iptables -I DOCKER-USER -i vpn ! -o tun0 -j REJECT --reject-with icmp-port-unreachable
iptables -I DOCKER-USER -i vpn -o vpn -j ACCEPT 
iptables -I DOCKER-USER -i vpn -d $local_network -j ACCEPT 
iptables -I DOCKER-USER -s $local_network -o vpn -j ACCEPT
iptables -I DOCKER-USER -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
```

Basically what this script says is that if traffic is coming from `vpn` and is routed through `tun0` then reject it. Traffic between `vpn` and `vpn` is allowed. Traffic to and from the local network is also allowed. The last line is needed such that existing connections are accepted. 

These rules usually live at `/etc/iptables/rules.v4`.


Running `curl -4 ifconfig.co` inside the container should now show the IP you have when tunneling your traffic through the VPN. If the OpenVPN process is stopped then the `curl` should timeout.

## What is DOCKER-USER?

IPtables rules are a bit of a pain with docker. Docker overwrites the iptables configuration when it starts. So if you want to add rules to the `FORWARD` chain you have to add the rules to `DOCKER-USER` instead such that they are not overwritten. You can read [more about this](https://docs.docker.com/network/iptables/) in the manual. Basically we are acting here like a router. A IPtables rule like `iptables -I DOCKER-USER -i src_if -o dst_if -j REJECT` describes how packets are allowed to flow. We are restricting this to a flow between `vpn` ↔ `tun0`.

If you want to have a network configuration which does not change you should set `"iptables": false` in `/etc/docker/daemon.json`. That way docker does not touch the IPtables rules. Before doing this I first copied the rules from IPtables when all containers are running. After stopping docker and setting the option to `false` I started the container again and applied the copied rules manually again.

# Why does this work?

When researching how to do this I sometimes has to lookup how routing and filtering actually works on Linux. Some tries by myself were based on marking packets coming from a specific process and then rejecting them if they are not flowing where they should. A further naive idea is to use the [IPtables owner module](http://ipset.netfilter.org/iptables-extensions.man.html) with `--uid-owner` (`iptables -m owner --help`). This does not work with docker though because packets from docker never go though the `INPUT`, Routing Decision and `OUTPUT` chain as seen in the figure below.

{{< resourceFigure "routing-decisions.jpg" "Flow-chart of the packets in the Linux kernel" "400px" />}}
<sup>Source: https://askubuntu.com/questions/579231/whats-the-difference-between-prerouting-and-forward-in-iptables</sup>

The packets from docker only go through `PREROUTING`, Routing Decision, `FORWARD`, Routing Decision, `POSTROUTING`. The best point to filter packets is at the `FORWARD`/`DOCKER-USER` chain as we can see from where the packet is coming and where it is going. Filtering by processes only works in the left part of the figure where the concept of Local Processes exists.

# References

* [Good post about routing tables.](https://kindlund.wordpress.com/2007/11/19/configuring-multiple-default-routes-in-linux/)
* If you are interested in WireGuard you can read [here](https://nbsoftsolutions.com/blog/routing-select-docker-containers-through-wireguard-vpn) more.

# Further noes

[^priority]: 

    > It's just a clever hack/trick. 
    >
    > There’s actually TWO important extra routes the VPN adds: 
    >
    > 128.0.0.0/128.0.0.0 (covers 0.0.0.0 thru 127.255.255.255) 
    > 0.0.0.0/128.0.0.0 (covers 128.0.0.0 thru 255.255.255.255) 
    >
    > The reason this works is because when it comes to routing, a more specific route is always preferred over a more general route. And 0.0.0.0/0.0.0.0 (the default gateway) is as general as it gets. But if we insert the above two routes, the fact they are more specific means one of them will always be chosen before 0.0.0.0/0.0.0.0 since those two routes still cover the entire IP spectrum (0.0.0.0 thru 255.255.255.255). 
    > 
    > VPNs do this to avoid messing w/ existing routes. They don’t need to delete anything that was already there, or even examine the routing table. They just add their own routes when the VPN comes up, and remove them when the VPN is shutdown. Simple.


    <sup>Source: http://www.dd-wrt.com/phpBB2/viewtopic.php?t=277001</sup>