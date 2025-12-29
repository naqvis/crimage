# Blurhash encoder and decoder for compact image placeholders.
#
# Blurhash is a compact representation of a placeholder for an image.
# It encodes the image using DCT (Discrete Cosine Transform) and produces
# a short string that can be used to show a blurred preview while the
# full image loads.
#
# ## Example
# ```
# # Encode an image to blurhash
# img = CrImage.read("photo.jpg")
# hash = CrImage::Util::Blurhash.encode(img, x_components: 4, y_components: 3)
# # => "LKO2?U%2Tw=w]~RBVZRi};RPxuwH"
#
# # Decode blurhash to image
# placeholder = CrImage::Util::Blurhash.decode(hash, width: 32, height: 32)
# ```
#
# See: https://blurha.sh/
module CrImage::Util::Blurhash
  # Base83 character set used for encoding
  CHARSET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#$%*+,-.:;=?@[]^_{|}~"

  # Lookup table for decoding base83
  CHARSET_LOOKUP = begin
    lookup = {} of Char => Int32
    CHARSET.each_char_with_index { |c, i| lookup[c] = i }
    lookup
  end

  class Error < Exception
  end

  # Encodes an image to a blurhash string.
  #
  # Parameters:
  # - `image` : Source image to encode
  # - `x_components` : Number of components on X axis (1-9, default: 4)
  # - `y_components` : Number of components on Y axis (1-9, default: 3)
  #
  # Returns: Blurhash string
  #
  # Example:
  # ```
  # hash = CrImage::Util::Blurhash.encode(img, x_components: 4, y_components: 3)
  # ```
  def self.encode(image : CrImage::Image, x_components : Int32 = 4, y_components : Int32 = 3) : String
    raise Error.new("x_components must be between 1 and 9") unless x_components >= 1 && x_components <= 9
    raise Error.new("y_components must be between 1 and 9") unless y_components >= 1 && y_components <= 9

    width = image.bounds.width
    height = image.bounds.height

    # Calculate DCT factors
    factors = Array(Array(Float64)).new(x_components * y_components) { [0.0, 0.0, 0.0] }

    y_components.times do |j|
      x_components.times do |i|
        factor = multiply_basis_function(image, width, height, i, j)
        factors[j * x_components + i] = factor
      end
    end

    # Encode DC value (first component)
    dc = factors[0]
    dc_value = encode_dc(dc[0], dc[1], dc[2])

    # Calculate maximum AC component value
    max_ac = 0.0
    if factors.size > 1
      factors[1..].each do |factor|
        factor.each do |v|
          max_ac = v.abs if v.abs > max_ac
        end
      end
    end

    # Quantize max AC
    quantised_max_ac = if max_ac > 0
                         [0, [82, (max_ac * 166 - 0.5).floor.to_i].min].max
                       else
                         0
                       end

    ac_scale = (quantised_max_ac + 1).to_f64 / 166.0

    # Build result string
    result = String.build do |str|
      # Size flag (1 digit)
      size_flag = (x_components - 1) + (y_components - 1) * 9
      str << encode_base83(size_flag, 1)

      # Quantised max AC (1 digit)
      str << encode_base83(quantised_max_ac, 1)

      # DC value (4 digits)
      str << encode_base83(dc_value, 4)

      # AC values (2 digits each)
      factors[1..].each do |factor|
        ac_value = encode_ac(factor[0], factor[1], factor[2], ac_scale)
        str << encode_base83(ac_value, 2)
      end
    end

    result
  end

  # Decodes a blurhash string to an image.
  #
  # Parameters:
  # - `blurhash` : Blurhash string to decode
  # - `width` : Output image width
  # - `height` : Output image height
  # - `punch` : Contrast adjustment (default: 1.0)
  #
  # Returns: RGBA image
  #
  # Example:
  # ```
  # img = CrImage::Util::Blurhash.decode("LKO2?U%2Tw=w]~RBVZRi};RPxuwH", 32, 32)
  # ```
  def self.decode(blurhash : String, width : Int32, height : Int32, punch : Float64 = 1.0) : CrImage::RGBA
    raise Error.new("Blurhash must be at least 6 characters") if blurhash.size < 6

    # Decode size flag
    size_flag = decode_base83(blurhash[0, 1])
    y_components = (size_flag // 9) + 1
    x_components = (size_flag % 9) + 1

    expected_length = 4 + 2 * x_components * y_components
    raise Error.new("Invalid blurhash length: expected #{expected_length}, got #{blurhash.size}") if blurhash.size != expected_length

    # Decode quantised max AC
    quantised_max_ac = decode_base83(blurhash[1, 1])
    max_ac = (quantised_max_ac + 1).to_f64 / 166.0

    # Decode colors
    colors = Array(Array(Float64)).new(x_components * y_components) { [0.0, 0.0, 0.0] }

    # DC value
    dc_value = decode_base83(blurhash[2, 4])
    colors[0] = decode_dc(dc_value)

    # AC values
    (1...x_components * y_components).each do |i|
      ac_value = decode_base83(blurhash[4 + (i - 1) * 2, 2])
      colors[i] = decode_ac(ac_value, max_ac * punch)
    end

    # Generate image
    img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

    height.times do |y|
      width.times do |x|
        r = 0.0
        g = 0.0
        b = 0.0

        y_components.times do |j|
          x_components.times do |i|
            basis = ::Math.cos((::Math::PI * x * i) / width) * ::Math.cos((::Math::PI * y * j) / height)
            color = colors[j * x_components + i]
            r += color[0] * basis
            g += color[1] * basis
            b += color[2] * basis
          end
        end

        img.set(x, y, CrImage::Color::RGBA.new(
          linear_to_srgb(r),
          linear_to_srgb(g),
          linear_to_srgb(b),
          255_u8
        ))
      end
    end

    img
  end

  # Returns the average color from a blurhash without full decoding.
  #
  # This is useful when you only need the dominant color.
  def self.average_color(blurhash : String) : CrImage::Color::RGBA
    raise Error.new("Blurhash must be at least 6 characters") if blurhash.size < 6
    dc_value = decode_base83(blurhash[2, 4])
    rgb = decode_dc(dc_value)
    CrImage::Color::RGBA.new(
      linear_to_srgb(rgb[0]),
      linear_to_srgb(rgb[1]),
      linear_to_srgb(rgb[2]),
      255_u8
    )
  end

  # Validates a blurhash string.
  def self.valid?(blurhash : String) : Bool
    return false if blurhash.size < 6

    size_flag = decode_base83(blurhash[0, 1])
    y_components = (size_flag // 9) + 1
    x_components = (size_flag % 9) + 1

    expected_length = 4 + 2 * x_components * y_components
    blurhash.size == expected_length
  rescue
    false
  end

  # Returns the number of components encoded in a blurhash.
  def self.components(blurhash : String) : {Int32, Int32}
    raise Error.new("Blurhash must be at least 6 characters") if blurhash.size < 6
    size_flag = decode_base83(blurhash[0, 1])
    y_components = (size_flag // 9) + 1
    x_components = (size_flag % 9) + 1
    {x_components, y_components}
  end

  # --- Private helpers ---

  private def self.multiply_basis_function(image : CrImage::Image, width : Int32, height : Int32, x_comp : Int32, y_comp : Int32) : Array(Float64)
    r = 0.0
    g = 0.0
    b = 0.0

    normalisation = x_comp == 0 && y_comp == 0 ? 1.0 : 2.0

    height.times do |y|
      width.times do |x|
        basis = normalisation * ::Math.cos((::Math::PI * x_comp * x) / width) * ::Math.cos((::Math::PI * y_comp * y) / height)
        color = image.at(x, y)
        cr, cg, cb, _ = color.rgba

        r += basis * srgb_to_linear((cr >> 8).to_u8)
        g += basis * srgb_to_linear((cg >> 8).to_u8)
        b += basis * srgb_to_linear((cb >> 8).to_u8)
      end
    end

    scale = 1.0 / (width * height)
    [r * scale, g * scale, b * scale]
  end

  private def self.srgb_to_linear(value : UInt8) : Float64
    v = value.to_f64 / 255.0
    if v <= 0.04045
      v / 12.92
    else
      ((v + 0.055) / 1.055) ** 2.4
    end
  end

  private def self.linear_to_srgb(value : Float64) : UInt8
    v = value.clamp(0.0, 1.0)
    result = if v <= 0.0031308
               v * 12.92
             else
               1.055 * (v ** (1.0 / 2.4)) - 0.055
             end
    (result * 255 + 0.5).to_i.clamp(0, 255).to_u8
  end

  private def self.encode_dc(r : Float64, g : Float64, b : Float64) : Int32
    rounded_r = linear_to_srgb(r).to_i
    rounded_g = linear_to_srgb(g).to_i
    rounded_b = linear_to_srgb(b).to_i
    (rounded_r << 16) + (rounded_g << 8) + rounded_b
  end

  private def self.decode_dc(value : Int32) : Array(Float64)
    r = value >> 16
    g = (value >> 8) & 255
    b = value & 255
    [srgb_to_linear(r.to_u8), srgb_to_linear(g.to_u8), srgb_to_linear(b.to_u8)]
  end

  private def self.encode_ac(r : Float64, g : Float64, b : Float64, max_ac : Float64) : Int32
    quant_r = [0, [18, sign_pow(r / max_ac, 0.5) * 9 + 9.5].min.floor.to_i].max
    quant_g = [0, [18, sign_pow(g / max_ac, 0.5) * 9 + 9.5].min.floor.to_i].max
    quant_b = [0, [18, sign_pow(b / max_ac, 0.5) * 9 + 9.5].min.floor.to_i].max
    quant_r * 19 * 19 + quant_g * 19 + quant_b
  end

  private def self.decode_ac(value : Int32, max_ac : Float64) : Array(Float64)
    quant_r = value // (19 * 19)
    quant_g = (value // 19) % 19
    quant_b = value % 19
    [
      sign_pow((quant_r - 9).to_f64 / 9.0, 2.0) * max_ac,
      sign_pow((quant_g - 9).to_f64 / 9.0, 2.0) * max_ac,
      sign_pow((quant_b - 9).to_f64 / 9.0, 2.0) * max_ac,
    ]
  end

  private def self.sign_pow(value : Float64, exp : Float64) : Float64
    value.abs ** exp * (value < 0 ? -1.0 : 1.0)
  end

  private def self.encode_base83(value : Int32, length : Int32) : String
    String.build(length) do |str|
      (1..length).reverse_each do |i|
        digit = (value // (83 ** (i - 1))) % 83
        str << CHARSET[digit]
      end
    end
  end

  private def self.decode_base83(str : String) : Int32
    value = 0
    str.each_char do |c|
      digit = CHARSET_LOOKUP[c]?
      raise Error.new("Invalid character '#{c}' in blurhash") if digit.nil?
      value = value * 83 + digit
    end
    value
  end
end
