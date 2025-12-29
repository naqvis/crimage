module CrImage::Util
  # Channel operations for extracting, manipulating, and combining color channels.
  #
  # Provides methods for working with individual R, G, B, A channels as grayscale
  # images, useful for advanced image processing and compositing workflows.
  module Channels
    # Extracts a single channel from an image as a grayscale image.
    #
    # Parameters:
    # - `src` : Source image
    # - `channel` : Channel to extract (:red, :green, :blue, :alpha)
    #
    # Returns: Gray image containing the channel values
    def self.extract(src : Image, channel : Symbol) : Gray
      bounds = src.bounds
      width = bounds.width
      height = bounds.height
      result = CrImage.gray(width, height)

      height.times do |y|
        width.times do |x|
          r, g, b, a = src.at(x + bounds.min.x, y + bounds.min.y).rgba
          value = case channel
                  when :red   then (r >> 8).to_u8
                  when :green then (g >> 8).to_u8
                  when :blue  then (b >> 8).to_u8
                  when :alpha then (a >> 8).to_u8
                  else             raise ArgumentError.new("Unknown channel: #{channel}")
                  end
          result.set(x, y, Color::Gray.new(value))
        end
      end

      result
    end

    # Combines separate channel images into an RGBA image.
    #
    # Parameters:
    # - `red` : Red channel (Gray image)
    # - `green` : Green channel (Gray image)
    # - `blue` : Blue channel (Gray image)
    # - `alpha` : Alpha channel (Gray image, optional - defaults to opaque)
    #
    # Returns: Combined RGBA image
    #
    # Raises: `ArgumentError` if channel dimensions don't match
    def self.combine(red : Gray, green : Gray, blue : Gray, alpha : Gray? = nil) : RGBA
      rb = red.bounds
      gb = green.bounds
      bb = blue.bounds

      unless rb.width == gb.width && rb.width == bb.width &&
             rb.height == gb.height && rb.height == bb.height
        raise ArgumentError.new("Channel dimensions must match")
      end

      if alpha
        ab = alpha.bounds
        unless rb.width == ab.width && rb.height == ab.height
          raise ArgumentError.new("Alpha channel dimensions must match")
        end
      end

      width = rb.width
      height = rb.height
      result = CrImage.rgba(width, height)

      height.times do |y|
        width.times do |x|
          r_val = red.at(x + rb.min.x, y + rb.min.y).as(Color::Gray).y
          g_val = green.at(x + gb.min.x, y + gb.min.y).as(Color::Gray).y
          b_val = blue.at(x + bb.min.x, y + bb.min.y).as(Color::Gray).y
          a_val = alpha ? alpha.at(x + alpha.bounds.min.x, y + alpha.bounds.min.y).as(Color::Gray).y : 255_u8

          result.set(x, y, Color::RGBA.new(r_val, g_val, b_val, a_val))
        end
      end

      result
    end

    # Swaps two channels in an image.
    #
    # Parameters:
    # - `src` : Source image
    # - `ch1` : First channel (:red, :green, :blue)
    # - `ch2` : Second channel (:red, :green, :blue)
    #
    # Returns: New RGBA image with swapped channels
    def self.swap(src : Image, ch1 : Symbol, ch2 : Symbol) : RGBA
      bounds = src.bounds
      width = bounds.width
      height = bounds.height
      result = CrImage.rgba(width, height)

      height.times do |y|
        width.times do |x|
          r, g, b, a = src.at(x + bounds.min.x, y + bounds.min.y).rgba
          r8 = (r >> 8).to_u8
          g8 = (g >> 8).to_u8
          b8 = (b >> 8).to_u8
          a8 = (a >> 8).to_u8

          # Get values for swapping
          val1 = case ch1
                 when :red   then r8
                 when :green then g8
                 when :blue  then b8
                 else             r8
                 end
          val2 = case ch2
                 when :red   then r8
                 when :green then g8
                 when :blue  then b8
                 else             r8
                 end

          # Apply swap
          new_r = ch1 == :red ? val2 : (ch2 == :red ? val1 : r8)
          new_g = ch1 == :green ? val2 : (ch2 == :green ? val1 : g8)
          new_b = ch1 == :blue ? val2 : (ch2 == :blue ? val1 : b8)

          result.set(x, y, Color::RGBA.new(new_r, new_g, new_b, a8))
        end
      end

      result
    end

    # Applies a function to a specific channel.
    #
    # Parameters:
    # - `src` : Source image
    # - `channel` : Channel to modify (:red, :green, :blue, :alpha)
    # - `&block` : Function that takes channel value (0-255) and returns new value
    #
    # Returns: New RGBA image with modified channel
    def self.map(src : Image, channel : Symbol, &block : UInt8 -> UInt8) : RGBA
      bounds = src.bounds
      width = bounds.width
      height = bounds.height
      result = CrImage.rgba(width, height)

      height.times do |y|
        width.times do |x|
          r, g, b, a = src.at(x + bounds.min.x, y + bounds.min.y).rgba
          r8 = (r >> 8).to_u8
          g8 = (g >> 8).to_u8
          b8 = (b >> 8).to_u8
          a8 = (a >> 8).to_u8

          case channel
          when :red   then r8 = yield r8
          when :green then g8 = yield g8
          when :blue  then b8 = yield b8
          when :alpha then a8 = yield a8
          else             raise ArgumentError.new("Unknown channel: #{channel}")
          end

          result.set(x, y, Color::RGBA.new(r8, g8, b8, a8))
        end
      end

      result
    end

    # Inverts a specific channel.
    #
    # Parameters:
    # - `src` : Source image
    # - `channel` : Channel to invert (:red, :green, :blue, :alpha)
    #
    # Returns: New RGBA image with inverted channel
    def self.invert_channel(src : Image, channel : Symbol) : RGBA
      map(src, channel) { |v| (255_u8 - v) }
    end

    # Sets a channel to a constant value.
    #
    # Parameters:
    # - `src` : Source image
    # - `channel` : Channel to set (:red, :green, :blue, :alpha)
    # - `value` : Value to set (0-255)
    #
    # Returns: New RGBA image with constant channel
    def self.set_channel(src : Image, channel : Symbol, value : UInt8) : RGBA
      map(src, channel) { |_| value }
    end

    # Multiplies a channel by a factor.
    #
    # Parameters:
    # - `src` : Source image
    # - `channel` : Channel to multiply (:red, :green, :blue, :alpha)
    # - `factor` : Multiplication factor (0.0 to any positive value)
    #
    # Returns: New RGBA image with scaled channel
    def self.multiply_channel(src : Image, channel : Symbol, factor : Float64) : RGBA
      map(src, channel) { |v| [(v.to_f64 * factor).round.to_i, 255].min.to_u8 }
    end

    # Splits an image into its R, G, B channels.
    #
    # Parameters:
    # - `src` : Source image
    #
    # Returns: Tuple of (red, green, blue) Gray images
    def self.split_rgb(src : Image) : {Gray, Gray, Gray}
      {extract(src, :red), extract(src, :green), extract(src, :blue)}
    end

    # Splits an image into its R, G, B, A channels.
    #
    # Parameters:
    # - `src` : Source image
    #
    # Returns: Tuple of (red, green, blue, alpha) Gray images
    def self.split_rgba(src : Image) : {Gray, Gray, Gray, Gray}
      {extract(src, :red), extract(src, :green), extract(src, :blue), extract(src, :alpha)}
    end
  end
end

module CrImage
  module Image
    # Extracts a single channel as a grayscale image.
    def extract_channel(channel : Symbol) : Gray
      Util::Channels.extract(self, channel)
    end

    # Swaps two color channels.
    def swap_channels(ch1 : Symbol, ch2 : Symbol) : RGBA
      Util::Channels.swap(self, ch1, ch2)
    end

    # Inverts a specific channel.
    def invert_channel(channel : Symbol) : RGBA
      Util::Channels.invert_channel(self, channel)
    end

    # Sets a channel to a constant value.
    def set_channel(channel : Symbol, value : UInt8) : RGBA
      Util::Channels.set_channel(self, channel, value)
    end

    # Multiplies a channel by a factor.
    def multiply_channel(channel : Symbol, factor : Float64) : RGBA
      Util::Channels.multiply_channel(self, channel, factor)
    end

    # Splits into R, G, B channels.
    def split_rgb : {Gray, Gray, Gray}
      Util::Channels.split_rgb(self)
    end

    # Splits into R, G, B, A channels.
    def split_rgba : {Gray, Gray, Gray, Gray}
      Util::Channels.split_rgba(self)
    end
  end
end
