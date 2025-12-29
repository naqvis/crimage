require "../src/crimage"

# Example: Pipeline/Fluent API
#
# Demonstrates the fluent API for chaining image operations
# in a readable, expressive style.
#
# Usage:
#   crystal run examples/pipeline_api_demo.cr

puts "Pipeline/Fluent API Demo"
puts "=" * 50

# Create a base image
base = CrImage.rgba(300, 200, CrImage::Color::WHITE)
base.draw_circle(150, 100, 60, color: CrImage::Color::RED, fill: true)
base.draw_rect(50, 50, 80, 60, fill: CrImage::Color::BLUE)
CrImage::PNG.write("pipeline_original.png", base)
puts "Created base image: pipeline_original.png"

# Chain multiple transform operations
puts "\nChaining: resize -> brightness -> border -> round_corners..."
result = base.pipeline
  .resize(200, 133)
  .brightness(30)
  .border(15, CrImage::Color::RGBA.new(50_u8, 50_u8, 50_u8, 255_u8))
  .round_corners(20)
  .result

CrImage::PNG.write("pipeline_transformed.png", result)
puts "Saved: pipeline_transformed.png"

# Pipeline with drawing operations
puts "\nCreating image with chained drawing..."
drawn = CrImage.rgba(300, 200, CrImage::Color::WHITE)
  .pipeline
  .draw_rect(20, 20, 100, 80, CrImage::Color::RED)
  .draw_circle(200, 100, 50, CrImage::Color::BLUE)
  .draw_line(0, 0, 299, 199, CrImage::Color::GREEN, thickness: 2)
  .draw_line(0, 199, 299, 0, CrImage::Color::GREEN, thickness: 2)
  .result

CrImage::PNG.write("pipeline_drawing.png", drawn)
puts "Saved: pipeline_drawing.png"

# Pipeline with filters
puts "\nApplying filter chain: grayscale -> blur -> sharpen..."
filtered = base.pipeline
  .grayscale
  .blur(2)
  .sharpen(1.0)
  .result

CrImage::PNG.write("pipeline_filtered.png", filtered)
puts "Saved: pipeline_filtered.png"

# Pipeline with custom operation
puts "\nUsing custom operation in pipeline..."
custom = base.pipeline
  .apply { |img| img.invert }
  .border(5, CrImage::Color::WHITE)
  .result

CrImage::PNG.write("pipeline_custom.png", custom)
puts "Saved: pipeline_custom.png"

# Complex pipeline combining everything
puts "\nComplex pipeline with multiple operations..."
complex = CrImage.rgba(400, 300, CrImage::Color::WHITE)
  .pipeline
  .draw_circle(200, 150, 80, CrImage::Color::RED)
  .draw_rect(50, 50, 100, 80, CrImage::Color::BLUE)
  .resize(300, 225)
  .contrast(1.3)
  .border(10, CrImage::Color::BLACK)
  .round_corners(15)
  .result

CrImage::PNG.write("pipeline_complex.png", complex)
puts "Saved: pipeline_complex.png"

puts "\nOutput files:"
puts "  - pipeline_original.png"
puts "  - pipeline_transformed.png"
puts "  - pipeline_drawing.png"
puts "  - pipeline_filtered.png"
puts "  - pipeline_custom.png"
puts "  - pipeline_complex.png"
