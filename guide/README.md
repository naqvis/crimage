# CrImage Documentation

Comprehensive guides for the CrImage image processing library.

## Guides

| Guide                                        | Description                                         |
| -------------------------------------------- | --------------------------------------------------- |
| [Quick Start](QUICK_START.md)                | 10 common tasks with working examples               |
| [Image Formats](IMAGE_FORMATS.md)            | PNG, JPEG, GIF, WebP, TIFF, BMP, ICO                |
| [Drawing & Text](DRAWING.md)                 | Primitives, gradients, fonts, text effects          |
| [Transforms & Filters](TRANSFORMS.md)        | Resize, rotate, blur, edge detection, effects       |
| [Color Models](COLOR_MODELS.md)              | RGBA, HSV, HSL, LAB conversions                     |
| [Utilities](UTILITIES.md)                    | Thumbnails, watermarks, QR codes, blurhash, sprites |
| [Performance](PERFORMANCE.md)                | Optimization techniques and thread-safety           |
| [Security](DECOMPRESSION_BOMB_PROTECTION.md) | Handling untrusted images safely                    |

## Quick Links

### Getting Started

- [Installation](../README.md#installation)
- [Quick Start](QUICK_START.md)
- [Examples](../examples/)

### Common Tasks

- [Resize images](TRANSFORMS.md#resize)
- [Create thumbnails](UTILITIES.md#thumbnails)
- [Draw shapes](DRAWING.md#lines)
- [Render text](DRAWING.md#text-rendering)
- [Apply filters](TRANSFORMS.md#blur)
- [Generate QR codes](UTILITIES.md#qr-codes)

### Reference

- [Supported formats](IMAGE_FORMATS.md#supported-formats)
- [Color models](COLOR_MODELS.md)
- [Font support](DRAWING.md#font-limitations)
- [Thread safety](PERFORMANCE.md#thread-safety)

## API Documentation

Generate API docs with:

```bash
crystal docs
open docs/index.html
```

## Examples

The [examples/](../examples/) directory contains 60+ working demos:

- **Basic:** read/write, resize, crop, rotate
- **Drawing:** shapes, gradients, text
- **Filters:** blur, sharpen, edge detection
- **Effects:** sepia, vignette, emboss
- **Utilities:** thumbnails, watermarks, QR codes
- **Animation:** animated GIFs
- **Advanced:** SIMD, threading, pipelines
