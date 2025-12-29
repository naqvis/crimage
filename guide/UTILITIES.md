# Utilities Guide

Thumbnails, watermarks, QR codes, blurhash, sprites, and more.

## Thumbnails

```crystal
# Convenience methods (recommended)
fitted = img.fit(800, 600)       # Fit within bounds, preserve aspect ratio
filled = img.fill(800, 600)      # Fill exact dimensions, crop excess
avatar = img.thumb(200)          # Square thumbnail (200x200)

# With quality options
fast = img.fit(800, 600, quality: :nearest)
smooth = img.fill(800, 600, quality: :lanczos)

# Full API
thumb = CrImage::Util.thumbnail(
  img,
  width: 200,
  height: 200,
  mode: CrImage::Util::ThumbnailMode::Fill,
  quality: CrImage::Util::ResampleQuality::Bicubic
)
```

**Modes:**

| Mode    | Behavior                                  |
| ------- | ----------------------------------------- |
| Fit     | Scale to fit within bounds (no cropping)  |
| Fill    | Scale and crop to fill exactly            |
| Stretch | Stretch to exact dimensions (may distort) |

## Watermarks

```crystal
# Image watermark
watermark_img = CrImage.read("logo.png")
options = CrImage::Util::WatermarkOptions.new(
  position: CrImage::Util::WatermarkPosition::BottomRight,
  opacity: 0.7
)
result = CrImage::Util.watermark_image(img, watermark_img, options)

# Tiled watermark
tiled_options = CrImage::Util::WatermarkOptions.new(
  position: CrImage::Util::WatermarkPosition::Center,
  opacity: 0.3,
  tiled: true
)
result = CrImage::Util.watermark_image(img, watermark_img, tiled_options)

# Text watermark
font = FreeType::TrueType.load("font.ttf")
face = FreeType::TrueType.new_face(font, 48.0)
text_options = CrImage::Util::WatermarkOptions.new(
  position: CrImage::Util::WatermarkPosition::Center,
  opacity: 0.5
)
result = CrImage::Util.watermark_text(img, "© 2024", face, text_options)

# Custom position
custom_options = CrImage::Util::WatermarkOptions.new(
  position: CrImage::Util::WatermarkPosition::Custom,
  custom_point: CrImage::Point.new(50, 50),
  opacity: 0.8
)
```

**Positions:** TopLeft, TopRight, BottomLeft, BottomRight, Center, Custom

## QR Codes

```crystal
# Simple
qr = CrImage.qr_code("https://example.com")
CrImage::PNG.write("qr.png", qr)

# With options
qr = CrImage.qr_code("Hello World",
  size: 400,
  error_correction: :high,
  margin: 4
)

# With logo overlay
logo = CrImage::PNG.read("logo.png")
qr = CrImage.qr_code("https://example.com",
  size: 400,
  logo: logo,
  logo_scale: 0.2,
  logo_border: 4
)

# Low-level API
code = CrImage::Util::QRCode.encode("Hello",
  error_correction: CrImage::Util::QRCode::ErrorCorrection::Medium
)
puts "Version: #{code.version}, Size: #{code.size}x#{code.size}"

# Custom colors
img = code.to_image(
  module_size: 10,
  margin: 4,
  foreground: CrImage::Color::BLUE,
  background: CrImage::Color::WHITE
)
```

**Error Correction Levels:**

| Level     | Recovery | Use Case              |
| --------- | -------- | --------------------- |
| :low      | ~7%      | Maximum data capacity |
| :medium   | ~15%     | Default, balanced     |
| :quartile | ~25%     | Printed codes         |
| :high     | ~30%     | Damaged/dirty codes   |

## Blurhash

Compact image placeholders:

```crystal
# Encode image to blurhash string
hash = img.to_blurhash  # => "LKO2?U%2Tw=w]~RBVZRi};RPxuwH"

# With custom components (more = more detail)
hash = img.to_blurhash(x_components: 5, y_components: 4)

# Decode to placeholder image
placeholder = CrImage::Util::Blurhash.decode(hash, width: 32, height: 32)

# With contrast boost
placeholder = CrImage::Util::Blurhash.decode(hash, 32, 32, punch: 1.5)

# Get average color (fast)
avg_color = CrImage::Util::Blurhash.average_color(hash)

# Validate
if CrImage::Util::Blurhash.valid?(hash)
  x, y = CrImage::Util::Blurhash.components(hash)
  puts "Components: #{x}x#{y}"
end
```

## Sprite Sheets

```crystal
sprites = [
  CrImage.read("icon1.png"),
  CrImage.read("icon2.png"),
  CrImage.read("icon3.png"),
]

# Generate sprite sheet
sheet = CrImage.generate_sprite_sheet(
  sprites,
  CrImage::Util::SpriteLayout::Horizontal,
  spacing: 8,
  background: CrImage::Color::TRANSPARENT
)

CrImage::PNG.write("sprites.png", sheet.image)

# Access sprite positions
sheet.sprites.each_with_index do |sprite, i|
  puts "Sprite #{i}: x=#{sprite.x}, y=#{sprite.y}, #{sprite.width}x#{sprite.height}"
end

# Extract sprite by index
sprite_info = sheet[2]
extracted = sheet.image.crop(sprite_info.bounds)
```

