---
layout: post
title: "Generating PDFs with QR Codes in the Browser"
date: 2022-01-06
slug: pdf-browser-qrcode
draft: false
wip: false

resources:
- src: "*.png"
- src: "*.jpg"

keywords: [ javascript, js, qrcode ]
categories: [ ]
---


Generating QR codes is supported by various high quality libraries. Generating PDF using JavaScript in browsers is also very well-supported nowadays.
In this post I want to present a method which has the following features:

* Uses stable and trusted libraries
* QR codes are embedded as vector graphic
* Support for advanced QR code options

We will use the well-known [@zxing/library](https://www.npmjs.com/package/@zxing/library) and [jsPDF](https://www.npmjs.com/package/jspdf) libraries. The former is responsible for encoding text as QR codes. The latter library can generate PDFs in browsers. `jsPDF` especially supports to render vector graphics within PDFs.

Note: I will use TypeScript in this post. A JavaScript solution is available [here](https://gist.github.com/maxammann/2e1c616d17800eeb045488efd7932e46).

## Generate QR codes

The library `@zxing/library` actually already support creating SVGs from QR codes. We will adopt the code of [BrowserQRCodeSvgWriter](https://github.com/zxing-js/library/blob/d1a270cb8ef3c4dba72966845991f5c876338aac/src/browser/BrowserQRCodeSvgWriter.ts) in order to create instructions which will allow us to embed QR codes in PDFs.

The following snippet is an adopted version of the [renderResult function](https://github.com/zxing-js/library/blob/d1a270cb8ef3c4dba72966845991f5c876338aac/src/browser/BrowserQRCodeSvgWriter.ts#L91) of `@zxing/library`.
The `createQRCode` function encodes a string `text` as a QR code.

* We can specify a size of the QR code using the `size` parameter. 
* The `hints` parameter allows us to set [additional options](https://zxing.github.io/zxing/apidocs/com/google/zxing/EncodeHintType.html). 
* Finally, we need to provide two functions: `renderRect` and `renderBoundary`. These two functions define the interface which `jsPDF` needs to fulfill.


```ts
import {
    EncodeHintType, IllegalStateException,
    QRCodeDecoderErrorCorrectionLevel as ErrorCorrectionLevel, QRCodeEncoder,
    QRCodeEncoderQRCode as QRCode
} from "@zxing/library";

const DEFAULT_QUIET_ZONE_SIZE = 10

// Adapted from https://github.com/zxing-js/library/blob/d1a270cb8ef3c4dba72966845991f5c876338aac/src/browser/BrowserQRCodeSvgWriter.ts#L91
const createQRCode = (text: string,
                      renderRect: (x: number, y: number, size: number) => void,
                      renderBoundary: (x: number, y: number, width: number, height: number) => void,
                      size: number, hints?: Map<EncodeHintType, any>) => {
    let errorCorrectionLevel = ErrorCorrectionLevel.L;
    let quietZone = DEFAULT_QUIET_ZONE_SIZE;
    const {width, height} = {width: size, height: size}

    if (hints) {
        if (hints.get(EncodeHintType.ERROR_CORRECTION)) {
            errorCorrectionLevel = ErrorCorrectionLevel.fromString(hints.get(EncodeHintType.ERROR_CORRECTION).toString());
        }

        if (hints.get(EncodeHintType.MARGIN) !== undefined) {
            quietZone = Number.parseInt(hints.get(EncodeHintType.MARGIN).toString(), 10);
        }
    }

    const code: QRCode = QRCodeEncoder.encode(text, errorCorrectionLevel, hints);

    const input = code.getMatrix();

    if (input === null) {
        throw new IllegalStateException();
    }

    const inputWidth = input.getWidth();
    const inputHeight = input.getHeight();
    const qrWidth = inputWidth + (quietZone * 2);
    const qrHeight = inputHeight + (quietZone * 2);
    const outputWidth = Math.max(width, qrWidth);
    const outputHeight = Math.max(height, qrHeight);

    const multiple = Math.min(Math.floor(outputWidth / qrWidth), Math.floor(outputHeight / qrHeight));


    // Padding includes both the quiet zone and the extra white pixels to accommodate the requested
    // dimensions. For example, if input is 25x25 the QR will be 33x33 including the quiet zone.
    // If the requested size is 200x160, the multiple will be 4, for a QR of 132x132. These will
    // handle all the padding from 100x100 (the actual QR) up to 200x160.
    const leftPadding = Math.floor((outputWidth - (inputWidth * multiple)) / 2);
    const topPadding = Math.floor((outputHeight - (inputHeight * multiple)) / 2);

    renderBoundary(0, 0, outputWidth, outputHeight)


    for (let inputY = 0; inputY < inputHeight; inputY++) {
        // Write the contents of this row of the barcode
        for (let inputX = 0; inputX < inputWidth; inputX++) {
            if (input.get(inputX, inputY) === 1) {
                let outputX = leftPadding + inputX * multiple;
                let outputY = topPadding + inputY * multiple;
                renderRect(outputX, outputY, multiple)
            }
        }
    }
}
```

## Rendering a QR code in a PDF

The following snippet shows how to integrate the above snippet with `jsPDF`. The `drawQrCode` function encodes the parameter `text` as QR code and then renders it.

* The parameters `x` and `y` determine where to draw the QR code within the `pdfDocument`
* The parameter `size` determines the size of the QR code.
* `pdfDocument` is the handle to the jsPDF document
* `border` optionally draws a border around the quiet zone around the QR code.
* `version` sets the [version](https://www.qrcode.com/en/about/version.html) of the QR code.

```ts
import {jsPDF} from "jspdf";
import {EncodeHintType} from "@zxing/library";

const drawQrCode = (text: string, x: number, y: number, size: number, pdfDocument: jsPDF, border: boolean = true, version = 7) => {
    const hints = new Map()
    hints.set(EncodeHintType.MARGIN, 0)
    hints.set(EncodeHintType.QR_VERSION, version)
    createQRCode(text, (rectX: number, rectY: number, rectSize: number) => {
            pdfDocument.rect(x + rectX, y + rectY, rectSize, rectSize, "FD");
        },
        (rectX: number, rectY: number, rectWidth: number, rectHeight: number) => {
            if (border) {
                pdfDocument.setLineWidth(.4)
                pdfDocument.roundedRect(x + rectX, y + rectY, rectWidth, rectHeight, 10, 10, "D");
                pdfDocument.setLineWidth(0)
            }
        }, size, hints)
}
```

The function above calls `createQRCode` and provides two lambda functions. Those arrow-functions are responsible to draw the correct rectangles and boundaries.

## Example Usage

There is a quick example on how to use the code above.

```ts
var doc = new jsPDF();
drawQrCode("test", 0, 0, 100, doc)

doc.save('Test.pdf');
```

A full example can be seen [here](https://gist.github.com/maxammann/2e1c616d17800eeb045488efd7932e46).

## Bonus: Create a Single SVG Path

Based on the code above we can also create a single SVG path. This is interesting for embedding a QR code in a website. The code below generates a single string which can be visualized using [this tool](https://yqnn.github.io/svg-path-editor/) for example.

```ts
import {EncodeHintType} from "@zxing/library";

const drawSVGPath = (text: string, size: number, version = 7) => {
    const hints = new Map()
    hints.set(EncodeHintType.MARGIN, 0)
    hints.set(EncodeHintType.QR_VERSION, version)

    let pathData = ""
    createQRCode(text, (x: number, y: number, size: number) => {
            return pathData += 'M' + x + ',' + y + ' v' + size + ' h' + size + ' v' + (-size) + ' Z ';
        },
        (rectX: number, rectY: number, rectWidth: number, rectHeight: number) => {
            return pathData += 'M' + rectX + ',' + rectY + ' v' + rectHeight + ' h' + rectWidth + ' v' + (-rectHeight) + ' Z ';
        }, size, hints)
    return pathData
}
``
