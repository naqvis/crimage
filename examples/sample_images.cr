require "../src/crimage"

# Helper module to generate sample images for examples
# This avoids dependency on external image files
module SampleImages
  # Generate a colorful gradient image
  def self.gradient(width : Int32 = 400, height : Int32 = 300) : CrImage::RGBA
    img = CrImage.rgba(width, height)

    height.times do |y|
      width.times do |x|
        # Create a colorful gradient
        r = (255.0 * x / width).to_u8
        g = (255.0 * y / height).to_u8
        b = (255.0 * (1.0 - x.to_f / width) * (1.0 - y.to_f / height)).to_u8

        img.set(x, y, CrImage::Color.rgb(r, g, b))
      end
    end

    img
  end

  # Generate a landscape scene (sky, mountains, ground)
  def self.landscape(width : Int32 = 600, height : Int32 = 400) : CrImage::RGBA
    img = CrImage.rgba(width, height)

    # Sky gradient (blue to light blue)
    sky_height = (height * 0.6).to_i
    sky_height.times do |y|
      t = y.to_f / sky_height
      r = (135 + (200 - 135) * t).to_u8
      g = (206 + (230 - 206) * t).to_u8
      b = (235 + (250 - 235) * t).to_u8

      width.times do |x|
        img.set(x, y, CrImage::Color.rgb(r, g, b))
      end
    end

    # Mountains (simple triangular shapes)
    draw_mountain(img, width // 4, sky_height, 150, 100, CrImage::Color.rgb(100, 120, 140))
    draw_mountain(img, width // 2, sky_height, 200, 120, CrImage::Color.rgb(80, 100, 120))
    draw_mountain(img, 3 * width // 4, sky_height, 180, 110, CrImage::Color.rgb(90, 110, 130))

    # Ground (green gradient)
    (sky_height...height).each do |y|
      t = (y - sky_height).to_f / (height - sky_height)
      r = (100 - 30 * t).to_u8
      g = (180 - 40 * t).to_u8
      b = (80 - 20 * t).to_u8

      width.times do |x|
        img.set(x, y, CrImage::Color.rgb(r, g, b))
      end
    end

    # Add sun
    sun_x = width - 100
    sun_y = 80
    sun_radius = 40

    (-sun_radius..sun_radius).each do |dy|
      (-sun_radius..sun_radius).each do |dx|
        if dx * dx + dy * dy <= sun_radius * sun_radius
          x = sun_x + dx
          y = sun_y + dy
          if x >= 0 && x < width && y >= 0 && y < height
            img.set(x, y, CrImage::Color.rgb(255, 220, 100))
          end
        end
      end
    end

    img
  end

  # Generate a portrait-oriented image with geometric shapes
  def self.geometric(width : Int32 = 400, height : Int32 = 600) : CrImage::RGBA
    img = CrImage.rgba(width, height)

    # Gradient background
    height.times do |y|
      width.times do |x|
        t = y.to_f / height
        r = (240 - 40 * t).to_u8
        g = (220 - 20 * t).to_u8
        b = (250 - 50 * t).to_u8
        img.set(x, y, CrImage::Color.rgb(r, g, b))
      end
    end

    # Draw some circles
    draw_circle(img, width // 4, height // 4, 60, CrImage::Color.rgba(255, 100, 100, 200))
    draw_circle(img, 3 * width // 4, height // 3, 80, CrImage::Color.rgba(100, 255, 100, 200))
    draw_circle(img, width // 2, 2 * height // 3, 70, CrImage::Color.rgba(100, 100, 255, 200))

    # Draw some rectangles
    draw_rect(img, 50, height - 200, 100, 150, CrImage::Color.rgba(255, 200, 100, 180))
    draw_rect(img, width - 150, height - 250, 100, 200, CrImage::Color.rgba(200, 100, 255, 180))

    img
  end

  # Generate a photo-like image with a subject
  def self.photo(width : Int32 = 800, height : Int32 = 600) : CrImage::RGBA
    img = CrImage.rgba(width, height)

    # Background gradient (warm tones)
    height.times do |y|
      width.times do |x|
        # Radial gradient from center
        cx = width / 2
        cy = height / 2
        dx = x - cx
        dy = y - cy
        dist = Math.sqrt(dx * dx + dy * dy)
        max_dist = Math.sqrt(cx * cx + cy * cy)
        t = (dist / max_dist).clamp(0.0, 1.0)

        r = (250 - 50 * t).to_u8
        g = (240 - 80 * t).to_u8
        b = (220 - 100 * t).to_u8

        img.set(x, y, CrImage::Color.rgb(r, g, b))
      end
    end

    # Draw a simple "subject" - a stylized flower
    center_x = width // 2
    center_y = height // 2

    # Petals (circles around center)
    petal_color = CrImage::Color.rgb(255, 150, 180)
    petal_radius = 80
    petal_distance = 100

    6.times do |i|
      angle = i * Math::PI / 3
      px = center_x + (petal_distance * Math.cos(angle)).to_i
      py = center_y + (petal_distance * Math.sin(angle)).to_i
      draw_circle(img, px, py, petal_radius, petal_color)
    end

    # Center
    draw_circle(img, center_x, center_y, 60, CrImage::Color.rgb(255, 220, 100))

    img
  end

  # Helper: Draw a mountain triangle
  private def self.draw_mountain(img : CrImage::RGBA, peak_x : Int32, base_y : Int32,
                                 width : Int32, height : Int32, color : CrImage::Color::Color)
    height.times do |dy|
      y = base_y - dy
      next if y < 0 || y >= img.bounds.height

      # Calculate width at this height
      w = (width * (height - dy).to_f / height).to_i
      left = peak_x - w // 2
      right = peak_x + w // 2

      (left..right).each do |x|
        next if x < 0 || x >= img.bounds.width
        img.set(x, y, color)
      end
    end
  end

  # Helper: Draw a filled circle
  private def self.draw_circle(img : CrImage::RGBA, cx : Int32, cy : Int32,
                               radius : Int32, color : CrImage::Color::Color)
    (-radius..radius).each do |dy|
      (-radius..radius).each do |dx|
        if dx * dx + dy * dy <= radius * radius
          x = cx + dx
          y = cy + dy
          if x >= 0 && x < img.bounds.width && y >= 0 && y < img.bounds.height
            # Alpha blend if color has transparency
            existing = img.at(x, y)
            blended = blend_colors(existing, color)
            img.set(x, y, blended)
          end
        end
      end
    end
  end

  # Helper: Draw a filled rectangle
  private def self.draw_rect(img : CrImage::RGBA, x : Int32, y : Int32,
                             width : Int32, height : Int32, color : CrImage::Color::Color)
    height.times do |dy|
      width.times do |dx|
        px = x + dx
        py = y + dy
        if px >= 0 && px < img.bounds.width && py >= 0 && py < img.bounds.height
          existing = img.at(px, py)
          blended = blend_colors(existing, color)
          img.set(px, py, blended)
        end
      end
    end
  end

  # Helper: Blend two colors with alpha
  private def self.blend_colors(base : CrImage::Color::Color, overlay : CrImage::Color::Color) : CrImage::Color::RGBA
    br, bg, bb, ba = base.rgba
    or_, og, ob, oa = overlay.rgba

    # Convert to 8-bit
    br8 = (br >> 8).to_f
    bg8 = (bg >> 8).to_f
    bb8 = (bb >> 8).to_f

    or8 = (or_ >> 8).to_f
    og8 = (og >> 8).to_f
    ob8 = (ob >> 8).to_f
    oa8 = (oa >> 8).to_f / 255.0

    # Alpha blend
    r = (or8 * oa8 + br8 * (1.0 - oa8)).to_u8
    g = (og8 * oa8 + bg8 * (1.0 - oa8)).to_u8
    b = (ob8 * oa8 + bb8 * (1.0 - oa8)).to_u8

    CrImage::Color.rgb(r, g, b)
  end
end

# If run directly, generate sample images
if ARGV.size > 0 && ARGV[0] == "generate"
  puts "Generating sample images..."

  output_dir = "examples/sample_output"
  Dir.mkdir_p(output_dir)

  puts "  Creating gradient.png..."
  gradient = SampleImages.gradient
  CrImage::PNG.write("#{output_dir}/sample_gradient.png", gradient)

  puts "  Creating landscape.png..."
  landscape = SampleImages.landscape
  CrImage::PNG.write("#{output_dir}/sample_landscape.png", landscape)

  puts "  Creating geometric.png..."
  geometric = SampleImages.geometric
  CrImage::PNG.write("#{output_dir}/sample_geometric.png", geometric)

  puts "  Creating photo.png..."
  photo = SampleImages.photo
  CrImage::PNG.write("#{output_dir}/sample_photo.png", photo)

  puts "Sample images generated in #{output_dir}/"
end
