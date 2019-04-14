---
layout: post
title: "Jira: Invalid Server ID"
date: 2018-11-21
slug: jira-server-id
---

In case you migrated from Jira Cloud to the self-hosted version your server id probably got
corrupted. You can revert this by searching your Jira logs for the ID and manually change it in the
database.

1. Download a support ZIP from the Jira
2. Stop the Jira server
2. Run `grep -r "Installation Type" -C 5 .` inside of the extracted support ZIP
3. You can find now a previous Server ID by looking though the output
4. Log into your database and update your Server ID: `UPDATE propertystring SET propertyvalue = 'XXXX-XXXX-XXXX-XXXX' where id = (select id from propertystring where id in (select id from propertyentry where PROPERTY_KEY='jira.sid.key'));`
5. Star Jira again!

You should have a new server id now.

