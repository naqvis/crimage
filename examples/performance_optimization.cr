require "../src/crimage"
require "benchmark"

# Demonstrate performance optimization techniques

puts "Performance Optimization Demo"
puts "=" * 50

# Create test images
width, height = 1000, 1000
img = CrImage.rgba(width, height)

# Fill with test pattern
height.times do |y|
  width.times do |x|
    r = ((x + y) % 256).to_u8
    g = (x % 256).to_u8
    b = (y % 256).to_u8
    img.set(x, y, CrImage::Color::RGBA.new(r, g, b, 255))
  end
end

puts "Created #{width}x#{height} test image"

# 1. Demonstrate bulk operations vs pixel-by-pixel
puts "\n1. Bulk Operations vs Pixel-by-Pixel"
puts "-" * 40

result1 = CrImage::RGBA.new(img.bounds)
result2 = CrImage::RGBA.new(img.bounds)

time1 = Benchmark.measure do
  # Pixel-by-pixel (slower)
  height.times do |y|
    width.times do |x|
      color = img.at(x, y)
      r, g, b, a = color.rgba
      # Simple brightness adjustment
      new_r = [(r >> 8).to_i + 50, 255].min.to_u8
      new_g = [(g >> 8).to_i + 50, 255].min.to_u8
      new_b = [(b >> 8).to_i + 50, 255].min.to_u8
      result1.set(x, y, CrImage::Color::RGBA.new(new_r, new_g, new_b, (a >> 8).to_u8))
    end
  end
end

time2 = Benchmark.measure do
  # Direct buffer access (faster)
  stride = img.stride
  bounds = img.bounds
  (bounds.min.y...bounds.max.y).each do |y|
    offset = y * stride
    (bounds.min.x...bounds.max.x).each do |x|
      idx = offset + x * 4
      result2.pix[idx] = [img.pix[idx].to_i + 50, 255].min.to_u8
      result2.pix[idx + 1] = [img.pix[idx + 1].to_i + 50, 255].min.to_u8
      result2.pix[idx + 2] = [img.pix[idx + 2].to_i + 50, 255].min.to_u8
      result2.pix[idx + 3] = img.pix[idx + 3]
    end
  end
end

puts "Pixel-by-pixel: #{time1.real}s"
puts "Direct buffer:  #{time2.real}s"
puts "Speedup: #{(time1.real / time2.real).round(2)}x"

# 2. In-place operations vs creating new images
puts "\n2. In-Place Operations vs New Images"
puts "-" * 40

img_copy1 = CrImage::RGBA.new(img.bounds)
height.times do |y|
  width.times do |x|
    img_copy1.set(x, y, img.at(x, y))
  end
end

img_copy2 = CrImage::RGBA.new(img.bounds)
height.times do |y|
  width.times do |x|
    img_copy2.set(x, y, img.at(x, y))
  end
end

time_new = Benchmark.measure do
  # Creates new image (more memory)
  temp = img_copy1.brightness(30)
  img_copy1 = temp
end

time_inplace = Benchmark.measure do
  # Modifies in-place (less memory)
  img_copy2.brightness!(30)
end

puts "New image:     #{time_new.real}s"
puts "In-place:      #{time_inplace.real}s"
puts "Memory saved:  ~#{(width * height * 4) / 1024 / 1024}MB (one image copy)"

# 3. Color model selection impact
puts "\n3. Color Model Selection"
puts "-" * 40

# RGBA (alpha-premultiplied) - fast blending
rgba_img = CrImage.rgba(500, 500)
# NRGBA (non-premultiplied) - accurate colors
nrgba_img = CrImage.nrgba(500, 500)
# Gray - memory efficient
gray_img = CrImage.gray(500, 500)

puts "Memory usage for 500x500 image:"
puts "  RGBA:  #{500 * 500 * 4 / 1024}KB (4 bytes/pixel)"
puts "  NRGBA: #{500 * 500 * 4 / 1024}KB (4 bytes/pixel)"
puts "  Gray:  #{500 * 500 * 1 / 1024}KB (1 byte/pixel)"
puts "  YCbCr 4:2:0: ~#{(500 * 500 * 1.5).to_i / 1024}KB (1.5 bytes/pixel)"

# 4. Resize algorithm comparison
puts "\n4. Resize Algorithm Performance"
puts "-" * 40

small_img = CrImage.rgba(200, 200)
200.times do |y|
  200.times do |x|
    small_img.set(x, y, CrImage::Color::RGBA.new((x % 256).to_u8, (y % 256).to_u8, 128, 255))
  end
end

algorithms = {
  nearest:  "Nearest Neighbor (fastest, lowest quality)",
  bilinear: "Bilinear (balanced)",
  bicubic:  "Bicubic (slower, better quality)",
  lanczos:  "Lanczos (slowest, best quality)",
}

algorithms.each do |method, description|
  time = Benchmark.measure do
    resized = small_img.resize(800, 800, method: method)
  end
  puts "#{method.to_s.ljust(10)}: #{time.real.round(4)}s - #{description}"
end

# 5. Sub-image operations (zero-copy)
puts "\n5. Sub-Image Operations (Zero-Copy)"
puts "-" * 40

time_copy = Benchmark.measure do
  # Crop creates a new image (allocates new memory)
  cropped = img.crop(100, 100, 400, 400)
end

time_subimage = Benchmark.measure do
  # Sub-image shares memory with original
  sub = img.sub_image(CrImage.rect(100, 100, 500, 500))
end

puts "Crop (copy):      #{time_copy.real}s"
puts "Sub-image (ref):  #{time_subimage.real}s"
puts "Note: sub_image shares pixel data with original"

# 6. Color conversion caching
puts "\n6. Color Conversion Optimization"
puts "-" * 40

test_colors = Array.new(1000) do
  CrImage::Color::RGBA.new(rand(256).to_u8, rand(256).to_u8, rand(256).to_u8, 255)
end

time_no_cache = Benchmark.measure do
  1000.times do
    test_colors.each do |color|
      # Convert every time
      CrImage::Color.ycbcr_model.convert(color)
    end
  end
end

# With caching
cache = Hash(CrImage::Color::RGBA, CrImage::Color::YCbCr).new
time_cached = Benchmark.measure do
  1000.times do
    test_colors.each do |color|
      cache[color] ||= CrImage::Color.ycbcr_model.convert(color).as(CrImage::Color::YCbCr)
    end
  end
end

puts "Without cache: #{time_no_cache.real}s"
puts "With cache:    #{time_cached.real}s"
puts "Speedup: #{(time_no_cache.real / time_cached.real).round(2)}x"
