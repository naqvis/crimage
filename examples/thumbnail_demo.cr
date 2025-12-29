require "../src/crimage"

# Create a sample image with a gradient pattern
width = 400
height = 300
img = CrImage.rgba(width, height)

# Fill with a gradient pattern
height.times do |y|
  width.times do |x|
    r = (x.to_f / width * 255).to_u8
    g = (y.to_f / height * 255).to_u8
    b = 128_u8
    img.set(x, y, CrImage::Color.rgb(r, g, b))
  end
end

# Save original
CrImage::PNG.write("thumbnail_original.png", img)
puts "Created original image: 400x300"

# Generate thumbnails with different modes
target_width = 150
target_height = 150

# Fit mode - preserves aspect ratio, fits within bounds
thumb_fit = CrImage::Util.thumbnail(img, target_width, target_height,
  CrImage::Util::ThumbnailMode::Fit,
  CrImage::Util::ResampleQuality::Bicubic)
CrImage::PNG.write("thumbnail_fit.png", thumb_fit)
puts "Fit mode: #{thumb_fit.bounds.width}x#{thumb_fit.bounds.height} (preserves aspect ratio)"

# Fill mode - fills bounds exactly, may crop
thumb_fill = CrImage::Util.thumbnail(img, target_width, target_height,
  CrImage::Util::ThumbnailMode::Fill,
  CrImage::Util::ResampleQuality::Bicubic)
CrImage::PNG.write("thumbnail_fill.png", thumb_fill)
puts "Fill mode: #{thumb_fill.bounds.width}x#{thumb_fill.bounds.height} (fills bounds, crops excess)"

# Stretch mode - stretches to exact dimensions
thumb_stretch = CrImage::Util.thumbnail(img, target_width, target_height,
  CrImage::Util::ThumbnailMode::Stretch,
  CrImage::Util::ResampleQuality::Bicubic)
CrImage::PNG.write("thumbnail_stretch.png", thumb_stretch)
puts "Stretch mode: #{thumb_stretch.bounds.width}x#{thumb_stretch.bounds.height} (stretches to exact size)"

# Demonstrate different quality levels
thumb_nearest = CrImage::Util.thumbnail(img, 100, 100,
  CrImage::Util::ThumbnailMode::Fit,
  CrImage::Util::ResampleQuality::Nearest)
CrImage::PNG.write("thumbnail_nearest.png", thumb_nearest)
puts "Nearest quality: #{thumb_nearest.bounds.width}x#{thumb_nearest.bounds.height} (fastest)"

thumb_lanczos = CrImage::Util.thumbnail(img, 100, 100,
  CrImage::Util::ThumbnailMode::Fit,
  CrImage::Util::ResampleQuality::Lanczos)
CrImage::PNG.write("thumbnail_lanczos.png", thumb_lanczos)
puts "Lanczos quality: #{thumb_lanczos.bounds.width}x#{thumb_lanczos.bounds.height} (highest quality)"

puts "\nThumbnail generation complete!"
