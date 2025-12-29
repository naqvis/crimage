# Quick Start Guide

10 common tasks to get you started with CrImage.

## 1. Read and Write Images

```crystal
require "crimage"

# Read any supported format (auto-detected)
img = CrImage.read("input.jpg")

# Write to different formats
CrImage::PNG.write("output.png", img)
CrImage::JPEG.write("output.jpg", img)
CrImage::WEBP.write("output.webp", img)

# Or use auto-detection by extension
CrImage.write("output.png", img)
```

## 2. Create Thumbnails

```crystal
# Fit within bounds (preserves aspect ratio)
thumbnail = img.fit(200, 200)

# Fill exact dimensions (crops excess)
cover = img.fill(200, 200)

# Square thumbnail
avatar = img.thumb(150)

# With quality control
hq_thumb = img.fit(200, 200, quality: :lanczos)
```

## 3. Resize Images

```crystal
# Basic resize
resized = img.resize(800, 600)

# With interpolation method
nearest = img.resize(800, 600, method: :nearest)   # Fastest
bilinear = img.resize(800, 600, method: :bilinear) # Good balance
bicubic = img.resize(800, 600, method: :bicubic)   # Better quality
lanczos = img.resize(800, 600, method: :lanczos)   # Best quality
```

## 4. Apply Filters

```crystal
# Blur
blurred = img.blur(radius: 3)
gaussian = img.blur_gaussian(radius: 5, sigma: 2.0)

# Sharpen
sharp = img.sharpen(amount: 1.5)

# Edge detection
edges = img.sobel
edges_binary = img.sobel(threshold: 50)

# Color adjustments
brighter = img.brightness(30)    # -255 to 255
contrasted = img.contrast(1.2)   # 0.0 to 2.0
grayscale = img.grayscale
inverted = img.invert
```

## 5. Crop and Rotate

```crystal
# Crop
cropped = img.crop(100, 100, 400, 300)  # x, y, width, height
cropped = img.crop(CrImage.rect(100, 100, 500, 400))

# Rotate
rotated_90 = img.rotate(90)    # Optimized for 90° increments
rotated_45 = img.rotate(45.0)  # Arbitrary angle

# Flip
flipped_h = img.flip_horizontal
flipped_v = img.flip_vertical
```

## 6. Draw Shapes

```crystal
img = CrImage.rgba(400, 400, CrImage::Color::WHITE)

# Lines
img.draw_line(0, 0, 400, 400, color: CrImage::Color::RED, thickness: 2)

# Circles
img.draw_circle(200, 200, 50, color: CrImage::Color::BLUE, fill: true)

# Rectangles
img.draw_rect(50, 50, 100, 80, stroke: CrImage::Color::BLACK, fill: CrImage::Color::YELLOW)

# Polygons
points = [
  CrImage::Point.new(200, 50),
  CrImage::Point.new(250, 150),
  CrImage::Point.new(150, 150)
]
img.draw_polygon(points, outline: CrImage::Color::GREEN, fill: CrImage::Color::GREEN)

CrImage::PNG.write("shapes.png", img)
```

## 7. Render Text

```crystal
require "freetype"

# Load font
font = FreeType::TrueType.load("/path/to/font.ttf")
face = FreeType::TrueType.new_face(font, 48.0)  # 48pt

# Create image
img = CrImage.rgba(400, 100, CrImage::Color::WHITE)

# Draw text
text_color = CrImage::Uniform.new(CrImage::Color::BLACK)
drawer = CrImage::Font::Drawer.new(img, text_color, face)
drawer.draw_text("Hello, World!", 20, 60)

# With effects
drawer.draw_text("Styled Text", 20, 60,
  shadow: true,
  outline: true,
  underline: true
)

CrImage::PNG.write("text.png", img)
```

## 8. Create Animated GIFs

```crystal
# Create frames
frames = [] of CrImage::GIF::Frame

10.times do |i|
  frame_img = CrImage.rgba(100, 100, CrImage::Color::WHITE)
  x = 10 + i * 8
  frame_img.draw_circle(x, 50, 10, color: CrImage::Color::RED, fill: true)
  frames << CrImage::GIF::Frame.new(frame_img, delay: 10)  # 100ms
end

# Create animation
animation = CrImage::GIF::Animation.new(frames, 100, 100, loop_count: 0)
CrImage::GIF.write_animation("animation.gif", animation)

# Read animation
loaded = CrImage::GIF.read_animation("animation.gif")
puts "#{loaded.frames.size} frames, #{loaded.duration}ms total"
```

## 9. Generate QR Codes

```crystal
# Simple QR code
qr = CrImage.qr_code("https://example.com")
CrImage::PNG.write("qr.png", qr)

# With options
qr = CrImage.qr_code("Hello World",
  size: 400,
  error_correction: :high,
  margin: 4
)

# Custom colors
code = CrImage::Util::QRCode.encode("Data")
img = code.to_image(
  module_size: 10,
  foreground: CrImage::Color::BLUE,
  background: CrImage::Color::WHITE
)
```

## 10. Compare Images

```crystal
original = CrImage.read("expected.png")
actual = CrImage.read("actual.png")

# Quality metrics
mse = original.mse(actual)       # Mean Squared Error (0 = identical)
psnr = original.psnr(actual)     # Peak SNR in dB (higher = better)
ssim = original.ssim(actual)     # Structural Similarity (1.0 = identical)

puts "MSE: #{mse}, PSNR: #{psnr} dB, SSIM: #{ssim}"

# Visual diff
diff = original.visual_diff(actual)
CrImage::PNG.write("diff.png", diff)

# Check if images match
if original.identical?(actual, threshold: 10, tolerance: 5)
  puts "Images match!"
end
```

## Bonus: Pipeline API

Chain operations fluently:

```crystal
result = img.pipeline
  .resize(800, 600)
  .brightness(20)
  .contrast(1.2)
  .blur(2)
  .border(10, CrImage::Color::WHITE)
  .round_corners(15)
  .result

CrImage::PNG.write("processed.png", result)
```

## Next Steps

- [Image Formats](IMAGE_FORMATS.md) — PNG, JPEG, GIF, WebP details
- [Drawing & Text](DRAWING.md) — Advanced drawing and fonts
- [Transforms & Filters](TRANSFORMS.md) — All transformation options
- [Utilities](UTILITIES.md) — Thumbnails, watermarks, blurhash, sprites
- [Performance](PERFORMANCE.md) — Optimization tips
