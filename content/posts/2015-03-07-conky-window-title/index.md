---
layout: post
title: "Conky: Display window title"
date: 2015-03-07
slug: conky-window-title
---

When using a tiling window you often want to hide the title bar of windows to achive a nicer look and save some space. But at the same time you don't want to miss important information which sometimes is only exposed through the name of a window which is displayed in the title bar by default. In i3 you can modify your status bar with conky, so why don't display it there?

The following conky command will return the name of the currently selected window.

```bash
${exec xprop -id $(xprop -root | awk '/_NET_ACTIVE_WINDOW\(WINDOW\)/{print $NF}') | awk '/_NET_WM_NAME/{$1=$2="";print}' | tr -s ' ' | awk '{print substr($0, 3, length($0) - 3)}'} 
```


Build into a complete conky script it will look like this:

```json
out_to_x no
own_window no
out_to_console yes
double_buffer no
background no
update_interval 0.15
use_spacer left

## Stuff after 'TEXT' will be formatted on screen
TEXT
[{"full_text": " "},
  {"full_text": " ${exec xprop -id $(xprop -root | awk '/_NET_ACTIVE_WINDOW\(WINDOW\)/{print $NF}') | awk '/_NET_WM_NAME/{$1=$2="";print}' | tr -s ' ' | awk '{print substr($0, 3, length($0) - 3)}'} ", "name":"window"},
  {"full_text": " ${time %a %d.%m.%y  %H:%M}","color":"\#6AFFD8 ", "name":"time"},
  {"full_text": " "}
],
```
Result:

{{< resourceFigure "conky-window-title.png" "Conky Window Title Result" />}}
