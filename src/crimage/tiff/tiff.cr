require "compress/zlib"

# TIFF module implements Reader and Writer.
# The TIFF specification is at http://partners.adobe.com/public/developer/en/tiff/TIFF6.pdf
module CrImage::TIFF
  extend CrImage::ImageReader

  LE_HEADER = "II\x2A\x00".to_slice # Little-endian header
  BE_HEADER = "MM\x00\x2A".to_slice # Big-endian header

  IFD_LEN = 12 # Length of an IFD entry in bytes

  # Data types (p. 14-16 of the spec)
  enum DataType
    Byte     = 1
    ASCII    = 2
    Short    = 3
    Long     = 4
    Rational = 5
  end

  # Length of one instance of each data type in bytes
  DATA_TYPE_LENGTHS = [0_u32, 1_u32, 1_u32, 2_u32, 4_u32, 8_u32]

  # Tags (see p. 28-41 of the spec)
  enum Tag
    ImageWidth                = 256
    ImageLength               = 257
    BitsPerSample             = 258
    Compression               = 259
    PhotometricInterpretation = 262
    FillOrder                 = 266
    StripOffsets              = 273
    SamplesPerPixel           = 277
    RowsPerStrip              = 278
    StripByteCounts           = 279
    T4Options                 = 292
    T6Options                 = 293
    TileWidth                 = 322
    TileLength                = 323
    TileOffsets               = 324
    TileByteCounts            = 325
    XResolution               = 282
    YResolution               = 283
    ResolutionUnit            = 296
    Predictor                 = 317
    ColorMap                  = 320
    ExtraSamples              = 338
    SampleFormat              = 339
  end

  # Compression types
  enum Compression
    None       =     1
    CCITT      =     2
    G3         =     3
    G4         =     4
    LZW        =     5
    JPEGOld    =     6
    JPEG       =     7
    Deflate    =     8
    PackBits   = 32773
    DeflateOld = 32946
  end

  # Photometric interpretation values
  enum Photometric
    WhiteIsZero = 0
    BlackIsZero = 1
    RGB         = 2
    Paletted    = 3
    TransMask   = 4
    CMYK        = 5
    YCbCr       = 6
    CIELab      = 8
  end

  # Predictor values
  enum Predictor
    None       = 1
    Horizontal = 2
  end

  # Resolution unit values
  enum ResolutionUnit
    None    = 1
    PerInch = 2
    PerCM   = 3
  end

  # Image mode
  enum ImageMode
    Bilevel
    Paletted
    Gray
    GrayInvert
    RGB
    RGBA
    NRGBA
    CMYK
  end

  # Compression type for encoding
  enum CompressionType
    Uncompressed
    Deflate
    LZW
  end

  # read and decode the entire image
  def self.read(path : String) : CrImage::Image
    Reader.read(path)
  end

  def self.read(io : IO) : CrImage::Image
    Reader.read(io)
  end

  # read and decode the configurations like color model, dimensions
  def self.read_config(path : String) : CrImage::Config
    Reader.read_config(path)
  end

  def self.read_config(io : IO) : CrImage::Config
    Reader.read_config(io)
  end

  # write the Image to file in TIFF format
  def self.write(path : String, image : CrImage::Image, compression = CompressionType::Uncompressed) : Nil
    Writer.write(path, image, compression)
  end

  # write the Image to IO in TIFF format
  def self.write(io : IO, image : CrImage::Image, compression = CompressionType::Uncompressed) : Nil
    Writer.write(io, image, compression)
  end

  class FormatError < CrImage::FormatError
  end

  class UnsupportedError < CrImage::UnsupportedError
  end
end

CrImage.register_format("tiff", CrImage::TIFF::LE_HEADER, CrImage::TIFF)
CrImage.register_format("tiff", CrImage::TIFF::BE_HEADER, CrImage::TIFF)

require "./*"
