---
layout: post
title: "Onlinezugangsgesetz in action: Disclosing security and privacy issues in NRW"
date: 2024-10-15
slug: security-privacy-disclosure-nrw
---

The Tür an Tür Digitalfabrik and I are publicly disclosing several security and privacy issues in the iOS and Android [NRW Ehrenamtskarten-App](https://www.engagiert-in-nrw.de/app-zur-ehrenamtskarte-nrw). We found 1 high-severity and 1 informational security issue, as well as 5 additional privacy and legal issues.

## Volunteering and service digitization in Germany

The digital volunteer card solution from the state of NRW enables volunteers to receive discounts at acceptance points such as museums, cafés, and car rental companies. Volunteers have to prove their volunteer status using the app and by verifying their identity using an ID.

In late 2020, a group of students from TUM, LMU, and the University of Augsburg, and engineers from the Tür an Tür Digitalfabrik started the design and development of the Ehrenamtskarte Bayern app. From the beginning the development was open-source. After the official introduction of the app at "Bayerisches Staatsministerium für Familie, Arbeit und Soziales", the concept was made generic such that it can be applied to other kinds of digital entitlement cards - the [entitlementcard](https://github.com/digitalfabrik/entitlementcard) project was born.

We knew that NRW was in the design process of developing a reference implementation of the OZG, because the OZG requires some transparency in the development process. Therefore the current state of implementations is published on the [Informationsplattform](https://informationsplattform.ozg-umsetzung.de/iNG/app/detail?id=103532&nav=RegKO_RO&tb=projectdetails&pager). We tried to reach out several times to the relevant people and companies in NRW to collaborate on the effort.
Because the Ehrenamtskarte Bayern is open-source software we tried to connect to development teams to share our learnings. However, these attempts failed.

The security of implementations for digital volunteering cards is essential, because museums, cafés, or any other discount providers depend on it.
In our disclosure, we found that there is no secure way to verify volunteers (EAK-1), which means that any person can create their volunteer card and receive discounts in NRW.
The Staatskanzlei des Landes Nordrhein-Westfalen argued that the discounts available in the app do not incentivize fraud enough.
However, we do not agree with this as the lack of security in the NRW app incentivizes discount providers, like a car rental company, to provide small or no discounts at all.

We believe this is a failure of the OZG and digitization of governmental processes.
The Ehrenamtskarte Bayern and its generic whitelabel solution offer a secure and private open-source solution - free of charge. The Bavarian solution is licensed under the MIT license.
We still hope that eventually either the NRW Ehrenamtskarten-App implements a security verification or considers forking the open source entitlementcard platform.

To illustrate the impact of EAK-1 we created a modified version of the NRW Ehrenamtskarten-App which displays a valid QR code for an arbitrary person:

{{< resourceFigureVideo "nrw-2024-04-13_15.06.22.mp4" >}}Illustration of EAK-1. We modified the code of the NRW Ehrenamtskarten-App to display arbitrary names with valid QR codes. We did not publish our modified app, however, once a modified app is published any person, even without any technical knowledge can get a fake volunteer card.{{< /resourceFigureVideo >}}

## Findings

We found the following security, privacy and legal issues in the [NRW Ehrenamtskarten-App](https://www.engagiert-in-nrw.de/app-zur-ehrenamtskarte-nrw). EAK-1 through EAK-6 affect the app version from 2024/04/18. EAK-7 affects the app version from 2024/08/06. In each case, the iOS and Android apps are affected.

|ID|Issue|Type|Severity|Fixed?|
|---|---|---|---|---|
|**EAK-1**|Lack of secure verification of volunteer status|Security|High|Partially|
|**EAK-2**|Existing card numbers can be determined by brute forcing|Security|Informational|No|
|**EAK-3**|Licenses of open source libraries used are not listed in the app |Legal|Informational|No|
|**EAK-4**|Privacy policy does not specify data transmission to Twitter/X|Privacy|High|Yes|
|**EAK-5**|Privacy policy does not specify data transmission to openstreetmap.org|Privacy|High|Yes|
|**EAK-6**|Lack of OpenStreetMap attribution on map|Legal|Medium|Yes|
|**EAK-7**|Privacy policy does not specify data transmission to jsDelivr|Privacy|High|Yes|

### EAK-1: Lack of secure verification of volunteer status [Severity: High]

The NRW Ehrenamtskarten-App does not provide for any verification of volunteer status. On the volunteer's end device
The app visually displays the first and last name of the cardholder, a validity date, and a card number on the volunteer's device. The same information is also encoded in a QR code.

To scan the QR codes, acceptance partners are given instructions on an [FAQ page](https://www.engagiert-in-nrw.de/faq-zur-ehrenamtskarten-app-nrw#faq_question_4037) published by the Staatskanzelei NRW (STK NRW) advises acceptance partners to
advised to use the camera app integrated in the system or another app for general scanning of QR codes.
In the best-case scenario, the acceptance partner can read the above data in plain text if the scanner app used supports this. Here is a screenshot of the website:

{{< resourceFigure "Screenshot 2024-04-16 08-45-42 Ehrenamtskarte FAQ.png"  >}}Screenshot of the NRW website{{< /resourceFigure >}}

However, this mechanism does not verify the data displayed in the QR code. Furthermore, the app
the QR code within the app to verify the encoded data via a hash comparison with a database in the backend. Another option would be to check a signature contained in the QR code
signature contained in the QR code, but this is not included either.

We assume that acceptance points do not assume that digital volunteer cards can be forged. It
It should be noted that a physical card, as is common for the volunteer cards of many federal states, also has no significant security features.
 However, with the digital version, it is possible with considerably less effort to issue counterfeit cards on a large scale.

In addition, security should always be taken into account when digitizing government services. The new development
of the digital volunteer card could have provided greater protection against counterfeiting for acceptance points.
Unfortunately, this opportunity has not been taken up to date and the security standard of an easily forged plastic card
has even been undercut. This also means that volunteers cannot benefit from discounts of a higher value, as acceptance points
as acceptance points cannot verify the volunteer status.

#### Exploit scenario

A volunteer takes a screenshot of the app containing the above data and the QR code. An
attacker named "Eve Mustermann", who is a friend of the volunteer, uses this screenshot to replace the volunteer's name with their own.
A QR code containing the following text is also created:

> Name: Eve Mustermann, Issuing municipality: City of Dortmund, Valid until: 01.04.2025, Card no.: 123

The falsified content of the screenshot is accepted by acceptance points as it does not contain any security features
and there is no mechanism to check the authenticity of the data.

To visualize the security risk, we created an alternative proof-of-concept attack by
modifying the source code of the app to display arbitrary names and QR codes in the app. This attack has the
advantage that a forgery is not recognizable in any case, as the app remains interactive, whereas a screenshot is
is static. See the video above of the attack.

#### Recommendation

In the short term, we recommend that acceptance points no longer offer benefits with a high value, as it cannot be
cannot be ruled out that counterfeit cards are not already in circulation.

In the long term, we recommend signing the content of the QR code and providing an app feature that allows verification of the QR code.
 If the QR code is not scanned with the app feature (e.g. camera app),
then no data about the volunteer should be recognizable as plain text to avoid possible misuse.

Alternatively, verification of the card number could also be ensured via a data query in the backend.
However, this alternative harbors data protection risks, as both the name and card number can be guessed by a brute force attack.
can be guessed. This means that an attacker could find out who has an honorary card without having access to
have access to QR codes.

A final alternative would be to use a secure open-source solution like the [entitlementcard](https://github.com/digitalfabrik/entitlementcard) project that has correctly identified and mitigates these attacks in its threat model.

#### Response by the Staatskanzlei NRW

The STK NRW agreed that the issue exists but did not agree with our severity rating and decided not to fix anything.

After we disagreed with the lower rating they implemented a feature that blocks the creation of screenshots and a feature that shows the current time in a format that includes seconds.

We still believe that the fix by STK NRW is inadequate.
In most cases, security problems are highly dependent on a threat scenario. If all the benefits you receive from the NRW volunteer card were of little financial value, we could understand your description of a lower level of severity. However, with the NRW volunteer card, for example, there is a €50 discount on car rental, a €100 subsidy on orthopedic mattresses or a €200 subsidy for a natural sleeping system from Pro Natura.

### EAK-2: Existing card numbers can be determined by brute forcing [Severity: For information]

Without authentication, the API endpoint `https://verwaltungsprogramm-eak-nrw[.]en/api/applications/$ID` returns either
404 Not Found, if an application does not exist, or 401 Unauthorized, if the authorization for the application
with the ID $ID is missing.

An attacker can therefore determine how many applications have already been received and thus estimate how many
volunteer cards are in circulation. Based on empirical data, we assume that the card numbers are a counter of the
cards created in the database. If applications for volunteer cards that have not been accepted/expired are deleted
are deleted, an attacker can also create a list of valid card numbers.

This information can be used to assign real existing card numbers and thus, in the case of a superficial comparison, verify the existence of the specified card numbers.
This information can be used to assign real ID card numbers and thus suggest a valid ID card during a superficial comparison of the existence of the specified ID card number. A detailed check
of the other ID card information does not stand up to such a check. Whether a comparison of the existence of ID
numbers is planned is not known to us.

#### Recommendation

If an application exists, but no authorization exists, the backend should respond with 404 Not Found.

#### Response by the Staatskanzlei NRW

The STK NRW confirmed this finding but decided not to fix it yet due to the low severity.

### EAK-3: Licenses of open-source libraries used are not listed in the app [Severity: For information].


References to the licenses of the open-source libraries used are missing. The lack of license information in an app can
pose legal risks and violate the principles of the open-source community. Uncertainties about
usage rights can lead to unintentional copyright infringements.

#### Recommendation

Developers should clearly document all libraries used and their licenses and also display these in the app UI.


#### Response by the Staatskanzlei NRW

The STK NRW confirmed this finding and plans to implement our recommendation.

### EAK-4: Privacy policy does not specify data transmission to Twitter/X [Severity: High]

The app transmits information such as time and IP addresses to Twitter/X. The app loads content from twimg.com, e.g:
https://pbs.twimg[.]com/media/GKLpXGkXgAI2Em_.jpg

The reason for this is that the app loads a Twitter feed from the app's backend. However, the images contained therein are
images are loaded directly from Twitter.

The lack of specific information on data transfer to third parties such as Twitter/X in a privacy policy can lead to a loss of trust and legal consequences.
loss of trust and legal consequences. Users may not be informed about how their data is
data is used and shared.

A current version of the privacy policy is attached in the appendix below.

#### Recommendation

We recommend that you no longer download content directly from Twitter/X, but instead obtain all media content via the backend of the
Volunteer Card if this is not legally problematic. The backend would then serve as a proxy for the content from Twitter/X.

In addition, current users of the app should be informed that data (IP addresses, usage behavior) has been sent to X without
the user's consent.

#### Response by the Staatskanzlei NRW

The STK NRW confirmed this finding and removed all image previews.

### EAK-5: Privacy policy does not specify data transmission to openstreetmap.org [Severity: High]

The app transmits information such as time, IP addresses, and possibly location data to openstreetmap.org.

This data transfer is required to display the map data from OpenStreetMap. The privacy policy does not mention this fact. As a result, users are not sufficiently informed about how their data is used and shared.

#### Recommendation

We recommend updating the privacy policy and mentioning the transfer of data to OpenStreetMap. Furthermore
users should be informed about a possible outflow of their data without their consent.

Furthermore, the use of OpenStreetMap's non-profit servers should be avoided in the long term, as the state of
NRW also has its own data services available.

#### Response by the Staatskanzlei NRW

The STK NRW confirmed this finding and added a banner to ask for consent before connecting to the new GIS provider GeoBasis-DE.

### EAK-6: Lack of OpenStreetMap attribution on map [Severity: Medium]

The lack of an "attribution" for OpenStreetMap map data violates the terms of use of
OpenStreetMap and may have legal implications. Users and other developers are not informed about the
source of the map data. 

In addition, the app's terms of use incorrectly state that the rights to the map data are held by
Geobasis NRW and the Federal Agency for Cartography and Geodesy.

#### Response by the Staatskanzlei NRW

The STK NRW confirmed this finding, switched to GeoBasis-DE, and added attribution.


### EAK-7: Privacy policy does not specify data transmission to jsDelivr [Severity: High]

We have noticed that fonts from cdn.jsdelivr.net are loaded when loading the map. This means that IP addresses are transmitted to the service provider jsDelivr without listing this in the privacy policy.

#### Response by the Staatskanzlei NRW

The STK NRW confirmed this finding and no longer transmits data to jsDelivr.

## Disclosure timeline

- 2024-04-18 - EAK-1 through EAK-6 were reported to the STK NRW. We set the embargo date to 2024-07-31.
- 2024-05-02 - NRW fixes EAK-4, EAK-5, and EAK-6.
- 2024-08-06 - We retested the app and reported EAK-7 to the STK NRW.
- 2024-08-28 - NRW fixes EAK-7.

The findings EAK-1, EAK-2, and EAK-3 were not fixed.
