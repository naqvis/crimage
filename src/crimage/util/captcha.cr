require "../../freetype/truetype/truetype"

module CrImage
  module Util
    # CAPTCHA generation utility
    #
    # Generates CAPTCHA images with distorted text, noise, and interference patterns
    # to prevent automated OCR while remaining human-readable.
    #
    # Example:
    # ```
    # captcha = CrImage::Util::Captcha.generate(
    #   text: "ABC123",
    #   font_path: "fonts/Roboto-Bold.ttf",
    #   width: 300,
    #   height: 100
    # )
    # CrImage::PNG.write("captcha.png", captcha)
    # ```
    module Captcha
      # CAPTCHA generation options
      struct Options
        property width : Int32
        property height : Int32
        property noise_level : Int32
        property line_count : Int32
        property background_color : Color::RGBA
        property wobble_strength : Float64
        property rotation_range : Float64

        def initialize(
          @width = 300,
          @height = 100,
          @noise_level = 25,
          @line_count = 6,
          @background_color = Color.rgb(240, 240, 240),
          @wobble_strength = 3.0,
          @rotation_range = 20.0,
        )
        end
      end

      # Generate a CAPTCHA image with the given text
      #
      # Parameters:
      # - text: The text to display in the CAPTCHA
      # - font_path: Path to TrueType font file
      # - options: CAPTCHA generation options (optional)
      #
      # Returns: RGBA image containing the CAPTCHA
      def self.generate(text : String, font_path : String, options : Options = Options.new) : RGBA
        raise ArgumentError.new("Text cannot be empty") if text.empty?
        raise ArgumentError.new("Font file not found: #{font_path}") unless File.exists?(font_path)

        # Create base image
        image = CrImage.rgba(options.width, options.height, options.background_color)

        # Add background noise
        image = image.add_noise(0.05, NoiseType::Gaussian, monochrome: true)

        # Load font
        font = FreeType::TrueType.load(font_path)
        font_size = options.height * 0.6
        face = FreeType::TrueType.new_face(font, font_size)

        # Draw distorted text
        draw_distorted_text(image, text, face, font_size, options)

        # Add interference lines
        add_interference_lines(image, options)

        # Add noise overlay
        if options.noise_level > 20
          noise_intensity = (options.noise_level - 20) / 100.0
          image = image.add_noise(noise_intensity, NoiseType::Gaussian, monochrome: true)
        end

        image
      end

      # Generate random CAPTCHA text
      #
      # Parameters:
      # - length: Number of characters (default: 6)
      # - charset: Character set to use (default: alphanumeric without confusing chars)
      #
      # Returns: Random text string
      def self.random_text(length : Int32 = 6, charset : String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789") : String
        String.build do |str|
          length.times { str << charset[rand(charset.size)] }
        end
      end

      private def self.draw_distorted_text(image : RGBA, text : String, face, font_size : Float64, options : Options)
        char_spacing = options.width // (text.size + 1)
        base_y = (options.height * 0.65).to_i

        text.each_char_with_index do |char, i|
          char_img = CrImage.rgba(options.width, options.height)

          # Random darker color for contrast
          r = rand(100).to_u8 + 20
          g = rand(100).to_u8 + 20
          b = rand(100).to_u8 + 20
          text_color = Uniform.new(Color::RGBA.new(r, g, b, 255))

          # Random scale
          scale = 0.8 + rand * 0.4
          scaled_font_size = (font_size * scale).to_i
          scaled_face = FreeType::TrueType.new_face(face.font, scaled_font_size.to_f64)

          # Position with random offset
          x_offset = char_spacing * (i + 1) + rand(20) - 10
          y_offset = base_y + rand(30) - 15

          # Draw character
          dot = Math::Fixed::Point26_6.new(
            Math::Fixed::Int26_6[x_offset * 64],
            Math::Fixed::Int26_6[y_offset * 64]
          )

          drawer = Font::Drawer.new(char_img, text_color, scaled_face, dot)
          drawer.draw(char.to_s)

          # Apply wobble distortion
          temp_img = apply_wobble(char_img, options)

          # Apply rotation
          temp_img = apply_rotation(temp_img, x_offset, y_offset, options)

          # Composite onto main image
          Draw.draw(image, image.bounds, temp_img, Point.zero, Draw::Op::OVER)
        end
      end

      private def self.apply_wobble(char_img : RGBA, options : Options) : RGBA
        temp_img = CrImage.rgba(char_img.bounds.width, char_img.bounds.height)

        char_img.bounds.height.times do |cy|
          char_img.bounds.width.times do |cx|
            pixel = char_img.at(cx, cy).as(Color::RGBA)
            next if pixel.a == 0

            # Wobble using multiple sine waves
            x_wobble = (::Math.sin(cy * 0.12 + rand * ::Math::PI) * options.wobble_strength +
                        ::Math.sin(cx * 0.18 + rand * ::Math::PI) * (options.wobble_strength * 0.67)).to_i
            y_wobble = (::Math.cos(cx * 0.12 + rand * ::Math::PI) * options.wobble_strength +
                        ::Math.cos(cy * 0.18 + rand * ::Math::PI) * (options.wobble_strength * 0.67)).to_i

            new_x = cx + x_wobble
            new_y = cy + y_wobble

            if new_x >= 0 && new_x < temp_img.bounds.width && new_y >= 0 && new_y < temp_img.bounds.height
              temp_img.set(new_x, new_y, pixel)
            end
          end
        end

        temp_img
      end

      private def self.apply_rotation(img : RGBA, center_x : Int32, center_y : Int32, options : Options) : RGBA
        rotation_angle = (rand * options.rotation_range * 2 - options.rotation_range) * ::Math::PI / 180
        return img if rotation_angle.abs < 0.1

        rotated_img = CrImage.rgba(img.bounds.width, img.bounds.height)

        img.bounds.height.times do |cy|
          img.bounds.width.times do |cx|
            pixel = img.at(cx, cy).as(Color::RGBA)
            next if pixel.a == 0

            dx = cx - center_x
            dy = cy - center_y

            new_x = (center_x + dx * ::Math.cos(rotation_angle) - dy * ::Math.sin(rotation_angle)).to_i
            new_y = (center_y + dx * ::Math.sin(rotation_angle) + dy * ::Math.cos(rotation_angle)).to_i

            if new_x >= 0 && new_x < rotated_img.bounds.width && new_y >= 0 && new_y < rotated_img.bounds.height
              rotated_img.set(new_x, new_y, pixel)
            end
          end
        end

        rotated_img
      end

      private def self.add_interference_lines(image : RGBA, options : Options)
        # Straight lines
        (options.line_count // 2).times do
          r = rand(200).to_u8 + 30
          g = rand(200).to_u8 + 30
          b = rand(200).to_u8 + 30

          x1 = rand(options.width)
          y1 = rand(options.height)
          x2 = rand(options.width)
          y2 = rand(options.height)

          draw_line(image, x1, y1, x2, y2, r, g, b, rand(3) + 1)
        end

        # Curved lines
        (options.line_count - options.line_count // 2).times do
          start_y = rand(options.height)
          amplitude = rand(20) + 12
          frequency = rand(3) + 1

          r = rand(160).to_u8 + 60
          g = rand(160).to_u8 + 60
          b = rand(160).to_u8 + 60

          thickness = rand(2) + 1

          options.width.times do |x|
            y = (start_y + amplitude * ::Math.sin(x * frequency * ::Math::PI / options.width)).to_i
            if y >= 0 && y < options.height
              (-thickness..thickness).each do |dy|
                (-thickness..thickness).each do |dx|
                  px = x + dx
                  py = y + dy
                  if px >= 0 && px < options.width && py >= 0 && py < options.height
                    blend_pixel(image, px, py, r, g, b)
                  end
                end
              end
            end
          end
        end
      end

      private def self.draw_line(image : RGBA, x1 : Int32, y1 : Int32, x2 : Int32, y2 : Int32,
                                 r : UInt8, g : UInt8, b : UInt8, thickness : Int32)
        dx = (x2 - x1).abs
        dy = (y2 - y1).abs
        sx = x1 < x2 ? 1 : -1
        sy = y1 < y2 ? 1 : -1
        err = dx - dy

        x, y = x1, y1

        loop do
          (-thickness..thickness).each do |dy_offset|
            (-thickness..thickness).each do |dx_offset|
              px = x + dx_offset
              py = y + dy_offset
              if px >= 0 && px < image.bounds.width && py >= 0 && py < image.bounds.height
                blend_pixel(image, px, py, r, g, b)
              end
            end
          end

          break if x == x2 && y == y2

          e2 = 2 * err
          if e2 > -dy
            err -= dy
            x += sx
          end
          if e2 < dx
            err += dx
            y += sy
          end
        end
      end

      private def self.blend_pixel(image : RGBA, x : Int32, y : Int32, r : UInt8, g : UInt8, b : UInt8)
        existing = image.at(x, y).as(Color::RGBA)
        blended_r = ((existing.r.to_i32 + r.to_i32) // 2).to_u8
        blended_g = ((existing.g.to_i32 + g.to_i32) // 2).to_u8
        blended_b = ((existing.b.to_i32 + b.to_i32) // 2).to_u8
        image.set(x, y, Color::RGBA.new(blended_r, blended_g, blended_b, 255))
      end
    end
  end
end
