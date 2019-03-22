---
layout: post
title: "Basics for a simple slack bot which crawls websites"
published: true
---

Writing a slack bot which pushes content to a workspace is quite simple and fast to do.
So if there is an updating piece of information in the internet from which your teams needs regular updates
this is an easy. In my case this is the weekly food plan.

I decided to go with [requests-html](https://html.python-requests.org/),
[tinydb](https://tinydb.readthedocs.io/en/latest/) and of course
[slackclient](https://python-slackclient.readthedocs.io/en/latest/).

I'll walk you through the important parts [on
GitHub](https://github.com/maxammann/slack-yummybot).

First setup a `SlackClient` and `HTMLSession`:

```
slack_token = os.environ["SLACK_BOT_TOKEN"]
sc = SlackClient(slack_token)
session = HTMLSession()
```

Next crawl the content from the html page and select the interresting parts:

```
r = session.get('https://tuerantuer.de/cafe/wochenplan/')
yummyImages = r.html.find(".site-content", first=True).find('img[class*=wp-image-]')
```
*Note: Make sure you have the permission to crawl the page!*\\
*Note: This does not work if the page does not render the page on the server!*

The last step is to post the content to the slack:

```python
for yummyImage in yummyImages:
    imageUrl = yummyImage.attrs['src']

    result = sc.api_call(
        "chat.postMessage",
        channel=CHANNEL,
        text=MESSAGE,
        attachments=[{
            "fallback": "Wochenplan from Cafe TaT",
            "image_url": imageUrl
        }]
    )

    if not result["ok"]:
        print(result)
print("Failed to send message to Slack")
```

Run this script as a cronjob every hour to post updates!
There is no need to use Web Hooks as this is only pushing to the slack.


