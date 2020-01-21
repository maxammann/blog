---
layout: post
title: "Armbian: Encrypting the root partition"
date: 2020-01-21
slug: armbian-encrypt-root
---

The default Armbian images do not offer an encrypted root partition. Unfortunately it is requied to build the image yourself inorder to use LUKS on your root partition.


## Building Armbian

In order to build an armbian image you need to setup a VM or docker container first. After that you can build the Armbian image for a supported board of your choice. A good guide for this is found in the official docs: [Building Armbian](https://docs.armbian.com/Developer-Guide_Build-Preparation/)

A quick overview of the process is the following:

* Setup a VM and login as `root`
* Setup the tools you need for compiling
* `git clone --depth 1 https://github.com/armbian/build`
* `cd build`

We will first use a dummy-password for the luks container as you probably do not want to expose your password to the `compile.sh` script. Note that it is technically possible that the Armbian script gets a copy of the **unencrypted master key** of your LUKS container. This is all about trust like any installation tool you run for encrypting your system.
So you need to compile using the following flags which can be found in the [Build Options](https://docs.armbian.com/Developer-Guide_Build-Options/) documentation:

* `./compile.sh CRYPTROOT_ENABLE=yes CRYPTROOT_PASSPHRASE=123456 CRYPTROOT_SSH_UNLOCK=yes CRYPTROOT_SSH_UNLOCK_PORT=2222`

This basically setup the full-disk encryption and a SSH server which runs before your root parition is unlocked and mounted. You should run on a different port than 22 as the server SSH server in the initram and in the root filesystem use different server keys.

A GUI should open which allows you to choose the board, kernel version and other options. Choose to build an image if the setup asks you. After approx. 30 minutes you should have an `Armbian_\*.img` and `Armbian_\*.key` file in `output/images`.

## Changing the password of the LUKS container

After generating the image and copying it to your trustworthy host system you can change the password by binding the paritions of the `Armbian_\*.img` file to loopback devices:

* `kpartx -v -a Armbian_*.img`
* `cryptsetup luksAddKey /dev/mapper/loop0p2`
* `cryptsetup luksRemoveKey /dev/mapper/loop0p2`
* `cryptsetup luksDump /dev/mapper/loop0p2`
* `kpartx -d Armbian_*.img`

Now you added a new key slot and removed the previous one.

## Booting the encrypted system

When you boot up your embedded system a dropbear SSH server is started on port 2222. You can use the `Armbian_\*.key` to login as root:

* `ssh root@192.168.123.123 -p2222 -i Armbian_*.key`
* Enter `cryptroot-unlock` in the SSH session to unlock the root partition and continue booting.

Finally you can login on your embedded system using as usual (default credentials are root:1234):

* `ssh root@192.168.123.123`

## Add an authorized key

In order to login using different SSH keys to unlock your root parition you can add your public key to `/etc/dropbear-initramfs/authorized_keys`. After that you need to update your initramfs:

* `update-initramfs -u`

After a reboot you should be able to login with your SSH key instead of the previous `Armbian_\*.key` file.

