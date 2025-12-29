require "../src/crimage"

# Demonstrate color space conversions
puts "Color Space Conversion Demo"
puts "=" * 50

# Create a gradient image
width = 256
height = 100
img = CrImage.rgba(width, height)

# Fill with horizontal gradient (red to blue)
height.times do |y|
  width.times do |x|
    r = (255 - x).to_u8
    b = x.to_u8
    img.set(x, y, CrImage::Color::RGBA.new(r, 0_u8, b, 255_u8))
  end
end

puts "\nOriginal image: #{width}x#{height}"

# Convert to HSV and back
hsv_img = img.to_hsv
puts "Converted to HSV and back: #{hsv_img.bounds.width}x#{hsv_img.bounds.height}"

# Convert to HSL and back
hsl_img = img.to_hsl
puts "Converted to HSL and back: #{hsl_img.bounds.width}x#{hsl_img.bounds.height}"

# Convert to LAB and back
lab_img = img.to_lab
puts "Converted to LAB and back: #{lab_img.bounds.width}x#{lab_img.bounds.height}"

# Demonstrate individual color conversions
puts "\nIndividual Color Conversions:"
puts "-" * 50

test_colors = [
  {name: "Red", color: CrImage::Color::RGBA.new(255_u8, 0_u8, 0_u8, 255_u8)},
  {name: "Green", color: CrImage::Color::RGBA.new(0_u8, 255_u8, 0_u8, 255_u8)},
  {name: "Blue", color: CrImage::Color::RGBA.new(0_u8, 0_u8, 255_u8, 255_u8)},
  {name: "Yellow", color: CrImage::Color::RGBA.new(255_u8, 255_u8, 0_u8, 255_u8)},
  {name: "Cyan", color: CrImage::Color::RGBA.new(0_u8, 255_u8, 255_u8, 255_u8)},
  {name: "Magenta", color: CrImage::Color::RGBA.new(255_u8, 0_u8, 255_u8, 255_u8)},
]

test_colors.each do |tc|
  puts "\n#{tc[:name]} RGB(#{tc[:color].r}, #{tc[:color].g}, #{tc[:color].b}):"

  hsv = tc[:color].to_hsv
  puts "  HSV: H=#{hsv.h.round(1)}° S=#{hsv.s.round(3)} V=#{hsv.v.round(3)}"

  hsl = tc[:color].to_hsl
  puts "  HSL: H=#{hsl.h.round(1)}° S=#{hsl.s.round(3)} L=#{hsl.l.round(3)}"

  lab = tc[:color].to_lab
  puts "  LAB: L=#{lab.l.round(1)} A=#{lab.a.round(1)} B=#{lab.b.round(1)}"
end

puts "\n" + "=" * 50
puts "Color space conversions completed successfully!"
