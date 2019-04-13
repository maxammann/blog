---
layout: post
title: Mounting qcow2 images
date: 2019-04-14
---

If you previously converted a raw image using `qemu-img convert` to a qcow2 image you maybe want to mount it to retrieve and modify data:

```bash
modprobe nbd max_part=8
qemu-nbd --connect=/dev/nbd0 db1_old.qcow2
```

Now you can mount partitions in the image using:
```bash
mount /dev/nbd0p1 /mnt/
```

In order to unmount and remove the device:
```bash
umount /mnt/
qemu-nbd --disconnect /dev/nbd0
```

You can also unload the kernel module: `modprobe -r nbd`

