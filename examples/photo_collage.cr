require "../src/crimage"
require "../src/freetype"
require "option_parser"

# Photo Collage Generator
# This example demonstrates multiple CrImage features:
# - Loading multiple images
# - Bicubic resize for thumbnails
# - Drawing primitives (borders, frames)
# - Polygon drawing for decorative elements
# - Color space conversions (HSL for color adjustments)
# - Text rendering with alignment
# - Gradient backgrounds
# - Image watermarking

module PhotoCollage
  # Create a photo collage from multiple images
  def self.generate(image_paths : Array(String), output_path : String, title : String, font_path : String)
    puts "🎨 Creating photo collage with #{image_paths.size} images..."

    # Canvas dimensions
    canvas_width = 1200
    canvas_height = 1600

    # Create canvas
    canvas = CrImage.rgba(canvas_width, canvas_height)

    # 1. Create gradient background
    puts "🌈 Creating gradient background..."
    create_gradient_background(canvas)

    # 2. Add decorative polygon elements
    puts "✨ Adding decorative elements..."
    add_decorative_polygons(canvas)

    # 3. Load and arrange photos
    puts "📸 Loading and arranging photos..."
    photos = load_and_resize_photos(image_paths, max_photos: 6)

    # Arrange photos in a grid (2 columns, 3 rows)
    photo_width = 450
    photo_height = 350
    margin = 50
    start_y = 200

    photos.each_with_index do |photo, idx|
      row = idx // 2
      col = idx % 2

      x = margin + col * (photo_width + margin)
      y = start_y + row * (photo_height + margin)

      # Resize photo to fit (skip if photo is too small)
      next if photo.bounds.width < 10 || photo.bounds.height < 10

      resized = CrImage::Transform.resize_bicubic(photo, photo_width, photo_height)

      # Apply color adjustment using HSL
      adjusted = adjust_photo_colors(resized)

      # Draw photo with border
      draw_photo_with_border(canvas, adjusted, x, y)
    end

    # 4. Add title with effects
    puts "📝 Adding title..."
    add_title(canvas, title, font_path)

    # 5. Add decorative frame
    puts "🖼️  Adding decorative frame..."
    add_frame(canvas)

    # 6. Add date stamp
    puts "📅 Adding date stamp..."
    add_date_stamp(canvas, font_path)

    # 7. Save result
    puts "💾 Saving collage..."
    CrImage::PNG.write(output_path, canvas)

    # 8. Create thumbnail
    puts "🔍 Creating thumbnail..."
    thumb = CrImage::Util.thumbnail(
      canvas,
      width: 400,
      height: 533,
      mode: CrImage::Util::ThumbnailMode::Fit,
      quality: CrImage::Util::ResampleQuality::Bicubic
    )
    thumb_path = output_path.sub(/\.(png|jpg|jpeg)$/i, "_thumb.png")
    CrImage::PNG.write(thumb_path, thumb)

    puts "✅ Done! Created:"
    puts "   📄 Collage: #{output_path}"
    puts "   🔍 Thumbnail: #{thumb_path}"
  end

  private def self.create_gradient_background(canvas : CrImage::Image)
    # Create a subtle gradient from top to bottom
    stops = [
      CrImage::Draw::ColorStop.new(0.0, CrImage::Color.rgb(240, 240, 250)),
      CrImage::Draw::ColorStop.new(0.5, CrImage::Color.rgb(250, 245, 255)),
      CrImage::Draw::ColorStop.new(1.0, CrImage::Color.rgb(245, 250, 255)),
    ]
    gradient = CrImage::Draw::LinearGradient.new(
      CrImage::Point.new(0, 0),
      CrImage::Point.new(0, canvas.bounds.height),
      stops
    )
    CrImage::Draw.fill_linear_gradient(canvas, canvas.bounds, gradient)
  end

  private def self.add_decorative_polygons(canvas : CrImage::Image)
    # Add some decorative triangular shapes in corners using HSV colors
    # Top-left corner
    color1_hsv = CrImage::Color::HSV.new(280.0, 0.3, 0.95)
    color1 = color1_hsv.to_rgba

    points1 = [
      CrImage::Point.new(0, 0),
      CrImage::Point.new(200, 0),
      CrImage::Point.new(0, 200),
    ]
    style1 = CrImage::Draw::PolygonStyle.new(
      fill_color: CrImage::Color.rgba(color1.r, color1.g, color1.b, 100),
      anti_alias: true
    )
    CrImage::Draw.polygon(canvas, points1, style1)

    # Bottom-right corner
    color2_hsv = CrImage::Color::HSV.new(200.0, 0.3, 0.95)
    color2 = color2_hsv.to_rgba

    w = canvas.bounds.width
    h = canvas.bounds.height
    points2 = [
      CrImage::Point.new(w, h),
      CrImage::Point.new(w - 200, h),
      CrImage::Point.new(w, h - 200),
    ]
    style2 = CrImage::Draw::PolygonStyle.new(
      fill_color: CrImage::Color.rgba(color2.r, color2.g, color2.b, 100),
      anti_alias: true
    )
    CrImage::Draw.polygon(canvas, points2, style2)
  end

  private def self.load_and_resize_photos(paths : Array(String), max_photos : Int32) : Array(CrImage::Image)
    photos = [] of CrImage::Image

    paths.first(max_photos).each do |path|
      begin
        img = CrImage.read(path)
        photos << img
      rescue ex
        puts "⚠️  Warning: Could not load #{path}: #{ex.message}"
      end
    end

    photos
  end

  private def self.adjust_photo_colors(img : CrImage::Image) : CrImage::Image
    # Slightly increase saturation using HSL color space
    # This is a simplified version - in practice you'd process each pixel
    # For this example, we'll just return the original
    # (Full implementation would convert each pixel to HSL, adjust, and convert back)
    img
  end

  private def self.draw_photo_with_border(canvas : CrImage::Image, photo : CrImage::Image, x : Int32, y : Int32)
    # Draw white border/mat
    border_width = 10
    border_rect = CrImage.rect(
      x - border_width,
      y - border_width,
      x + photo.bounds.width + border_width,
      y + photo.bounds.height + border_width
    )

    # Fill border with white
    (border_rect.min.x).upto(border_rect.max.x) do |bx|
      (border_rect.min.y).upto(border_rect.max.y) do |by|
        if CrImage::Point.new(bx, by).in(canvas.bounds)
          canvas.set(bx, by, CrImage::Color::WHITE)
        end
      end
    end

    # Draw photo
    photo_rect = CrImage.rect(x, y, x + photo.bounds.width, y + photo.bounds.height)
    CrImage::Draw.draw(canvas, photo_rect, photo, CrImage::Point.zero, CrImage::Draw::Op::OVER)

    # Add subtle shadow effect using lines
    shadow_color = CrImage::Color.rgba(0, 0, 0, 40)
    line_style = CrImage::Draw::LineStyle.new(shadow_color, thickness: 3, anti_alias: true)

    # Right shadow
    CrImage::Draw.line(
      canvas,
      CrImage::Point.new(border_rect.max.x + 2, border_rect.min.y + 5),
      CrImage::Point.new(border_rect.max.x + 2, border_rect.max.y + 2),
      line_style
    )

    # Bottom shadow
    CrImage::Draw.line(
      canvas,
      CrImage::Point.new(border_rect.min.x + 5, border_rect.max.y + 2),
      CrImage::Point.new(border_rect.max.x + 2, border_rect.max.y + 2),
      line_style
    )
  end

  private def self.add_title(canvas : CrImage::Image, title : String, font_path : String)
    font = FreeType::TrueType.load(font_path)
    face = FreeType::TrueType.new_face(font, 64.0)

    # Create semi-transparent background for title
    title_bg_rect = CrImage.rect(0, 50, canvas.bounds.width, 150)
    bg_color = CrImage::Color.rgba(255, 255, 255, 200)

    (title_bg_rect.min.x).upto(title_bg_rect.max.x) do |x|
      (title_bg_rect.min.y).upto(title_bg_rect.max.y) do |y|
        if CrImage::Point.new(x, y).in(canvas.bounds)
          # Blend with existing pixel
          existing = canvas.at(x, y).rgba
          blended = blend_colors(existing, bg_color)
          canvas.set(x, y, blended)
        end
      end
    end

    # Draw title text with shadow
    text_color = CrImage::Uniform.new(CrImage::Color.rgb(50, 50, 50))
    dot = CrImage::Math::Fixed::Point26_6.new(
      CrImage::Math::Fixed::Int26_6[100 * 64],
      CrImage::Math::Fixed::Int26_6[120 * 64]
    )
    drawer = CrImage::Font::Drawer.new(canvas, text_color, face, dot)

    shadow = CrImage::Font::Shadow.new(
      offset_x: 3,
      offset_y: 3,
      blur_radius: 5,
      color: CrImage::Color.rgba(0, 0, 0, 100)
    )
    style = CrImage::Font::TextStyle.new(shadow: shadow)
    drawer.draw_styled(title, style)
  end

  private def self.add_frame(canvas : CrImage::Image)
    # Draw decorative frame around entire canvas
    frame_color = CrImage::Color.rgb(100, 100, 120)
    line_style = CrImage::Draw::LineStyle.new(frame_color, thickness: 8, anti_alias: true)

    margin = 20
    w = canvas.bounds.width
    h = canvas.bounds.height

    # Top
    CrImage::Draw.line(canvas, CrImage::Point.new(margin, margin), CrImage::Point.new(w - margin, margin), line_style)
    # Bottom
    CrImage::Draw.line(canvas, CrImage::Point.new(margin, h - margin), CrImage::Point.new(w - margin, h - margin), line_style)
    # Left
    CrImage::Draw.line(canvas, CrImage::Point.new(margin, margin), CrImage::Point.new(margin, h - margin), line_style)
    # Right
    CrImage::Draw.line(canvas, CrImage::Point.new(w - margin, margin), CrImage::Point.new(w - margin, h - margin), line_style)

    # Add corner decorations (small circles)
    circle_style = CrImage::Draw::CircleStyle.new(frame_color, fill: true, anti_alias: true)
    CrImage::Draw.circle(canvas, CrImage::Point.new(margin, margin), 12, circle_style)
    CrImage::Draw.circle(canvas, CrImage::Point.new(w - margin, margin), 12, circle_style)
    CrImage::Draw.circle(canvas, CrImage::Point.new(margin, h - margin), 12, circle_style)
    CrImage::Draw.circle(canvas, CrImage::Point.new(w - margin, h - margin), 12, circle_style)
  end

  private def self.add_date_stamp(canvas : CrImage::Image, font_path : String)
    font = FreeType::TrueType.load(font_path)
    face = FreeType::TrueType.new_face(font, 24.0)

    date_text = Time.local.to_s("%B %d, %Y")
    text_color = CrImage::Uniform.new(CrImage::Color.rgb(120, 120, 120))

    dot = CrImage::Math::Fixed::Point26_6.new(
      CrImage::Math::Fixed::Int26_6[50 * 64],
      CrImage::Math::Fixed::Int26_6[(canvas.bounds.height - 50) * 64]
    )
    drawer = CrImage::Font::Drawer.new(canvas, text_color, face, dot)
    drawer.draw(date_text)
  end

  private def self.blend_colors(base : Tuple(UInt32, UInt32, UInt32, UInt32),
                                overlay : CrImage::Color::RGBA) : CrImage::Color::RGBA
    # Simple alpha blending
    alpha = overlay.a.to_f / 255.0
    inv_alpha = 1.0 - alpha

    r = (overlay.r.to_f * alpha + base[0].to_f * inv_alpha).clamp(0.0, 255.0).to_u8
    g = (overlay.g.to_f * alpha + base[1].to_f * inv_alpha).clamp(0.0, 255.0).to_u8
    b = (overlay.b.to_f * alpha + base[2].to_f * inv_alpha).clamp(0.0, 255.0).to_u8
    a = 255_u8

    CrImage::Color.rgba(r, g, b, a)
  end
