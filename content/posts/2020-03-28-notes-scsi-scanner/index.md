---
layout: post
title: "Notes about Setting up a SCSI Nikon LS-2000 Scanner on Windows 10"
date: 2020-03-28
slug: notes-scsi-scanner

resources:
- src: '*.png'

keywords: [ scsi, scanner, nikon, windows ]

---

[VueScan for the Nikon LS-2000](https://www.hamrick.com/vuescan/nikon_ls_2000.html) offers a future proof way of using old scanners over the legacy SCSI standard. The not that small [Small Computer System Interface](https://en.wikipedia.org/wiki/SCSI) is not easy to setup in 2020. Three things are required in order to use it:
1. BIOS mainboard (UEFI is not supported by most PCI-Cards)
2. PCI expansion slot (most SCSI cards are not PCIe compatible)
3. SCSI card with drivers for your operating system (Windows or MacOS)

# SCSI Card with Drivers for your Operating System

The well-known [Adaptec SCSI cards](https://storage.microsemi.com/en-us/support/scsi/) work well and are very cheap. I got an [Adaptec SCSI Card 19160](https://storage.microsemi.com/en-us/support/scsi/u160/asc-19160/) [from Ebay](https://www.ebay.de/itm/Adaptec-Controller-Card-ASC-19160-ASC-29160N-PCI-SCSI-Adapter-U160-PCI3-0-NUR/252975397739) for less than 20€. This card has the two advantages that it is cheap and **supports Windows 10**! As the VueScan software also runs on Windows 10, we are able to use a modern OS with our legacy Nikon scanner. Do not waste any time getting the original driver to work. VueScan is able to create a bit-by-bit scan with raw data from the sensors. Here is the driver information from Windows as a proof:

{{< resourceFigure "scsi_card.png" "Windows driver info for Adaptec SCSI Card 19160" />}}

# BIOS Mainboard and PCI Expansion Slot

The SCSI cards which are available today do not work with UEFI. At least I did not find one with a reasonable price. Furthermore, most cards only support PCI and not PCIe. This means a mainboard prior to ~2010 should do the job well. I went with a ASUS P5Q-PRO.

Modern UEFI board are not compatible with the SCSI cards I tested. It seems that there is no mapping for the PCI address space. Also, there is no support for the management of [interrupts](https://en.wikipedia.org/wiki/Conventional_PCI#Interrupts) on modern boards. I found this out the hard way by testing a PCIe to PCI card from CSL. This usually works well with most PCI cards. Unfortunately if the card depends on a BIOS integration these adapters do not work.

# Connecting the Scanner and Start the Software

You have to connect and start the scanner before starting the computer. After booting, installing the SCSI drivers you only need to get VueScan and start a scan. VueScan has all the drivers bundled.

You can find the [specs](https://imaging.nikon.com/lineup/scanner/scoolscan_2000/spec.htm) and the [manual](https://cdn-10.nikon-cdn.com/pdf/LS2kug.pdf) for the Nikon LS-2000 still on their website. Unfortunately the manual is only for the original Nikon software which does not work well with Windows 10. VueScan offers a well [written manual](https://www.hamrick.com/vuescan/html/vuesc.htm) for all the settings.


I hope I was able to get a brief overview of running an old scanner on a modern software stack.
