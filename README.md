# CrImage

A comprehensive pure-Crystal image processing library with no external dependencies.

## Why CrImage?

A few highlights:

- Complete image toolkit: formats, drawing, text, filters, effects — all in one shard
- Built-in TrueType font engine (no FreeType dependency)
- Animated GIF creation and multi-resolution ICO support
- QR code generation, blurhash encoding, smart cropping
- Decompression bomb protection for untrusted images

See [Features at a Glance](#features-at-a-glance) for the full list.

## Installation

Add to your `shard.yml`:

```yaml
dependencies:
  crimage:
    github: naqvis/crimage
```

Then run `shards install`.

## Quick Start

```crystal
require "crimage"

# Read any supported format (auto-detected)
img = CrImage.read("photo.jpg")

# Basic operations
resized = img.resize(800, 600, method: :lanczos)
thumbnail = img.thumb(200)  # 200x200 square

# Apply filters
result = img.brightness(20).contrast(1.2).blur(2)

# Save in any format
CrImage::PNG.write("output.png", result)
CrImage::WEBP.write("output.webp", result)
```

## Features at a Glance

| Category      | Capabilities                                                         |
| ------------- | -------------------------------------------------------------------- |
| **Formats**   | PNG, JPEG, GIF (animated), BMP, TIFF, WebP (VP8L), ICO               |
| **Color**     | RGBA, NRGBA, Gray, CMYK, YCbCr, HSV, HSL, LAB, Paletted              |
| **Transform** | Resize (nearest/bilinear/bicubic/lanczos), rotate, crop, flip        |
| **Filters**   | Blur, sharpen, edge detection (Sobel/Prewitt/Roberts/Scharr)         |
| **Effects**   | Sepia, emboss, vignette, temperature, grayscale, invert              |
| **Analysis**  | Histogram, CLAHE, SSIM, PSNR, perceptual hash, palette extraction    |
| **Drawing**   | Lines, circles, polygons, gradients, Bézier, patterns, chart helpers |
| **Text**      | TrueType/OpenType/WOFF fonts, multi-line, alignment, effects         |
| **Utilities** | Thumbnails, watermarks, sprites, QR codes, blurhash, smart crop      |

## Common Tasks

<details>
<summary><b>Resize and Thumbnails</b></summary>

```crystal
# Fit within bounds (preserves aspect ratio)
fitted = img.fit(800, 600)

# Fill exact dimensions (crops excess)
filled = img.fill(800, 600)

# Square thumbnail
avatar = img.thumb(200)

# High-quality resize
hq = img.resize(1920, 1080, method: :lanczos)
```

</details>

<details>
<summary><b>Color Adjustments</b></summary>

```crystal
# Basic adjustments
brighter = img.brightness(30)      # -255 to 255
contrasted = img.contrast(1.5)     # 0.0 to 2.0
grayscale = img.grayscale
inverted = img.invert

# Effects
vintage = img.sepia
warm = img.temperature(30)         # positive = warmer
cool = img.temperature(-30)        # negative = cooler
```

</details>

<details>
<summary><b>Filters</b></summary>

```crystal
# Blur
blurred = img.blur(radius: 3)
gaussian = img.blur_gaussian(radius: 5, sigma: 2.0)

# Sharpen
sharp = img.sharpen(amount: 1.5)

# Edge detection
edges = img.sobel
edges = img.prewitt
edges = img.detect_edges(threshold: 50)
```

</details>

<details>
<summary><b>Drawing</b></summary>

```crystal
img = CrImage.rgba(400, 400, CrImage::Color::WHITE)

# Shapes
img.draw_line(0, 0, 400, 400, color: CrImage::Color::RED)
img.draw_circle(200, 200, 50, color: CrImage::Color::BLUE, fill: true)
img.draw_rect(50, 50, 100, 80, stroke: CrImage::Color::BLACK)

# Thick anti-aliased lines
style = CrImage::Draw::LineStyle.new(CrImage::Color::RED, thickness: 5, anti_alias: true)
CrImage::Draw.line(img, CrImage::Point.new(50, 50), CrImage::Point.new(350, 350), style)

# Ring slice (for donut charts)
ring_style = CrImage::Draw::RingStyle.new(CrImage::Color::BLUE, fill: true)
CrImage::Draw.ring_slice(img, CrImage::Point.new(200, 200), 40, 80, 0.0, Math::PI, ring_style)

# Clipping regions
img.with_clip(50, 50, 200, 200) do |clipped|
  # Drawing here is restricted to the clip region
  clipped.draw_circle(100, 100, 150, color: CrImage::Color::GREEN, fill: true)
end

# Gradients
stops = [
  CrImage::Draw::ColorStop.new(0.0, CrImage::Color::RED),
  CrImage::Draw::ColorStop.new(1.0, CrImage::Color::BLUE)
]
gradient = CrImage::Draw::LinearGradient.new(
  CrImage::Point.new(0, 0),
  CrImage::Point.new(400, 0),
  stops
)
CrImage::Draw.fill_linear_gradient(img, img.bounds, gradient)
```

</details>

<details>
<summary><b>Text Rendering</b></summary>

```crystal
require "freetype"

font = FreeType::TrueType.load("path/to/font.ttf")
face = FreeType::TrueType.new_face(font, 48.0)

img = CrImage.rgba(400, 100, CrImage::Color::WHITE)
text_color = CrImage::Uniform.new(CrImage::Color::BLACK)
drawer = CrImage::Font::Drawer.new(img, text_color, face)

# Simple text
drawer.draw_text("Hello, World!", 20, 60)

# With effects
drawer.draw_text("Styled", 20, 60,
  shadow: true,
  outline: true,
  underline: true
)

# Easy text measurement
width = face.measure("Hello")
width, height = face.text_size("Hello")
line_height = face.line_height
```

</details>

<details>
<summary><b>Animated GIFs</b></summary>

```crystal
frames = (0...10).map do |i|
  frame_img = CrImage.rgba(100, 100, CrImage::Color::WHITE)
  frame_img.draw_circle(10 + i * 8, 50, 10, color: CrImage::Color::RED, fill: true)
  CrImage::GIF::Frame.new(frame_img, delay: 10)  # 100ms per frame
end

animation = CrImage::GIF::Animation.new(frames, 100, 100, loop_count: 0)
CrImage::GIF.write_animation("animated.gif", animation)
```

</details>

<details>
<summary><b>QR Codes</b></summary>

```crystal
# Simple
qr = CrImage.qr_code("https://example.com")
CrImage::PNG.write("qr.png", qr)

# With options
qr = CrImage.qr_code("Hello",
  size: 400,
  error_correction: :high,
  margin: 4
)
```

</details>

<details>
<summary><b>Blurhash</b></summary>

```crystal
# Encode image to blurhash string
hash = img.to_blurhash  # => "LKO2?U%2Tw=w]~RBVZRi};RPxuwH"

# Decode to placeholder
placeholder = CrImage::Util::Blurhash.decode(hash, width: 32, height: 32)
```

</details>

<details>
<summary><b>Image Comparison</b></summary>

```crystal
original = CrImage.read("original.png")
modified = CrImage.read("modified.png")

mse = original.mse(modified)        # Mean Squared Error
psnr = original.psnr(modified)      # Peak Signal-to-Noise Ratio (dB)
ssim = original.ssim(modified)      # Structural Similarity (0-1)

# Visual diff for testing
diff = original.visual_diff(modified)
CrImage::PNG.write("diff.png", diff)
```

</details>

## Font Support

The library includes a complete TrueType font engine:

| Feature                         | Status                                |
| ------------------------------- | ------------------------------------- |
| TrueType (.ttf)                 | ✅ Full support                       |
| OpenType/CFF (.otf)             | ✅ Full support                       |
| WOFF (.woff)                    | ✅ Auto-decompression                 |
| TrueType Collections (.ttc)     | ✅ Multi-font files                   |
| Legacy kern table               | ✅ Pair kerning                       |
| GPOS kerning                    | ✅ Modern pair positioning            |
| GSUB ligatures                  | ✅ Standard ligatures (fi/fl/ffi/ffl) |
| Vertical text                   | ✅ Top-to-bottom layout               |
| Variable fonts                  | ⚠️ Axis detection only                |
| Complex scripts (Arabic, Indic) | ❌ Requires external shaper           |

> **Note:** Text rendering uses left-to-right glyph placement. Complex scripts (Arabic, Hebrew, Thai, Indic) and advanced OpenType features (contextual forms, mark positioning) require an external shaping engine like HarfBuzz.

## Architecture

```
CrImage::Image          # Base interface for all image types
├── CrImage::RGBA       # 8-bit RGBA (premultiplied alpha)
├── CrImage::NRGBA      # 8-bit RGBA (non-premultiplied)
├── CrImage::Gray       # 8-bit grayscale
├── CrImage::Alpha      # 8-bit alpha channel
├── CrImage::CMYK       # Print color model
├── CrImage::YCbCr      # JPEG color model
├── CrImage::Paletted   # Indexed color (GIF)
└── CrImage::Uniform    # Solid color fill

CrImage::Draw           # Drawing primitives
CrImage::Transform      # Resize, rotate, filters
CrImage::Util           # Thumbnails, watermarks, etc.
CrImage::Font           # Text rendering
FreeType::TrueType      # Font parsing
```

## Documentation

| Guide                                              | Description                              |
| -------------------------------------------------- | ---------------------------------------- |
| [Quick Start](guide/QUICK_START.md)                | 10 common tasks with examples            |
| [Image Formats](guide/IMAGE_FORMATS.md)            | Supported formats and adding custom ones |
| [Drawing & Text](guide/DRAWING.md)                 | Primitives, gradients, fonts             |
| [Transforms & Filters](guide/TRANSFORMS.md)        | Resize, rotate, blur, effects            |
| [Color Models](guide/COLOR_MODELS.md)              | RGBA, HSV, LAB conversions               |
| [Utilities](guide/UTILITIES.md)                    | Thumbnails, watermarks, QR, blurhash     |
| [Performance](guide/PERFORMANCE.md)                | Optimization and thread-safety           |
| [Security](guide/DECOMPRESSION_BOMB_PROTECTION.md) | Handling untrusted images                |

**Examples:** See [examples/](examples/) for 60+ working demos.

**API Docs:** Run `crystal docs` and open `docs/index.html`.

## Development

```bash
crystal spec          # Run tests
crystal docs          # Generate API docs
```

## Contributing

1. Fork it (<https://github.com/naqvis/crimage/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

MIT License. See [LICENSE](LICENSE) for details.

## Contributors

- [Ali Naqvi](https://github.com/naqvis) - creator and maintainer