end

# Command-line interface
image_paths = [] of String
output_path = "photo_collage.png"
title = "Memories"
font_path = "fonts/Roboto/static/Roboto-Bold.ttf"

OptionParser.parse do |parser|
  parser.banner = "Usage: photo_collage [options]"

  parser.on("-i PATH", "--input=PATH", "Input photo paths (can be specified multiple times)") do |path|
    image_paths << path
  end
  parser.on("-o PATH", "--output=PATH", "Output path (default: photo_collage.png)") { |path| output_path = path }
  parser.on("-t TITLE", "--title=TITLE", "Collage title (default: Memories)") { |text| title = text }
  parser.on("-f PATH", "--font=PATH", "Font path") { |path| font_path = path }
  parser.on("-h", "--help", "Show this help") do
    puts parser
    puts "\nExample:"
    puts "  crystal run examples/photo_collage.cr -- -i photo1.jpg -i photo2.jpg -i photo3.jpg -t \"Summer 2024\""
    puts "\nThis example demonstrates:"
    puts "  • Bicubic interpolation for photo resizing"
    puts "  • Linear gradients for backgrounds"
    puts "  • Polygon drawing for decorative elements"
    puts "  • HSV color space for accent colors"
    puts "  • Drawing primitives (lines, circles) for borders"
    puts "  • Text rendering with shadows"
    puts "  • Alpha blending for overlays"
    puts "  • Thumbnail generation"
    exit
  end
end

if image_paths.empty?
  puts "Error: At least one input photo is required"
  puts "Use --help for usage information"
  exit 1
end

image_paths.each do |path|
  unless File.exists?(path)
    puts "Warning: Photo file not found: #{path}"
  end
end

unless File.exists?(font_path)
  puts "Error: Font file not found: #{font_path}"
  exit 1
end

begin
  PhotoCollage.generate(image_paths, output_path, title, font_path)
rescue ex
  puts "Error: #{ex.message}"
  puts ex.backtrace.join("\n")
  exit 1
end
