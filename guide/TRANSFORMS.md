# Transforms & Filters Guide

Image transformations, filters, and effects.

## Resize

```crystal
# Basic resize
resized = img.resize(800, 600)

# With interpolation method
nearest = img.resize(800, 600, method: :nearest)   # Fastest, pixelated
bilinear = img.resize(800, 600, method: :bilinear) # Good balance
bicubic = img.resize(800, 600, method: :bicubic)   # Better quality
lanczos = img.resize(800, 600, method: :lanczos)   # Best quality, slowest

# Convenience methods
fitted = img.fit(800, 600)      # Fit within bounds, preserve aspect ratio
filled = img.fill(800, 600)    # Fill exact dimensions, crop excess
avatar = img.thumb(200)         # Square thumbnail (200x200)
```

**Algorithm Comparison:**

| Method   | Speed | Quality | Best For            |
| -------- | ----- | ------- | ------------------- |
| Nearest  | ★★★★★ | ★☆☆☆☆   | Pixel art, previews |
| Bilinear | ★★★★☆ | ★★★☆☆   | General use         |
| Bicubic  | ★★★☆☆ | ★★★★☆   | Photos              |
| Lanczos  | ★★☆☆☆ | ★★★★★   | High-quality output |

## Rotate

```crystal
# Optimized 90° increments
rotated_90 = img.rotate(90)
rotated_180 = img.rotate(180)
rotated_270 = img.rotate(270)

# Arbitrary angles
rotated_45 = img.rotate(45.0)
rotated_30 = img.rotate(30.0, interpolation: CrImage::Transform::RotationInterpolation::Nearest)

# With background color (for corners)
rotated = img.rotate(15.0, background: CrImage::Color::WHITE)

# Flip
flipped_h = img.flip_horizontal
flipped_v = img.flip_vertical
```

## Crop

```crystal
# By coordinates
cropped = img.crop(100, 100, 400, 300)  # x, y, width, height

# By rectangle
cropped = img.crop(CrImage.rect(100, 100, 500, 400))

# Smart crop (content-aware)
smart = img.smart_crop(800, 600)  # Default: entropy-based

# Different strategies
entropy = img.smart_crop(800, 600, CrImage::Util::CropStrategy::Entropy)
edge = img.smart_crop(800, 600, CrImage::Util::CropStrategy::Edge)
center = img.smart_crop(800, 600, CrImage::Util::CropStrategy::CenterWeighted)
attention = img.smart_crop(800, 600, CrImage::Util::CropStrategy::Attention)
```

**Smart Crop Strategies:**

| Strategy       | Description                                |
| -------------- | ------------------------------------------ |
| Entropy        | Keeps regions with most detail/information |
| Edge           | Keeps regions with most edges              |
| CenterWeighted | Prefers center but considers content       |
| Attention      | Tries to keep faces and important subjects |

## Blur

```crystal
# Box blur
blurred = img.blur(radius: 3)

# Gaussian blur
gaussian = img.blur_gaussian(radius: 5)
gaussian = img.blur_gaussian(radius: 5, sigma: 2.0)

# In-place (memory efficient)
img.blur!(3)
img.blur_gaussian!(radius: 5, sigma: 2.0)
```

## Sharpen

```crystal
sharpened = img.sharpen(amount: 1.5)

# In-place
img.sharpen!(1.5)
```

## Color Adjustments

```crystal
# Brightness (-255 to 255)
brighter = img.brightness(50)
darker = img.brightness(-50)

# Contrast (0.0 to 2.0, 1.0 = no change)
more_contrast = img.contrast(1.5)
less_contrast = img.contrast(0.7)

# Grayscale
gray = img.grayscale

# Invert colors
inverted = img.invert

# In-place operations
img.brightness!(30)
img.contrast!(1.2)
img.invert!
```

## Edge Detection

```crystal
# Different operators
sobel = img.sobel          # Most common, good balance
prewitt = img.prewitt      # Similar to Sobel
roberts = img.roberts      # Fast 2x2 operator
scharr = img.detect_edges(EdgeOperator::Scharr)  # Improved Sobel

# Binary edge map with threshold
binary_edges = img.sobel(threshold: 50)
```

**Operator Comparison:**

| Operator | Kernel Size | Speed | Noise Sensitivity |
| -------- | ----------- | ----- | ----------------- |
| Roberts  | 2×2         | ★★★★★ | High              |
| Prewitt  | 3×3         | ★★★★☆ | Medium            |
| Sobel    | 3×3         | ★★★★☆ | Medium            |
| Scharr   | 3×3         | ★★★☆☆ | Low               |

## Visual Effects

```crystal
# Sepia (vintage look)
vintage = img.sepia

# Emboss (3D raised effect)
embossed = img.emboss(angle: 45.0, depth: 1.5)

# Vignette (darkened edges)
vignetted = img.vignette(strength: 0.7)

# Temperature adjustment
warmer = img.temperature(30)   # Positive = warmer (orange/red)
cooler = img.temperature(-30)  # Negative = cooler (blue)
```

