# Image Formats Guide

CrImage supports reading and writing multiple image formats with automatic detection.

## Supported Formats

| Format | Read | Write | Features                                |
| ------ | ---- | ----- | --------------------------------------- |
| PNG    | ✅   | ✅    | 8/16-bit, alpha, interlaced             |
| JPEG   | ✅   | ✅    | Baseline & progressive, quality control |
| GIF    | ✅   | ✅    | Animated, transparency, LZW             |
| BMP    | ✅   | ✅    | 1/4/8/24/32-bit                         |
| TIFF   | ✅   | ✅    | Deflate compression, strips/tiles       |
| WebP   | ✅   | ✅    | VP8L lossless only                      |
| ICO    | ✅   | ✅    | Multi-resolution icons                  |

## Auto-Detection

```crystal
# Read any format (detected from magic bytes)
img = CrImage.read("image.png")
img = CrImage.read("photo.jpg")

# Check supported formats
puts CrImage.supported_formats  # => ["bmp", "gif", "jpeg", "png", "tiff", "webp"]

# Read config without decoding pixels (fast)
config = CrImage.read_config("large_image.png")
puts "#{config.width}x#{config.height}"
```

## PNG

Portable Network Graphics — lossless compression with alpha support.

```crystal
# Read
img = CrImage::PNG.read("image.png")
config = CrImage::PNG.read_config("image.png")

# Write
CrImage::PNG.write("output.png", img)

# Write to IO
io = IO::Memory.new
CrImage::PNG.write(io, img)
```

**Features:**

- 8-bit and 16-bit color depth
- Full alpha channel support
- Interlaced images (Adam7)
- Grayscale, RGB, RGBA, paletted
- Decompression bomb protection

## JPEG

Joint Photographic Experts Group — lossy compression for photos.

```crystal
# Read
img = CrImage::JPEG.read("photo.jpg")

# Write with quality (1-100, default 75)
CrImage::JPEG.write("output.jpg", img)
CrImage::JPEG.write("high_quality.jpg", img, 95)
CrImage::JPEG.write("small_file.jpg", img, 60)

# Read EXIF metadata
exif = CrImage::EXIF.read("photo.jpg")
if exif
  puts "Camera: #{exif.camera}"
  puts "ISO: #{exif.iso}"
  puts "Orientation: #{exif.orientation}"

  # Auto-orient based on EXIF
  if exif.needs_transform?
    img = img.auto_orient(exif.orientation)
  end
end
```

**Features:**

- Baseline and progressive JPEG
- Quality control (1-100)
- YCbCr color space
- EXIF metadata reading
- Auto-orientation correction

**Quantization Control:**

```crystal
# Access standard quantization tables
lum_table = CrImage::JPEG::STANDARD_LUMINANCE_QUANT_TABLE
chrom_table = CrImage::JPEG::STANDARD_CHROMINANCE_QUANT_TABLE

# Scale for different quality
high_q = CrImage::JPEG.scale_quant_table(lum_table, 95)
low_q = CrImage::JPEG.scale_quant_table(lum_table, 20)
```

## GIF

Graphics Interchange Format — animation and transparency support.

```crystal
# Read static GIF
img = CrImage::GIF.read("image.gif")

# Read animated GIF
animation = CrImage::GIF.read_animation("animated.gif")
puts "Frames: #{animation.frames.size}"
puts "Duration: #{animation.duration}ms"
puts "Loop count: #{animation.loop_count}"  # 0 = infinite

# Access frames
animation.frames.each_with_index do |frame, i|
  puts "Frame #{i}: delay=#{frame.delay}cs"
  CrImage::PNG.write("frame_#{i}.png", frame.image)
end

# Write static GIF (auto-converts to paletted)
CrImage::GIF.write("output.gif", img)

# Write animated GIF
frames = (0...10).map do |i|
  frame_img = CrImage.rgba(100, 100, CrImage::Color::WHITE)
  frame_img.draw_circle(10 + i * 8, 50, 10, color: CrImage::Color::RED, fill: true)
  CrImage::GIF::Frame.new(frame_img, delay: 10)  # 100ms
end

animation = CrImage::GIF::Animation.new(frames, 100, 100, loop_count: 0)
CrImage::GIF.write_animation("animated.gif", animation)
```

