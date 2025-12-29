require "../image"

# GIF module implements a GIF image decoder and encoder.
# The GIF specification is at https://www.w3.org/Graphics/GIF/spec-gif89a.txt
module CrImage::GIF
  extend CrImage::ImageReader

  GIF_HEADER_87A = "GIF87a".to_slice
  GIF_HEADER_89A = "GIF89a".to_slice

  # GIF block types
  EXTENSION_INTRODUCER = 0x21_u8
  IMAGE_SEPARATOR      = 0x2C_u8
  TRAILER              = 0x3B_u8
  BLOCK_TERMINATOR     = 0x00_u8

  # Extension labels
  GRAPHIC_CONTROL_LABEL = 0xF9_u8
  COMMENT_LABEL         = 0xFE_u8
  PLAIN_TEXT_LABEL      = 0x01_u8
  APPLICATION_EXTENSION = 0xFF_u8

  # Disposal methods
  enum DisposalMethod
    Unspecified         = 0
    DoNotDispose        = 1
    RestoreToBackground = 2
    RestoreToPrevious   = 3
  end

  # Single frame in an animated GIF
  struct Frame
    property image : CrImage::Image
    property delay : Int32 # Delay in centiseconds (1/100th of a second)
    property disposal : DisposalMethod
    property transparent_index : Int32?

    def initialize(@image, @delay = 0, @disposal = DisposalMethod::Unspecified, @transparent_index = nil)
    end
  end

  # Animated GIF container
  class Animation
    property frames : Array(Frame)
    property width : Int32
    property height : Int32
    property loop_count : Int32 # 0 = infinite loop

    def initialize(@frames = [] of Frame, @width = 0, @height = 0, @loop_count = 0)
    end

    # Get total duration in milliseconds
    def duration : Int32
      frames.sum(&.delay) * 10 # Convert centiseconds to milliseconds
    end
  end

  class FormatError < CrImage::FormatError
  end

  # read and decode the entire image (first frame for animated GIFs)
  def self.read(path : String) : CrImage::Image
    Reader.read(path)
  end

  def self.read(io : IO) : CrImage::Image
    Reader.read(io)
  end

  # read all frames from an animated GIF
  def self.read_animation(path : String) : Animation
    Reader.read_animation(path)
  end

  def self.read_animation(io : IO) : Animation
    Reader.read_animation(io)
  end

  # read and decode the configurations like color model, dimensions
  def self.read_config(path : String) : CrImage::Config
    Reader.read_config(path)
  end

  def self.read_config(io : IO) : CrImage::Config
    Reader.read_config(io)
  end

  # write the Image to file in GIF format
  def self.write(path : String, image : CrImage::Image, transparent_index : Int32? = nil) : Nil
    Writer.write(path, image, transparent_index)
  end

  # write the Image to IO in GIF format
  def self.write(io : IO, image : CrImage::Image, transparent_index : Int32? = nil) : Nil
    Writer.write(io, image, transparent_index)
  end

  # write an animated GIF to file
  def self.write_animation(path : String, animation : Animation) : Nil
    Writer.write_animation(path, animation)
  end

  def self.write_animation(io : IO, animation : Animation) : Nil
    Writer.write_animation(io, animation)
  end
end

CrImage.register_format("gif", CrImage::GIF::GIF_HEADER_89A, CrImage::GIF)

require "./*"
