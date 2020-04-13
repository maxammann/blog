---
layout: post
title: "Data Visualization of Telegram messages (Encrypted Chats)"
date: 2020-03-25
slug: telegram-data-visualization

resources:
- name: timestamps
  src: timestamps.png
---

We are going to visualize the timestamps of messages in the Telegram database. This also includes encrypted chats as we analyze the SQLite database of the app.

# Obtaining the database

We pull the database of Telegram using the ADB tool. You can read [here](https://developer.android.com/studio/command-line/adb) how this tool works and how to set it up. Make sure your phone is rooted and you set `Root access` to `ADB only`. Then you can restart ADB using `adb root`. Finally you can pull the database to your current working directory using:

```bash
adb pull /data/data/org.telegram.messenger/files/cache4.db
```

# Collecting timestamp information

Using the sqlite3 tool we can get data and output it as CSV file.

```bash
sqlite3 cache4.db -csv -header "SELECT 1;" > timestamps.csv
```

The `timestamps.csv` should contain now a single 1. The following queries show how to query the timestamps for encrypted and non-encrypted chats.

## Non-Encrypted Chat

For non-encrypted chats you can use:

```sql
SELECT date FROM messages WHERE uid = (
    SELECT uid FROM users WHERE name LIKE '%lower case name of person%'
);
```

## Encrypted chat

For encrypted chat we first need to query an other `uid`. The new `uid` is longer as it is bit-shifted by 64 to the left. In order to find the chat messages for encrypted chats, we first undo this in the query and then find the corresponding user in the `enc_chats` table.

```sql
SELECT date FROM messages
    WHERE mid < 0 AND substr(printf('%X', uid), 0, length(printf('%X', uid)) - 7) = (
        SELECT printf('%X', uid) FROM enc_chats WHERE name LIKE '%lower case name of person%'
    );
```

There are also the data-blobs with column name `data` which are not further discussed here. Maybe an other post will take a deeper look at the actual message content.
We can UNION and sort the results now to get ta complete overview of the timestamps.

_TL;DR (show me the command!)_

```sql
sqlite3 cache4.db -csv -header "
SELECT * FROM (
    SELECT date FROM messages WHERE uid = (
        SELECT uid FROM users WHERE name LIKE '%lower case name of person%'
    )
    UNION
    SELECT date FROM messages
        WHERE mid < 0 AND substr(printf('%X', uid), 0, length(printf('%X', uid)) - 7) = (
            SELECT printf('%X', uid) FROM enc_chats WHERE name LIKE '%lower case name of person%'
        )
) ORDER BY date;
" > timestamps.csv
```

# Creating a Data Visualization

The following script allows you to plot the data using pandas and matplotlib with the kxcd style:

```python
import pandas as pd
import matplotlib
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
from matplotlib import patheffects

#import numpy
#df = pd.DataFrame(numpy.random.randint(1546300800, 1576368000, size=(2000, 1)), columns=['date'])
df = pd.read_csv('timestamps.csv')
df["date"] = df["date"].astype("datetime64[s]")

df = df.groupby(df["date"].dt.month).count()
print("Chat messages per month:")
print(df)
df = df.drop(df.tail(1).index)

plt.xkcd()
matplotlib.rcParams['path.effects'] = [patheffects.withStroke(linewidth=0)]
matplotlib.rcParams['font.family'] = 'xkcd'

fig, ax = plt.subplots(figsize=(8, 5))

df.plot(kind="bar", ax=ax, legend=False)

ax.set_xlabel('')
ax.set_ylabel('')

ax.spines['right'].set_visible(False)
ax.spines['top'].set_visible(False)
for item in [fig, ax]:
    item.patch.set_visible(False)

ax.xaxis.set_ticks_position('bottom')
ax.xaxis.set_major_formatter(mticker.FixedFormatter(
    ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC']))
ax.tick_params(axis=u'both', which=u'both', length=0)
plt.xticks(rotation='horizontal')

ax.set_title("CHAT MESSAGES PER MONTH")

fig.savefig('timestamps.png', dpi=600, transparent=True)
```

You can also annotate special points using `plt.annotate` and `plt.text`:

```python
plt.annotate(
    '',
    xy=(7.5, 250), arrowprops=dict(arrowstyle='simple', fc='black'), xytext=(6.5, 250), annotation_clip=False)

plt.text(6.5, 269, 'FUTURE', fontsize=16)
```

Here is an example output:

{{< resourceFigure "timestamps" "Example visualization from January until December" />}}

The data was generated randomly.

# More Resources about Telegram Reverse-engineering

You can find more information on the [dflab blog](https://dflab.blogspot.com/2019/01/cache4db-file-of-telegram-for-android_3.html) about reversing the Telegram database. Thanks for sharing the knowledge! The following section was the key to this post:

> if "mid" is negative, "uid" is negative or positive and has a length of about 19 characters[6] – the interlocutor’s data can be find in the "Enc_chats" table by the converted "uid" value. To find the appropriate contact in the "Enc_chats" table, you need to convert the decimal "uid" number to hexadecimal, then cut off the last 8 zeros from the received number and convert the eight-digit hexadecimal number back to decimal;