---
layout: post
title: "Keeping a Secret Safe (and not only Secure)"
date: 2021-01-05
slug: keeping-secret-safe
---

Keeping a secret like GPG keys safe is not a trivial task. It gets even more complicated if you want to backup it and have access in the more distant future. Having your key on a HSM has the goal of keeping it secret. Keeping a secret safe means that it is not easy to loose your key. 

## Goals

The following will describe how you can backup your key with the following goals in mind.

* Create the backup on the air gapped laptop
* Store the backup encrypted
* Allow restoring the secret even if you lost your memory
* Print the backup on physical paper
* Use only standard Linux tools

## Intro

So we have our encrypted GPG key on an air gapped laptop. How do we backup the key now? 
The [GPG documentation](https://gnupg.org/documentation/manuals/gnupg-devel/Operational-GPG-Commands.html#Operational-GPG-Commands) recommends to print backups on paper and recommends [paperkey](https://www.jabberwocky.com/software/paperkey/). Paper has excellent properties for backups which should last. Storing backups on Flash Memory like USB sticks is not very safe. Cheat flash storage can easily die. Burning the key to a CD seems like a good idea as manufactures promise over a 100 years durability. But do you still have a CD burner at home? Can you even read CDs anymore? I can not and the storage industry has invented many formats which are ancient today.

### Tools

Here are the tools I used in my script with their purpose. I suggest you to create your own script as you only can trust one you created or reviewed.

|Tool|Purpose|
|---|---|
|gpg|Manages GPG keys|
|paperkey|Reduces the size of GPG keys by stripping away the public key and metadata|
|qrencode|Create QR codes from binary data or text|
|gs|Processing QR codes and creating PDFs|
|a2ps|Create a printable file from plain text|
|base64|Create text from binary data for more portable data|
|split|Dividing data into multiple data chunks|
|ssss-split|Creating shares of a passphrase|

That's it! These tools are available on Ubuntu 20.10 and even on the latest Debian (`apt install -y paperkey qrencode gnupg pwgen ssss ghostscript a2ps`). If you use a live CD then I suggest connecting the Laptop to the internet and install these tools. In my opinion the important thing is that you can be sure that the live CD does not come with malware. If you do not trust the live CD which you are using then you have a different issue. That means you should check the checksum and signature of the image you want to boot from:

```bash
sha256sum ubuntu-20.10-desktop-amd64.iso
cat SHA256SUMS
gpg --verify SHA256SUMS.sig
```
In my opinion it is enough to use a live CD and disconnect from LAN.
After installing the tools you can disconnect from the internet. Now nothing can leave your system, and you are safe to decrypt your GPG key. 

## Steps Explained

Firstly, we will use `paperkey` to reduce the size of our exported key. This is maybe not needed if you use ECC. But it definitely makes sense with bulky RSA keys. QR Codes do not store infinite data and the more data they need to store the harder it is to scan them. We will use base64 to make the process more portable. QR codes support binary data by specification. This is not well implemented though. For example [zbar](http://zbar.sourceforge.net/) has problems with handling binary data. A more portable solution is to stick with text. A further simplification is not to use "Structured Append". This feature would allow us to split data automatically when creating QR codes with `qrencode`. Again zbar does not support it.

```bash
gpg --export-secret-keys $key_id > secret-key.gpg
paperkey --secret-key=secret-key.gpg --output-type=raw | base64 -w 76 > paperkey.base64
```

`gpg` should have asked you for a password. If not then this is a good time to set one using `gpg --edit-key $keyid`. You can use the tool `pwgen` to create secure passwords. Else you will store your GPG key unencrypted.

Now let's split the created file and use 10 lines per QR code. Even though the QR codes could potentially store more data I used fewer lines per QR code. That way they do not get too big.

```bash
split paperkey.base64 -d --lines=8 --additional-suffix=.base64 output/paperkey_split
```

We split by lines such that `split` does not destroy the UTF-8 encoding of our text. You should end up with 5-10 splits depending on your key. At this point it is maybe a good idea to create a second backup of the key using `paperkey` which will not use QR codes:

```bash
paperkey --secret-key=secret-key.gpg | a2ps -R --columns=1 -f 10 --margin=0 --no-header -o - | gs \
   -o "output/paperkey.pdf" \
   -sDEVICE=pdfwrite -g5950x8420 -
```

`a2ps` create a PostScript file which is then given to `gs` which create a PDF file with the specified format `5950x8420` which corresponds to A4.

Now lets iterate over each split in `output/paperkey_split*.base64` and generate QR codes:

```bash
  qrencode --read-from="$split" -l L --type=EPS --size 6 --output "output/$name.eps"
  gs -q -o "output/$name.pdf" -sDEVICE=pdfwrite -g5950x8420 \
     -c "/Helvetica findfont 15 scalefont setfont 40 800 moveto (QR-Code $name) show
         /Helvetica findfont 12 scalefont setfont 40 700 moveto (SHA256 of split: $split_sum) show
         /Helvetica findfont 12 scalefont setfont 40 680 moveto (SHA256 of paperkey: $paperkey_sum) show" \
     -f "output/$name.eps"
```

The above code create a QR code using `qrencode` with low error correction. Then we pass the QR code to `gs` which creates a PDF and places some text like the name of the split and some hashes for verification. The name allows us to keep reference to the splits after printing.

I told you in the Goals section that we want to be able to restore the key even if we lost our memory and therefore the passphrase to the key. This will be possible using [ssss](http://point-at-infinity.org/ssss/) (The [Wikipedia article](https://en.wikipedia.org/wiki/Shamir%27s_Secret_Sharing) is actually pretty nice. All knowledge required for this is high school math).  This allows us to split the passphrase into shares. These shares will be given to people you trust together with the encrypted key. `t` out of `n` shares are required to restore the passphrase.

```bash
shares=$(echo "$passphrase" | ssss-split -q -t 2 -n 5) 
```

Again we can iterate over the lines in `$shares` and generate QR codes like shown above.


## Restoring the Passphrase and the GPG Key

Restoring the key is pretty simple. I used `zbarcam` for this.

```bash
zbarcam --raw > scan.base64
base64 -d < scan.base64 | paperkey --pubring pub.gpg > secret-key.gpg
```

You simply scan the codes one by one and write it to a file. `zbarcam` will add a new line after each scan. This is not a problem though because we used base64 encoding which is very portable. It will just ignore the new lines. Then we pass the decoded data to `paperkey` which required the public key to reconstruct the secret GPG key.

We also need `t` out of `n` shares to get back to the passphrase.

```bash
ssss-combine -t 2
```

Enter two shares by scanning them or simply by reading and typing them. You will see the passphrase you will need to import the secret key:

```bash
gpg --import secret-key.gpg
```

## Printing

Printing and Linux can still be challenging in 2021. I used the Ubuntu 20.10 live CD and a Brother printer. CUPS worked flawlessly via USB and allowed me to print. In comparison the CUPS installation on the Debian live CD was broken and even crashed with a segmentation fault.
After installing the USB printer via the CUPS web interface I was able to print all the PDFs.

## Conclusion

I showed how to backup huge GPG keys. The same procedure can also be used to backup other bigger secrets (> 128 bytes). If you have secrets which are smaller than 128 ASCII characters then you can use `ssss` directly.
Each QR code should be printed on a separate page. This makes it easier to scan them.

I think I also covered all of my initial goals. The encrypted keys are now stored on paper and can be decrypted by `t` people even if I love my memory. The tools used are also so common that it is easy to do this on an air gapped laptop.

**Disclaimer: Please test your backup procedure multiple times. This means print your secrets and then test whether you can reconstruct your key and have access. I know it is tedious, but a backup which does not work is worthless!**
