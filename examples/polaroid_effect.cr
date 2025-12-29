require "../src/crimage"
require "../src/freetype"
require "./sample_images"
require "option_parser"

# Polaroid Effect Generator
# This example demonstrates creating a classic polaroid photo effect:
# - White border frame with larger bottom section
# - Vintage color grading (sepia or faded colors)
# - Subtle vignette effect
# - Optional caption text at bottom
# - Slight rotation for authentic look
# - Shadow effect for depth

module PolaroidEffect
  # Polaroid style options
  enum Style
    Classic # Sepia tone, strong vintage look
    Faded   # Desaturated colors, soft vintage
    Modern  # Minimal processing, clean look
  end

  # Generate a polaroid-style image
  def self.generate(input_path : String, output_path : String,
                    caption : String?, font_path : String?,
                    style : Style = Style::Classic,
                    rotate_angle : Float64 = 0.0)
    puts "📸 Creating polaroid effect..."

    # 1. Load image
    puts "📂 Loading image: #{input_path}"
    img = CrImage.read(input_path)

    # 2. Apply vintage color effect based on style
    puts "🎨 Applying #{style} color effect..."
    processed = apply_color_effect(img, style)

    # 3. Add subtle vignette
    puts "🌑 Adding vignette..."
    vignetted = processed.vignette(strength: 0.25, radius: 0.8)

    # 4. Create polaroid frame
    puts "🖼️  Creating polaroid frame..."
    polaroid = create_polaroid_frame(vignetted, caption, font_path)

    # 5. Apply rotation if specified
    if rotate_angle != 0.0
      puts "🔄 Rotating polaroid..."
      polaroid = CrImage::Transform.rotate(
        polaroid,
        rotate_angle,
        interpolation: CrImage::Transform::RotationInterpolation::Bilinear,
        background: CrImage::Color.rgb(245, 245, 240)
      )
    end

    # 6. Add shadow effect
    puts "💫 Adding shadow effect..."
    final = add_shadow(polaroid)

    # 7. Save result
    puts "💾 Saving polaroid..."
    CrImage::PNG.write(output_path, final)

    puts "✅ Done! Polaroid saved to: #{output_path}"
    puts "   Size: #{final.bounds.width}x#{final.bounds.height}px"
  end

  # Apply color effect based on style
  private def self.apply_color_effect(img : CrImage::Image, style : Style) : CrImage::Image
    case style
    when .classic?
      # Classic sepia tone
      img.sepia
    when .faded?
      # Faded colors: reduce saturation and add slight warmth
      desaturated = reduce_saturation(img, 0.4)
      desaturated.temperature(10)
    when .modern?
      # Minimal processing: slight contrast boost
      img.contrast(1.1)
    else
      img
    end
  end

  # Reduce saturation by blending with grayscale
  private def self.reduce_saturation(img : CrImage::Image, amount : Float64) : CrImage::Image
    bounds = img.bounds
    width = bounds.width
    height = bounds.height

    result = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

    height.times do |y|
      width.times do |x|
        r, g, b, a = img.at(x + bounds.min.x, y + bounds.min.y).rgba

        # Calculate grayscale value
        gray = ((r * 299 + g * 587 + b * 114) // 1000)

        # Blend between color and grayscale
        new_r = ((r.to_f * (1.0 - amount) + gray * amount)).to_u16
        new_g = ((g.to_f * (1.0 - amount) + gray * amount)).to_u16
        new_b = ((b.to_f * (1.0 - amount) + gray * amount)).to_u16

        result.set(x, y, CrImage::Color::RGBA64.new(new_r, new_g, new_b, a))
      end
    end

    result
  end

  # Create polaroid frame with white border
  private def self.create_polaroid_frame(img : CrImage::Image,
                                         caption : String?,
                                         font_path : String?) : CrImage::RGBA
    src_bounds = img.bounds
    src_width = src_bounds.width
    src_height = src_bounds.height

    # Polaroid proportions: white border on all sides, larger at bottom
    border_side = 40    # Left, right, top borders
    border_bottom = 120 # Bottom border (for caption)

    # Calculate frame dimensions
    frame_width = src_width + (border_side * 2)
    frame_height = src_height + border_side + border_bottom

    # Create white canvas
    frame = CrImage::RGBA.new(CrImage.rect(0, 0, frame_width, frame_height))
    frame.fill(CrImage::Color.rgb(255, 255, 255))

    # Add slight texture to white border (subtle noise)
    add_paper_texture(frame)

    # Composite image onto frame
    img_rect = CrImage.rect(border_side, border_side,
      border_side + src_width,
      border_side + src_height)
    CrImage::Draw.draw(frame, img_rect, img, CrImage::Point.zero, CrImage::Draw::Op::OVER)

    # Add caption if provided
    if caption && font_path && File.exists?(font_path)
      add_caption(frame, caption, font_path, border_side, border_side + src_height,
        src_width, border_bottom)
    end

    frame
  end

  # Add subtle paper texture to white border
  private def self.add_paper_texture(frame : CrImage::RGBA)
    bounds = frame.bounds
    width = bounds.width
    height = bounds.height

    # Add very subtle random noise to simulate paper texture
    random = Random.new

    height.times do |y|
      width.times do |x|
        current = frame.at(x, y)
        r, g, b, a = current.rgba

        # Only add texture to white/near-white areas
        if (r >> 8) > 250 && (g >> 8) > 250 && (b >> 8) > 250
          # Very subtle noise (-3 to +3)
          noise = random.rand(-3..3)

          new_r = ((r >> 8).to_i + noise).clamp(0, 255).to_u8
          new_g = ((g >> 8).to_i + noise).clamp(0, 255).to_u8
          new_b = ((b >> 8).to_i + noise).clamp(0, 255).to_u8

          frame.set(x, y, CrImage::Color::RGBA.new(new_r, new_g, new_b, (a >> 8).to_u8))
        end
      end
    end
  end

  # Add caption text to bottom border
  private def self.add_caption(frame : CrImage::RGBA, caption : String,
                               font_path : String, x_offset : Int32,
                               y_offset : Int32, width : Int32, height : Int32)
    font = FreeType::TrueType.load(font_path)
    face = FreeType::TrueType.new_face(font, 32.0)

    # Measure text to center it
    bounds, advance = CrImage::Font.bounds(face, caption)
    text_width = advance.ceil.to_i

    # Center text horizontally in the bottom section
    text_x = x_offset + (width - text_width) // 2
    text_y = y_offset + 60 # Vertically centered in bottom border

    # Draw text in dark gray (handwritten look)
    text_color = CrImage::Uniform.new(CrImage::Color.rgb(60, 60, 60))
    dot = CrImage::Math::Fixed::Point26_6.new(
      CrImage::Math::Fixed::Int26_6[text_x * 64],
      CrImage::Math::Fixed::Int26_6[text_y * 64]
    )
    drawer = CrImage::Font::Drawer.new(frame, text_color, face, dot)
    drawer.draw(caption)
  end

  # Add shadow effect around polaroid
  private def self.add_shadow(polaroid : CrImage::Image) : CrImage::RGBA
    bounds = polaroid.bounds
    pol_width = bounds.width
    pol_height = bounds.height

    # Shadow parameters
    shadow_offset_x = 8
    shadow_offset_y = 12
    shadow_blur = 15
    shadow_padding = shadow_blur + [shadow_offset_x, shadow_offset_y].max

    # Create larger canvas for shadow
    canvas_width = pol_width + shadow_padding * 2
    canvas_height = pol_height + shadow_padding * 2

    # Create canvas with light background
    canvas = CrImage::RGBA.new(CrImage.rect(0, 0, canvas_width, canvas_height))
    canvas.fill(CrImage::Color.rgb(245, 245, 240))

    # Draw soft shadow
    draw_soft_shadow(canvas, shadow_padding + shadow_offset_x,
      shadow_padding + shadow_offset_y,
      pol_width, pol_height, shadow_blur)

    # Composite polaroid on top
    pol_rect = CrImage.rect(shadow_padding, shadow_padding,
      shadow_padding + pol_width,
      shadow_padding + pol_height)
    CrImage::Draw.draw(canvas, pol_rect, polaroid, CrImage::Point.zero, CrImage::Draw::Op::OVER)

    canvas
  end

  # Draw soft shadow using multiple passes
  private def self.draw_soft_shadow(canvas : CrImage::RGBA, x : Int32, y : Int32,
                                    width : Int32, height : Int32, blur : Int32)
    # Create shadow rectangle with gradient opacity
    shadow_color = CrImage::Color.rgba(0, 0, 0, 40)

    # Draw shadow with decreasing opacity from center
    blur.times do |i|
      offset = blur - i
      alpha = (40.0 * (1.0 - i.to_f / blur)).to_u8
      color = CrImage::Color.rgba(0, 0, 0, alpha)

      # Draw shadow rectangle outline
      draw_shadow_rect(canvas, x - offset, y - offset,
        width + offset * 2, height + offset * 2, color)
    end
  end

  # Draw shadow rectangle outline
  private def self.draw_shadow_rect(canvas : CrImage::RGBA, x : Int32, y : Int32,
                                    width : Int32, height : Int32, color : CrImage::Color::Color)
    bounds = canvas.bounds

    # Top edge
    (x...(x + width)).each do |px|
      next unless px >= 0 && px < bounds.width && y >= 0 && y < bounds.height
      blend_pixel(canvas, px, y, color)
    end

    # Bottom edge
    (x...(x + width)).each do |px|
      py = y + height - 1
      next unless px >= 0 && px < bounds.width && py >= 0 && py < bounds.height
      blend_pixel(canvas, px, py, color)
    end

    # Left edge
    (y...(y + height)).each do |py|
      next unless x >= 0 && x < bounds.width && py >= 0 && py < bounds.height
      blend_pixel(canvas, x, py, color)
    end

    # Right edge
    (y...(y + height)).each do |py|
      px = x + width - 1
      next unless px >= 0 && px < bounds.width && py >= 0 && py < bounds.height
      blend_pixel(canvas, px, py, color)
    end
  end

  # Blend pixel with alpha
  private def self.blend_pixel(canvas : CrImage::RGBA, x : Int32, y : Int32,
                               color : CrImage::Color::Color)
    existing = canvas.at(x, y)
    er, eg, eb, ea = existing.rgba
    sr, sg, sb, sa = color.rgba

    # Alpha blending
    alpha = (sa >> 8).to_f / 255.0
    inv_alpha = 1.0 - alpha

    new_r = ((sr >> 8).to_f * alpha + (er >> 8).to_f * inv_alpha).round.to_u8
    new_g = ((sg >> 8).to_f * alpha + (eg >> 8).to_f * inv_alpha).round.to_u8
    new_b = ((sb >> 8).to_f * alpha + (eb >> 8).to_f * inv_alpha).round.to_u8

    canvas.set(x, y, CrImage::Color::RGBA.new(new_r, new_g, new_b, 255_u8))
  end
end

# Command-line interface
input_path = ""
output_path = "polaroid.png"
caption : String? = nil
font_path : String? = "fonts/Roboto/static/Roboto-Regular.ttf"
style = PolaroidEffect::Style::Classic
rotate_angle = 0.0

OptionParser.parse do |parser|
  parser.banner = "Usage: polaroid_effect [options]"

  parser.on("-i PATH", "--input=PATH", "Input image path (required)") do |path|
    input_path = path
  end

  parser.on("-o PATH", "--output=PATH", "Output path (default: polaroid.png)") do |path|
    output_path = path
  end

  parser.on("-c TEXT", "--caption=TEXT", "Caption text for bottom of polaroid") do |text|
    caption = text
  end

  parser.on("-f PATH", "--font=PATH", "Font path for caption") do |path|
    font_path = path
  end

  parser.on("-s STYLE", "--style=STYLE", "Style: classic, faded, or modern (default: classic)") do |s|
    style = case s.downcase
            when "classic" then PolaroidEffect::Style::Classic
            when "faded"   then PolaroidEffect::Style::Faded
            when "modern"  then PolaroidEffect::Style::Modern
            else
              puts "Unknown style: #{s}. Using classic."
              PolaroidEffect::Style::Classic
            end
  end

  parser.on("-r ANGLE", "--rotate=ANGLE", "Rotation angle in degrees (e.g., -5, 3)") do |angle|
    rotate_angle = angle.to_f
  end

  parser.on("-h", "--help", "Show this help") do
    puts parser
    puts "\nExamples:"
    puts "  # Basic polaroid"
    puts "  crystal run examples/polaroid_effect.cr -- -i photo.jpg"
    puts ""
    puts "  # With caption and rotation"
    puts "  crystal run examples/polaroid_effect.cr -- -i photo.jpg -c \"Summer 2024\" -r -3"
    puts ""
    puts "  # Faded style"
    puts "  crystal run examples/polaroid_effect.cr -- -i photo.jpg -s faded -c \"Memories\""
    puts ""
    puts "Styles:"
    puts "  classic - Sepia tone, strong vintage look (default)"
    puts "  faded   - Desaturated colors, soft vintage"
    puts "  modern  - Minimal processing, clean look"
    puts ""
    puts "Features:"
    puts "  • Authentic polaroid frame with white border"
    puts "  • Larger bottom section for captions"
    puts "  • Vintage color effects (sepia, faded, or modern)"
    puts "  • Subtle vignette effect"
    puts "  • Optional rotation for authentic look"
    puts "  • Soft shadow for depth"
    puts "  • Paper texture on white border"
    exit
  end
end

if input_path.empty?
  puts "No input specified. Generating sample image..."
  puts "Tip: Use -i <path> to use your own image"
  puts ""

  # Generate a sample image
  sample_img = SampleImages.photo(800, 600)
  temp_path = "/tmp/polaroid_sample_input.png"
  CrImage::PNG.write(temp_path, sample_img)
  input_path = temp_path
  puts "Generated sample image"
  puts ""
end

unless File.exists?(input_path)
  puts "Error: Input file not found: #{input_path}"
  exit 1
end

if caption
  if fp = font_path
    unless File.exists?(fp)
      puts "Warning: Font file not found: #{fp}"
      puts "Caption will be skipped. Install fonts or specify correct path with -f"
      font_path = nil
    end
  end
end

begin
  PolaroidEffect.generate(input_path, output_path, caption, font_path, style, rotate_angle)
rescue ex
  puts "Error: #{ex.message}"
  puts ex.backtrace.join("\n")
  exit 1
end
