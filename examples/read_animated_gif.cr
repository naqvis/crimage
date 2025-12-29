require "../src/crimage"

# Example: Read and analyze an animated GIF

unless ARGV.size > 0
  puts "Usage: crystal run examples/read_animated_gif.cr <path_to_animated.gif>"
  exit 1
end

gif_path = ARGV[0]

unless File.exists?(gif_path)
  puts "Error: File not found: #{gif_path}"
  exit 1
end

puts "Reading animated GIF: #{gif_path}"
puts

# Read the animation
animation = CrImage::GIF.read_animation(gif_path)

puts "Animation Info:"
puts "  Dimensions: #{animation.width}x#{animation.height}"
puts "  Frames: #{animation.frames.size}"
puts "  Loop count: #{animation.loop_count == 0 ? "infinite" : animation.loop_count}"
puts "  Total duration: #{animation.duration}ms (#{animation.duration / 1000.0}s)"
puts

# Analyze each frame
puts "Frame Details:"
animation.frames.each_with_index do |frame, i|
  puts "  Frame #{i + 1}:"
  puts "    Delay: #{frame.delay} centiseconds (#{frame.delay * 10}ms)"
  puts "    Disposal: #{frame.disposal}"
  puts "    Transparent index: #{frame.transparent_index || "none"}"
  puts "    Image size: #{frame.image.bounds.width}x#{frame.image.bounds.height}"
end
puts

# Calculate average FPS
avg_delay = animation.frames.sum(&.delay) / animation.frames.size
fps = 100.0 / avg_delay
puts "Average FPS: #{fps.round(2)}"

# Export frames if requested
if ARGV.size > 1 && ARGV[1] == "--export"
  puts "\nExporting frames..."
  animation.frames.each_with_index do |frame, i|
    filename = "frame_#{i.to_s.rjust(4, '0')}.png"
    CrImage::PNG.write(filename, frame.image)
    puts "  Saved: #{filename}"
  end
  puts "Exported #{animation.frames.size} frames"
end
