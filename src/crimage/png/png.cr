require "digest/crc32"

# PNG module implements Reader and Writer.
# The PNG specification is at https://www.w3.org/TR/PNG/.
module CrImage::PNG
  extend CrImage::ImageReader
  PNG_HEADER = "\x89PNG\r\n\x1a\n".to_slice
  # Color type, as per the PNG spec.
  enum ColorType
    Grayscale      = 0
    TrueColor      = 2
    Paletted       = 3
    GrayscaleAlpha = 4
    TrueColorAlpha = 6
  end

  # Combination of color type and bit depth
  enum ColorBit
    Invalid = 0
    G1
    G2
    G4
    G8
    GA8
    TC8
    P1
    P2
    P4
    P8
    TCA8
    G16
    GA16
    TC16
    TCA16

    def paletted?
      P1 <= self && self <= P8
    end
  end

  # Filter type, as per the PNG spec
  enum FilterType
    None    = 0
    Sub
    Up
    Average
    Paeth
  end

  # Interlace Type
  enum InterlaceType
    None  = 0
    Adam7
  end

  # Compression Levels
  enum CompressionLevel
    NoCompression
    Default
    BestCompression
    BestSpeed
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

  # write the Image to file in PNG format
  def self.write(path : String, image : CrImage::Image, level = CompressionLevel::Default) : Nil
    Writer.write(path, image, level)
  end

  # write the Image to IO in PNG format
  def self.write(io : IO, image : CrImage::Image, level = CompressionLevel::Default) : Nil
    Writer.write(io, image, level)
  end

  class FormatError < CrImage::FormatError
  end

  private class CRC
    def initialize
      @crc = 0_u32
    end

    def reset
      @crc = 0_u32
    end

    def write(w : Bytes)
      return if w.empty?
      @crc = Digest::CRC32.update(w, @crc)
    end

    def sum32
      @crc
    end
  end
end

CrImage.register_format("png", CrImage::PNG::PNG_HEADER, CrImage::PNG)

require "./*"
