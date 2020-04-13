---
layout: post
title: Cross-compiling ROS Melodic for Raspbian (ARMv6)
date: 2019-04-13
slug: crosscompiling-ros-raspbian

keywords: [ ros, raspberry, compile ]
---

**Disclaimer: This is probably not a step by step guide because there are a lot of dependencies involved. I tried to cover all the important aspects of cross-compiling ROS or actually any other software for Raspbian and ARMv6. This is at least a proof-of-concept that compiling ROS Melodic works for ARMv6.**


This guide covers how to cross-compile ROS. This will cover some basic concepts of cross-compiling and will give some hints along the way.

Along the way you'll need to do these steps:

* Setup a Debian environment to compile for Raspbian
* Build and compile a recent toolchain to target [ARMv6](https://en.wikipedia.org/wiki/Raspberry_Pi#Pi_Zero)
* Setup and prepare a `sysroot`
* Compile and prepare ROS dependencies
* Compile ROS
* Prepare a Raspbian image for production

# Setup a Debian Environment to Compile for Raspbian

It really makes sense to cross-compile in an environment which is similar to your target. Raspbian is basically just a Debian which supports ARMv6 and therefore the Raspberry Pi 1 and Raspberry Pi Zero. There can be some confusion with the term armhf (ARM hard-float), because Debian [means the ARMv7 architecture](https://wiki.debian.org/ArmHardFloatPort).

Therefore we need to setup a Debian Stretch (That's the version Raspbian is based on currently). The best way to do this is using a chroot or docker as this could also be integrated in a automated CI environment.

So let's pull the image first:
```bash
docker pull debian:stretch
```

I prepared a folder structure for the cross-compiling. You can check it out using git:
```bash
git clone --recurse-submodules https://gitlab.com/searchwing/development/searchwing-pi-ros build_ros
```

Mount the working directory which I named `build_ros` and run the container interactively:
```bash
docker run -it --name build_ros -v "$PWD":/build_ros debian:stretch /bin/bash
```

If you want to switch to the container later just run:
```bash
docker start build_ros -i
```

# Build and Compile a Recent Toolchain to Target ARMv6

Install some general packages for compiling and the dependencies we need for ROS in the docker image.
```bash
apt install build-essential pkg-config cmake unzip gzip rsync
apt install python2.7 python-pip
pip install catkin_pkg
apt install python-rosdep python-rosinstall-generator python-wstool python-rosinstall python-empy
```
<sup>Hint: Why do I need to install `catkin_pkg` using pip?[^catkin_pkg]</sup>

To compile the tools of our toolchain we first need to compile crosstool-ng.

```bash
cd /build_ros/cross-compile
curl -O http://crosstool-ng.org/download/crosstool-ng/crosstool-ng-1.23.0.tar.xz
tar xf crosstool-ng-1.23.0.tar.xz
cd crosstool-ng-1.23.0
make -j10
make install
cd ..
```

I prepared a configuration, which is based on the [original raspberry config](https://github.com/raspberrypi/tools/blob/1169511ac73c7bb89f79df2e2465b4b80fbafd2f/configs/arm-rpi-4.9.3-linux-gnueabihf.config), for crosstool-ng which builds a GCC 6.3. Compiling ROS with an older version fails.

```bash
cd toolchain-build
ct-ng build
```

This task about 20 minutes on my machine. After that your toolchain will be in `/root/x-tools6h-new`. You can leave the terminal window with docker open for later.


# Setup and Prepare a Sysroot

*Now switch to your host and continue with the following steps.*

[Download a Raspbian image](https://www.raspberrypi.org/downloads/raspbian/) and extract it to `build_ros`.
Now you can mount in on `/mnt` and copy the needed files to `build_ros/cross-compile/sysroot`

```bash
cd /build_ros
OFFSET=$(fdisk -l 2018-11-13-raspbian-stretch-lite.img | grep "Linux" | awk '{print $2 * 512}')
mount -o ro,loop,offset=$OFFSET -t auto 2018-11-13-raspbian-stretch-lite.img /mnt
cd cross-compile
./copy-img-host.sh
umount /mnt
```

A few tweaks are needed before we can use the sysroot for compiling.
Let's start by chroot into it. You're maybe thinking right now: Hey this is an ARM image I have a x86 CPU! How dump...

But there actually is a way to do this! The feature is called [binfmt_misc](https://en.wikipedia.org/wiki/Binfmt_misc).
This allows you to just run about any binary and qemu will be used to emulate it.
The setup is quite easy. On Arch Linux you can install the package `qemu-user-static-bin` from the AUR and start the service for binfmt.

```bash
systemctl restart systemd-binfmt
```

If `ls /proc/sys/fs/binfmt_misc` shows several qemu files the setup worked.

You can now enter the chroot:
```bash
cd cross-compile
mount --bind /sys sysroot/sys
mount --bind /proc sysroot/proc
mount --bind /dev sysroot/dev
mount --bind /dev/pts sysroot/dev/pts

chroot sysroot sysroot /bin/bash
```

The first thing you need to do inside the changed root is `export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`.
Now we can run apt to install the stuff we need for compiling!
```bash
apt update
apt upgrade
apt install python2.7 python-pip
pip install rospkg catkin_pkg
apt install pkg-config python-dev sbcl libboost-all-dev libgtest-dev liblz4-dev libbz2-dev libyaml-dev python-nose python-empy python-netifaces python-defusedxml libpoco-dev
```
<sup>Hint: Why do I need to install `catkin_pkg` using pip?[^catkin_pkg]</sup>

Now you can exit the chroot and unmount all the directories you mounted previously e.g:

```bash
umount /sys sysroot/sys
umount /proc sysroot/proc
umount /dev sysroot/dev
umount /dev/pts sysroot/dev/pts
```
<sup>Hint: If a unmount fails you maybe need to unmount child directories first.</sup>

If we'd try to cross-compile ROS using that directory now it would fail because symbolic links are broken in the `sysroot`. To solve this you can do:
```bash
python sysroot-relativelinks.py sysroot/
```

Next you need to edit `./sysroot/usr/lib/arm-linux-gnueabihf/libc.so` and `./sysroot/usr/lib/arm-linux-gnueabihf/libpthread.so`.
You need to replace the absolute paths with relative ones (e.g. `/lib/arm-linux-gnueabihf/libc.so.6` becomes `libc.so.6` )
In my case this yields those two files:

`libc.so`:
```ld
OUTPUT_FORMAT(elf32-littlearm)
GROUP ( libc.so.6 libc_nonshared.a  AS_NEEDED ( ld-linux-armhf.so.3 ) )
```
`libpthread.so`:
```ld
OUTPUT_FORMAT(elf32-littlearm)
GROUP ( libpthread.so.0 libpthread_nonshared.a )
```

Now the sysroot is setup for cross compilation!


# Compile and Prepare ROS Dependencies

*Now change back to the docker image.*

cross-compile `gtest` and install it to `sysroot`.
```bash
cd /build_ros/cross-compile
cd gtest
cmake -D CMAKE_TOOLCHAIN_FILE=/build_ros/cross-compile/toolchain.cmake /build_ros/cross-compile/sysroot/usr/src/gtest
make -j10
make install DESTDIR=/build_ros/cross-compile/sysroot
cd ..
```

cross-compile `console_bridge` and install it to `sysroot`.
```bash
git clone https://github.com/ros/console_bridge
mkdir console_bridge/build
cd console_bridge/build
cmake -D CMAKE_TOOLCHAIN_FILE=/build_ros/cross-compile/toolchain.cmake /build_ros/cross-compile/console_bridge/
make -j10
make install DESTDIR=/build_ros/cross-compile/sysroot
cd ../..
```
<sup>Hint: console_bridge is not delivered though the ROS source distribution management.</sup>

cross-compile `tinyxml` and install it to `sysroot`.
```bash
mkdir tinyxml/build
cd tinyxml/build
cmake -D CMAKE_TOOLCHAIN_FILE=/build_ros/cross-compile/toolchain.cmake /build_ros/cross-compile/tinyxml/
make -j10
make install DESTDIR=/build_ros/cross-compile/sysroot
cd ../..
```
<sup>Hint: TinyXML is needed because the version [packaged in Raspbian has a bug](https://answers.ros.org/question/278733/rospack-find-throws-exception-error/).</sup>

We can now prepare the docker container for the compilation. We need to install the same dependencies in the Raspbian `sysroot` as on docker, because the build process maybe needs x86 binaries which need to be available in docker.

```bash
rosdep init
rosdep update
cd catkin
rosinstall_generator ros_comm --rosdistro melodic --deps --tar > melodic-ros_comm.rosinstall
wstool init -j8 src melodic-ros_comm-wet.rosinstall
```
<sup>Hint: `rosdep init` needs root because it creates a directory in `/etc`</sup>

The next command will install dependencies of ROS as root without using `sudo` (`--as-root apt:false`) because it is not available in the container. It will also continue if there are errors (`-r`):
```bash
rosdep install --from-paths src --ignore-src --rosdistro melodic --os=debian:stretch --as-root apt:false -y -r
```

In order to install the same dependencies in the Raspbian `sysroot` we need to copy the catkin workspace to the `sysroot`:
```bash
rsync -rap . /build_ros/cross-compile/sysroot/catkin
```

Now chroot into the `sysroot` directory like above (mount directory and export `PATH`) and install the dependencies as well:

```bash
sudo rosdep init
rosdep update
cd /catkin
rosdep install --from-paths src --ignore-src --rosdistro melodic -r --os=debian:stretch
```
<sup>Hint: It is fine if several ROS dependencies are not found. We need to compile these we well because they are not packaged.</sup>

# Compile ROS

*Switch back to the docker shell and start the compilation!*

```bash
cd /build_ros/cross-compile/catkin
./src/catkin/bin/catkin_make_isolated --install --install-space /build_ros/cross-compile/sysroot/opt/ros/melodic -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE=/build_ros/cross-compile/toolchain.cmake
```
<sup>If this fails this could be because of missing dependencies in the `.rosinstall` file.[^missing_dependencies]</sup>


## MAVROS and raspicam_node

I prepared *rosinstall* files for `mavros` and `rapicam_node` in the catkin directory with all the needed dependencies.
For convenience I grabbed the dependencies of `mavros` and `raspicam` which need to be installed in docker **AND** in the Raspbian `sysroot`.

```bash
apt install python-rosdep libgpgme-dev cmake liblog4cxx-dev libssl-dev python-numpy python-imaging python-gnupg python-coverage libpoco-dev libconsole-bridge-dev google-mock python-paramiko python-psutil libbullet-dev liburdfdom-headers-dev python-pyproj libgeographic-dev python-future libeigen3-dev python-sip-dev geographiclib-tools graphviz python-wxtools libcppunit-dev python-lxml liburdfdom-dev hddtemp libraspberrypi0 libtheora-dev libyaml-cpp-dev libgtest-dev build-essential git cmake pkg-config libtiff5-dev libjasper-dev libavcodec-dev libavformat-dev libswscale-dev libv4l-dev libgtk2.0-dev libatlas-base-dev gfortran
```

Also update the geographiclib datasets in docker **AND** the Raspbian `sysroot`.
```bash
curl -O https://raw.githubusercontent.com/mavlink/mavros/master/mavros/scripts/install_geographiclib_datasets.sh
chmod +x install_geographiclib_datasets.sh
./install_geographiclib_datasets.sh
```

You also need to compile [opencv3](https://github.com/opencv/opencv/archive/3.4.5.zip) for the Raspbian `sysroot`. Here is [how to do it](https://docs.opencv.org/3.3.0/d7/d9f/tutorial_linux_install.html) on Linux. This works similarly to the compilation of `console_bridge`. The `apt install` above already installs all the dependencies you  need.

After preparing those dependencies you should be fine by just downloading the dependencies to `catkin/src`.
```bash
cd /build_ros/cross-compile/catkin
wstool merge -t src missing-dependencies.rosinstall
wstool update -t src -j8
```

Now run the compilation again like in [Compile Ros](#compile-ros)


# Prepare a Raspbian image for Production

You have compiled now everything in the Raspbian `sysroot` directory. You should resize the original Raspbian image now and install the dependencies there again.

```bash
dd if=/dev/zero bs=1M count=1024 >> raspbian-stretch-lite-ros.img
```

Now delete partition 2 and recreate it using fdisk[^parition_resize]. The starting block of the new partition should be the same as in the previous partition.
```bash
fdisk raspbian-stretch-lite-ros.img
```

And resize the ext4 partition:
```bash
losetup -P /dev/loop0 raspbian-stretch-lite-ros.img
e2fsck -f /dev/loop0p2
resize2fs /dev/loop0p2
losetup -d /dev/loop0
```

You can now mount the root and boot partition of raspbian-stretch-lite-ros.img in `sysroot-release` and `sysroot-release/boot`.
You should also chroot into `sysroot-release` and run the `apt upgrade`.
Finally you can run install the packages again:
```
make install DESTDIR=/build_ros/cross-compile/sysroot-release
```
<sup>Note: For opencv3 you need to run `cmake -DCMAKE_INSTALL_PREFIX=/build_ros/cross-compile/sysroot-release` again to install to an other directory!</sup>

# Conclusion

We successfully compiled ROS (MAVROS and raspicam_node) in this guide. There is lot of back-and-forth by installing dependencies in docker and the Raspbian `sysroot`. Maybe sometimes this is not needed and can be skipped. This depends whether the compilation process needs binaries like `sip` which is required by MAVROS.

My original cross-compilation notes notes can be found [here](https://gitlab.com/searchwing/development/searchwing-pi-ros/blob/master/original-install-notes.md).


# Possible Problems

* You should also make sure that `PyYaml` has the version `3` in oder to avoid [this bug](https://github.com/PX4/Firmware/issues/11662).


[^catkin_pkg]: The catkin version in the Raspbian repository is outdated and does not match the version expected when building ROS. Version `0.4.11` in pip works!

[^missing_dependencies]: If this fails it is probably because of some missing ROS dependency. In this case use the generator to add the dependency to the `catkin/src` directory:
    ```bash
    rosinstall_generator $missing_dependency --rosdistro melodic --deps --tar > missing-dependencies.rosinstall
    wstool merge -t src missing-dependencies.rosinstall
    wstool update -t src -j8
    ```
    If you added new ROS dependencies you also need to run `rosdep install` again on docker **AND** in the Raspbian `sysroot` to install dependencies you need for compiling. In my case this was needed when compiling `mavros`. 

[^parition_resize]: To do this you need to run the following commands: `p d 2 n p 2 $start_sector Enter w`