**Layouts:**

| Layout     | Description           |
| ---------- | --------------------- |
| Horizontal | Single row            |
| Vertical   | Single column         |
| Grid       | Optimal grid          |
| Packed     | Minimize wasted space |

## Borders and Frames

```crystal
# Simple border
bordered = img.add_border(20, CrImage::Color::WHITE)

# Rounded corners
rounded = img.round_corners(30)

# Border with shadow
shadowed = img.add_border_with_shadow(
  border_width: 20,
  border_color: CrImage::Color::WHITE,
  shadow_offset: 10,
  shadow_blur: 15
)

# Rounded border with shadow
framed = img.add_rounded_border(
  border_width: 25,
  corner_radius: 40,
  border_color: CrImage::Color::WHITE,
  shadow: true
)
```

## Image Tiling

```crystal
# Tile in grid
tiled = tile.tile(4, 3)  # 4 columns, 3 rows

# Tile to fill dimensions
background = tile.tile_to_size(1920, 1080)

# Make seamless (blend edges)
seamless = tile.make_seamless(blend_width: 15)
seamless_tiled = seamless.tile(5, 5)
```

## Image Stacking

```crystal
images = [img1, img2, img3]

# Horizontal
horizontal = CrImage.stack_horizontal(images, spacing: 10)

# Vertical
vertical = CrImage.stack_vertical(images, spacing: 10)

# Before/after comparison
comparison = CrImage.compare_images(before, after, divider: true)

# Grid layout
gallery = CrImage.create_grid(images, cols: 3, spacing: 15)
```

## Image Comparison

```crystal
original = CrImage.read("expected.png")
actual = CrImage.read("actual.png")

# Quality metrics
mse = original.mse(actual)       # Mean Squared Error (0 = identical)
psnr = original.psnr(actual)     # Peak SNR in dB (higher = better)
ssim = original.ssim(actual)     # Structural Similarity (1.0 = identical)

# Perceptual hash
hash1 = original.perceptual_hash
hash2 = actual.perceptual_hash
distance = CrImage::Util::Metrics.hamming_distance(hash1, hash2)
puts "Similar!" if distance < 10

# Visual diff
diff = original.visual_diff(actual)
CrImage::PNG.write("diff.png", diff)

# Count differences
count = original.diff_count(actual, threshold: 10)
percent = CrImage::Util::VisualDiff.diff_percent(original, actual)

# Check if identical
if original.identical?(actual, threshold: 10, tolerance: 5)
  puts "Images match!"
end
```

**Metric Interpretation:**

| Metric | Identical | Excellent | Good     | Poor   |
| ------ | --------- | --------- | -------- | ------ |
| MSE    | 0         | <100      | <500     | >1000  |
| PSNR   | ∞         | >40 dB    | 30-40 dB | <30 dB |
| SSIM   | 1.0       | >0.98     | >0.90    | <0.80  |
| pHash  | 0         | <5        | <10      | >15    |

## Palette Extraction

```crystal
# Extract dominant colors
colors = img.extract_palette(5)
colors.each { |c| puts c.to_hex }

# With frequency weights
weighted = img.extract_palette_with_weights(5)
weighted.each do |color, weight|
  puts "#{color.to_hex}: #{(weight * 100).round(1)}%"
end

# Single dominant color
dominant = img.dominant_color
```

## Channel Operations

```crystal
# Extract channels
red = img.extract_channel(:red)
green = img.extract_channel(:green)
blue = img.extract_channel(:blue)
alpha = img.extract_channel(:alpha)

# Split all at once
r, g, b = img.split_rgb
r, g, b, a = img.split_rgba

# Combine channels
combined = CrImage::Util::Channels.combine(red, green, blue)

# Manipulate channels
swapped = img.swap_channels(:red, :blue)
boosted = img.multiply_channel(:red, 1.5)
zeroed = img.set_channel(:green, 0_u8)
inverted = img.invert_channel(:blue)
```

## Factory Methods

```crystal
# Checkerboard (transparency background)
checker = CrImage.checkerboard(400, 300, cell_size: 16)
checker = CrImage.checkerboard(400, 300,
  cell_size: 8,
  color1: CrImage::Color.rgb(200, 200, 200),
  color2: CrImage::Color::WHITE
)

# Gradients
horizontal = CrImage.gradient(400, 100, CrImage::Color::RED, CrImage::Color::BLUE, :horizontal)
vertical = CrImage.gradient(100, 400, CrImage::Color::GREEN, CrImage::Color::YELLOW, :vertical)
diagonal = CrImage.gradient(400, 400, CrImage::Color::BLACK, CrImage::Color::WHITE, :diagonal)
```
