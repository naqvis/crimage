module CrImage::EXIF
  # EXIF reader implementation.
  # Parses EXIF data from various sources.
  class Reader
    @data : Bytes
    @byte_order : IO::ByteFormat
    @tiff_offset : Int32

    private def initialize(@data : Bytes)
      @byte_order = IO::ByteFormat::LittleEndian
      @tiff_offset = 0
    end

    # Read EXIF from a file path (auto-detects format).
    def self.read(path : String) : Data?
      return nil unless File.exists?(path)
      File.open(path, "rb") do |file|
        read(file)
      end
    rescue
      nil
    end

    # Read EXIF from an IO stream (auto-detects format).
    def self.read(io : IO) : Data?
      # Read first bytes to detect format
      header = Bytes.new(12)
      bytes_read = io.read(header)
      return nil if bytes_read < 2

      # Detect format and extract EXIF
      if header[0] == 0xFF && header[1] == 0xD8
        # JPEG - seek back and read EXIF from APP1
        io.seek(0)
        read_jpeg(io)
      elsif (header[0..1] == LITTLE_ENDIAN || header[0..1] == BIG_ENDIAN) &&
            bytes_read >= 4
        # TIFF - seek back and read EXIF from IFD
        io.seek(0)
        read_tiff(io)
      elsif bytes_read >= 12 && String.new(header[0, 4]) == "RIFF" &&
            String.new(header[8, 4]) == "WEBP"
        # WebP - seek back and look for EXIF chunk
        io.seek(0)
        read_webp(io)
      else
        nil
      end
    end

    # Read EXIF from raw EXIF data bytes (after Exif\0\0 header).
    def self.read_raw(data : Bytes) : Data?
      return nil if data.size < 8
      reader = new(data)
      reader.parse
    end

    # Read EXIF from JPEG file.
    def self.read_jpeg(io : IO) : Data?
      # Skip SOI marker
      soi = Bytes.new(2)
      io.read_fully(soi)
      return nil unless soi[0] == 0xFF && soi[1] == 0xD8

      # Scan for APP1 marker with EXIF data
      loop do
        marker = Bytes.new(2)
        bytes_read = io.read(marker)
        return nil if bytes_read < 2

        # Handle padding
        while marker[0] == 0xFF && marker[1] == 0xFF
          marker[0] = marker[1]
          b = io.read_byte
          return nil if b.nil?
          marker[1] = b
        end

        return nil unless marker[0] == 0xFF

        marker_type = marker[1]

        # End of image or start of scan - no EXIF found
        return nil if marker_type == 0xD9 || marker_type == 0xDA

        # Read segment length
        len_bytes = Bytes.new(2)
        io.read_fully(len_bytes)
        length = (len_bytes[0].to_u16 << 8) | len_bytes[1].to_u16
        return nil if length < 2

        segment_size = length - 2

        if marker_type == 0xE1 && segment_size >= 6
          # APP1 - check for EXIF signature
          sig = Bytes.new(6)
          io.read_fully(sig)

          if sig == EXIF_SIGNATURE
            # Read EXIF data
            exif_data = Bytes.new(segment_size - 6)
            io.read_fully(exif_data)
            return read_raw(exif_data)
          else
            # Not EXIF, skip rest of segment
            io.skip(segment_size - 6)
          end
        else
          # Skip segment
          io.skip(segment_size)
        end
      end
    end

    # Read EXIF from TIFF file.
    def self.read_tiff(io : IO) : Data?
      # Read entire file (TIFF EXIF is embedded in file structure)
      io.seek(0, IO::Seek::End)
      size = io.pos
      io.seek(0)

      # Limit size to prevent memory issues
      return nil if size > 50 * 1024 * 1024 # 50MB max

      data = Bytes.new(size.to_i32)
      io.read_fully(data)

      read_raw(data)
    end

    # Read EXIF from WebP file.
    def self.read_webp(io : IO) : Data?
      # Read RIFF header
      header = Bytes.new(12)
      io.read_fully(header)

      return nil unless String.new(header[0, 4]) == "RIFF"
      return nil unless String.new(header[8, 4]) == "WEBP"

      file_size = IO::ByteFormat::LittleEndian.decode(UInt32, header[4, 4])
      pos = 12

      # Scan chunks for EXIF
      while pos < file_size + 8
        chunk_header = Bytes.new(8)
        bytes_read = io.read(chunk_header)
        break if bytes_read < 8

        chunk_id = String.new(chunk_header[0, 4])
        chunk_size = IO::ByteFormat::LittleEndian.decode(UInt32, chunk_header[4, 4])

        if chunk_id == "EXIF"
          exif_data = Bytes.new(chunk_size.to_i32)
          io.read_fully(exif_data)

          # WebP EXIF may or may not have the "Exif\0\0" prefix
          if exif_data.size >= 6 && exif_data[0, 6] == EXIF_SIGNATURE
            return read_raw(exif_data[6..])
          else
            return read_raw(exif_data)
          end
        else
          # Skip chunk (with padding for odd sizes)
          skip_size = chunk_size + (chunk_size & 1)
          io.skip(skip_size.to_i32)
        end

        pos += 8 + chunk_size + (chunk_size & 1)
      end

      nil
    end

    # Parse EXIF data from raw bytes.
    protected def parse : Data?
      return nil if @data.size < 8

      # Parse TIFF header
      if @data[0, 2] == LITTLE_ENDIAN
        @byte_order = IO::ByteFormat::LittleEndian
      elsif @data[0, 2] == BIG_ENDIAN
        @byte_order = IO::ByteFormat::BigEndian
      else
        return nil
      end

      # Verify TIFF magic
      magic = read_u16(2)
      return nil unless magic == TIFF_MAGIC

      # Get IFD0 offset
      ifd0_offset = read_u32(4).to_i32
      return nil if ifd0_offset < 8 || ifd0_offset >= @data.size

      result = Data.new

      # Parse IFD0 (main image tags)
      exif_ifd_offset : Int32? = nil
      gps_ifd_offset : Int32? = nil

      parse_ifd(ifd0_offset) do |tag, value|
        case tag
        when Tag::ExifIFDPointer.value
          exif_ifd_offset = value.as_u32.try(&.to_i32)
        when Tag::GPSInfoPointer.value
          gps_ifd_offset = value.as_u32.try(&.to_i32)
        else
          result.tags[tag] = value
        end
      end

      # Parse EXIF sub-IFD
      if offset = exif_ifd_offset
        if offset > 0 && offset < @data.size
          parse_ifd(offset) do |tag, value|
            result.exif_tags[tag] = value
          end
        end
      end

      # Parse GPS sub-IFD
      if offset = gps_ifd_offset
        if offset > 0 && offset < @data.size
          parse_ifd(offset) do |tag, value|
            result.gps_tags[tag] = value
          end
        end
      end

      result
    end

    private def parse_ifd(offset : Int32, &block : UInt16, TagValue ->)
      return if offset < 0 || offset + 2 > @data.size

      num_entries = read_u16(offset)
      return if num_entries == 0 || num_entries > 1000 # Sanity check

      entry_offset = offset + 2

      num_entries.times do |i|
        entry_start = entry_offset + i * IFD_ENTRY_SIZE
        break if entry_start + IFD_ENTRY_SIZE > @data.size

        tag_id = read_u16(entry_start)
        type_id = read_u16(entry_start + 2)
        count = read_u32(entry_start + 4)
        value_offset = entry_start + 8

        # Skip invalid types
        next unless type_id >= 1 && type_id <= 12

        data_type = DataType.from_value(type_id)
        type_size = DATA_TYPE_SIZES[data_type]
        total_size = count * type_size

        # If data doesn't fit in 4 bytes, value_offset contains pointer
        if total_size > 4
          ptr = read_u32(value_offset).to_i32
          next if ptr < 0 || ptr + total_size > @data.size
          value_offset = ptr
        end

        value = read_value(data_type, count, value_offset)
        next if value.nil?

        yield tag_id, value
      end
    end

    private def read_value(type : DataType, count : UInt32, offset : Int32) : TagValue?
      case type
      when .byte?
        if count == 1
          TagValue.new(@data[offset])
        else
          TagValue.new(@data[offset, count.to_i32].to_a)
        end
      when .ascii?
        str = String.new(@data[offset, count.to_i32])
        # Remove null terminator
        str = str.rstrip('\0')
        TagValue.new(str)
      when .short?
        if count == 1
          TagValue.new(read_u16(offset))
        else
          arr = Array(UInt16).new(count.to_i32) do |i|
            read_u16(offset + i * 2)
          end
          TagValue.new(arr.first) # Return first for simplicity
        end
      when .long?
        if count == 1
          TagValue.new(read_u32(offset))
        else
          arr = Array(UInt32).new(count.to_i32) do |i|
            read_u32(offset + i * 4)
          end
          TagValue.new(arr.first)
        end
      when .rational?
        if count == 1
          num = read_u32(offset)
          den = read_u32(offset + 4)
          TagValue.new(Rational.new(num, den))
        else
          arr = Array(Rational).new(count.to_i32) do |i|
            num = read_u32(offset + i * 8)
            den = read_u32(offset + i * 8 + 4)
            Rational.new(num, den)
          end
          TagValue.new(arr)
        end
      when .s_byte?
        TagValue.new(@data[offset])
      when .undefined?
        TagValue.new(@data[offset, count.to_i32].to_a)
      when .s_short?
        TagValue.new(read_i16(offset).to_i32)
      when .s_long?
        TagValue.new(read_i32(offset))
      when .s_rational?
        num = read_i32(offset)
        den = read_i32(offset + 4)
        TagValue.new(SRational.new(num, den))
      else
        nil
      end
    end

    private def read_u16(offset : Int32) : UInt16
      @byte_order.decode(UInt16, @data[offset, 2])
    end

    private def read_i16(offset : Int32) : Int16
      @byte_order.decode(Int16, @data[offset, 2])
    end

    private def read_u32(offset : Int32) : UInt32
      @byte_order.decode(UInt32, @data[offset, 4])
    end

    private def read_i32(offset : Int32) : Int32
      @byte_order.decode(Int32, @data[offset, 4])
    end
  end

  # Module-level convenience methods
  def self.read(path : String) : Data?
    Reader.read(path)
  end

  def self.read(io : IO) : Data?
    Reader.read(io)
  end

  def self.read_jpeg(io : IO) : Data?
    Reader.read_jpeg(io)
  end

  def self.read_tiff(io : IO) : Data?
    Reader.read_tiff(io)
  end

  def self.read_webp(io : IO) : Data?
    Reader.read_webp(io)
  end
end
