require "../image"

# ICO (Windows Icon) format support
#
# ICO is a container format that stores multiple images at different resolutions
# in a single file. This is commonly used for favicons, application icons, and
# Windows desktop shortcuts.
#
# ## Features
#
# - Multi-resolution support (up to 256 images per file)
# - Standard icon sizes: 16x16, 32x32, 48x48, 64x64, 128x128, 256x256
# - Full transparency support via alpha channel
# - BMP and PNG encoding support
# - Automatic format detection
#
# ## Usage
#
# ```
# # Write single icon
# img = CrImage.rgba(32, 32)
# CrImage::ICO.write("icon.ico", img)
#
# # Write multi-resolution icon
# icons = [16, 32, 48].map { |size| CrImage.rgba(size, size) }
# CrImage::ICO.write_multi("favicon.ico", icons)
#
# # Read icon (returns largest)
# icon = CrImage::ICO.read("favicon.ico")
#
# # Read all sizes
# all = CrImage::ICO.read_all("favicon.ico")
# largest = all.largest
# icon_32 = all.find_size(32, 32)
# ```
#
# ## Specification
#
# https://en.wikipedia.org/wiki/ICO_(file_format)
module CrImage::ICO
  # ICO file header magic bytes
  ICO_MAGIC = Bytes[0x00, 0x00, 0x01, 0x00]
  # CUR (cursor) file header magic bytes
  CUR_MAGIC = Bytes[0x00, 0x00, 0x02, 0x00]

  # PNG magic bytes for detecting PNG-encoded icons
  PNG_MAGIC = Bytes[0x89, 0x50, 0x4E, 0x47]

  # Exception raised when ICO file format is invalid or unsupported
  class FormatError < Exception
  end

  # Represents a single icon entry in an ICO file
  #
  # Each ICO file contains a directory of entries describing the images
  # stored within. This struct holds the metadata for one such entry.
  struct IconEntry
    property width : Int32
    property height : Int32
    property color_count : Int32
    property planes : Int32
    property bit_count : Int32
    property size : Int32
    property offset : Int32

    def initialize(@width, @height, @color_count, @planes, @bit_count, @size, @offset)
    end

    # Returns the actual width in pixels
    #
    # In ICO format, a value of 0 represents 256 pixels.
    def actual_width : Int32
      @width == 0 ? 256 : @width
    end

    # Returns the actual height in pixels
    #
    # In ICO format, a value of 0 represents 256 pixels.
    def actual_height : Int32
      @height == 0 ? 256 : @height
    end

    # Returns total pixel count for size comparison
    #
    # Used internally to find largest/smallest icons.
    def pixel_count : Int32
      actual_width * actual_height
    end
  end

  # Represents an ICO file with multiple icon sizes
  #
  # ICO files can contain multiple images at different resolutions.
  # This class provides convenient access to all images and their metadata.
  #
  # ## Example
  #
  # ```
  # icon = CrImage::ICO.read_all("favicon.ico")
  # puts "Contains #{icon.images.size} sizes"
  #
  # # Get specific sizes
  # largest = icon.largest
  # smallest = icon.smallest
  # icon_32 = icon.find_size(32, 32)
  # ```
  class Icon
    # Array of icon entry metadata
    property entries : Array(IconEntry)
    # Array of decoded images corresponding to entries
    property images : Array(CrImage::Image)

    def initialize(@entries, @images)
    end

    # Returns the largest icon by pixel count
    #
    # ```
    # icon = CrImage::ICO.read_all("app.ico")
    # largest = icon.largest # Returns 256x256 if available
    # ```
    def largest : CrImage::Image
      max_index = @entries.each_with_index.max_by { |entry, _| entry.pixel_count }[1]
      @images[max_index]
    end

    # Returns the smallest icon by pixel count
    #
    # ```
    # icon = CrImage::ICO.read_all("favicon.ico")
    # smallest = icon.smallest # Returns 16x16 if available
    # ```
    def smallest : CrImage::Image
      min_index = @entries.each_with_index.min_by { |entry, _| entry.pixel_count }[1]
      @images[min_index]
    end

    # Finds the icon closest to the specified dimensions
    #
    # Returns the image whose total pixel count is closest to the
    # target size. Useful for selecting appropriate icon for display.
    #
    # ```
    # icon = CrImage::ICO.read_all("favicon.ico")
    # # Get icon closest to 40x40 (likely returns 32x32 or 48x48)
    # best_fit = icon.find_size(40, 40)
    # ```
    def find_size(width : Int32, height : Int32) : CrImage::Image?
      target_pixels = width * height
      closest = @entries.each_with_index.min_by do |entry, _|
        (entry.pixel_count - target_pixels).abs
      end
      @images[closest[1]]
    end
  end

  # ImageReader implementation
  extend CrImage::ImageReader

  # Reads an ICO file and returns the largest icon
  #
  # ```
  # icon = CrImage::ICO.read("favicon.ico")
  # puts "#{icon.bounds.width}x#{icon.bounds.height}"
  # ```
  def self.read(path : String) : CrImage::Image
    Reader.read(path)
  end

  # Reads an ICO from IO and returns the largest icon
  #
  # ```
  # File.open("icon.ico", "rb") do |file|
  #   icon = CrImage::ICO.read(file)
  # end
  # ```
  def self.read(io : IO) : CrImage::Image
    Reader.read(io)
  end

  # Reads ICO configuration without decoding full image
  #
  # Returns metadata for the largest icon. Faster than full read
  # when you only need dimensions and color model.
  #
  # ```
  # config = CrImage::ICO.read_config("favicon.ico")
  # puts "#{config.width}x#{config.height}"
  # ```
  def self.read_config(path : String) : CrImage::Config
    Reader.read_config(path)
  end

  # Reads ICO configuration from IO without decoding full image
  def self.read_config(io : IO) : CrImage::Config
    Reader.read_config(io)
  end

  # Reads all icons from an ICO file
  #
  # Returns an `Icon` object containing all images and their metadata.
  # Use this when you need access to multiple resolutions.
  #
  # ```
  # all = CrImage::ICO.read_all("favicon.ico")
  # all.images.each_with_index do |img, i|
  #   puts "Size #{i}: #{img.bounds.width}x#{img.bounds.height}"
  # end
  # ```
  def self.read_all(path : String) : Icon
    Reader.read_all(path)
  end

  # Reads all icons from IO
  def self.read_all(io : IO) : Icon
    Reader.read_all(io)
  end

  # Writes a single image as an ICO file
  #
  # Creates an ICO file containing one icon at the image's size.
  # The image is encoded as 32-bit BMP with alpha channel.
  #
  # ```
  # img = CrImage.rgba(32, 32)
  # # ... draw icon ...
  # CrImage::ICO.write("icon.ico", img)
  # ```
  def self.write(path : String, image : CrImage::Image) : Nil
    Writer.write(path, image)
  end

  # Writes a single image to IO as ICO
  def self.write(io : IO, image : CrImage::Image) : Nil
    Writer.write(io, image)
  end

  # Writes multiple images as a multi-resolution ICO file
  #
  # Creates an ICO file containing multiple icon sizes. This is the
  # recommended format for favicons and application icons.
  #
  # Standard sizes: 16, 32, 48, 64, 128, 256 pixels
  # Maximum: 256 images per file
  #
  # ```
  # icons = [16, 32, 48].map do |size|
  #   img = CrImage.rgba(size, size)
  #   # ... draw icon at this size ...
  #   img
  # end
  # CrImage::ICO.write_multi("favicon.ico", icons)
  # ```
  def self.write_multi(path : String, images : Array(CrImage::Image)) : Nil
    Writer.write_multi(path, images)
  end

  # Writes multiple images to IO as multi-resolution ICO
  def self.write_multi(io : IO, images : Array(CrImage::Image)) : Nil
    Writer.write_multi(io, images)
  end
end

require "./reader"
require "./writer"

# Register ICO format
CrImage.register_format("ico", CrImage::ICO::ICO_MAGIC, CrImage::ICO)
