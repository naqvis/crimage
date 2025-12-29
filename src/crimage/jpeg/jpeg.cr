require "../image"

# JPEG module implements a JPEG image decoder and encoder.
# The JPEG specification is at https://www.w3.org/Graphics/JPEG/
#
# ## Supported Features
# - Baseline DCT-based JPEG images (SOF0)
# - Grayscale (1 component)
# - YCbCr color space (3 components)
# - CMYK color space (4 components)
# - Standard Huffman tables
# - Quality-based quantization
#
# ## Limitations
# - No arithmetic coding support
# - No hierarchical JPEG support
# - No lossless JPEG support
module CrImage::JPEG
  extend CrImage::ImageReader

  # JPEG magic bytes - Start of Image (SOI) marker
  JPEG_MAGIC = "\xFF\xD8\xFF".to_slice

  # JPEG markers
  enum Marker : UInt8
    SOI  = 0xD8 # Start of Image
    EOI  = 0xD9 # End of Image
    SOS  = 0xDA # Start of Scan
    SOF0 = 0xC0 # Start of Frame (Baseline DCT)
    SOF1 = 0xC1 # Start of Frame (Extended Sequential DCT)
    SOF2 = 0xC2 # Start of Frame (Progressive DCT)
    DHT  = 0xC4 # Define Huffman Table
    DQT  = 0xDB # Define Quantization Table
    APP0 = 0xE0 # Application Segment 0 (JFIF)
    COM  = 0xFE # Comment
  end

  class FormatError < CrImage::FormatError
    def initialize
      super("Invalid or unsupported JPEG image")
    end

    def initialize(message : String)
      super(message)
    end
  end

  # Component information for JPEG image
  class Component
    property id : UInt8
    property h_samp : UInt8      # Horizontal sampling factor
    property v_samp : UInt8      # Vertical sampling factor
    property quant_table : UInt8 # Quantization table index
    property dc_table : UInt8    # DC Huffman table index
    property ac_table : UInt8    # AC Huffman table index
    property dc_pred : Int32     # DC predictor

    def initialize(@id : UInt8, @h_samp : UInt8, @v_samp : UInt8, @quant_table : UInt8)
      @dc_table = 0_u8
      @ac_table = 0_u8
      @dc_pred = 0
    end
  end

  # Quantization table
  struct QuantTable
    property table : Array(UInt16)

    def initialize
      @table = Array(UInt16).new(64, 0_u16)
    end

    def initialize(@table : Array(UInt16))
    end
  end

  # Frame header information
  class FrameHeader
    property width : Int32
    property height : Int32
    property precision : UInt8
    property components : Array(Component)
    property zig_start : Int32
    property zig_end : Int32
    property ah : UInt32
    property al : UInt32
    property scan_components : Array(Int32)
    property num_scan_components : Int32

    def initialize(@width : Int32, @height : Int32, @precision : UInt8)
      @components = [] of Component
      @zig_start = 0
      @zig_end = 63
      @ah = 0_u32
      @al = 0_u32
      @scan_components = [] of Int32
      @num_scan_components = 0
    end
  end

  # Standard JPEG quantization table for luminance (Y component)
  # Based on Annex K of the JPEG specification
  STANDARD_LUMINANCE_QUANT_TABLE = [
    16_u16, 11_u16, 10_u16, 16_u16, 24_u16, 40_u16, 51_u16, 61_u16,
    12_u16, 12_u16, 14_u16, 19_u16, 26_u16, 58_u16, 60_u16, 55_u16,
    14_u16, 13_u16, 16_u16, 24_u16, 40_u16, 57_u16, 69_u16, 56_u16,
    14_u16, 17_u16, 22_u16, 29_u16, 51_u16, 87_u16, 80_u16, 62_u16,
    18_u16, 22_u16, 37_u16, 56_u16, 68_u16, 109_u16, 103_u16, 77_u16,
    24_u16, 35_u16, 55_u16, 64_u16, 81_u16, 104_u16, 113_u16, 92_u16,
    49_u16, 64_u16, 78_u16, 87_u16, 103_u16, 121_u16, 120_u16, 101_u16,
    72_u16, 92_u16, 95_u16, 98_u16, 112_u16, 100_u16, 103_u16, 99_u16,
  ]

  # Standard JPEG quantization table for chrominance (Cb and Cr components)
  # Based on Annex K of the JPEG specification
  STANDARD_CHROMINANCE_QUANT_TABLE = [
    17_u16, 18_u16, 24_u16, 47_u16, 99_u16, 99_u16, 99_u16, 99_u16,
    18_u16, 21_u16, 26_u16, 66_u16, 99_u16, 99_u16, 99_u16, 99_u16,
    24_u16, 26_u16, 56_u16, 99_u16, 99_u16, 99_u16, 99_u16, 99_u16,
    47_u16, 66_u16, 99_u16, 99_u16, 99_u16, 99_u16, 99_u16, 99_u16,
    99_u16, 99_u16, 99_u16, 99_u16, 99_u16, 99_u16, 99_u16, 99_u16,
    99_u16, 99_u16, 99_u16, 99_u16, 99_u16, 99_u16, 99_u16, 99_u16,
    99_u16, 99_u16, 99_u16, 99_u16, 99_u16, 99_u16, 99_u16, 99_u16,
    99_u16, 99_u16, 99_u16, 99_u16, 99_u16, 99_u16, 99_u16, 99_u16,
  ]

  # Scale a quantization table based on quality factor
  # Quality ranges from 1 (worst) to 100 (best)
  # Quality 50 uses the standard tables
  # Quality < 50 increases quantization (lower quality, smaller file)
  # Quality > 50 decreases quantization (higher quality, larger file)
  def self.scale_quant_table(standard_table : Array(UInt16), quality : Int32) : Array(UInt16)
    # Validate quality parameter
    raise FormatError.new("Quality must be between 1 and 100") unless quality >= 1 && quality <= 100

    # Calculate scaling factor based on quality
    # Formula from Independent JPEG Group's implementation
    scale_factor = if quality < 50
                     5000 // quality
                   else
                     200 - quality * 2
                   end

    # Scale each value in the table
    scaled_table = Array(UInt16).new(64) do |i|
      # Apply scaling: (standard_value * scale_factor + 50) / 100
      # Clamp result between 1 and 255
      value = ((standard_table[i].to_i32 * scale_factor + 50) // 100).to_u16
      value = 1_u16 if value < 1_u16
      value = 255_u16 if value > 255_u16
      value
    end

    scaled_table
  end

  # read and decode the entire image
  def self.read(path : String) : CrImage::Image
    Reader.read(path)
  end

  def self.read(io : IO) : CrImage::Image
    Reader.read(io)
  end

  # read and decode the configurations like color model, dimensions and
  # does not decode entire image. This returns CrImage::Config instead.
  def self.read_config(path : String) : CrImage::Config
    Reader.read_config(path)
  end

  def self.read_config(io : IO) : CrImage::Config
    Reader.read_config(io)
  end

  # write the Image to file in JPEG format
  def self.write(path : String, image : CrImage::Image, quality : Int32 = 75) : Nil
    Writer.write(path, image, quality)
  end

  # write the Image to IO in JPEG format
  def self.write(io : IO, image : CrImage::Image, quality : Int32 = 75) : Nil
    Writer.write(io, image, quality)
  end
end

# Register JPEG format with CrImage
CrImage.register_format("jpeg", CrImage::JPEG::JPEG_MAGIC, CrImage::JPEG)

require "./huffman"
require "./reader"
require "./writer"
