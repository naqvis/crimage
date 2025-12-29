module CrImage
  # DecompressionGuard provides protection against decompression bombs
  # (also known as zip bombs or compression bombs).
  #
  # A decompression bomb is a maliciously crafted compressed file that
  # expands to an enormous size when decompressed, potentially exhausting
  # system memory and causing denial of service.
  #
  # This module tracks compressed vs decompressed data ratios and enforces
  # configurable limits to prevent such attacks.
  module DecompressionGuard
    # Default maximum expansion ratio (compressed:decompressed)
    # A 1KB compressed file can expand to at most 1000KB (1MB)
    DEFAULT_MAX_EXPANSION_RATIO = 1000_i64

    # Maximum total decompressed size (500MB by default)
    # This is separate from InputValidation's pixel area limit
    DEFAULT_MAX_DECOMPRESSED_SIZE = 500_000_000_i64

    # Minimum compressed size to start checking ratio (1KB)
    # Files smaller than this are exempt from ratio checks
    MIN_COMPRESSED_SIZE_FOR_CHECK = 1024_i64

    # Configuration for decompression bomb protection
    class Config
      property max_expansion_ratio : Int64
      property max_decompressed_size : Int64
      property min_compressed_size_for_check : Int64

      def initialize(
        @max_expansion_ratio = DEFAULT_MAX_EXPANSION_RATIO,
        @max_decompressed_size = DEFAULT_MAX_DECOMPRESSED_SIZE,
        @min_compressed_size_for_check = MIN_COMPRESSED_SIZE_FOR_CHECK,
      )
      end

      # Create a permissive config for trusted sources
      def self.permissive : Config
        new(
          max_expansion_ratio: 10_000_i64,
          max_decompressed_size: 2_000_000_000_i64
        )
      end

      # Create a strict config for untrusted sources
      def self.strict : Config
        new(
          max_expansion_ratio: 100_i64,
          max_decompressed_size: 100_000_000_i64
        )
      end
    end

    # Global default configuration
    @@default_config = Config.new

    # Get the default configuration
    def self.default_config : Config
      @@default_config
    end

    # Set the default configuration
    def self.default_config=(config : Config)
      @@default_config = config
    end

    # Guard tracks decompression progress and enforces limits
    class Guard
      @config : Config
      @compressed_bytes : Int64
      @decompressed_bytes : Int64
      @format : String

      def initialize(@format : String, @config : Config = DecompressionGuard.default_config)
        @compressed_bytes = 0_i64
        @decompressed_bytes = 0_i64
      end

      # Record compressed data read
      def add_compressed(bytes : Int) : Nil
        @compressed_bytes += bytes.to_i64
      end

      # Record decompressed data produced
      def add_decompressed(bytes : Int) : Nil
        @decompressed_bytes += bytes.to_i64
        check_limits
      end

      # Check if limits are exceeded and raise if so
      def check_limits : Nil
        # Check absolute decompressed size limit
        if @decompressed_bytes > @config.max_decompressed_size
          raise MemoryError.new(
            "Decompression bomb detected in #{@format}: " \
            "decompressed size #{@decompressed_bytes} bytes exceeds limit of #{@config.max_decompressed_size} bytes"
          )
        end

        # Check expansion ratio (only if we've read enough compressed data)
        if @compressed_bytes >= @config.min_compressed_size_for_check
          ratio = @decompressed_bytes.to_f64 / @compressed_bytes.to_f64

          if ratio > @config.max_expansion_ratio
            raise MemoryError.new(
              "Decompression bomb detected in #{@format}: " \
              "expansion ratio #{ratio.round(2)}:1 exceeds limit of #{@config.max_expansion_ratio}:1 " \
              "(#{@compressed_bytes} bytes compressed → #{@decompressed_bytes} bytes decompressed)"
            )
          end
        end
      end

      # Get current statistics
      def stats : {compressed: Int64, decompressed: Int64, ratio: Float64}
        ratio = @compressed_bytes > 0 ? @decompressed_bytes.to_f64 / @compressed_bytes.to_f64 : 0.0
        {
          compressed:   @compressed_bytes,
          decompressed: @decompressed_bytes,
          ratio:        ratio,
        }
      end

      # Validate expected decompressed size against limits
      # Call this when you know the expected size before decompression
      def validate_expected_size(width : Int32, height : Int32, bytes_per_pixel : Int32) : Nil
        expected_size = width.to_i64 * height.to_i64 * bytes_per_pixel.to_i64

        if expected_size > @config.max_decompressed_size
          raise MemoryError.new(
            "Image too large for #{@format}: " \
            "expected decompressed size #{expected_size} bytes (#{width}x#{height}x#{bytes_per_pixel}) " \
            "exceeds limit of #{@config.max_decompressed_size} bytes"
          )
        end
      end
    end

    # Create a new guard for a specific format
    def self.create(format : String, config : Config? = nil) : Guard
      Guard.new(format, config || default_config)
    end

    # Convenience method to wrap IO with decompression tracking
    # Returns a wrapper IO that tracks bytes read
    class TrackingIO < IO
      @io : IO
      @guard : Guard
      @is_compressed : Bool

      def initialize(@io : IO, @guard : Guard, @is_compressed : Bool = true)
      end

      def read(slice : Bytes) : Int32
        n = @io.read(slice)
        if @is_compressed
          @guard.add_compressed(n)
        else
          @guard.add_decompressed(n)
        end
        n
      end

      def write(slice : Bytes) : Nil
        raise IO::Error.new("Cannot write to TrackingIO")
      end

      # Forward other IO methods to underlying IO
      def close : Nil
        @io.close
      end

      def closed? : Bool
        @io.closed?
      end

      def flush : Nil
        @io.flush if @io.responds_to?(:flush)
      end
    end

    # Wrap an IO to track compressed bytes read
    def self.track_compressed(io : IO, guard : Guard) : TrackingIO
      TrackingIO.new(io, guard, is_compressed: true)
    end

    # Wrap an IO to track decompressed bytes written
    def self.track_decompressed(io : IO, guard : Guard) : TrackingIO
      TrackingIO.new(io, guard, is_compressed: false)
    end
  end
end
