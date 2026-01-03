module CrImage
  macro define_slice_image_type(type_name, color_type, bytes_per_pixel, model_method, at_method, set_method, default_color, opaque_default = false, single_field = "y")
    class {{type_name.id}}
      include Image
      @pix : Bytes
      getter stride : Int32
      getter rect : Rectangle

      # :nodoc:
      def pix : Bytes
        @pix
      end

      def initialize(@pix = Bytes.empty, @stride = 0, @rect = Rectangle.zero)
      end

      def initialize(r : Rectangle)
        SafeMath.validate_rectangle(r)
        w, h = r.width, r.height
        buffer_size = SafeMath.safe_buffer_size(w, h, {{bytes_per_pixel}})
        @pix = Bytes.new(buffer_size.to_i32)
        @stride = SafeMath.safe_stride(w, {{bytes_per_pixel}})
        @rect = r
      end

      # Creates an image from an existing pixel buffer.
      #
      # Convenience constructor that calculates stride automatically.
      # The buffer is used directly (not copied), so modifications to the
      # image will affect the original buffer.
      #
      # Parameters:
      # - `buffer` : Raw pixel data in row-major order
      # - `width` : Image width in pixels
      # - `height` : Image height in pixels
      #
      # Raises: `ArgumentError` if buffer size doesn't match expected size
      #
      # Example:
      # ```
      # # Create 100x100 RGBA image from raw bytes
      # pixels = Bytes.new(100 * 100 * 4)
      # img = CrImage::RGBA.from_buffer(pixels, 100, 100)
      # ```
      def self.from_buffer(buffer : Bytes, width : Int32, height : Int32) : self
        expected_size = width * height * {{bytes_per_pixel}}
        if buffer.size < expected_size
          raise ArgumentError.new("Buffer too small: got #{buffer.size} bytes, need #{expected_size} for #{width}x#{height} image")
        end
        stride = width * {{bytes_per_pixel}}
        new(buffer, stride, CrImage.rect(0, 0, width, height))
      end

      # Swaps the underlying pixel buffer without allocation.
      #
      # Useful for video/realtime processing where you want to reuse
      # an image object with different frame data.
      #
      # Parameters:
      # - `buffer` : New pixel buffer (must match current dimensions)
      #
      # Raises: `ArgumentError` if buffer size doesn't match
      #
      # Example:
      # ```
      # img = CrImage::RGBA.from_buffer(frame1, 1920, 1080)
      # process(img)
      # img.swap_buffer(frame2)  # Zero allocation
      # process(img)
      # ```
      def swap_buffer(buffer : Bytes) : Nil
        expected_size = @rect.width * @rect.height * {{bytes_per_pixel}}
        if buffer.size < expected_size
          raise ArgumentError.new("Buffer too small: got #{buffer.size} bytes, need #{expected_size}")
        end
        @pix = buffer
      end

      def color_model : Color::Model
        Color.{{model_method.id}}
      end

      def bounds : Rectangle
        @rect
      end

      # Returns the color at the specified coordinates.
      #
      # If the coordinates are outside the image bounds, returns a default color
      # (typically transparent black) rather than raising an exception. This is
      # intentional behavior to simplify image processing algorithms that may
      # sample outside bounds.
      #
      # For explicit bounds checking, use `bounds.in?(Point.new(x, y))` before calling.
      #
      # Parameters:
      # - `x` : X coordinate
      # - `y` : Y coordinate
      #
      # Returns: The color at (x, y), or default color if out of bounds
      #
      # Example:
      # ```
      # img = CrImage.rgba(100, 100)
      # color = img.at(50, 50)      # Returns actual color
      # color = img.at(200, 200)    # Returns default color (out of bounds)
      # 
      # # Explicit bounds check:
      # if img.bounds.in?(CrImage.point(x, y))
      #   color = img.at(x, y)  # Guaranteed to be actual pixel
      # end
      # ```
      def at(x : Int32, y : Int32) : Color::Color
        {{at_method.id}}(x, y)
      end

      def {{at_method.id}}(x : Int32, y : Int32) : {{color_type.id}}
        return {{default_color.id}} unless Point.new(x, y).in(@rect)
        i = pixel_offset(x, y)
        {% if bytes_per_pixel == 1 %}
          {{color_type.id}}.new(@pix[i])
        {% elsif bytes_per_pixel == 2 %}
          {{color_type.id}}.new((@pix[i + 0].to_u16 << 8 | @pix[i + 1].to_u16).to_u16)
        {% elsif bytes_per_pixel == 4 %}
          s = @pix[i...i + 4]
          {{color_type.id}}.new(s[0], s[1], s[2], s[3])
        {% else %}
          s = @pix[i...i + 8]
          {{color_type.id}}.new(
            (s[0].to_u16 << 8 | s[1].to_u16).to_u16,
            (s[2].to_u16 << 8 | s[3].to_u16).to_u16,
            (s[4].to_u16 << 8 | s[5].to_u16).to_u16,
            (s[6].to_u16 << 8 | s[7].to_u16).to_u16
          )
        {% end %}
      end

      # Returns the color at the specified coordinates, or nil if out of bounds.
      #
      # This is an alternative to `at` that explicitly returns nil for out-of-bounds
      # coordinates, making bounds checking more explicit in the type system.
      #
      # Parameters:
      # - `x` : X coordinate
      # - `y` : Y coordinate
      #
      # Returns: The color at (x, y), or nil if out of bounds
      #
      # Example:
      # ```
      # img = CrImage.rgba(100, 100)
      # if color = img.at?(50, 50)
      #   # color is guaranteed to be from the image
      # end
      # 
      # img.at?(200, 200)  # => nil (out of bounds)
      # ```
      def at?(x : Int32, y : Int32) : {{color_type.id}}?
        return nil unless Point.new(x, y).in(@rect)
        {{at_method.id}}(x, y)
      end

      def pixel_offset(x : Int32, y : Int32) : Int32
        dy = y - @rect.min.y
        dx = x - @rect.min.x
        (dy.to_i64 * @stride.to_i64 + dx.to_i64 * {{bytes_per_pixel}}_i64).to_i32
      end

      # Sets the color at the specified coordinates.
      #
      # If the coordinates are outside the image bounds, this method does nothing
      # (no-op) rather than raising an exception. This is intentional behavior to
      # simplify drawing operations that may extend beyond image boundaries.
      #
      # For explicit bounds checking, use `bounds.in?(Point.new(x, y))` before calling.
      #
      # Parameters:
      # - `x` : X coordinate
      # - `y` : Y coordinate
      # - `c` : Color to set
      #
      # Example:
      # ```
      # img = CrImage.rgba(100, 100)
      # img.set(50, 50, CrImage::Color::RED)    # Sets pixel
      # img.set(200, 200, CrImage::Color::RED)  # No-op (out of bounds)
      # ```
      def set(x : Int32, y : Int32, c : Color::Color)
        return unless Point.new(x, y).in(@rect)
        
        if c.is_a?({{color_type.id}})
          {{set_method.id}}(x, y, c)
          return
        end

        i = pixel_offset(x, y)
        c1 = Color.{{model_method.id}}.convert(c)
        return unless c1.is_a?({{color_type.id}})
        {% if bytes_per_pixel == 1 %}
          @pix[i] = c1.{{single_field.id}}
        {% elsif bytes_per_pixel == 2 %}
          @pix[i + 0] = (c1.{{single_field.id}} >> 8).to_u8
          @pix[i + 1] = (c1.{{single_field.id}} & 0xff).to_u8
        {% elsif bytes_per_pixel == 4 %}
          s = @pix[i...i + 4]
          s[0] = c1.r
          s[1] = c1.g
          s[2] = c1.b
          s[3] = c1.a
        {% else %}
          s = @pix[i...i + 8]
          s[0] = (c1.r >> 8).to_u8
          s[1] = (c1.r & 0xff).to_u8
          s[2] = (c1.g >> 8).to_u8
          s[3] = (c1.g & 0xff).to_u8
          s[4] = (c1.b >> 8).to_u8
          s[5] = (c1.b & 0xff).to_u8
          s[6] = (c1.a >> 8).to_u8
          s[7] = (c1.a & 0xff).to_u8
        {% end %}
      end

      def {{set_method.id}}(x : Int32, y : Int32, c : {{color_type.id}})
        return unless Point.new(x, y).in(@rect)
        i = pixel_offset(x, y)
        {% if bytes_per_pixel == 1 %}
          @pix[i] = c.{{single_field.id}}
        {% elsif bytes_per_pixel == 2 %}
          @pix[i + 0] = (c.{{single_field.id}} >> 8).to_u8
          @pix[i + 1] = (c.{{single_field.id}} & 0xff).to_u8
        {% elsif bytes_per_pixel == 4 %}
          s = @pix[i...i + 4]
          s[0] = c.r
          s[1] = c.g
          s[2] = c.b
          s[3] = c.a
        {% else %}
          s = @pix[i...i + 8]
          s[0] = (c.r >> 8).to_u8
          s[1] = (c.r & 0xff).to_u8
          s[2] = (c.g >> 8).to_u8
          s[3] = (c.g & 0xff).to_u8
          s[4] = (c.b >> 8).to_u8
          s[5] = (c.b & 0xff).to_u8
          s[6] = (c.a >> 8).to_u8
          s[7] = (c.a & 0xff).to_u8
        {% end %}
      end

      def sub_image(r : Rectangle) : Image
        r = r.intersect(@rect)
        return {{type_name.id}}.new if r.empty
        i = pixel_offset(r.min.x, r.min.y)
        {{type_name.id}}.new(@pix[i..], @stride, r)
      end

      def opaque? : Bool
        {% if opaque_default %}
          true
        {% else %}
          return true if @rect.empty

          {% if bytes_per_pixel == 8 %}
            i0, i1 = 6, @rect.width * 8
            y = @rect.min.y
            while y < @rect.max.y
              i = i0
              while i < i1
                return false unless @pix[i] == 0xff && @pix[i + 1] == 0xff
                i += 8
              end
              i0 += @stride
              i1 += @stride
              y += 1
            end
            true
          {% else %}
            i0, i1 = 3, @rect.width * {{bytes_per_pixel}}
            y = @rect.min.y
            while y < @rect.max.y
              i = i0
              while i < i1
                return false unless @pix[i] == 0xff
                i += {{bytes_per_pixel}}
              end
              i0 += @stride
              i1 += @stride
              y += 1
            end
            true
          {% end %}
        {% end %}
      end

      def_equals_and_hash @pix, @stride, @rect
    end
  end
end
