---
layout: post
title: "Auto-connect to ADB Wireless Debugging on Android 11"
date: 2022-01-03T16:00:00+01:00
slug: android11-adb-automatic
draft: false
wip: false

resources:
- src: "*.png"
- src: "*.jpg"

keywords: [ ]
categories: [ ]
---

## Background

With Android 11 the method for connecting to Android phones via ADB over the network [has changed](https://developer.android.com/studio/command-line/adb#connect-to-a-device-over-wi-fi-android-11+). Unfortunately, the new method requires to know the port on which the ADB service on the phone is running. 

I suspect that this was introduced as a security by obscurity feature. Even if, an attacker has a whitelisted key which allows debugging via ADB, she still has to know the TCP port on which ADB is running on the phone. The usual way to get this port number is to have physical contact with the phone and read it from the screen.
This offers a wrong sense of security. You still should not blindly accept any connection requests on your phone from ADB.
In fact, it takes less than 10 seconds to scan the range of possible ports.


## Port Scanning

The following `nmap` command scans the specified host. By observing which ports are usually used by ADB I discovered that the range 37000 to port 44000 should be sufficient. At least I haven't had a single port which was outside this range in the last year.

```bash
sudo nmap $IP -p 37000-44000 --defeat-rst-ratelimit
```

The flag `--defeat-rst-ratelimit` increases performance by not distinguishing between closed and filtered ports. In fact, we are only looking for open ports. By executing this command with root privileges nmap can utilize a faster scanning method.

## One-liner

In order to connect to an open ADB session wirelessly to your Android phone you can use the following one-liner. It usually takes less than 10s to connect to your phone.

```bash
IP=192.168.178.15 bash -c 'adb connect $IP:$(sudo nmap $IP -p 37000-44000 -sS -oG - --defeat-rst-ratelimit | awk "/open/{print \$5}" | cut -d/ -f1)'
```

That way you no longer have to read and copy the port from your Android phone. You can just enable wireless debugging and execute the command above.