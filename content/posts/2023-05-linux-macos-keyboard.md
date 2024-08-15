---
layout: post
title: "macOS keyboard on Linux: Use macOS like keybindings on Linux"
date: 2023-05-27
slug: linux-macos-keyboard
draft: true
wip: false

keywords: [openssl]
categories: [ security ]
---


kinto is messy and only work on X: 
* https://github.com/rbreaves/kinto/blob/master/linux/initkb

Swapping keys in X:
* https://kasikcz.medium.com/en-macos-keyboard-shortcuts-in-ubuntu-gnome-linux-61f49a6cc216
altwin is hacky: /usr/share/X11/xkb/symbols/altwin

GTK keybindings + Qt:
* https://technex.us/2020/09/getting-macos-style-hotkeys-working-in-gnu-linux/

GTK keybindings are used for emacs keybindings:
* http://kb.mozillazine.org/Emacs_Keybindings_-_Firefox#Any_OS.2C_without_GTK

GTK keybindings are actually broken (only work in certain inputs):
* https://discourse.gnome.org/t/question-which-node-name-in-gtk-key-theme-should-i-use-to-set-key-bindings-for-copying-text-in-firefox/3271

GTK 4 drop it again... https://www.reddit.com/r/emacs/comments/c22ff1/gtk_4_support_for_key_themes_does_not_affect/

Firefox uses GTK and internal handling:
* https://bugzilla.mozilla.org/show_bug.cgi?id=1269058

firefox internal handling: 
https://askubuntu.com/questions/39462/how-do-i-reconfigure-keyboard-shortcuts-for-copy-and-paste

Super: 94
Meta: 224
(
https://searchcode.com/codesearch/view/26755902/
http://kb.mozillazine.org/Ui.key.generalAccessKey
https://bugzilla.mozilla.org/show_bug.cgi?id=426891
https://bugzilla.mozilla.org/show_bug.cgi?id=128452
https://gist.github.com/spaced/092bafb493d9c9fac97cebf9bd03dc5a

about:config -° ui.key.accelKey
)


swap_lalt_l_win messes with Alt. Pressing meta means: Alt+Meta for VScode
https://superuser.com/questions/691975/switching-left-alt-and-left-win

Handling on app layer (e.g. Alacritty)
```
key_bindings:
  - { key: Return,   mods: Control|Shift, action: SpawnNewInstance }
```
https://wiki.archlinux.org/title/Alacritty


IntelliJ support for Meta key: 
https://intellij-support.jetbrains.com/hc/en-us/community/posts/206374219-What-is-the-meta-key-in-windows-
(also has a mac layout)

vscode mac layout:
https://github.com/FredHappyface/VSCode.OSKeybindings
https://github.com/codebling/vs-code-default-keybindings

xmodmap dump
xmodmap -pke (
    https://wiki.ubuntuusers.de/Xmodmap/ 
https://wiki.archlinux.org/title/xmodmap 
)
resolving messes in x level mapping: https://jp-larocque.livejournal.com/49209.html

kernel level:

https://unix.stackexchange.com/questions/58559/how-to-change-a-keycode-using-setkeycodes
https://wiki.archlinux.org/title/map_scancodes_to_keycodes
https://wiki.archlinux.org/title/Keyboard_input#Identifying_scancodes 
via udev:
https://unix.stackexchange.com/questions/384492/fedora-selected-lenovo-hotkeys-not-working-on-fedora-26-keycode-255/384566#384566


sadly something like keyd or [kmonad](https://github.com/kmonad/kmonad) is the only workable solution:
https://github.com/canadaduane/meta-mac/tree/main

summary: https://medium.com/@canadaduane/key-remapping-in-linux-2021-edition-47320999d2aa


note on apple keyboards:
root@max-laptop ~ # cat /etc/modprobe.d/hid_apple.conf
options hid_apple fnmode=1 iso_layout=1 swap_opt_cmd=0

thinkpad keyboard:
130 max@max-laptop ~ ❯ cat /etc/udev/hwdb.d/90-custom-keyboard.hwdb
evdev:atkbd:dmi:bvnLENOVO:bvr*:bd*:svn*:pn*:pvr*
 KEYBOARD_KEY_38=leftmeta
 KEYBOARD_KEY_db=leftalt

 systemd-hwdb update
 sudo udevadm trigger --subsystem-match=input --action=change


 ```
 Win phy. key code = 125
  x: 64
  scancode: 0xe05b, 0xe0db
Alt phy. key code = 56
  x: 133
  scancode: 0x38b8

setkeycode phys.key key code

win phys to alt
setkeycodes 0xe05b 56


alt phys to win
setkeycodes 0x38 125


wwwooot? it works with xmodmap but not with altwin:left_meta_win?

xmodmap -e "keysym Super_L = Meta_L"

sudo udevadm trigger --subsystem-match=input --action=change

getkeycodes

showkey -s
```

QT https://bugreports.qt.io/browse/QTBUG-113699