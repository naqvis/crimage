require "../src/crimage"

# Demonstrate thread-safe and non-thread-safe operations

puts "Thread Safety Demo"
puts "=" * 50

# 1. Thread-safe: Reading from different images in parallel
puts "\n1. Safe: Parallel image processing"
puts "-" * 40

images = [] of CrImage::RGBA
3.times do |i|
  img = CrImage::RGBA.new(CrImage.rect(0, 0, 100, 100))
  100.times do |y|
    100.times do |x|
      img.set(x, y, CrImage::Color::RGBA.new((i * 80).to_u8, (x + y).to_u8, 128, 255))
    end
  end
  images << img
end

channel = Channel(CrImage::RGBA).new
images.each_with_index do |img, i|
  spawn do
    # Each fiber processes a different image - SAFE
    resized = img.resize(50, 50, method: :bilinear)
    channel.send(resized)
  end
end

results = [] of CrImage::RGBA
3.times { results << channel.receive }
puts "Processed #{results.size} images in parallel safely"

# 2. Thread-safe: Immutable operations
puts "\n2. Safe: Immutable operations"
puts "-" * 40

base_img = CrImage::RGBA.new(CrImage.rect(0, 0, 100, 100))
100.times do |y|
  100.times do |x|
    base_img.set(x, y, CrImage::Color::RGBA.new((x * 2).to_u8, (y * 2).to_u8, 128, 255))
  end
end

channel2 = Channel(CrImage::Image).new
spawn do
  # Returns new image - SAFE
  result = base_img.brightness(50)
  channel2.send(result)
end

spawn do
  # Returns new image - SAFE
  result = base_img.blur(radius: 2)
  channel2.send(result)
end

2.times { channel2.receive }
puts "Multiple immutable operations on same image safely"

# 3. NOT thread-safe: Concurrent writes
puts "\n3. Unsafe: Concurrent writes (DON'T DO THIS)"
puts "-" * 40

unsafe_img = CrImage::RGBA.new(CrImage.rect(0, 0, 100, 100))

puts "⚠ This would cause data races:"
puts "  spawn { unsafe_img.set(0, 0, color1) }"
puts "  spawn { unsafe_img.set(1, 1, color2) }"
puts "  # Multiple fibers writing to same image!"

# 4. Safe alternative: Use mutex for synchronization
puts "\n4. Safe: Synchronized writes"
puts "-" * 40

safe_img = CrImage::RGBA.new(CrImage.rect(0, 0, 100, 100))
mutex = Mutex.new

done = Channel(Nil).new
10.times do |i|
  spawn do
    mutex.synchronize do
      # Only one fiber can write at a time - SAFE
      safe_img.set(i * 10, i * 10, CrImage::Color::RED)
    end
    done.send(nil)
  end
end

10.times { done.receive }
puts "Synchronized writes completed safely"

# 5. Safe: In-place operations with proper synchronization
puts "\n5. Safe: In-place operations (single-threaded)"
puts "-" * 40

inplace_img = CrImage::RGBA.new(CrImage.rect(0, 0, 100, 100))
100.times do |y|
  100.times do |x|
    inplace_img.set(x, y, CrImage::Color::RGBA.new(128, 128, 128, 255))
  end
end

# In-place operations should be single-threaded
inplace_img.brightness!(50).blur!(2)
puts "In-place operations completed (single-threaded)"

puts "\nThread Safety Summary:"
puts "Safe: Reading from different images in parallel"
puts "Safe: Immutable operations (resize, brightness, etc.)"
puts "Safe: Color conversions (pure functions)"
puts "x Unsafe: Concurrent writes to same image"
puts "x Unsafe: In-place operations from multiple threads"
puts "Solution: Use mutex or process images sequentially"
