require "./color/color"
require "./geom"

module CrImage
  # Black is an opaque black uniform image.
  BLACK = Uniform.new(Color::BLACK)
  # White is an opaque white uniform image.
  WHITE = Uniform.new(Color::WHITE)
  # Transparent is a fully transparent uniform image.
  TRANSPARENT = Uniform.new(Color::TRANSPARENT)
  # Opaque is a fully opaque uniform image.
  OPAQUE = Uniform.new(Color::OPAQUE)

  # Config holds an image's color model and dimensions.
  #
  # Used by `read_config` methods to get image metadata without
  # decoding the entire image, which is faster and uses less memory.
  #
  # Example:
  # ```
  # config = CrImage.read_config("large_image.png")
  # puts "#{config.width}x#{config.height}"
  # puts config.color_model.name
  # ```
  struct Config
    property color_model : Color::Model
    property width : Int32
    property height : Int32

    def initialize(@color_model, @width, @height)
    end
  end

  class UnknownFormat < Exception
    def initialize
      formats = CrImage.supported_formats.join(",")
      super("Unknown image format. Supported formats are [#{formats}]")
    end

    def initialize(message)
      super(message)
    end
  end

  # `Image` is a finite rectangular grid of `Color::Color` values taken from a color model
  # An `Image` maps every grid square in a Rectangle to a `Color` from a Model.
  # "The pixel at (x, y)" refers to the color of the grid square defined by the points (x, y), (x+1, y), (x+1, y+1) and (x, y+1).
  # A common mistake is assuming that an Image's bounds start at (0, 0).
  # For example, an animated GIF contains a sequence of Images, and each Image after the first typically only holds pixel data
  # for the area that changed, and that area doesn't necessarily start at (0, 0).
  # The correct way to iterate over an Image m's pixels looks like:
  # ```
  # b = m.bounds
  # b.min.y.upto(b.max.y - 1) do |y|
  #   b.min.x.upto(b.max.x - 1) do |x|
  #     do_stuff_with(m[x, y]) # or call `m.at(x,y)`
  #   end
  # end
  # ```
  #
  # Image implementations do not have to be based on an in-memory slice of pixel data.
  # For example, a `CrImage::Uniform` is an Image of enormous bounds and uniform color, whose in-memory representation is simply that color.
  # Typically, though, programs will want an image based on a Slice. Classes types like `CrImage::RGBA` and `CrImage::Gray` etc (Look below into `Including Types`)
  # hold slices of pixel data and implement the Image interface.
  # These types also provide a set(x, y , c : Color::Color) method that allows modifying the image one pixel at a time.
  #
  # ```
  # m = CrImage::RGBA.new(CrImage.rect(0,0,640,480))
  # m[5,5] = Color::RGBA.new(255,0,0,255)) #Or call set method like  `m.set(5,5, Color::RGBA.new(255,0,0,255))`
  # ```
  # If you're reading or writing a lot of pixel data, it can be more efficient, but more complicated, to access these classes `pix` field directly.
  # The slice-based Image implementations also provide a `sub_image` method, which returns an Image backed by the same array.
  # Modifying the pixels of a sub-image will affect the pixels of the original image, analogous to how modifying the contents of a
  # sub-slice s[i0..i1] will affect the contents of the original slice s.
  #
  # ```
  # m0 = CrImage::RGBA.new(CrImage.rect(0, 0, 8, 5))
  # m1 = m0.sub_image(CrImage.rect(1, 2, 5, 5)).as(CrImage::RGBA)
  # pp "#{m0.bounds.width}, #{m1.bounds.width}" # => 8,4
  # pp m0.stride == m1.stride                   # => true
  # ```
  # For low-level code that works on an image's Pix field, be aware that ranging over Pix can affect pixels outside an image's bounds.
  # In the example above, the pixels covered by m1.pix are shaded in blue. Higher-level code, such as the `at` and `set` methods or the `CrImage::Draw package`,
  # will clip their operations to the image's bounds.
  module Image
    # color_model returns the Image's color model
    abstract def color_model : Color::Model
    # bounds returns the domain for which `at` can return non-zero color.
    # The bounds do not necessarily contain the point(0,0).
    abstract def bounds : Rectangle
    # Returns the color of the pixel at (x,y).
    #
    # If coordinates are outside bounds, returns a default color (typically transparent black)
    # rather than raising an exception. This simplifies image processing algorithms.
    #
    # - `at(bounds().min.x, bounds().min.y)` returns the upper-left pixel of the grid.
    # - `at(bounds().max.x-1, bounds().max.y-1)` returns the lower-right one.
    #
    # For explicit nil on out-of-bounds, concrete types provide `at?` method.
    abstract def at(x : Int32, y : Int32) : Color::Color

    # Sets the color of the pixel at (x,y).
    #
    # If the provided coordinates are not within bounds, this method does nothing (no-op).
    # This simplifies drawing operations that may extend beyond image boundaries.
    abstract def set(x : Int32, y : Int32, c : Color::Color)

    # Short form for `at`
    def [](x, y)
      at(x, y)
    end

    # Short form for `set`
    def []=(x, y, color)
      set(x, y, color)
    end
  end

  # PalettedImage is an image whose colors may come from a limited palette.
  # If m is a PalettedImage and m.color_model() returns a Color::Palette p,
  # then m.at(x, y) should be equivalent to p[m.color_index_at(x, y)]. If m's
  # color model is not a Color::Palette, then color_index_at's behavior is
  # undefined.
  module PalettedImage
    include Image

    # `color_index_at` returns the pallete index of the pixel at (x,y).
    abstract def color_index_at(x : Int32, y : Int32) : UInt8
  end

  # :nodoc:
  module ImageReader
    abstract def read(path : String) : CrImage::Image
    abstract def read(io : IO) : CrImage::Image
    abstract def read_config(path : String) : CrImage::Config
    abstract def read_config(io : IO) : CrImage::Config
  end

  extend ImageReader
  private record Format, name : String, magic : Bytes, reader : ImageReader

  @@formats = [] of Format

  # Reads and decodes an entire image from a file.
  #
  # Automatically detects the image format by examining magic bytes.
  # Refer to `supported_formats` for a list of registered decoders.
  #
  # Supported formats: BMP, PNG, JPEG, GIF, TIFF, WebP, ICO
  #
  # Example:
  # ```
  # img = CrImage.read("photo.jpg")
  # puts "#{img.bounds.width}x#{img.bounds.height}"
  # ```
  def self.read(path : String) : CrImage::Image
    File.open(path) do |file|
      read(file)
    end
  end

  # Reads and decodes an entire image from an IO stream.
  #
  # Automatically detects the image format by examining magic bytes.
  # Refer to `supported_formats` for a list of registered decoders.
  #
  # Example:
  # ```
  # File.open("photo.jpg") do |file|
  #   img = CrImage.read(file)
  # end
  # ```
  def self.read(io : IO) : CrImage::Image
    sniff(io).read(io)
  end

  # Reads image metadata without decoding the entire image.
  #
  # This is much faster and uses less memory than `read` when you only
  # need dimensions and color model information.
  #
  # Returns: A `Config` struct with width, height, and color model
  #
  # Example:
  # ```
  # config = CrImage.read_config("large_photo.jpg")
  # puts "Dimensions: #{config.width}x#{config.height}"
  # puts "Color model: #{config.color_model.name}"
  # ```
  def self.read_config(path : String) : CrImage::Config
    File.open(path) do |file|
      read_config(file)
    end
  end

  # Reads image metadata from an IO stream without decoding the entire image.
  #
  # Returns: A `Config` struct with width, height, and color model
  def self.read_config(io : IO) : CrImage::Config
    sniff(io).read_config(io)
  end

  # Registers a new image format decoder.
  #
  # This allows extending the library with custom image format support.
  #
  # Parameters:
  # - `name` : Format name (e.g., "png", "jpeg")
  # - `magic` : Magic bytes for format detection (use '?' for wildcards)
  # - `reader` : ImageReader implementation
  #
  # Example:
  # ```
  # CrImage.register_format("custom", "CUST".to_slice, MyCustomReader.new)
  # ```
  def self.register_format(name : String, magic : Bytes, reader : ImageReader)
    @@formats << Format.new(name, magic, reader)
  end

  # Returns a list of supported image format names.
  #
  # Example:
  # ```
  # puts CrImage.supported_formats
  # # => ["bmp", "gif", "jpeg", "png", "tiff", "webp", "ico"]
  # ```
  def self.supported_formats
    @@formats.map(&.name).uniq!
  end

  private def self.sniff(io)
    @@formats.each do |format|
      b = Bytes.new(format.magic.size)
      n = io.read(b)
      raise UnknownFormat.new("Invalid file format") unless n == format.magic.size
      io.rewind
      return format.reader if match(format.magic, b)
    end
    raise UnknownFormat.new
  end

  private def self.match(magic, b)
    return false unless magic.size == b.size
    b.each_with_index do |byte, idx|
      return false unless magic[idx] == byte || magic[idx] == '?'.ord
    end
    true
  end
end

require "./image/**"
require "./transform"
