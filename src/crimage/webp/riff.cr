module CrImage::WEBP
  # FourCC is a four character code used in RIFF containers.
  #
  # FourCC (Four Character Code) identifies chunk types in RIFF files.
  # Examples: "RIFF", "WEBP", "VP8L", "VP8X", "ALPH"
  struct FourCC
    property bytes : StaticArray(UInt8, 4)

    def initialize(@bytes : StaticArray(UInt8, 4))
    end

    # Creates FourCC from string (takes first 4 characters).
    def initialize(str : String)
      @bytes = StaticArray(UInt8, 4).new(0_u8)
      str.bytes.each_with_index do |b, i|
        @bytes[i] = b if i < 4
      end
    end

    def ==(other : FourCC)
      @bytes == other.bytes
    end

    def to_s(io : IO)
      @bytes.each { |b| io << b.chr }
    end
  end

  # RIFF (Resource Interchange File Format) chunk reader for WEBP.
  #
  # Parses RIFF container structure, iterating through chunks and
  # providing access to chunk data. Handles padding bytes and validates
  # chunk boundaries.
  class RIFFReader
    @io : IO
    @total_len : UInt32
    @chunk_len : UInt32
    @padded : Bool
    @buf : Bytes
    @chunk_reader : ChunkReader?

    def initialize(@io : IO, @total_len : UInt32)
      @chunk_len = 0_u32
      @padded = false
      @buf = Bytes.new(8)
      @chunk_reader = nil
    end

    # Reads the next chunk from the RIFF container.
    #
    # Returns tuple of {chunk_id, chunk_length, chunk_data_io} or nil if
    # no more chunks. The IO provides access to chunk data.
    #
    # Raises: `FormatError` if chunk structure is invalid
    def next : Tuple(FourCC, UInt32, IO)?
      # Drain the rest of the previous chunk
      if @chunk_len != 0
        if reader = @chunk_reader
          want = @chunk_len
          got = 0_u32
          begin
            # Copy remaining data to discard buffer
            discard = IO::Memory.new
            copied = IO.copy(reader, discard)
            got = copied.to_u32
          rescue ex
            raise FormatError.new("Error draining chunk: #{ex.message}")
          end

          if got != want
            raise FormatError.new("Short chunk data")
          end
        end
      end
      @chunk_reader = nil

      # Handle padding byte
      if @padded
        if @total_len == 0
          raise FormatError.new("List subchunk too long")
        end
        @total_len -= 1
        begin
          byte = @io.read_byte
          if byte.nil?
            raise FormatError.new("Missing padding byte")
          end
        rescue IO::EOFError
          raise FormatError.new("Missing padding byte")
        end
        @padded = false
      end

      # We are done if we have no more data
      return nil if @total_len == 0

      # Read the next chunk header
      if @total_len < 8
        raise FormatError.new("Short chunk header")
      end
      @total_len -= 8

      begin
        @io.read_fully(@buf)
      rescue IO::EOFError
        raise FormatError.new("Short chunk header")
      end

      chunk_id = FourCC.new(StaticArray[
        @buf[0], @buf[1], @buf[2], @buf[3],
      ])
      @chunk_len = read_u32_le(@buf, 4)

      if @chunk_len > @total_len
        raise FormatError.new("List subchunk too long")
      end

      @padded = (@chunk_len & 1) == 1
      chunk_reader = ChunkReader.new(self)
      @chunk_reader = chunk_reader
      {chunk_id, @chunk_len, chunk_reader}
    end

    # Internal method for ChunkReader to read chunk data.
    #
    # Reads up to buf.size bytes from current chunk, updating counters.
    protected def read_chunk_data(buf : Bytes) : Int32
      return 0 if @chunk_len == 0

      n = [@chunk_len, buf.size.to_u32].min.to_i32
      begin
        bytes_read = @io.read(buf[0, n])
        if bytes_read.nil?
          bytes_read = 0
        end
      rescue ex
        raise ex
      end

      @total_len -= bytes_read.to_u32
      @chunk_len -= bytes_read.to_u32
      bytes_read
    end

    private def read_u32_le(buf : Bytes, offset : Int32) : UInt32
      buf[offset].to_u32 |
        (buf[offset + 1].to_u32 << 8) |
        (buf[offset + 2].to_u32 << 16) |
        (buf[offset + 3].to_u32 << 24)
    end
  end

  # ChunkReader wraps the RIFF reader to provide chunk-scoped reading.
  #
  # Provides an IO interface for reading data from a single RIFF chunk.
  # Automatically limits reads to chunk boundaries.
  class ChunkReader < IO
    @reader : RIFFReader

    def initialize(@reader : RIFFReader)
    end

    def read(slice : Bytes) : Int32
      @reader.read_chunk_data(slice)
    end

    def write(slice : Bytes) : Nil
      raise IO::Error.new("ChunkReader is read-only")
    end
  end

  # Creates a new RIFF reader from IO stream.
  #
  # Reads and validates RIFF header, extracts form type (e.g., "WEBP"),
  # and returns a reader for iterating through chunks.
  #
  # Returns: Tuple of {form_type, riff_reader}
  #
  # Raises: `FormatError` if RIFF header is invalid or missing
  def self.new_riff_reader(io : IO) : Tuple(FourCC, RIFFReader)
    buf = Bytes.new(8)
    begin
      io.read_fully(buf)
    rescue IO::EOFError
      raise FormatError.new("Missing RIFF header")
    end

    # Check RIFF signature
    unless buf[0] == 'R'.ord && buf[1] == 'I'.ord &&
           buf[2] == 'F'.ord && buf[3] == 'F'.ord
      raise FormatError.new("Missing RIFF header")
    end

    # Read chunk length
    chunk_len = buf[4].to_u32 |
                (buf[5].to_u32 << 8) |
                (buf[6].to_u32 << 16) |
                (buf[7].to_u32 << 24)

    raise FormatError.new("Short chunk data") if chunk_len < 4

    # Read form type (4 bytes)
    form_buf = Bytes.new(4)
    begin
      io.read_fully(form_buf)
    rescue IO::EOFError
      raise FormatError.new("Short chunk data")
    end

    form_type = FourCC.new(StaticArray[
      form_buf[0], form_buf[1], form_buf[2], form_buf[3],
    ])

    reader = RIFFReader.new(io, chunk_len - 4)
    {form_type, reader}
  end
end
