module CrImage
  # Uniform is an infinite-sized image of a single uniform color.
  #
  # This is a memory-efficient representation for solid color images.
  # Instead of storing pixel data, it returns the same color for all coordinates.
  #
  # Bounds: Effectively infinite (±1 billion pixels)
  # Memory: Only stores a single color value
  #
  # Use Uniform for:
  # - Solid color backgrounds
  # - Fill patterns
  # - Compositing operations with uniform colors
  #
  # Example:
  # ```
  # white = CrImage::Uniform.new(CrImage::Color::WHITE)
  # red = CrImage::Uniform.new(CrImage::Color.rgb(255, 0, 0))
  # color = white.at(1000, 1000) # Always returns white
  # ```
  class Uniform
    include Color::Color
    include Color::Model
    include Image

    property color : Color::Color

    def initialize(@color)
    end

    def rgba : {UInt32, UInt32, UInt32, UInt32}
      @color.rgba
    end

    def color_model : Color::Model
      self
    end

    def convert(c : Color::Color) : Color::Color
      @color
    end

    def name : String
      "UNIFORM"
    end

    def bounds : Rectangle
      CrImage.rect(-1e9.to_i, -1e9.to_i, 1e9.to_i, 1e9.to_i)
    end

    def at(x : Int32, y : Int32) : Color::Color
      @color
    end

    def set(x : Int32, y : Int32, c : Color::Color)
      @color = c
    end

    # opaque? scans the entire image and reports whether it is fully opaque
    def opaque? : Bool
      _, _, _, a = rgba
      a == Color::MAX_32BIT
    end

    def_equals_and_hash @color
  end
end