**Features:**

- 256 color palette (auto-generated from true-color)
- Transparency via transparent color index
- Animation with frame delays
- Loop control (infinite or specific count)
- Disposal methods
- LZW compression
- Decompression bomb protection

## BMP

Windows Bitmap — simple uncompressed format.

```crystal
# Read
img = CrImage::BMP.read("image.bmp")

# Write
CrImage::BMP.write("output.bmp", img)
```

**Features:**

- 1, 4, 8, 24, 32-bit color depths
- RLE compression (reading)
- Top-down and bottom-up orientation

## TIFF

Tagged Image File Format — flexible format for archival.

```crystal
# Read
img = CrImage::TIFF.read("image.tiff")

# Write uncompressed
CrImage::TIFF.write("output.tiff", img)

# Write with deflate compression
CrImage::TIFF.write("compressed.tiff", img, CrImage::TIFF::CompressionType::Deflate)
```

**Features:**

- Little-endian (II) and big-endian (MM)
- Grayscale (8/16-bit), RGB, RGBA, paletted
- Uncompressed and Deflate compression
- Strip-based and tiled images
- Horizontal predictor

## WebP

Google's modern image format — superior lossless compression.

```crystal
# Read
img = CrImage::WEBP.read("image.webp")

# Write (VP8L lossless)
CrImage::WEBP.write("output.webp", img)

# Write with extended format (VP8X for metadata)
options = CrImage::WEBP::Options.new(use_extended_format: true)
CrImage::WEBP.write("extended.webp", img, options)
```

**Features:**

- VP8L lossless format
- Alpha channel support
- RIFF container parsing
- Predictor and color transforms
- LZ77 and Huffman encoding

> **Note:** Currently only VP8L (lossless) is supported. VP8 (lossy) is planned.

## ICO

Windows Icon format — multi-resolution icons.

```crystal
# Read (returns largest image)
icon = CrImage::ICO.read("favicon.ico")

# Read all sizes
all_icons = CrImage::ICO.read_all("favicon.ico")
puts "Contains #{all_icons.images.size} sizes"

# Get specific size
icon_32 = all_icons.find_size(32, 32)
largest = all_icons.largest
smallest = all_icons.smallest

# Write single icon
CrImage::ICO.write("icon.ico", img)

# Write multi-resolution
icons = [16, 32, 48].map do |size|
  img.fit(size, size)
end
CrImage::ICO.write_multi("favicon.ico", icons)
```

**Features:**

- Multiple resolutions in one file
- Standard sizes: 16, 32, 48, 64, 128, 256
- Full alpha transparency
- PNG compression for large sizes

## Format Conversion

```crystal
# Read any format
img = CrImage.read("input.webp")

# Convert to any other format
CrImage::PNG.write("output.png", img)
CrImage::JPEG.write("output.jpg", img, 85)
CrImage::GIF.write("output.gif", img)
CrImage::BMP.write("output.bmp", img)
CrImage::TIFF.write("output.tiff", img)
CrImage::WEBP.write("output.webp", img)
```

## Custom Format Registration

Add support for custom formats:

```crystal
module MyFormat
  extend CrImage::ImageReader

  def self.read(path : String) : CrImage::Image
    # Implementation
  end

  def self.read(io : IO) : CrImage::Image
    # Implementation
  end

  def self.read_config(path : String) : CrImage::Config
    # Implementation
  end

  def self.read_config(io : IO) : CrImage::Config
    # Implementation
  end
end

# Register with magic bytes
CrImage.register_format("xyz", "MAGIC".to_slice, MyFormat)
```
