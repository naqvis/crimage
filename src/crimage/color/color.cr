# Module Color implements a basic color library
# Color is an interface that defines the minimal method set of any type that can be
# considered a color: one that can be converted to red, green, blue and alpha values.
# The conversion may be lossy, such as converting from CMYK or YCbCr color spaces.
module CrImage::Color
  # Color bit depth constants
  MAX_8BIT      =    0xff_u8 # Maximum 8-bit color value (255)
  MAX_16BIT     = 0xffff_u16 # Maximum 16-bit color value (65535)
  MAX_32BIT     = 0xffff_u32 # Maximum 16-bit color value as 32-bit (65535)
  SCALE_8_TO_16 =  0x101_u32 # Scale factor from 8-bit to 16-bit (257)

  # YCbCr conversion constants (JFIF specification)
  # Y' =  0.2990*R + 0.5870*G + 0.1140*B
  # Note: 19595 + 38470 + 7471 = 65536
  YCBCR_Y_R_COEFF = 19595 # 0.2990 * 65536
  YCBCR_Y_G_COEFF = 38470 # 0.5870 * 65536
  YCBCR_Y_B_COEFF =  7471 # 0.1140 * 65536

  # Cb/Cr conversion coefficients
  YCBCR_CB_R_COEFF = -11056 # -0.1687 * 65536
  YCBCR_CB_G_COEFF = -21712 # -0.3313 * 65536
  YCBCR_CB_B_COEFF =  32768 #  0.5000 * 65536

  YCBCR_CR_R_COEFF =  32768 #  0.5000 * 65536
  YCBCR_CR_G_COEFF = -27440 # -0.4187 * 65536
  YCBCR_CR_B_COEFF =  -5328 # -0.0813 * 65536

  # RGB to YCbCr rounding adjustment: 257 << 15
  YCBCR_CHROMA_OFFSET = 257 << 15

  # YCbCr to RGB conversion coefficients (scaled by 65536)
  RGB_FROM_CR_COEFF   =  91881 # 1.40200 * 65536
  RGB_FROM_CB_G_COEFF =  22554 # 0.34414 * 65536
  RGB_FROM_CR_G_COEFF =  46802 # 0.71414 * 65536
  RGB_FROM_CB_COEFF   = 116130 # 1.77200 * 65536

  # YY1 multiplier for YCbCr to RGB: Y' * 0x10101
  YCBCR_YY1_MULTIPLIER = 0x10101

  # Standard colors
  BLACK       = Gray16.new(0_u16).as(Color)
  WHITE       = Gray16.new(MAX_16BIT).as(Color)
  TRANSPARENT = Alpha16.new(0_u16).as(Color)
  OPAQUE      = Alpha16.new(MAX_16BIT).as(Color)

  # Common named colors (CSS/Web colors)
  RED     = RGBA.new(255, 0, 0, 255)
  GREEN   = RGBA.new(0, 255, 0, 255)
  BLUE    = RGBA.new(0, 0, 255, 255)
  YELLOW  = RGBA.new(255, 255, 0, 255)
  CYAN    = RGBA.new(0, 255, 255, 255)
  MAGENTA = RGBA.new(255, 0, 255, 255)
  ORANGE  = RGBA.new(255, 165, 0, 255)
  PURPLE  = RGBA.new(128, 0, 128, 255)
  PINK    = RGBA.new(255, 192, 203, 255)
  BROWN   = RGBA.new(165, 42, 42, 255)
  GRAY    = RGBA.new(128, 128, 128, 255)
  GREY    = RGBA.new(128, 128, 128, 255)

  # Parse a color from various string formats:
  # - Hex: "#RRGGBB", "#RRGGBBAA", "#RGB", "#RGBA"
  # - CSS: "rgb(r, g, b)", "rgba(r, g, b, a)"
  # - Named: "red", "blue", "green", etc.
  #
  # Examples:
  # ```
  # Color.parse("#FF0000")            # => Red
  # Color.parse("#FF0000FF")          # => Red with alpha
  # Color.parse("#F00")               # => Red (short form)
  # Color.parse("rgb(255, 0, 0)")     # => Red
  # Color.parse("rgba(255, 0, 0, 1)") # => Red with alpha
  # Color.parse("red")                # => Red
  # ```
  def self.parse(str : String) : RGBA
    str = str.strip.downcase

    # Try named colors first
    case str
    when "red"          then return RED
    when "green"        then return GREEN
    when "blue"         then return BLUE
    when "yellow"       then return YELLOW
    when "cyan"         then return CYAN
    when "magenta"      then return MAGENTA
    when "orange"       then return ORANGE
    when "purple"       then return PURPLE
    when "pink"         then return PINK
    when "brown"        then return BROWN
    when "gray", "grey" then return GRAY
    when "black"        then return RGBA.new(0, 0, 0, 255)
    when "white"        then return RGBA.new(255, 255, 255, 255)
    when "transparent"  then return RGBA.new(0, 0, 0, 0)
    end

    # Try hex format
    if str.starts_with?('#')
      return parse_hex(str[1..])
    end

    # Try CSS rgb/rgba format
    if str.starts_with?("rgb")
      return parse_css_rgb(str)
    end

    raise ArgumentError.new("Invalid color format: #{str}")
  end

  # Parse hex color string (without # prefix)
  private def self.parse_hex(hex : String) : RGBA
    case hex.size
    when 3 # RGB short form
      r = hex[0].to_i(16) * 17
      g = hex[1].to_i(16) * 17
      b = hex[2].to_i(16) * 17
      RGBA.new(r, g, b, 255)
    when 4 # RGBA short form
      r = hex[0].to_i(16) * 17
      g = hex[1].to_i(16) * 17
      b = hex[2].to_i(16) * 17
      a = hex[3].to_i(16) * 17
      RGBA.new(r, g, b, a)
    when 6 # RRGGBB
      r = hex[0..1].to_i(16)
      g = hex[2..3].to_i(16)
      b = hex[4..5].to_i(16)
      RGBA.new(r, g, b, 255)
    when 8 # RRGGBBAA
      r = hex[0..1].to_i(16)
      g = hex[2..3].to_i(16)
      b = hex[4..5].to_i(16)
      a = hex[6..7].to_i(16)
      RGBA.new(r, g, b, a)
    else
      raise ArgumentError.new("Invalid hex color length: #{hex}")
    end
  end

  # Parse CSS rgb/rgba format
  private def self.parse_css_rgb(str : String) : RGBA
    # Extract values from rgb(r, g, b) or rgba(r, g, b, a)
    if match = str.match(/rgba?\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)/)
      r = match[1].to_i
      g = match[2].to_i
      b = match[3].to_i
      a = match[4]? ? (match[4].to_f * 255).to_i : 255
      RGBA.new(r, g, b, a)
    else
      raise ArgumentError.new("Invalid CSS color format: #{str}")
    end
  end

  # Create RGBA color from hex integer
  # ```
  # Color.hex(0xFF0000FF) # => Red with full alpha
  # Color.hex(0xFF0000)   # => Red (alpha = 255)
  # ```
  def self.hex(value : Int, has_alpha : Bool = true) : RGBA
    if has_alpha
      r = ((value >> 24) & 0xFF).to_u8
      g = ((value >> 16) & 0xFF).to_u8
      b = ((value >> 8) & 0xFF).to_u8
      a = (value & 0xFF).to_u8
    else
      r = ((value >> 16) & 0xFF).to_u8
      g = ((value >> 8) & 0xFF).to_u8
      b = (value & 0xFF).to_u8
      a = 255_u8
    end
    RGBA.new(r, g, b, a)
  end

  # Create RGB color (alpha = 255)
  # ```
  # Color.rgb(255, 0, 0) # => Red
  # ```
  def self.rgb(r : Int, g : Int, b : Int) : RGBA
    RGBA.new(r.to_u8, g.to_u8, b.to_u8, 255_u8)
  end

  # Create RGBA color
  # ```
  # Color.rgba(255, 0, 0, 128) # => Semi-transparent red
  # ```
  def self.rgba(r : Int, g : Int, b : Int, a : Int) : RGBA
    RGBA.new(r.to_u8, g.to_u8, b.to_u8, a.to_u8)
  end

  # Create grayscale color
  # ```
  # Color.gray(128) # => 50% gray
  # ```
  def self.gray(value : Int) : Gray
    Gray.new(value.to_u8)
  end

  # Blend two colors together with a ratio.
  # Ratio of 0.0 returns c1, ratio of 1.0 returns c2.
  # ```
  # blended = Color.blend(Color::RED, Color::BLUE, 0.5) # => Purple
  # ```
  def self.blend(c1 : Color, c2 : Color, ratio : Float64) : RGBA
    ratio = ratio.clamp(0.0, 1.0)
    inv_ratio = 1.0 - ratio

    r1, g1, b1, a1 = c1.rgba
    r2, g2, b2, a2 = c2.rgba

    # Convert to 8-bit, blend, and clamp to valid range
    r = ((r1 >> 8).to_f64 * inv_ratio + (r2 >> 8).to_f64 * ratio).round.clamp(0.0, 255.0).to_u8
    g = ((g1 >> 8).to_f64 * inv_ratio + (g2 >> 8).to_f64 * ratio).round.clamp(0.0, 255.0).to_u8
    b = ((b1 >> 8).to_f64 * inv_ratio + (b2 >> 8).to_f64 * ratio).round.clamp(0.0, 255.0).to_u8
    a = ((a1 >> 8).to_f64 * inv_ratio + (a2 >> 8).to_f64 * ratio).round.clamp(0.0, 255.0).to_u8

    RGBA.new(r, g, b, a)
  end

  # Mix multiple colors together (average).
  # ```
  # mixed = Color.mix([Color::RED, Color::GREEN, Color::BLUE])
  # ```
  def self.mix(colors : Array(Color)) : RGBA
    return RGBA.new(0, 0, 0, 0) if colors.empty?

    total_r = 0_u32
    total_g = 0_u32
    total_b = 0_u32
    total_a = 0_u32

    colors.each do |c|
      r, g, b, a = c.rgba
      total_r += r >> 8
      total_g += g >> 8
      total_b += b >> 8
      total_a += a >> 8
    end

    count = colors.size
    RGBA.new(
      (total_r // count).to_u8,
      (total_g // count).to_u8,
      (total_b // count).to_u8,
      (total_a // count).to_u8
    )
  end

  # Calculate Euclidean distance between two colors in RGB space.
  # Returns a value between 0.0 (identical) and ~441.67 (black to white).
  # ```
  # dist = Color.distance(Color::RED, Color::BLUE) # => ~360.62
  # ```
  def self.distance(c1 : Color, c2 : Color) : Float64
    r1, g1, b1, _ = c1.rgba
    r2, g2, b2, _ = c2.rgba

    dr = (r1 >> 8).to_i - (r2 >> 8).to_i
    dg = (g1 >> 8).to_i - (g2 >> 8).to_i
    db = (b1 >> 8).to_i - (b2 >> 8).to_i

    ::Math.sqrt(dr * dr + dg * dg + db * db)
  end

  # Alias for blend - interpolate between two colors.
  # ```
  # mid = Color.interpolate(Color::RED, Color::BLUE, 0.5) # => Purple
  # ```
  def self.interpolate(c1 : Color, c2 : Color, t : Float64) : RGBA
    blend(c1, c2, t)
  end

  # Create a new color with a different alpha value.
  # Alpha should be 0-255 for 8-bit or 0-65535 for 16-bit.
  # ```
  # semi_red = Color.with_alpha(Color::RED, 128) # => Semi-transparent red
  # ```
  def self.with_alpha(color : Color, alpha : Int) : RGBA
    r, g, b, _ = color.rgba
    RGBA.new(
      ((r >> 8) & 0xFF).to_u8,
      ((g >> 8) & 0xFF).to_u8,
      ((b >> 8) & 0xFF).to_u8,
      alpha.clamp(0, 255).to_u8
    )
  end

  # Calculate perceived luminance of a color (0.0 to 1.0).
  # Uses standard luminance coefficients (ITU-R BT.709).
  # ```
  # lum = Color.luminance(Color::WHITE) # => 1.0
  # lum = Color.luminance(Color::BLACK) # => 0.0
  # ```
  def self.luminance(color : Color) : Float64
    r, g, b, _ = color.rgba
    # Convert to 0-1 range and apply luminance coefficients
    rf = (r >> 8).to_f64 / 255.0
    gf = (g >> 8).to_f64 / 255.0
    bf = (b >> 8).to_f64 / 255.0
    0.2126 * rf + 0.7152 * gf + 0.0722 * bf
  end

  # Check if a color is considered "light" (luminance > 0.5).
  # Useful for determining text color on backgrounds.
  # ```
  # Color.light?(Color::WHITE) # => true
  # Color.light?(Color::BLACK) # => false
  # ```
  def self.light?(color : Color) : Bool
    luminance(color) > 0.5
  end

  # Check if a color is considered "dark" (luminance <= 0.5).
  # ```
  # Color.dark?(Color::BLACK) # => true
  # Color.dark?(Color::WHITE) # => false
  # ```
  def self.dark?(color : Color) : Bool
    luminance(color) <= 0.5
  end

  # Get a contrasting color (black or white) for text on this background.
  # ```
  # text_color = Color.contrasting(background_color)
  # ```
  def self.contrasting(color : Color) : RGBA
    light?(color) ? RGBA.new(0, 0, 0, 255) : RGBA.new(255, 255, 255, 255)
  end

  # Lighten a color by a percentage (0.0 to 1.0).
  # ```
  # lighter = Color.lighten(Color::RED, 0.2) # => Lighter red
  # ```
  def self.lighten(color : Color, amount : Float64) : RGBA
    r, g, b, a = color.rgba
    factor = 1.0 + amount.clamp(0.0, 1.0)
    RGBA.new(
      [(((r >> 8) * factor)).to_i, 255].min.to_u8,
      [(((g >> 8) * factor)).to_i, 255].min.to_u8,
      [(((b >> 8) * factor)).to_i, 255].min.to_u8,
      ((a >> 8) & 0xFF).to_u8
    )
  end

  # Darken a color by a percentage (0.0 to 1.0).
  # ```
  # darker = Color.darken(Color::RED, 0.2) # => Darker red
  # ```
  def self.darken(color : Color, amount : Float64) : RGBA
    r, g, b, a = color.rgba
    factor = 1.0 - amount.clamp(0.0, 1.0)
    RGBA.new(
      (((r >> 8) * factor)).to_u8,
      (((g >> 8) * factor)).to_u8,
      (((b >> 8) * factor)).to_u8,
      ((a >> 8) & 0xFF).to_u8
    )
  end

  # Color can convert itself to alpha-premultiplied 160bits per channel RGBA.
  # The conversion may be lossy.
  # There are three important subtleties about the return values. First, the red, green and blue are alpha-premultiplied:
  # a fully saturated red that is also 25% transparent is represented by RGBA returning a 75% r.
  # Second, the channels have a 16-bit effective range: 100% red is represented by RGBA returning an r of 65535, not 255,
  # so that converting from CMYK or YCbCr is not as lossy. Third, the type returned is uint32, even though the maximum value is 65535,
  # to guarantee that multiplying two values together won't overflow. Such multiplications occur when blending two colors according to an
  # alpha mask from a third color, in the style of [Porter and Duff's](https://en.wikipedia.org/wiki/Alpha_compositing) classic algebra:
  module Color
    # RGBA returns the alpha-premultiplied red, green, blue and alpha values
    # for the color. Each value ranges within [0, 0xffff], but is represented
    # by a uint32 so that multiplying by a blend factor up to 0xffff will not
    # overflow.
    #
    # An alpha-premultiplied color component c has been scaled by alpha (a),
    # so has valid values 0 <= c <= a.
    abstract def rgba : {UInt32, UInt32, UInt32, UInt32}

    # Returns the color as an 8-bit RGBA struct.
    # Converts 16-bit color components to 8-bit by taking the high byte.
    #
    # Example:
    # ```
    # color = CrImage::Color::RGBA64.new(0xFFFF_u16, 0x8000_u16, 0x0000_u16, 0xFFFF_u16)
    # rgba8 = color.to_rgba8 # => RGBA(255, 128, 0, 255)
    # ```
    def to_rgba8 : RGBA
      r, g, b, a = rgba
      RGBA.new((r >> 8).to_u8, (g >> 8).to_u8, (b >> 8).to_u8, (a >> 8).to_u8)
    end
  end

  # RGBA represents a traditional 32-bit alpha-premultiplied color, having
  # 8 bits for each of red, green, blue and alpha
  struct RGBA
    include Color

    property r : UInt8
    property g : UInt8
    property b : UInt8
    property a : UInt8

    def initialize(@r, @g, @b, @a)
    end

    def initialize(r : Number, g : Number, b : Number, a : Number)
      @r = r.to_u8
      @g = g.to_u8
      @b = b.to_u8
      @a = a.to_u8
    end

    def self.from_rgb(r, g, b)
      new(r, g, b, 255)
    end

    def +(o : self)
      new(r + o.r, g + o.g, b + o.b, a)
    end

    def *(o : self)
      new(r*o.r, g * o.g, b * o.b, a)
    end

    def scale(k)
      new(k*r, k*g, k*b, a)
    end

    # Return a new color with modified alpha
    def with_alpha(new_alpha : Int) : RGBA
      RGBA.new(r, g, b, new_alpha.to_u8)
    end

    # Check if color is fully opaque
    def opaque? : Bool
      a == 255
    end

    # Check if color is fully transparent
    def transparent? : Bool
      a == 0
    end

    # Lighten color by percentage (0.0 to 1.0)
    def lighten(amount : Float64) : RGBA
      factor = 1.0 + amount
      RGBA.new(
        BoundsCheck.clamp_u8(r.to_f * factor),
        BoundsCheck.clamp_u8(g.to_f * factor),
        BoundsCheck.clamp_u8(b.to_f * factor),
        a
      )
    end

    # Darken color by percentage (0.0 to 1.0)
    def darken(amount : Float64) : RGBA
      factor = 1.0 - amount
      RGBA.new(
        (r.to_f * factor).to_u8,
        (g.to_f * factor).to_u8,
        (b.to_f * factor).to_u8,
        a
      )
    end

    # Convert to hex string
    def to_hex(include_alpha : Bool = true) : String
      if include_alpha
        "#%02X%02X%02X%02X" % [r, g, b, a]
      else
        "#%02X%02X%02X" % [r, g, b]
      end
    end

    # Blend this color with another.
    # Ratio of 0.0 returns self, ratio of 1.0 returns other.
    def blend(other : Color, ratio : Float64) : RGBA
      CrImage::Color.blend(self, other, ratio)
    end

    # Calculate distance to another color in RGB space.
    def distance(other : Color) : Float64
      CrImage::Color.distance(self, other)
    end

    # Check if this color is similar to another within a threshold.
    def similar?(other : Color, threshold : Float64 = 30.0) : Bool
      distance(other) <= threshold
    end

    # Get the complementary color (opposite on color wheel).
    def complement : RGBA
      RGBA.new(255_u8 - r, 255_u8 - g, 255_u8 - b, a)
    end

    # Get grayscale value (luminance).
    def luminance : UInt8
      # Using standard luminance coefficients
      (0.299 * r + 0.587 * g + 0.114 * b).to_u8
    end

    def rgba : {UInt32, UInt32, UInt32, UInt32}
      r = self.r.to_u32
      r |= r << 8
      g = self.g.to_u32
      g |= g << 8
      b = self.b.to_u32
      b |= b << 8
      a = self.a.to_u32
      a |= a << 8
      {r, g, b, a}
    end

    def to_s(io : IO) : Nil
      io << "RGBA(#{r},#{g},#{b},#{a})"
    end

    def_equals_and_hash @r, @g, @b, @a
  end

  # RGBA64 represents a traditional 64-bit alpha-premultiplied color, having
  # 16 bits for each of red, green, blue and alpha.
  #
  # An alpha-premultiplied color comoponent C has been scaled by alpha (A), so
  # has valid values 0 <= C <= A
  struct RGBA64
    include Color

    property r : UInt16
    property g : UInt16
    property b : UInt16
    property a : UInt16

    def initialize(@r, @g, @b, @a)
    end

    def initialize(r : Number, g : Number, b : Number, a : Number)
      @r = r.to_u16
      @g = g.to_u16
      @b = b.to_u16
      @a = a.to_u16
    end

    def rgba : {UInt32, UInt32, UInt32, UInt32}
      {self.r.to_u32, self.g.to_u32, self.b.to_u32, self.a.to_u32}
    end

    def to_s(io : IO) : Nil
      io << "RGBA64(#{r},#{g},#{b},#{a})"
    end

    def_equals_and_hash @r, @g, @b, @a
  end

  # NRGBA represents a non-alpha-premultiplied 32-bit color.
  struct NRGBA
    include Color

    property r : UInt8
    property g : UInt8
    property b : UInt8
    property a : UInt8

    def initialize(@r, @g, @b, @a)
    end

    def initialize(r : Number, g : Number, b : Number, a : Number)
      @r = r.to_u8
      @g = g.to_u8
      @b = b.to_u8
      @a = a.to_u8
    end

    def rgba : {UInt32, UInt32, UInt32, UInt32}
      r = self.r.to_u32
      r |= r << 8
      r *= self.a.to_u32
      r /= 0xff

      g = self.g.to_u32
      g |= g << 8
      g *= self.a.to_u32
      g /= 0xff

      b = self.b.to_u32
      b |= b << 8
      b *= self.a.to_u32
      b /= 0xff

      a = self.a.to_u32
      a |= a << 8

      {r.to_u32, g.to_u32, b.to_u32, a.to_u32}
    end

    def to_s(io : IO) : Nil
      io << "NRGBA(#{r},#{g},#{b},#{a})"
    end

    def_equals_and_hash @r, @g, @b, @a
  end

  # NRGBA64 represents a non-alpha-premultiplied 64-bit color,
  # having 16 bits for each of red, gree, blue and alpha.
  struct NRGBA64
    include Color

    property r : UInt16
    property g : UInt16
    property b : UInt16
    property a : UInt16

    def initialize(@r, @g, @b, @a)
    end

    def initialize(r : Number, g : Number, b : Number, a : Number)
      @r = r.to_u16.clamp(0_u16, MAX_16BIT)
      @g = g.to_u16.clamp(0_u16, MAX_16BIT)
      @b = b.to_u16.clamp(0_u16, MAX_16BIT)
      @a = a.to_u16.clamp(0_u16, MAX_16BIT)
    end

    def rgba : {UInt32, UInt32, UInt32, UInt32}
      r = self.r.to_u32
      r *= self.a.to_u32
      r /= 0xffff

      g = self.g.to_u32
      g *= self.a.to_u32
      g /= 0xffff

      b = self.b.to_u32
      b *= self.a.to_u32
      b /= 0xffff

      a = self.a.to_u32

      {r.to_u32, g.to_u32, b.to_u32, a.to_u32}
    end

    def to_s(io : IO) : Nil
      io << "NRGBA64(#{r},#{g},#{b},#{a})"
    end

    def_equals_and_hash @r, @g, @b, @a
  end

  # Alpha represents an 8-bit alpha color.
  struct Alpha
    include Color
    property a : UInt8

    def initialize(@a)
    end

    def initialize(a : Number)
      @a = a.to_u8
    end

    def rgba : {UInt32, UInt32, UInt32, UInt32}
      a = self.a.to_u32
      a |= a << 8
      {a, a, a, a}
    end

    def to_s(io : IO) : Nil
      io << "Alpha(#{a})"
    end
  end

  # Alpha16 represents a 16-bit alpha color.
  struct Alpha16
    include Color
    property a : UInt16

    def initialize(@a)
    end

    def initialize(a : Number)
      @a = a.to_u16
    end

    def rgba : {UInt32, UInt32, UInt32, UInt32}
      a = self.a.to_u32
      {a, a, a, a}
    end

    def to_s(io : IO) : Nil
      io << "Alpha16(#{a})"
    end
  end

  # Gray represents an 8-bit grayscale color.
  struct Gray
    include Color
    property y : UInt8

    def initialize(@y)
    end

    def initialize(y : Number)
      @y = y.to_u8
    end

    def rgba : {UInt32, UInt32, UInt32, UInt32}
      a = @y.to_u32
      a |= (a.to_u32 << 8)
      {a, a, a, 0xffff_u32}
    end

    def to_s(io : IO) : Nil
      io << "Gray(#{y})"
    end
  end

  # Gray16 represents an 16-bit grayscale color.
  struct Gray16
    include Color
    property y : UInt16

    def initialize(@y)
    end

    def initialize(y : Number)
      @y = y.to_u16.clamp(0_u16, MAX_16BIT)
    end

    def rgba : {UInt32, UInt32, UInt32, UInt32}
      y = self.y.to_u32
      {y, y, y, 0xffff_u32}
    end

    def to_s(io : IO) : Nil
      io << "Gray16(#{y})"
    end
  end

  # Model can convert any Color to one from its own color model. The conversion may
  # be lossy
  module Model
    abstract def convert(c : Color) : Color
    abstract def name : String
  end

  alias ModelProc = Color -> Color # Proc(Color, Color)

  private struct ModelFunc
    include Model

    def initialize(@f : ModelProc, @n : String)
    end

    def convert(c : Color) : Color
      @f.call(c)
    end

    def name : String
      @n.gsub("_model", "").upcase
    end
  end

  # Models for the standard color types
  {% for method in %w(rgba_model rgba64_model nrgba_model nrgba64_model alpha_model alpha16_model gray_model gray16_model ycbcr_model nycbcra_model cmyk_model) %}
    def self.{{method.id}}() : Model
      ModelFunc.new(->{{method.id}}(Color), {{method.id.stringify}}).as(Model)
    end
  {% end %}

  private def self.rgba_model(c : Color) : Color
    return c if c.is_a?(RGBA)
    r, g, b, a = c.rgba
    RGBA.new(((r >> 8) & 0xFF).to_u8, ((g >> 8) & 0xFF).to_u8, ((b >> 8) & 0xFF).to_u8, ((a >> 8) & 0xFF).to_u8).as(Color)
  end

  private def self.rgba64_model(c : Color) : Color
    return c if c.is_a?(RGBA64)
    r, g, b, a = c.rgba
    RGBA64.new(r.to_u16, g.to_u16, b.to_u16, a.to_u16).as(Color)
  end

  private def self.nrgba_model(c : Color) : Color
    return c if c.is_a?(NRGBA)
    r, g, b, a = c.rgba

    return NRGBA.new(((r >> 8) & 0xFF).to_u8, ((g >> 8) & 0xFF).to_u8, ((b >> 8) & 0xFF).to_u8, 0xff_u8).as(Color) if a == 0xffff

    return NRGBA.new(0_u8, 0_u8, 0_u8, 0_u8).as(Color) if a == 0

    # Since Color::rgba returns an alpha-premultiplied color, we should have r <= a && g <= a && b <= a
    r = (r * 0xffff) // a
    g = (g * 0xffff) // a
    b = (b * 0xffff) // a
    NRGBA.new(((r >> 8) & 0xFF).to_u8, ((g >> 8) & 0xFF).to_u8, ((b >> 8) & 0xFF).to_u8, ((a >> 8) & 0xFF).to_u8).as(Color)
  end

  private def self.nrgba64_model(c : Color) : Color
    return c if c.is_a?(NRGBA64)
    r, g, b, a = c.rgba

    return NRGBA64.new(r.to_u16.clamp(0_u16, MAX_16BIT), g.to_u16.clamp(0_u16, MAX_16BIT), b.to_u16.clamp(0_u16, MAX_16BIT), 0xffff_u16).as(Color) if a == 0xffff

    return NRGBA64.new(0_u16, 0_u16, 0_u16, 0_u16).as(Color) if a == 0

    # Since Color::rgba returns an alpha-premultiplied color, we should have r <= a && g <= a && b <= a
    r = (r * 0xffff) // a
    g = (g * 0xffff) // a
    b = (b * 0xffff) // a

    NRGBA64.new(r.clamp(0_u32, MAX_32BIT).to_u16, g.clamp(0_u32, MAX_32BIT).to_u16, b.clamp(0_u32, MAX_32BIT).to_u16, a.clamp(0_u32, MAX_32BIT).to_u16).as(Color)
  end

  private def self.alpha_model(c : Color) : Color
    return c if c.is_a?(Alpha)

    _, _, _, a = c.rgba
    Alpha.new(((a >> 8) & 0xFF).to_u8).as(Color)
  end

  private def self.alpha16_model(c : Color) : Color
    return c if c.is_a?(Alpha16)
    _, _, _, a = c.rgba
    Alpha16.new(a).as(Color)
  end

  private def self.gray_model(c : Color) : Color
    return c if c.is_a?(Gray)

    r, g, b, _ = c.rgba

    # These coefficients (the fractions 0.299, 0.587 and 0.114) are the same
    # as those given by the JFIF specification and used by func rgb_to_ycbcr in
    # ycbcr.cr.
    #
    # Note that YCBCR_Y_R_COEFF + YCBCR_Y_G_COEFF + YCBCR_Y_B_COEFF equals 65536.
    #
    # The 24 is 16 + 8. The 16 is the same as used in rgb_to_ycbcr. The 8 is
    # because the return value is 8 bit color, not 16 bit color.
    y = (YCBCR_Y_R_COEFF &* r &+ YCBCR_Y_G_COEFF &* g &+ YCBCR_Y_B_COEFF &* b &+ (1 << 15)) >> 24
    Gray.new(y.clamp(0, 255).to_u8).as(Color)
  end

  private def self.gray16_model(c : Color) : Color
    return c if c.is_a?(Gray16)

    r, g, b, _ = c.rgba

    # These coefficients (the fractions 0.299, 0.587 and 0.114) are the same
    # as those given by the JFIF specification and used by func rgb_to_ycbcr in
    # ycbcr.cr.
    #
    # Note that YCBCR_Y_R_COEFF + YCBCR_Y_G_COEFF + YCBCR_Y_B_COEFF equals 65536.

    y = (YCBCR_Y_R_COEFF &* r &+ YCBCR_Y_G_COEFF &* g &+ YCBCR_Y_B_COEFF &* b &+ (1 << 15)) >> 16
    Gray16.new(y.clamp(0, MAX_32BIT.to_i32).to_u16).as(Color)
  end

  # Pallete is a palette of colors.
  struct Palette
    include Enumerable(Color)
    include Model

    def initialize
      @colors = Array(Color).new
    end

    def initialize(@colors : Array(Color))
    end

    def each(&)
      @colors.each { |color| yield color }
    end

    # returns the palette color closest to c in Euclidean R,G,B space.
    def convert(c : Color) : Color
      raise Exception.new("Invalid palette, contains no colors") if @colors.size == 0
      @colors[index(c)]
    end

    def name : String
      "PALETTE"
    end

    # index returns the index of the palette color closest to c in Euclidean R,G,B,A space.
    def index(c : Color)
      cr, cg, cb, ca = c.rgba
      ret, best_sum = {0, (1_u32 << 32 - 1).to_u32}

      @colors.each_with_index do |v, i|
        vr, vg, vb, va = v.rgba
        sum = CrImage::Color.sq_diff(cr, vr) + CrImage::Color.sq_diff(cg, vg) + CrImage::Color.sq_diff(cb, vb) + CrImage::Color.sq_diff(ca, va)
        if sum < best_sum
          return i if sum == 0
          ret, best_sum = i, sum
        end
      end
      ret
    end

    forward_missing_to @colors
  end

  # sq_diff returns the squared-difference of x and y, shifted by 2 so that
  # adding four of those won't overflow a UInt32
  protected def self.sq_diff(x : UInt32, y : UInt32) : UInt32
    # The canonical code of this function looks as follows:
    #
    #	var d uint32
    #	if x > y {
    #		d = x - y
    #	} else {
    #		d = y - x
    #	}
    #	return (d * d) >> 2
    #
    # Language spec guarantees the following properties of unsigned integer
    # values operations with respect to overflow/wrap around:
    #
    # > For unsigned integer values, the operations +, -, *, and << are
    # > computed modulo 2n, where n is the bit width of the unsigned
    # > integer's type. Loosely speaking, these unsigned integer operations
    # > discard high bits upon overflow, and programs may rely on ``wrap
    # > around''.
    #
    # Considering these properties and the fact that this function is
    # called in the hot paths (x,y loops), it is reduced to the below code
    # which is slightly faster. See TestSqDiff for correctness check.
    d = x &- y
    ((d &* d) >> 2).to_u32
  end
end

# String extension for color parsing
class String
  # Convert string to color
  #
  # Convenience method for parsing color strings. Supports hex colors,
  # CSS color names, and CSS rgb/rgba functions.
  #
  # ```
  # "#FF0000".to_color        # => Red
  # "rgb(255, 0, 0)".to_color # => Red
  # "red".to_color            # => Red
  # ```
  #
  # See `CrImage::Color.parse` for full documentation.
  def to_color : CrImage::Color::RGBA
    CrImage::Color.parse(self)
  end
end

require "./**"