## Histogram Operations

```crystal
# Analyze histogram
hist = img.histogram
puts "Mean: #{hist.mean}"
puts "Median: #{hist.median}"
puts "Std Dev: #{hist.std_dev}"
puts "90th percentile: #{hist.percentile(90)}"

# Global equalization
enhanced = img.equalize

# CLAHE (Contrast Limited Adaptive Histogram Equalization)
adaptive = img.equalize_adaptive(tile_size: 16, clip_limit: 2.0)
```

## Dithering

Reduce color depth while maintaining visual quality:

```crystal
# Create palette
palette = CrImage::Color::Palette.new([
  CrImage::Color::BLACK,
  CrImage::Color::WHITE,
  CrImage::Color::RED,
  CrImage::Color::GREEN,
  CrImage::Color::BLUE,
] of CrImage::Color::Color)

# Apply dithering
floyd = img.dither(palette)  # Floyd-Steinberg (default)
atkinson = img.dither(palette, DitheringAlgorithm::Atkinson)
sierra = img.dither(palette, DitheringAlgorithm::Sierra)
ordered = img.dither(palette, DitheringAlgorithm::Ordered)
```

**Dithering Algorithms:**

| Algorithm       | Neighbors | Effect                |
| --------------- | --------- | --------------------- |
| Floyd-Steinberg | 4         | Most common, balanced |
| Atkinson        | 6         | Lighter, artistic     |
| Sierra          | 10        | More diffusion        |
| Burkes          | 7         | Good balance          |
| Stucki          | 12        | High quality          |
| Ordered/Bayer   | N/A       | Regular pattern       |

## Morphological Operations

```crystal
# Basic operations
eroded = img.erode(5)                    # Shrink bright regions
dilated = img.dilate(5)                  # Expand bright regions
opened = img.morphology_open(5)          # Remove noise
closed = img.morphology_close(5)         # Fill gaps
gradient = img.morphology_gradient(3)    # Edge detection

# Different structuring elements
cross_eroded = img.erode(5, StructuringElement::Cross)
ellipse_dilated = img.dilate(7, StructuringElement::Ellipse)
```

## Color Quantization

Generate optimal palettes:

```crystal
# Different algorithms
median_cut = img.generate_palette(16, QuantizationAlgorithm::MedianCut)
octree = img.generate_palette(16, QuantizationAlgorithm::Octree)
popularity = img.generate_palette(16, QuantizationAlgorithm::Popularity)

# Apply palette with dithering
quantized = img.dither(median_cut)
```

## Noise

```crystal
# Add noise to image
grainy = img.add_noise(0.1, CrImage::Util::NoiseType::Gaussian)
uniform = img.add_noise(0.1, CrImage::Util::NoiseType::Uniform)
salt_pepper = img.add_noise(0.05, CrImage::Util::NoiseType::SaltAndPepper)
perlin = img.add_noise(0.2, CrImage::Util::NoiseType::Perlin)

# Monochrome noise (same for all channels)
vintage = img.add_noise(0.15, monochrome: true)

# Generate noise texture
noise = CrImage.generate_noise(800, 600, CrImage::Util::NoiseType::Perlin)
```

## In-Place Operations

For memory efficiency, use bang methods:

```crystal
# These modify the image directly (no copy)
img.brightness!(50)
img.contrast!(1.2)
img.blur!(3)
img.blur_gaussian!(radius: 5, sigma: 2.0)
img.sharpen!(1.5)
img.invert!

# Chain in-place operations
img.brightness!(30).contrast!(1.2).blur!(2)
```

> **Note:** In-place operations only work on RGBA images.

## Pipeline API

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

# Available pipeline operations:
# - resize, scale, crop, rotate, flip
# - brightness, contrast, grayscale, invert, saturate
# - blur, sharpen, edge_detect
# - border, round_corners, sepia, vignette
# - draw_rect, draw_circle, draw_line
# - apply { |img| custom_operation(img) }
```

## EXIF Auto-Orientation

```crystal
# Read EXIF and auto-orient
exif = CrImage::EXIF.read("photo.jpg")
if exif && exif.needs_transform?
  img = img.auto_orient(exif.orientation)
end

# Or by orientation value (1-8)
img = img.auto_orient(6)  # Rotate 90° clockwise
```

**EXIF Orientation Values:**

| Value | Transform       |
| ----- | --------------- |
| 1     | Normal          |
| 2     | Flip horizontal |
| 3     | Rotate 180°     |
| 4     | Flip vertical   |
| 5     | Transpose       |
| 6     | Rotate 90° CW   |
| 7     | Transverse      |
| 8     | Rotate 270° CW  |
