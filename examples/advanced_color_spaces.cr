require "../src/crimage"

# Demonstrate advanced color space conversions and manipulations

puts "Advanced Color Space Demo"
puts "=" * 50

# Create a test image with various colors
width, height = 400, 300
img = CrImage.rgba(width, height)

# Fill with a rainbow gradient
height.times do |y|
  width.times do |x|
    hue = (x.to_f / width) * 360.0
    saturation = 1.0
    value = 1.0 - (y.to_f / height) * 0.5

    # Convert HSV to RGB
    c = value * saturation
    x_val = c * (1 - ((hue / 60.0) % 2 - 1).abs)
    m = value - c

    r, g, b = case hue
              when 0...60    then {c, x_val, 0.0}
              when 60...120  then {x_val, c, 0.0}
              when 120...180 then {0.0, c, x_val}
              when 180...240 then {0.0, x_val, c}
              when 240...300 then {x_val, 0.0, c}
              else                {c, 0.0, x_val}
              end

    r_byte = ((r + m) * 255).to_u8
    g_byte = ((g + m) * 255).to_u8
    b_byte = ((b + m) * 255).to_u8

    img.set(x, y, CrImage::Color::RGBA.new(r_byte, g_byte, b_byte, 255))
  end
end

CrImage::PNG.write("output/color_space_original.png", img)
puts "Created rainbow gradient: output/color_space_original.png"

# Demonstrate YCbCr color space
puts "\n1. YCbCr Color Space (JPEG/Video)"
ycbcr_img = CrImage::YCbCr.new(img.bounds, CrImage::YCbCrSubSampleRatio::YCbCrSubsampleRatio444)
height.times do |y|
  width.times do |x|
    color = img.at(x, y)
    r, g, b, _ = color.rgba
    y_val, cb_val, cr_val = CrImage::Color.rgb_to_ycbcr((r >> 8).to_u8, (g >> 8).to_u8, (b >> 8).to_u8)
    ycbcr_img.set_ycbcr(x, y, CrImage::Color::YCbCr.new(y_val, cb_val, cr_val))
  end
end

# Manipulate in YCbCr space - reduce color saturation
ycbcr_desaturated = CrImage::RGBA.new(img.bounds)
height.times do |y|
  width.times do |x|
    ycbcr = ycbcr_img.ycbcr_at(x, y).as(CrImage::Color::YCbCr)
    # Move Cb and Cr toward 128 (neutral) to desaturate
    cb_new = (ycbcr.cb * 0.5 + 128 * 0.5).to_u8
    cr_new = (ycbcr.cr * 0.5 + 128 * 0.5).to_u8
    ycbcr_desaturated.set(x, y, CrImage::Color::YCbCr.new(ycbcr.y, cb_new, cr_new))
  end
end

CrImage::PNG.write("output/color_space_ycbcr_desaturated.png", ycbcr_desaturated)
puts "   Desaturated in YCbCr space: output/color_space_ycbcr_desaturated.png"

# Demonstrate CMYK color space
puts "\n2. CMYK Color Space (Printing)"
cmyk_img = CrImage::RGBA.new(img.bounds)
height.times do |y|
  width.times do |x|
    color = img.at(x, y)
    r, g, b, _ = color.rgba
    c, m, y_cmyk, k = CrImage::Color.rgb_to_cmyk((r >> 8).to_u8, (g >> 8).to_u8, (b >> 8).to_u8)

    # Visualize CMYK channels
    if x < width // 4
      # Show Cyan channel
      cmyk_img.set(x, y, CrImage::Color::RGBA.new(0, 255 - c, 255 - c, 255))
    elsif x < width // 2
      # Show Magenta channel
      cmyk_img.set(x, y, CrImage::Color::RGBA.new(255 - m, 0, 255 - m, 255))
    elsif x < 3 * width // 4
      # Show Yellow channel
      cmyk_img.set(x, y, CrImage::Color::RGBA.new(255 - y_cmyk, 255 - y_cmyk, 0, 255))
    else
      # Show Black channel
      val = 255 - k
      cmyk_img.set(x, y, CrImage::Color::RGBA.new(val, val, val, 255))
    end
  end
end

CrImage::PNG.write("output/color_space_cmyk_channels.png", cmyk_img)
puts "   CMYK channels visualization: output/color_space_cmyk_channels.png"

# Demonstrate Grayscale conversion with different methods
puts "\n3. Grayscale Conversions"

# Method 1: Using color model (perceptually weighted)
gray_img1 = CrImage::Gray.new(img.bounds)
height.times do |y|
  width.times do |x|
    gray_color = CrImage::Color.gray_model.convert(img.at(x, y)).as(CrImage::Color::Gray)
    gray_img1.set(x, y, gray_color)
  end
end

gray_rgba1 = CrImage::RGBA.new(img.bounds)
height.times do |y|
  width.times do |x|
    gray_rgba1.set(x, y, gray_img1.at(x, y))
  end
end

CrImage::PNG.write("output/color_space_gray_weighted.png", gray_rgba1)
puts "   Perceptually weighted: output/color_space_gray_weighted.png"

# Method 2: Using YCbCr luminance
gray_img2 = CrImage::RGBA.new(img.bounds)
height.times do |y|
  width.times do |x|
    color = img.at(x, y)
    r, g, b, _ = color.rgba
    y_val, _, _ = CrImage::Color.rgb_to_ycbcr((r >> 8).to_u8, (g >> 8).to_u8, (b >> 8).to_u8)
    gray_img2.set(x, y, CrImage::Color::RGBA.new(y_val, y_val, y_val, 255))
  end
end

CrImage::PNG.write("output/color_space_gray_luminance.png", gray_img2)
puts "   YCbCr luminance: output/color_space_gray_luminance.png"

# Demonstrate color space comparison
puts "\n4. Color Space Properties"
test_color = CrImage::Color::RGBA.new(128, 64, 192, 255)

# Convert to different spaces
nrgba = CrImage::Color.nrgba_model.convert(test_color).as(CrImage::Color::NRGBA)
ycbcr = CrImage::Color.ycbcr_model.convert(test_color).as(CrImage::Color::YCbCr)
cmyk = CrImage::Color.cmyk_model.convert(test_color).as(CrImage::Color::CMYK)
gray = CrImage::Color.gray_model.convert(test_color).as(CrImage::Color::Gray)

puts "   Original RGBA: (#{test_color.r}, #{test_color.g}, #{test_color.b}, #{test_color.a})"
puts "   NRGBA: (#{nrgba.r}, #{nrgba.g}, #{nrgba.b}, #{nrgba.a})"
puts "   YCbCr: (Y=#{ycbcr.y}, Cb=#{ycbcr.cb}, Cr=#{ycbcr.cr})"
puts "   CMYK: (C=#{cmyk.c}, M=#{cmyk.m}, Y=#{cmyk.y}, K=#{cmyk.k})"
puts "   Gray: (#{gray.y})"

puts "\nColor space use cases:"
puts "- RGBA/NRGBA: General purpose, screen display"
puts "- YCbCr: JPEG, video, brightness/color separation"
puts "- CMYK: Printing, subtractive color"
puts "- Gray: Grayscale images, masks, memory efficiency"
