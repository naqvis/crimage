require "./spec_helper"

# Generate test images for spec tests

module TestDataGenerator
  # Generate a simple video frame-like image (replaces video-001.png)
  def self.video_frame(width : Int32 = 160, height : Int32 = 120) : CrImage::RGBA
    img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

    # Create a colorful test pattern
    height.times do |y|
      width.times do |x|
        # Create color bars pattern
        section = (x * 8) // width

        color = case section
                when 0 then CrImage::Color.rgb(255, 255, 255) # White
                when 1 then CrImage::Color.rgb(255, 255, 0)   # Yellow
                when 2 then CrImage::Color.rgb(0, 255, 255)   # Cyan
                when 3 then CrImage::Color.rgb(0, 255, 0)     # Green
                when 4 then CrImage::Color.rgb(255, 0, 255)   # Magenta
                when 5 then CrImage::Color.rgb(255, 0, 0)     # Red
                when 6 then CrImage::Color.rgb(0, 0, 255)     # Blue
                else        CrImage::Color.rgb(0, 0, 0)       # Black
                end

        # Add gradient in vertical direction
        factor = 1.0 - (y.to_f / height * 0.3)
        r, g, b, a = color.rgba

        new_r = ((r >> 8).to_f * factor).to_u8
        new_g = ((g >> 8).to_f * factor).to_u8
        new_b = ((b >> 8).to_f * factor).to_u8

        img.set(x, y, CrImage::Color.rgb(new_r, new_g, new_b))
      end
    end

    img
  end

  # Generate a grayscale test image (replaces video-005.gray.jpeg)
  def self.grayscale_pattern(width : Int32 = 160, height : Int32 = 120) : CrImage::Gray
    img = CrImage::Gray.new(CrImage.rect(0, 0, width, height))

    height.times do |y|
      width.times do |x|
        # Create a gradient pattern
        value = ((x + y) * 255 // (width + height)).to_u8
        img.set(x, y, CrImage::Color::Gray.new(value))
      end
    end

    img
  end

  # Generate a simple geometric pattern for BMP tests
  def self.geometric_pattern(width : Int32 = 128, height : Int32 = 128) : CrImage::RGBA
    img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

    # Background
    img.fill(CrImage::Color.rgb(240, 240, 240))

    # Draw concentric circles
    center_x = width // 2
    center_y = height // 2

    5.times do |i|
      radius = 10 + i * 15
      color = case i % 3
              when 0 then CrImage::Color.rgb(255, 100, 100)
              when 1 then CrImage::Color.rgb(100, 255, 100)
              else        CrImage::Color.rgb(100, 100, 255)
              end

      draw_circle(img, center_x, center_y, radius, color)
    end

    img
  end

  # Generate a paletted/indexed color image
  def self.paletted_pattern(width : Int32 = 128, height : Int32 = 128) : CrImage::Paletted
    # Create a simple 16-color palette
    palette = CrImage::Color::Palette.new([
      CrImage::Color.rgb(0, 0, 0),       # Black
      CrImage::Color.rgb(255, 255, 255), # White
      CrImage::Color.rgb(255, 0, 0),     # Red
      CrImage::Color.rgb(0, 255, 0),     # Green
      CrImage::Color.rgb(0, 0, 255),     # Blue
      CrImage::Color.rgb(255, 255, 0),   # Yellow
      CrImage::Color.rgb(255, 0, 255),   # Magenta
      CrImage::Color.rgb(0, 255, 255),   # Cyan
      CrImage::Color.rgb(128, 0, 0),     # Dark red
      CrImage::Color.rgb(0, 128, 0),     # Dark green
      CrImage::Color.rgb(0, 0, 128),     # Dark blue
      CrImage::Color.rgb(128, 128, 0),   # Olive
      CrImage::Color.rgb(128, 0, 128),   # Purple
      CrImage::Color.rgb(0, 128, 128),   # Teal
      CrImage::Color.rgb(192, 192, 192), # Silver
      CrImage::Color.rgb(128, 128, 128), # Gray
    ] of CrImage::Color::Color)

    img = CrImage::Paletted.new(CrImage.rect(0, 0, width, height), palette)

    # Create a checkerboard pattern
    height.times do |y|
      width.times do |x|
        # Use different colors based on position
        index = ((x // 16) + (y // 16)) % 16
        img.set_color_index(x, y, index.to_u8)
      end
    end

    img
  end

  # Generate a gradient for PNG tests
  def self.gradient_pattern(width : Int32 = 256, height : Int32 = 256) : CrImage::RGBA
    img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

    height.times do |y|
      width.times do |x|
        r = (255.0 * x / width).to_u8
        g = (255.0 * y / height).to_u8
        b = (255.0 * (1.0 - x.to_f / width)).to_u8

        img.set(x, y, CrImage::Color.rgb(r, g, b))
      end
    end

    img
  end

  # Generate a simple animation frame
  def self.animation_frame(frame_num : Int32, total_frames : Int32,
                           width : Int32 = 100, height : Int32 = 100) : CrImage::RGBA
    img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

    # Background
    img.fill(CrImage::Color.rgb(240, 240, 250))

    # Moving circle
    progress = frame_num.to_f / total_frames
    x = (width * progress).to_i
    y = height // 2

    draw_circle(img, x, y, 20, CrImage::Color.rgb(255, 100, 100))

    img
  end

  # Helper: Draw a circle
  private def self.draw_circle(img : CrImage::Image, cx : Int32, cy : Int32,
                               radius : Int32, color : CrImage::Color::Color)
    bounds = img.bounds
    (-radius..radius).each do |dy|
      (-radius..radius).each do |dx|
        if dx * dx + dy * dy <= radius * radius
          x = cx + dx
          y = cy + dy
          if x >= 0 && x < bounds.width && y >= 0 && y < bounds.height
            img.set(x, y, color)
          end
        end
      end
    end
  end
end

# Generate all test images
puts "🎨 Generating test data images..."
puts ""

# Create base directory
base_dir = "spec/testdata"
Dir.mkdir_p(base_dir)

# Generate main test images
puts "📸 Generating main test images..."
video_001 = TestDataGenerator.video_frame
CrImage::PNG.write("#{base_dir}/video-001.png", video_001)
CrImage::JPEG.write("#{base_dir}/video-001.jpeg", video_001, quality: 90)

# Note: Progressive JPEG is not supported by CrImage encoder
# Create a placeholder that will trigger the expected error
File.write("#{base_dir}/video-001.progressive.jpeg", "PROGRESSIVE_JPEG_PLACEHOLDER")

gray_005 = TestDataGenerator.grayscale_pattern
CrImage::JPEG.write("#{base_dir}/video-005.gray.jpeg", gray_005, quality: 90)

puts "  ✓ video-001.png"
puts "  ✓ video-001.jpeg"
puts "  ✓ video-001.progressive.jpeg (placeholder)"
puts "  ✓ video-005.gray.jpeg"
puts ""

# BMP test images
puts "📸 Generating BMP test images..."
Dir.mkdir_p("#{base_dir}/bmp")

bmp_pattern = TestDataGenerator.geometric_pattern
CrImage::PNG.write("#{base_dir}/bmp/video-001.png", bmp_pattern)
CrImage::BMP.write("#{base_dir}/bmp/video-001.bmp", bmp_pattern)

colormap = TestDataGenerator.paletted_pattern
CrImage::PNG.write("#{base_dir}/bmp/colormap.png", colormap)
CrImage::BMP.write("#{base_dir}/bmp/colormap.bmp", colormap)

gradient_small = TestDataGenerator.gradient_pattern(128, 128)
CrImage::PNG.write("#{base_dir}/bmp/gradient-small.png", gradient_small)
CrImage::BMP.write("#{base_dir}/bmp/gradient-small.bmp", gradient_small)
CrImage::BMP.write("#{base_dir}/bmp/gradient-small-v5.bmp", gradient_small)
CrImage::PNG.write("#{base_dir}/bmp/gradient-small-v5.png", gradient_small)

puts "  ✓ BMP test images (8 files)"
puts ""

# GIF test images
puts "📸 Generating GIF test images..."
Dir.mkdir_p("#{base_dir}/gif")

gif_pattern = TestDataGenerator.video_frame(100, 100)
CrImage::GIF.write("#{base_dir}/gif/video-001.gif", gif_pattern)

# Interlaced GIF (CrImage may not support interlacing, so we create a regular one)
CrImage::GIF.write("#{base_dir}/gif/video-001.interlaced.gif", gif_pattern)

# 5bpp GIF (will be stored as 8bpp internally)
gif_5bpp = TestDataGenerator.paletted_pattern(100, 100)
CrImage::GIF.write("#{base_dir}/gif/video-001.5bpp.gif", gif_5bpp)

# Create a simple triangle pattern
triangle = CrImage::RGBA.new(CrImage.rect(0, 0, 50, 50))
triangle.fill(CrImage::Color.rgb(255, 255, 255))
25.times do |i|
  (0..i).each do |j|
    triangle.set(25 - i + j * 2, 10 + i, CrImage::Color.rgb(255, 0, 0))
  end
end
CrImage::GIF.write("#{base_dir}/gif/triangle-001.gif", triangle)

gray_gif = TestDataGenerator.grayscale_pattern(100, 100)
CrImage::GIF.write("#{base_dir}/gif/video-005.gray.gif", gray_gif)

puts "  ✓ GIF test images (6 files)"
puts ""

# PNG test images
puts "📸 Generating PNG test images..."
Dir.mkdir_p("#{base_dir}/png")

# Various PNG test patterns
gradient = TestDataGenerator.gradient_pattern
CrImage::PNG.write("#{base_dir}/png/gray-gradient.png", gradient)

bench_gray = TestDataGenerator.grayscale_pattern(256, 256)
CrImage::PNG.write("#{base_dir}/png/benchGray.png", bench_gray)

bench_rgb = TestDataGenerator.video_frame(256, 256)
CrImage::PNG.write("#{base_dir}/png/benchRGB.png", bench_rgb)

# Interlaced RGB
CrImage::PNG.write("#{base_dir}/png/benchRGB-interlace.png", bench_rgb)

# NRGBA gradient - convert to NRGBA explicitly
bench_nrgba_rgba = TestDataGenerator.gradient_pattern(256, 256)
bench_nrgba = CrImage::NRGBA.new(bench_nrgba_rgba.bounds)
bench_nrgba_rgba.bounds.height.times do |y|
  bench_nrgba_rgba.bounds.width.times do |x|
    bench_nrgba.set(x, y, bench_nrgba_rgba.at(x, y))
  end
end
CrImage::PNG.write("#{base_dir}/png/benchNRGBA-gradient.png", bench_nrgba)

bench_paletted = TestDataGenerator.paletted_pattern(256, 256)
CrImage::PNG.write("#{base_dir}/png/benchPaletted.png", bench_paletted)

puts "  ✓ PNG test images (6 files)"
puts ""

# TIFF test images
puts "📸 Generating TIFF test images..."
Dir.mkdir_p("#{base_dir}/tiff")

tiff_pattern = TestDataGenerator.video_frame
CrImage::TIFF.write("#{base_dir}/tiff/video-001.tiff", tiff_pattern)

tiff_gray = TestDataGenerator.grayscale_pattern
CrImage::TIFF.write("#{base_dir}/tiff/video-001-gray.tiff", tiff_gray)

tiff_paletted = TestDataGenerator.paletted_pattern
CrImage::TIFF.write("#{base_dir}/tiff/video-001-paletted.tiff", tiff_paletted)

# Simple black and white pattern
bw = CrImage::Gray.new(CrImage.rect(0, 0, 64, 64))
64.times do |y|
  64.times do |x|
    value = ((x + y) % 2 == 0) ? 255_u8 : 0_u8
    bw.set(x, y, CrImage::Color::Gray.new(value))
  end
end
CrImage::TIFF.write("#{base_dir}/tiff/bw-uncompressed.tiff", bw)

puts "  ✓ TIFF test images (4 files)"
puts ""

# WebP test images
puts "📸 Generating WebP test images..."
Dir.mkdir_p("#{base_dir}/webp")

# Blue-purple-pink gradient
blue_purple = CrImage::RGBA.new(CrImage.rect(0, 0, 256, 256))
256.times do |y|
  256.times do |x|
    t = x.to_f / 256
    r = (100 + 155 * t).to_u8
    g = (100 - 50 * t).to_u8
    b = (255 - 100 * t).to_u8
    blue_purple.set(x, y, CrImage::Color.rgb(r, g, b))
  end
end
CrImage::WEBP.write("#{base_dir}/webp/blue-purple-pink.lossless.webp", blue_purple)

# Large version
blue_purple_large = CrImage::RGBA.new(CrImage.rect(0, 0, 512, 512))
512.times do |y|
  512.times do |x|
    t = x.to_f / 512
    r = (100 + 155 * t).to_u8
    g = (100 - 50 * t).to_u8
    b = (255 - 100 * t).to_u8
    blue_purple_large.set(x, y, CrImage::Color.rgb(r, g, b))
  end
end
CrImage::WEBP.write("#{base_dir}/webp/blue-purple-pink-large.lossless.webp", blue_purple_large)

# Small grayscale patterns (1bpp, 2bpp, 4bpp, 8bpp)
[1, 2, 4, 8].each do |bpp|
  colors_count = 2 ** bpp
  small_pattern = CrImage::RGBA.new(CrImage.rect(0, 0, 64, 64))
  64.times do |y|
    64.times do |x|
      # Create a pattern based on position
      value = ((x + y) * colors_count // 128) % colors_count
      gray = (value * 255 // (colors_count - 1)).to_u8
      small_pattern.set(x, y, CrImage::Color.rgb(gray, gray, gray))
    end
  end
  CrImage::WEBP.write("#{base_dir}/webp/small-pattern.#{bpp}bpp.lossless.webp", small_pattern)
end

# Geometric shape (circles and ovals)
geometric = CrImage::RGBA.new(CrImage.rect(0, 0, 100, 100))
geometric.fill(CrImage::Color.rgb(255, 255, 255))
# Outer shape (black oval)
50.times do |y|
  40.times do |x|
    if (x - 20) ** 2 + (y - 25) ** 2 < 400
      geometric.set(x + 30, y + 30, CrImage::Color.rgb(0, 0, 0))
    end
  end
end
# Inner shape (white oval)
30.times do |y|
  20.times do |x|
    if (x - 10) ** 2 + (y - 15) ** 2 < 150
      geometric.set(x + 40, y + 45, CrImage::Color.rgb(255, 255, 255))
    end
  end
end
CrImage::WEBP.write("#{base_dir}/webp/geometric.lossless.webp", geometric)

# Radial gradient (warm colors)
radial_gradient = CrImage::RGBA.new(CrImage.rect(0, 0, 200, 200))
200.times do |y|
  200.times do |x|
    dx = x - 100
    dy = y - 100
    dist = Math.sqrt(dx * dx + dy * dy)
    if dist < 80
      intensity = (1.0 - dist / 80.0)
      r = (255 * intensity).to_u8
      g = (220 * intensity).to_u8
      b = (100 * intensity).to_u8
      radial_gradient.set(x, y, CrImage::Color.rgb(r, g, b))
    else
      radial_gradient.set(x, y, CrImage::Color.rgb(240, 240, 240))
    end
  end
end
CrImage::WEBP.write("#{base_dir}/webp/radial-gradient.lossless.webp", radial_gradient)

# Lossy WebP files (minimal valid RIFF/WEBP with VP8 chunk to trigger NotImplementedError)
# These will trigger NotImplementedError when read
lossy_webp = IO::Memory.new
lossy_webp.write("RIFF".to_slice)
lossy_webp.write_bytes(20_u32, IO::ByteFormat::LittleEndian) # File size - 8
lossy_webp.write("WEBP".to_slice)
lossy_webp.write("VP8 ".to_slice)                           # VP8 lossy chunk (note the space)
lossy_webp.write_bytes(8_u32, IO::ByteFormat::LittleEndian) # Chunk size
8.times { lossy_webp.write_bytes(0_u8) }                    # Dummy data
File.write("#{base_dir}/webp/blue-purple-pink.lossy.webp", lossy_webp.to_slice)

lossy_alpha_webp = IO::Memory.new
lossy_alpha_webp.write("RIFF".to_slice)
lossy_alpha_webp.write_bytes(20_u32, IO::ByteFormat::LittleEndian)
lossy_alpha_webp.write("WEBP".to_slice)
lossy_alpha_webp.write("VP8 ".to_slice) # VP8 lossy chunk
lossy_alpha_webp.write_bytes(8_u32, IO::ByteFormat::LittleEndian)
8.times { lossy_alpha_webp.write_bytes(0_u8) }
File.write("#{base_dir}/webp/radial-gradient.lossy-with-alpha.webp", lossy_alpha_webp.to_slice)

puts "  ✓ WebP test images (12 files)"
puts ""

# BMP test images (for BMP spec)
puts "📸 Generating BMP test images for specs..."
Dir.mkdir_p("#{base_dir}/bmp")

colormap_bmp = TestDataGenerator.paletted_pattern
CrImage::PNG.write("#{base_dir}/bmp/colormap.png", colormap_bmp)

puts "  ✓ BMP reference images (1 file)"
puts ""

# GIF test images (for GIF specs)
puts "📸 Generating GIF test images for specs..."
Dir.mkdir_p("#{base_dir}/gif")

gif_video = TestDataGenerator.video_frame(100, 100)
CrImage::GIF.write("#{base_dir}/gif/video-001.gif", gif_video)

puts "  ✓ GIF test images (1 file)"
puts ""

puts "Test data generation complete!"
