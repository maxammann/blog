---
layout: post
title: "Installing ROS on virtual Raspberry PI Zero"
date: 2019-03-31
---

**This post represents a slow way to compile ROS. In a [new post]({{< ref "2019-04-13-crosscompiling-ros-raspbian" >}}) I show how to crosscompile ROS."

This post should guide you through the process of compiling ROS on a virtualized Raspberry PI Zero.

# Setup virtual Raspberry PI Zero with QEMU

Start by checking out the repo of a custom kernel for qemu:
```bash
 git clone https://github.com/dhruvvyas90/qemu-rpi-kernel
```

Next download the latest [Raspbian Image](https://www.raspberrypi.org/downloads/raspbian/).
It is advised to create a qemu image of the extracted image:
```bash
 qemu-img convert -f raw -O qcow2 2018-11-13-raspbian-stretch-lite.img raspbian-stretch-lite.qcow
```

You can resize the image by running `qemu-img convert -f raw -O qcow2 2018-11-13-raspbian-stretch-lite.img raspbian-stretch-lite.qcow`.
This will not resize the root partition! You'll have to do this later by using `raspi-config` or doing it manually.


That's all! Now you can start the virtual PI by running:
```bash
qemu-system-arm \ 
  -M versatilepb \ 
  -cpu arm1176 -smp 1 \ 
  -m 256 -net nic -net user \ 
  -hda raspbian-stretch-lite.qcow \ 
  -dtb qemu-rpi-kernel/versatile-pb.dtb  \ 
  -kernel qemu-rpi-kernel/kernel-qemu-4.14.79-stretch \ 
  -append 'root=/dev/sda2 panic=1' \ 
  -no-reboot
```
Please note that you can not use more than 256MB of RAM and only one core.

Login with pi:raspberry and you should have a working PI with access to the internet like the host.

To install ROS you basically have to follow [this guide](http://wiki.ros.org/melodic/Installation/Source).
A TLDR version is the following:

* `sudo apt install python-pip`
* `sudo pip install -U catkin_pkg`\\
  Note: This is not recommended because packages installed by pip
  override those from apt. In this case we need to do this because the version provided by apt is
  [not working](https://github.com/ros/catkin/issues/956)
* `sudo apt install python-rosdep python-rosinstall-generator python-wstool python-rosinstall build-essential`
* `sudo rosdep init`
* `rosdep update`
* `mkdir ~/ros_catkin_ws`
* `cd ~/ros_catkin_ws`
* `rosinstall_generator ros_comm --rosdistro melodic --deps --tar > melodic-ros_comm.rosinstall`\\
  If you want a full install replace `ros_comm` with `desktop` or `desktop_full`.
* `rosdep install --from-paths src --ignore-src --rosdistro melodic -r --os=debian:stretch -y` (`debian:strech` is required because we are installing on Raspbian)\\
  In my case this installed the following dependencies: ???
* `./src/catkin/bin/catkin_make_isolated --install -DCMAKE_BUILD_TYPE=Release -j1`

You can try to compile with `-j2` (More does not make sense), but you maybe will get an out of memory error because the PI has
only 256MB of RAM. Here is an example of the memory consumption ;)
```bash
pi@raspberrypi:~$ free -h
              total        used        free      shared  buff/cache   available
Mem:           247M        218M         21M          0B        7.7M        1.3M
Swap:           99M         99M          0B
```

You can active the ROS environment with `source ~/ros_catkin_ws/install_isolated/setup.bash`. You
can also add this to your `.bashrc` if you like.

The next task for me is to get the data from the qemu image to copy it to the real hardware.

See [this post for how to mount qcow2 images]({{< ref "2019-04-14-mounting-qcow.md" >}}).

