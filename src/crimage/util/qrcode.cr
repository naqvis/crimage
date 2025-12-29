# QR Code generator for CrImage.
#
# Generates QR codes following ISO/IEC 18004 specification.
# Supports versions 1-40, all error correction levels, and automatic
# mode/version selection.
#
# ## Example
# ```
# # Generate QR code image
# img = CrImage::Util::QRCode.generate("https://example.com", size: 300)
#
# # With options
# img = CrImage::Util::QRCode.generate("Hello",
#   error_correction: :high,
#   size: 400,
#   margin: 4
# )
#
# # Low-level API
# qr = CrImage::Util::QRCode.encode("Hello World")
# img = qr.to_image(module_size: 10)
# ```
module CrImage::Util::QRCode
  # Error correction levels
  enum ErrorCorrection
    Low      # ~7% recovery
    Medium   # ~15% recovery
    Quartile # ~25% recovery
    High     # ~30% recovery
  end

  # Encoding modes
  enum Mode
    Numeric      # 0-9
    Alphanumeric # 0-9, A-Z, space, $%*+-./:
    Byte         # ISO-8859-1 / UTF-8
    Kanji        # Shift JIS (not implemented)
  end

  # Alphanumeric character set
  ALPHANUMERIC_CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:"

  # Format info for each EC level and mask (pre-calculated with BCH)
  FORMAT_INFO = {
    ErrorCorrection::Low => [
      0x77c4, 0x72f3, 0x7daa, 0x789d, 0x662f, 0x6318, 0x6c41, 0x6976,
    ],
    ErrorCorrection::Medium => [
      0x5412, 0x5125, 0x5e7c, 0x5b4b, 0x45f9, 0x40ce, 0x4f97, 0x4aa0,
    ],
    ErrorCorrection::Quartile => [
      0x355f, 0x3068, 0x3f31, 0x3a06, 0x24b4, 0x2183, 0x2eda, 0x2bed,
    ],
    ErrorCorrection::High => [
      0x1689, 0x13be, 0x1ce7, 0x19d0, 0x0762, 0x0255, 0x0d0c, 0x083b,
    ],
  }

  # Version info (versions 7-40, pre-calculated with BCH)
  VERSION_INFO = [
    0x07c94, 0x085bc, 0x09a99, 0x0a4d3, 0x0bbf6, 0x0c762, 0x0d847, 0x0e60d,
    0x0f928, 0x10b78, 0x1145d, 0x12a17, 0x13532, 0x149a6, 0x15683, 0x168c9,
    0x177ec, 0x18ec4, 0x191e1, 0x1afab, 0x1b08e, 0x1cc1a, 0x1d33f, 0x1ed75,
    0x1f250, 0x209d5, 0x216f0, 0x228ba, 0x2379f, 0x24b0b, 0x2542e, 0x26a64,
    0x27541, 0x28c69,
  ]

  # Number of error correction codewords per block for each version and EC level
  # Format: [total_codewords, ec_codewords_per_block, num_blocks_group1, data_cw_group1, num_blocks_group2, data_cw_group2]
  EC_BLOCKS = {
    ErrorCorrection::Low => [
      [26, 7, 1, 19, 0, 0],        # V1
      [44, 10, 1, 34, 0, 0],       # V2
      [70, 15, 1, 55, 0, 0],       # V3
      [100, 20, 1, 80, 0, 0],      # V4
      [134, 26, 1, 108, 0, 0],     # V5
      [172, 18, 2, 68, 0, 0],      # V6
      [196, 20, 2, 78, 0, 0],      # V7
      [242, 24, 2, 97, 0, 0],      # V8
      [292, 30, 2, 116, 0, 0],     # V9
      [346, 18, 2, 68, 2, 69],     # V10
      [404, 20, 4, 81, 0, 0],      # V11
      [466, 24, 2, 92, 2, 93],     # V12
      [532, 26, 4, 107, 0, 0],     # V13
      [581, 30, 3, 115, 1, 116],   # V14
      [655, 22, 5, 87, 1, 88],     # V15
      [733, 24, 5, 98, 1, 99],     # V16
      [815, 28, 1, 107, 5, 108],   # V17
      [901, 30, 5, 120, 1, 121],   # V18
      [991, 28, 3, 113, 4, 114],   # V19
      [1085, 28, 3, 107, 5, 108],  # V20
      [1156, 28, 4, 116, 4, 117],  # V21
      [1258, 28, 2, 111, 7, 112],  # V22
      [1364, 30, 4, 121, 5, 122],  # V23
      [1474, 30, 6, 117, 4, 118],  # V24
      [1588, 26, 8, 106, 4, 107],  # V25
      [1706, 28, 10, 114, 2, 115], # V26
      [1828, 30, 8, 122, 4, 123],  # V27
      [1921, 30, 3, 117, 10, 118], # V28
      [2051, 30, 7, 116, 7, 117],  # V29
      [2185, 30, 5, 115, 10, 116], # V30
      [2323, 30, 13, 115, 3, 116], # V31
      [2465, 30, 17, 115, 0, 0],   # V32
      [2611, 30, 17, 115, 1, 116], # V33
      [2761, 30, 13, 115, 6, 116], # V34
      [2876, 30, 12, 121, 7, 122], # V35
      [3034, 30, 6, 121, 14, 122], # V36
      [3196, 30, 17, 122, 4, 123], # V37
      [3362, 30, 4, 122, 18, 123], # V38
      [3532, 30, 20, 117, 4, 118], # V39
      [3706, 30, 19, 118, 6, 119], # V40
    ],
    ErrorCorrection::Medium => [
      [26, 10, 1, 16, 0, 0],
      [44, 16, 1, 28, 0, 0],
      [70, 26, 1, 44, 0, 0],
      [100, 18, 2, 32, 0, 0],
      [134, 24, 2, 43, 0, 0],
      [172, 16, 4, 27, 0, 0],
      [196, 18, 4, 31, 0, 0],
      [242, 22, 2, 38, 2, 39],
      [292, 22, 3, 36, 2, 37],
      [346, 26, 4, 43, 1, 44],
      [404, 30, 1, 50, 4, 51],
      [466, 22, 6, 36, 2, 37],
      [532, 22, 8, 37, 1, 38],
      [581, 24, 4, 40, 5, 41],
      [655, 24, 5, 41, 5, 42],
      [733, 28, 7, 45, 3, 46],
      [815, 28, 10, 46, 1, 47],
      [901, 26, 9, 43, 4, 44],
      [991, 26, 3, 44, 11, 45],
      [1085, 26, 3, 41, 13, 42],
      [1156, 26, 17, 42, 0, 0],
      [1258, 28, 17, 46, 0, 0],
      [1364, 28, 4, 47, 14, 48],
      [1474, 28, 6, 45, 14, 46],
      [1588, 28, 8, 47, 13, 48],
      [1706, 28, 19, 46, 4, 47],
      [1828, 28, 22, 45, 3, 46],
      [1921, 28, 3, 45, 23, 46],
      [2051, 28, 21, 45, 7, 46],
      [2185, 28, 19, 47, 10, 48],
      [2323, 28, 2, 46, 29, 47],
      [2465, 28, 10, 46, 23, 47],
      [2611, 28, 14, 46, 21, 47],
      [2761, 28, 14, 46, 23, 47],
      [2876, 28, 12, 47, 26, 48],
      [3034, 28, 6, 47, 34, 48],
      [3196, 28, 29, 46, 14, 47],
      [3362, 28, 13, 46, 32, 47],
      [3532, 28, 40, 47, 7, 48],
      [3706, 28, 18, 47, 31, 48],
    ],
    ErrorCorrection::Quartile => [
      [26, 13, 1, 13, 0, 0],
      [44, 22, 1, 22, 0, 0],
      [70, 18, 2, 17, 0, 0],
      [100, 26, 2, 24, 0, 0],
      [134, 18, 2, 15, 2, 16],
      [172, 24, 4, 19, 0, 0],
      [196, 18, 2, 14, 4, 15],
      [242, 22, 4, 18, 2, 19],
      [292, 20, 4, 16, 4, 17],
      [346, 24, 6, 19, 2, 20],
      [404, 28, 4, 22, 4, 23],
      [466, 26, 4, 20, 6, 21],
      [532, 24, 8, 20, 4, 21],
      [581, 20, 11, 16, 5, 17],
      [655, 30, 5, 24, 7, 25],
      [733, 24, 15, 19, 2, 20],
      [815, 28, 1, 22, 15, 23],
      [901, 28, 17, 22, 1, 23],
      [991, 26, 17, 21, 4, 22],
      [1085, 30, 15, 24, 5, 25],
      [1156, 28, 17, 22, 6, 23],
      [1258, 30, 7, 24, 16, 25],
      [1364, 30, 11, 24, 14, 25],
      [1474, 30, 11, 24, 16, 25],
      [1588, 30, 7, 24, 22, 25],
      [1706, 28, 28, 22, 6, 23],
      [1828, 30, 8, 23, 26, 24],
      [1921, 30, 4, 24, 31, 25],
      [2051, 30, 1, 23, 37, 24],
      [2185, 30, 15, 24, 25, 25],
      [2323, 30, 42, 24, 1, 25],
      [2465, 30, 10, 24, 35, 25],
      [2611, 30, 29, 24, 19, 25],
      [2761, 30, 44, 24, 7, 25],
      [2876, 30, 39, 24, 14, 25],
      [3034, 30, 46, 24, 10, 25],
      [3196, 30, 49, 24, 10, 25],
      [3362, 30, 48, 24, 14, 25],
      [3532, 30, 43, 24, 22, 25],
      [3706, 30, 34, 24, 34, 25],
    ],
    ErrorCorrection::High => [
      [26, 17, 1, 9, 0, 0],
      [44, 28, 1, 16, 0, 0],
      [70, 22, 2, 13, 0, 0],
      [100, 16, 4, 9, 0, 0],
      [134, 22, 2, 11, 2, 12],
      [172, 28, 4, 15, 0, 0],
      [196, 26, 4, 13, 1, 14],
      [242, 26, 4, 14, 2, 15],
      [292, 24, 4, 12, 4, 13],
      [346, 28, 6, 15, 2, 16],
      [404, 24, 3, 12, 8, 13],
      [466, 28, 7, 14, 4, 15],
      [532, 22, 12, 11, 4, 12],
      [581, 24, 11, 12, 5, 13],
      [655, 24, 11, 12, 7, 13],
      [733, 30, 3, 15, 13, 16],
      [815, 28, 2, 14, 17, 15],
      [901, 28, 2, 14, 19, 15],
      [991, 26, 9, 13, 16, 14],
      [1085, 28, 15, 15, 10, 16],
      [1156, 30, 19, 16, 6, 17],
      [1258, 24, 34, 13, 0, 0],
      [1364, 30, 16, 15, 14, 16],
      [1474, 30, 30, 16, 2, 17],
      [1588, 30, 22, 15, 13, 16],
      [1706, 30, 33, 16, 4, 17],
      [1828, 30, 12, 15, 28, 16],
      [1921, 30, 11, 15, 31, 16],
      [1828, 30, 19, 15, 26, 16],
      [2185, 30, 23, 15, 25, 16],
      [2323, 30, 23, 15, 28, 16],
      [2465, 30, 19, 15, 35, 16],
      [2611, 30, 11, 15, 46, 16],
      [2761, 30, 59, 16, 1, 17],
      [2876, 30, 22, 15, 41, 16],
      [3034, 30, 2, 15, 64, 16],
      [3196, 30, 24, 15, 46, 16],
      [3362, 30, 42, 15, 32, 16],
      [3532, 30, 10, 15, 67, 16],
      [3706, 30, 20, 15, 61, 16],
    ],
  }

  # Alignment pattern positions for each version
  ALIGNMENT_POSITIONS = [
    [] of Int32,                    # V1
    [6, 18],                        # V2
    [6, 22],                        # V3
    [6, 26],                        # V4
    [6, 30],                        # V5
    [6, 34],                        # V6
    [6, 22, 38],                    # V7
    [6, 24, 42],                    # V8
    [6, 26, 46],                    # V9
    [6, 28, 50],                    # V10
    [6, 30, 54],                    # V11
    [6, 32, 58],                    # V12
    [6, 34, 62],                    # V13
    [6, 26, 46, 66],                # V14
    [6, 26, 48, 70],                # V15
    [6, 26, 50, 74],                # V16
    [6, 30, 54, 78],                # V17
    [6, 30, 56, 82],                # V18
    [6, 30, 58, 86],                # V19
    [6, 34, 62, 90],                # V20
    [6, 28, 50, 72, 94],            # V21
    [6, 26, 50, 74, 98],            # V22
    [6, 30, 54, 78, 102],           # V23
    [6, 28, 54, 80, 106],           # V24
    [6, 32, 58, 84, 110],           # V25
    [6, 30, 58, 86, 114],           # V26
    [6, 34, 62, 90, 118],           # V27
    [6, 26, 50, 74, 98, 122],       # V28
    [6, 30, 54, 78, 102, 126],      # V29
    [6, 26, 52, 78, 104, 130],      # V30
    [6, 30, 56, 82, 108, 134],      # V31
    [6, 34, 60, 86, 112, 138],      # V32
    [6, 30, 58, 86, 114, 142],      # V33
    [6, 34, 62, 90, 118, 146],      # V34
    [6, 30, 54, 78, 102, 126, 150], # V35
    [6, 24, 50, 76, 102, 128, 154], # V36
    [6, 28, 54, 80, 106, 132, 158], # V37
    [6, 32, 58, 84, 110, 136, 162], # V38
    [6, 26, 54, 82, 110, 138, 166], # V39
    [6, 30, 58, 86, 114, 142, 170], # V40
  ]

  class Error < Exception
  end

  # Galois Field GF(2^8) arithmetic for Reed-Solomon encoding
  module GaloisField
    # Generator polynomial: x^8 + x^4 + x^3 + x^2 + 1 (0x11d)
    PRIMITIVE = 0x11d

    # Pre-computed log and antilog tables
    LOG = begin
      log = Array(Int32).new(256, 0)
      antilog = Array(Int32).new(256, 0)
      x = 1
      256.times do |i|
        antilog[i] = x
        log[x] = i if i < 255
        x <<= 1
        x ^= PRIMITIVE if x >= 256
      end
      log[1] = 0
      log
    end

    ANTILOG = begin
      antilog = Array(Int32).new(256, 0)
      x = 1
      256.times do |i|
        antilog[i] = x
        x <<= 1
        x ^= PRIMITIVE if x >= 256
      end
      antilog
    end

    def self.multiply(a : Int32, b : Int32) : Int32
      return 0 if a == 0 || b == 0
      ANTILOG[(LOG[a] + LOG[b]) % 255]
    end

    def self.divide(a : Int32, b : Int32) : Int32
      raise Error.new("Division by zero in GF") if b == 0
      return 0 if a == 0
      ANTILOG[(LOG[a] - LOG[b] + 255) % 255]
    end

    def self.power(a : Int32, n : Int32) : Int32
      return 1 if n == 0
      return 0 if a == 0
      ANTILOG[(LOG[a] * n) % 255]
    end
  end

  # Reed-Solomon encoder for QR codes
  # Uses GF(2^8) with primitive polynomial x^8 + x^4 + x^3 + x^2 + 1 (0x11d)
  module ReedSolomon
    # Pre-computed EXP (antilog) table
    EXP = begin
      exp = Array(Int32).new(512, 0)
      x = 1
      256.times do |i|
        exp[i] = x
        x <<= 1
        x ^= 0x11d if x >= 256
      end
      # Extend for easy modulo operations
      256.times { |i| exp[i + 256] = exp[i % 255] }
      exp
    end

    # Pre-computed LOG table
    LOG = begin
      log = Array(Int32).new(256, 0)
      x = 1
      255.times do |i|
        log[x] = i
        x <<= 1
        x ^= 0x11d if x >= 256
      end
      log
    end

    # Multiply two numbers in GF(256)
    def self.gf_mul(a : Int32, b : Int32) : Int32
      return 0 if a == 0 || b == 0
      EXP[(LOG[a] + LOG[b]) % 255]
    end

    # Generate generator polynomial g(x) = (x - α^0)(x - α^1)...(x - α^(n-1))
    # Returns coefficients from highest to lowest degree
    def self.generator_polynomial(nsym : Int32) : Array(Int32)
      g = [1]
      nsym.times do |i|
        # Multiply g by (x + α^i)
        new_g = Array(Int32).new(g.size + 1, 0)
        g.each_with_index do |coef, j|
          new_g[j] ^= coef
          new_g[j + 1] ^= gf_mul(coef, EXP[i])
        end
        g = new_g
      end
      g
    end

    # Generate error correction codewords using polynomial division
    def self.encode(data : Array(UInt8), nsym : Int32) : Array(UInt8)
      gen = generator_polynomial(nsym)

      # msg = data * x^nsym (append nsym zeros)
      msg = data.map(&.to_i32) + Array(Int32).new(nsym, 0)

      # Polynomial division
      data.size.times do |i|
        coef = msg[i]
        if coef != 0
          gen.each_with_index do |g, j|
            msg[i + j] ^= gf_mul(g, coef)
          end
        end
      end

      # Remainder is the EC codewords
      msg[data.size..].map(&.to_u8)
    end
  end

  # QR Code matrix representation
  class Matrix
    getter size : Int32
    getter modules : Array(Array(Bool?))

    def initialize(@size : Int32)
      @modules = Array.new(size) { Array(Bool?).new(size, nil) }
    end

    def [](x : Int32, y : Int32) : Bool?
      @modules[y][x]
    end

    def []=(x : Int32, y : Int32, value : Bool?)
      @modules[y][x] = value
    end

    def set(x : Int32, y : Int32, dark : Bool)
      @modules[y][x] = dark
    end

    def dark?(x : Int32, y : Int32) : Bool
      return false unless @modules[y]?
      @modules[y][x]? == true
    end

    def reserved?(x : Int32, y : Int32) : Bool
      return false unless @modules[y]?
      !@modules[y][x]?.nil?
    end

    def clone : Matrix
      m = Matrix.new(@size)
      @size.times do |y|
        @size.times do |x|
          m[x, y] = @modules[y][x]
        end
      end
      m
    end
  end

  # Encoded QR code ready for rendering
  class Code
    getter version : Int32
    getter error_correction : ErrorCorrection
    getter matrix : Matrix

    def initialize(@version : Int32, @error_correction : ErrorCorrection, @matrix : Matrix)
    end

    # Size of the QR code in modules
    def size : Int32
      @matrix.size
    end

    # Check if module at position is dark
    def dark?(x : Int32, y : Int32) : Bool
      @matrix.dark?(x, y)
    end

    # Render to RGBA image
    def to_image(module_size : Int32 = 10, margin : Int32 = 4,
                 foreground : Color::Color = Color::BLACK,
                 background : Color::Color = Color::WHITE) : RGBA
      total_size = (size + margin * 2) * module_size
      img = RGBA.new(CrImage.rect(0, 0, total_size, total_size))

      # Fill background
      total_size.times do |y|
        total_size.times do |x|
          img.set(x, y, background)
        end
      end

      # Draw modules
      size.times do |qy|
        size.times do |qx|
          if dark?(qx, qy)
            module_size.times do |dy|
              module_size.times do |dx|
                px = (margin + qx) * module_size + dx
                py = (margin + qy) * module_size + dy
                img.set(px, py, foreground)
              end
            end
          end
        end
      end

      img
    end
  end

  # Encoder class
  class Encoder
    @version : Int32
    @ec_level : ErrorCorrection
    @mode : Mode
    @data : String

    def initialize(@data : String, @ec_level : ErrorCorrection = ErrorCorrection::Medium, version : Int32? = nil)
      @mode = detect_mode(@data)
      @version = version || find_version(@data, @mode, @ec_level)
      raise Error.new("Data too long for QR code") if @version > 40
    end

    # Encode data and return QR code
    def encode : Code
      # Encode data to bits
      bits = encode_data

      # Add error correction
      codewords = add_error_correction(bits)

      # Create matrix and place patterns
      matrix = create_matrix(codewords)

      Code.new(@version, @ec_level, matrix)
    end

    private def detect_mode(data : String) : Mode
      return Mode::Numeric if data.chars.all? { |c| c.ascii_number? }
      # Alphanumeric mode only supports uppercase - don't use it if data has lowercase
      return Mode::Alphanumeric if data.chars.all? { |c| ALPHANUMERIC_CHARS.includes?(c) }
      Mode::Byte
    end

    private def find_version(data : String, mode : Mode, ec : ErrorCorrection) : Int32
      data_bits = case mode
                  when Mode::Numeric
                    (data.size // 3) * 10 + [0, 4, 7][data.size % 3]
                  when Mode::Alphanumeric
                    (data.size // 2) * 11 + (data.size.odd? ? 6 : 0)
                  else
                    data.bytesize * 8
                  end

      (1..40).each do |v|
        capacity = data_capacity(v, mode, ec)
        char_count_bits = char_count_indicator_bits(v, mode)
        total_bits = 4 + char_count_bits + data_bits
        return v if total_bits <= capacity * 8
      end
      41 # Too large
    end

    private def data_capacity(version : Int32, mode : Mode, ec : ErrorCorrection) : Int32
      ec_info = EC_BLOCKS[ec][version - 1]
      total = ec_info[0]
      ec_per_block = ec_info[1]
      blocks1 = ec_info[2]
      data1 = ec_info[3]
      blocks2 = ec_info[4]
      data2 = ec_info[5]
      blocks1 * data1 + blocks2 * data2
    end

    private def char_count_indicator_bits(version : Int32, mode : Mode) : Int32
      case mode
      when Mode::Numeric
        version <= 9 ? 10 : (version <= 26 ? 12 : 14)
      when Mode::Alphanumeric
        version <= 9 ? 9 : (version <= 26 ? 11 : 13)
      when Mode::Byte
        version <= 9 ? 8 : 16
      else
        version <= 9 ? 8 : (version <= 26 ? 10 : 12)
      end
    end

    private def encode_data : Array(UInt8)
      bits = BitBuffer.new

      # Mode indicator (4 bits)
      mode_bits = case @mode
                  when Mode::Numeric      then 0b0001
                  when Mode::Alphanumeric then 0b0010
                  when Mode::Byte         then 0b0100
                  else                         0b0100
                  end
      bits.append(mode_bits, 4)

      # Character count indicator
      count_bits = char_count_indicator_bits(@version, @mode)
      char_count = @mode == Mode::Byte ? @data.bytesize : @data.size
      bits.append(char_count, count_bits)

      # Encode data
      case @mode
      when Mode::Numeric
        encode_numeric(bits)
      when Mode::Alphanumeric
        encode_alphanumeric(bits)
      else
        encode_byte(bits)
      end

      # Add terminator
      capacity = data_capacity(@version, @mode, @ec_level) * 8
      terminator_length = [4, capacity - bits.length].min
      bits.append(0, terminator_length)

      # Pad to byte boundary
      while bits.length % 8 != 0
        bits.append(0, 1)
      end

      # Add pad codewords
      pad_bytes = [0xec, 0x11]
      pad_index = 0
      while bits.length < capacity
        bits.append(pad_bytes[pad_index], 8)
        pad_index = 1 - pad_index
      end

      bits.to_bytes
    end

    private def encode_numeric(bits : BitBuffer)
      i = 0
      while i < @data.size
        remaining = @data.size - i
        if remaining >= 3
          num = @data[i, 3].to_i
          bits.append(num, 10)
          i += 3
        elsif remaining == 2
          num = @data[i, 2].to_i
          bits.append(num, 7)
          i += 2
        else
          num = @data[i].to_i
          bits.append(num, 4)
          i += 1
        end
      end
    end

    private def encode_alphanumeric(bits : BitBuffer)
      chars = @data.upcase.chars
      i = 0
      while i < chars.size
        if i + 1 < chars.size
          val = alphanumeric_value(chars[i]) * 45 + alphanumeric_value(chars[i + 1])
          bits.append(val, 11)
          i += 2
        else
          bits.append(alphanumeric_value(chars[i]), 6)
          i += 1
        end
      end
    end

    private def alphanumeric_value(c : Char) : Int32
      idx = ALPHANUMERIC_CHARS.index(c)
      raise Error.new("Invalid alphanumeric character: #{c}") unless idx
      idx
    end

    private def encode_byte(bits : BitBuffer)
      @data.each_byte do |b|
        bits.append(b.to_i, 8)
      end
    end

    private def add_error_correction(data : Array(UInt8)) : Array(UInt8)
      ec_info = EC_BLOCKS[@ec_level][@version - 1]
      ec_per_block = ec_info[1]
      blocks1 = ec_info[2]
      data1 = ec_info[3]
      blocks2 = ec_info[4]
      data2 = ec_info[5]

      # Split data into blocks
      data_blocks = [] of Array(UInt8)
      ec_blocks = [] of Array(UInt8)
      offset = 0

      blocks1.times do
        block = data[offset, data1]
        data_blocks << block
        ec_blocks << ReedSolomon.encode(block, ec_per_block)
        offset += data1
      end

      blocks2.times do
        block = data[offset, data2]
        data_blocks << block
        ec_blocks << ReedSolomon.encode(block, ec_per_block)
        offset += data2
      end

      # Interleave data codewords
      result = [] of UInt8
      max_data = [data1, data2].max
      max_data.times do |i|
        data_blocks.each do |block|
          result << block[i] if i < block.size
        end
      end

      # Interleave EC codewords
      ec_per_block.times do |i|
        ec_blocks.each do |block|
          result << block[i]
        end
      end

      result
    end

    private def create_matrix(codewords : Array(UInt8)) : Matrix
      size = @version * 4 + 17
      matrix = Matrix.new(size)

      # Place finder patterns
      place_finder_pattern(matrix, 0, 0)
      place_finder_pattern(matrix, size - 7, 0)
      place_finder_pattern(matrix, 0, size - 7)

      # Place alignment patterns
      place_alignment_patterns(matrix)

      # Place timing patterns
      place_timing_patterns(matrix)

      # Reserve format info areas
      reserve_format_info(matrix)

      # Reserve version info areas (version >= 7)
      reserve_version_info(matrix) if @version >= 7

      # Place data
      place_data(matrix, codewords)

      # Apply best mask and add format/version info
      best_mask = find_best_mask(matrix)
      apply_mask(matrix, best_mask)
      add_format_info(matrix, best_mask)
      add_version_info(matrix) if @version >= 7

      # Dark module (always dark) - must be set after format info
      matrix.set(8, matrix.size - 8, true)

      matrix
    end

    private def place_finder_pattern(matrix : Matrix, x : Int32, y : Int32)
      (-1..7).each do |dy|
        (-1..7).each do |dx|
          px, py = x + dx, y + dy
          next unless px >= 0 && px < matrix.size && py >= 0 && py < matrix.size

          dark = if dx == -1 || dx == 7 || dy == -1 || dy == 7
                   false # Separator
                 elsif dx == 0 || dx == 6 || dy == 0 || dy == 6
                   true # Outer border
                 elsif dx >= 2 && dx <= 4 && dy >= 2 && dy <= 4
                   true # Inner square
                 else
                   false
                 end
          matrix.set(px, py, dark)
        end
      end
    end

    private def place_alignment_patterns(matrix : Matrix)
      positions = ALIGNMENT_POSITIONS[@version - 1]
      return if positions.empty?

      positions.each do |row|
        positions.each do |col|
          # Skip if overlapping with finder patterns
          next if (row < 9 && col < 9) ||
                  (row < 9 && col >= matrix.size - 9) ||
                  (row >= matrix.size - 9 && col < 9)

          place_alignment_pattern(matrix, col, row)
        end
      end
    end

    private def place_alignment_pattern(matrix : Matrix, cx : Int32, cy : Int32)
      (-2..2).each do |dy|
        (-2..2).each do |dx|
          dark = dx.abs == 2 || dy.abs == 2 || (dx == 0 && dy == 0)
          matrix.set(cx + dx, cy + dy, dark)
        end
      end
    end

    private def place_timing_patterns(matrix : Matrix)
      (8...matrix.size - 8).each do |i|
        dark = i.even?
        matrix.set(i, 6, dark) unless matrix.reserved?(i, 6)
        matrix.set(6, i, dark) unless matrix.reserved?(6, i)
      end
    end

    private def reserve_format_info(matrix : Matrix)
      # Around top-left finder
      9.times do |i|
        matrix.set(i, 8, false) unless matrix.reserved?(i, 8)
        matrix.set(8, i, false) unless matrix.reserved?(8, i)
      end

      # Around top-right finder
      (matrix.size - 8...matrix.size).each do |i|
        matrix.set(i, 8, false)
      end

      # Around bottom-left finder
      (matrix.size - 8...matrix.size).each do |i|
        matrix.set(8, i, false)
      end

      # Dark module
      matrix.set(8, matrix.size - 8, true)
    end

    private def reserve_version_info(matrix : Matrix)
      # Bottom-left
      6.times do |i|
        3.times do |j|
          matrix.set(i, matrix.size - 11 + j, false)
        end
      end

      # Top-right
      6.times do |i|
        3.times do |j|
          matrix.set(matrix.size - 11 + j, i, false)
        end
      end
    end

    private def place_data(matrix : Matrix, codewords : Array(UInt8))
      bit_index = 0
      total_bits = codewords.size * 8

      # Start from bottom-right, move up in 2-column strips
      col = matrix.size - 1
      while col > 0
        col -= 1 if col == 6 # Skip timing pattern column

        going_up = ((matrix.size - 1 - col) // 2).even?
        rows = going_up ? (matrix.size - 1).downto(0) : (0...matrix.size)

        rows.each do |row|
          [col, col - 1].each do |c|
            next if matrix.reserved?(c, row)
            next if bit_index >= total_bits

            byte_idx = bit_index // 8
            bit_pos = 7 - (bit_index % 8)
            dark = ((codewords[byte_idx] >> bit_pos) & 1) == 1
            matrix.set(c, row, dark)
            bit_index += 1
          end
        end

        col -= 2
      end
    end

    private def find_best_mask(matrix : Matrix) : Int32
      best_mask = 0
      best_penalty = Int32::MAX

      8.times do |mask|
        test = matrix.clone
        apply_mask(test, mask)
        penalty = calculate_penalty(test)
        if penalty < best_penalty
          best_penalty = penalty
          best_mask = mask
        end
      end

      best_mask
    end

    private def apply_mask(matrix : Matrix, mask : Int32)
      matrix.size.times do |y|
        matrix.size.times do |x|
          next if is_function_pattern?(x, y, matrix.size)

          invert = case mask
                   when 0 then (x + y).even?
                   when 1 then y.even?
                   when 2 then x % 3 == 0
                   when 3 then (x + y) % 3 == 0
                   when 4 then ((y // 2) + (x // 3)).even?
                   when 5 then (x * y) % 2 + (x * y) % 3 == 0
                   when 6 then ((x * y) % 2 + (x * y) % 3).even?
                   when 7 then ((x + y) % 2 + (x * y) % 3).even?
                   else        false
                   end

          if invert
            current = matrix[x, y]
            matrix[x, y] = !current if !current.nil?
          end
        end
      end
    end

    private def is_function_pattern?(x : Int32, y : Int32, size : Int32) : Bool
      # Finder patterns + separators
      return true if x < 9 && y < 9
      return true if x < 9 && y >= size - 8
      return true if x >= size - 8 && y < 9

      # Timing patterns
      return true if x == 6 || y == 6

      # Format info areas (row 8 and column 8)
      return true if y == 8 && (x < 9 || x >= size - 8)
      return true if x == 8 && (y < 9 || y >= size - 8)

      # Dark module
      return true if x == 8 && y == size - 8

      # Alignment patterns
      positions = ALIGNMENT_POSITIONS[@version - 1]
      positions.each do |row|
        positions.each do |col|
          next if (row < 9 && col < 9) ||
                  (row < 9 && col >= size - 9) ||
                  (row >= size - 9 && col < 9)
          return true if (x - col).abs <= 2 && (y - row).abs <= 2
        end
      end

      # Version info
      if @version >= 7
        return true if x < 6 && y >= size - 11 && y < size - 8
        return true if y < 6 && x >= size - 11 && x < size - 8
      end

      false
    end

    private def calculate_penalty(matrix : Matrix) : Int32
      penalty = 0
      size = matrix.size

      # Rule 1: Consecutive modules in row/column
      size.times do |i|
        row_count = 1
        col_count = 1
        (1...size).each do |j|
          # Row
          if matrix.dark?(j, i) == matrix.dark?(j - 1, i)
            row_count += 1
          else
            penalty += row_count - 2 if row_count >= 5
            row_count = 1
          end
          # Column
          if matrix.dark?(i, j) == matrix.dark?(i, j - 1)
            col_count += 1
          else
            penalty += col_count - 2 if col_count >= 5
            col_count = 1
          end
        end
        penalty += row_count - 2 if row_count >= 5
        penalty += col_count - 2 if col_count >= 5
      end

      # Rule 2: 2x2 blocks
      (0...size - 1).each do |y|
        (0...size - 1).each do |x|
          dark = matrix.dark?(x, y)
          if dark == matrix.dark?(x + 1, y) &&
             dark == matrix.dark?(x, y + 1) &&
             dark == matrix.dark?(x + 1, y + 1)
            penalty += 3
          end
        end
      end

      # Rule 3: Finder-like patterns
      size.times do |i|
        (0..size - 11).each do |j|
          # Row pattern
          if finder_like_pattern?(matrix, j, i, true)
            penalty += 40
          end
          # Column pattern
          if finder_like_pattern?(matrix, i, j, false)
            penalty += 40
          end
        end
      end

      # Rule 4: Dark/light ratio
      dark_count = 0
      size.times do |y|
        size.times do |x|
          dark_count += 1 if matrix.dark?(x, y)
        end
      end
      total = size * size
      percent = (dark_count * 100) // total
      deviation = (percent - 50).abs
      penalty += (deviation // 5) * 10

      penalty
    end

    private def finder_like_pattern?(matrix : Matrix, x : Int32, y : Int32, horizontal : Bool) : Bool
      pattern = [true, false, true, true, true, false, true, false, false, false, false]
      pattern.each_with_index do |dark, i|
        px = horizontal ? x + i : x
        py = horizontal ? y : y + i
        return false if matrix.dark?(px, py) != dark
      end
      true
    end

    private def add_format_info(matrix : Matrix, mask : Int32)
      format = FORMAT_INFO[@ec_level][mask]

      # Format info is 15 bits placed in two locations
      # Bits are placed MSB first (bit 14 at position 0)

      15.times do |i|
        # Read bits from MSB to LSB
        bit = ((format >> (14 - i)) & 1) == 1

        # First copy: around top-left finder pattern
        case i
        when 0..5
          # Row 8, columns 0-5
          matrix.set(i, 8, bit)
        when 6
          # Row 8, column 7 (skip timing at column 6)
          matrix.set(7, 8, bit)
        when 7
          # Row 8, column 8
          matrix.set(8, 8, bit)
        when 8
          # Column 8, row 7 (skip timing at row 6)
          matrix.set(8, 7, bit)
        else # 9..14
          # Column 8, rows 5 down to 0
          matrix.set(8, 14 - i, bit)
        end

        # Second copy: split between bottom-left and top-right
        case i
        when 0..7
          # Bottom-left: column 8, rows (size-1) down to (size-8)
          matrix.set(8, matrix.size - 1 - i, bit)
        else # 8..14
          # Top-right: row 8, columns (size-8) to (size-1)
          matrix.set(matrix.size - 15 + i, 8, bit)
        end
      end
    end

    private def add_version_info(matrix : Matrix)
      return if @version < 7

      info = VERSION_INFO[@version - 7]

      18.times do |i|
        bit = ((info >> i) & 1) == 1
        x = i // 3
        y = i % 3

        # Bottom-left
        matrix.set(x, matrix.size - 11 + y, bit)
        # Top-right
        matrix.set(matrix.size - 11 + y, x, bit)
      end
    end
  end

  # Bit buffer for encoding
  class BitBuffer
    @bits : Array(Int32)

    def initialize
      @bits = [] of Int32
    end

    def append(value : Int32, length : Int32)
      (length - 1).downto(0) do |i|
        @bits << ((value >> i) & 1)
      end
    end

    def length : Int32
      @bits.size
    end

    def to_bytes : Array(UInt8)
      result = [] of UInt8
      (@bits.size // 8).times do |i|
        byte = 0
        8.times do |j|
          byte = (byte << 1) | @bits[i * 8 + j]
        end
        result << byte.to_u8
      end
      result
    end
  end

  # Generate QR code image from text
  def self.generate(data : String, size : Int32 = 300,
                    error_correction : ErrorCorrection = ErrorCorrection::Medium,
                    margin : Int32 = 4,
                    foreground : Color::Color = Color::BLACK,
                    background : Color::Color = Color::WHITE) : RGBA
    code = encode(data, error_correction)
    module_size = size // (code.size + margin * 2)
    module_size = 1 if module_size < 1
    code.to_image(module_size, margin, foreground, background)
  end

  # Generate QR code with a logo/image overlay in the center
  #
  # The logo is placed in the center of the QR code. QR codes have built-in
  # error correction that allows up to 30% of the code to be obscured (with
  # High error correction level). For best results:
  # - Use High error correction level
  # - Keep logo_scale at 0.2-0.25 (20-25% of QR size)
  # - Use a logo with good contrast against the QR background
  #
  # ## Example
  # ```
  # logo = CrImage::PNG.read("logo.png")
  # qr = CrImage::Util::QRCode.generate_with_logo(
  #   "https://example.com",
  #   logo,
  #   size: 400,
  #   error_correction: CrImage::Util::QRCode::ErrorCorrection::High
  # )
  # ```
  def self.generate_with_logo(data : String, logo : Image,
                              size : Int32 = 300,
                              error_correction : ErrorCorrection = ErrorCorrection::High,
                              margin : Int32 = 4,
                              foreground : Color::Color = Color::BLACK,
                              background : Color::Color = Color::WHITE,
                              logo_scale : Float64 = 0.2,
                              logo_border : Int32 = 4) : RGBA
    # Generate base QR code
    qr = generate(data, size, error_correction, margin, foreground, background)

    # Calculate logo size (as percentage of QR code size)
    logo_size = (size * logo_scale).to_i
    logo_size = [logo_size, logo.bounds.width, logo.bounds.height].min

    # Resize logo to fit
    scaled_logo = logo.fit(logo_size, logo_size)

    # Calculate center position
    qr_center_x = qr.bounds.width // 2
    qr_center_y = qr.bounds.height // 2
    logo_x = qr_center_x - scaled_logo.bounds.width // 2
    logo_y = qr_center_y - scaled_logo.bounds.height // 2

    # Draw white border/background behind logo for better contrast
    if logo_border > 0
      border_x = logo_x - logo_border
      border_y = logo_y - logo_border
      border_w = scaled_logo.bounds.width + logo_border * 2
      border_h = scaled_logo.bounds.height + logo_border * 2

      border_h.times do |dy|
        border_w.times do |dx|
          px = border_x + dx
          py = border_y + dy
          if px >= 0 && px < qr.bounds.width && py >= 0 && py < qr.bounds.height
            qr.set(px, py, background)
          end
        end
      end
    end

    # Composite logo onto QR code
    scaled_logo.bounds.height.times do |y|
      scaled_logo.bounds.width.times do |x|
        src = scaled_logo[x, y]
        dst_x = logo_x + x
        dst_y = logo_y + y

        next unless dst_x >= 0 && dst_x < qr.bounds.width
        next unless dst_y >= 0 && dst_y < qr.bounds.height

        # Alpha blending
        alpha = src.a.to_f / 255.0
        if alpha > 0.99
          qr.set(dst_x, dst_y, src)
        elsif alpha > 0.01
          dst = qr[dst_x, dst_y]
          blended = Color::RGBA.new(
            ((src.r.to_f * alpha + dst.r.to_f * (1 - alpha))).clamp(0, 255).to_u8,
            ((src.g.to_f * alpha + dst.g.to_f * (1 - alpha))).clamp(0, 255).to_u8,
            ((src.b.to_f * alpha + dst.b.to_f * (1 - alpha))).clamp(0, 255).to_u8,
            255_u8
          )
          qr.set(dst_x, dst_y, blended)
        end
      end
    end

    qr
  end

  # Encode data to QR code
  def self.encode(data : String, error_correction : ErrorCorrection = ErrorCorrection::Medium,
                  version : Int32? = nil) : Code
    encoder = Encoder.new(data, error_correction, version)
    encoder.encode
  end
end
