require "compress/zlib"
require "./truetype/truetype"

# WOFF (Web Open Font Format) support
# WOFF is a compressed wrapper around TrueType/OpenType fonts
# Specification: https://www.w3.org/TR/WOFF/
module FreeType::WOFF
  # WOFF font wrapper that decompresses to TrueType
  class Font
    getter data : Bytes
    @decompressed_data : Bytes?

    def initialize(@data)
      validate_and_decompress
    end

    # Check if data is a WOFF font
    def self.is_woff?(data : Bytes) : Bool
      return false if data.size < 4
      signature = (data[0].to_u32 << 24) | (data[1].to_u32 << 16) |
                  (data[2].to_u32 << 8) | data[3].to_u32
      signature == 0x774F4646 # 'wOFF'
    end

    # Get decompressed TrueType font data
    def truetype_data : Bytes
      @decompressed_data.not_nil!
    end

    # Create a TrueType font from this WOFF font
    def to_truetype : FreeType::TrueType::Font
      FreeType::TrueType::Font.new(truetype_data)
    end

    private def validate_and_decompress
      raise CrImage::FormatError.new("WOFF data too small") if @data.size < 44

      # Verify WOFF signature
      signature = read_u32(0)
      raise CrImage::FormatError.new("Invalid WOFF signature") unless signature == 0x774F4646

      # Read WOFF header
      flavor = read_u32(4)           # Should be 0x00010000 for TrueType or 'OTTO' for CFF
      length = read_u32(8)           # Total WOFF file size
      num_tables = read_u16(12)      # Number of tables
      _reserved = read_u16(14)       # Reserved, must be 0
      total_sfnt_size = read_u32(16) # Uncompressed font size
      _major_version = read_u16(20)
      _minor_version = read_u16(22)
      _meta_offset = read_u32(24)
      _meta_length = read_u32(28)
      _meta_orig_length = read_u32(32)
      _priv_offset = read_u32(36)
      _priv_length = read_u32(40)

      # Validate file size
      raise CrImage::FormatError.new("WOFF length mismatch") if length != @data.size

      # Validate number of tables
      raise CrImage::FormatError.new("Invalid number of tables") if num_tables == 0 || num_tables > 256

      # Calculate table directory size
      table_dir_size = 44 + num_tables * 20
      raise CrImage::FormatError.new("WOFF header extends beyond file") if table_dir_size > @data.size

      # Decompress font data
      decompress_font(flavor, num_tables, total_sfnt_size)
    end

    private def decompress_font(flavor : UInt32, num_tables : UInt16, total_sfnt_size : UInt32)
      # Create output buffer for decompressed TrueType font
      output = Bytes.new(total_sfnt_size)

      # Write TrueType/OpenType header
      write_u32(output, 0, flavor)
      write_u16(output, 4, num_tables)

      # Calculate search range, entry selector, range shift
      max_power = (Math.log2(num_tables).floor.to_i)
      search_range = (1 << max_power) * 16
      entry_selector = max_power
      range_shift = num_tables * 16 - search_range

      write_u16(output, 6, search_range.to_u16)
      write_u16(output, 8, entry_selector.to_u16)
      write_u16(output, 10, range_shift.to_u16)

      # Read and decompress tables
      table_dir_offset = 12
      data_offset = 12 + num_tables * 16

      num_tables.times do |i|
        woff_entry_offset = 44 + i * 20

        tag = @data[woff_entry_offset, 4]
        table_offset = read_u32(woff_entry_offset + 4)
        comp_length = read_u32(woff_entry_offset + 8)
        orig_length = read_u32(woff_entry_offset + 12)
        orig_checksum = read_u32(woff_entry_offset + 16)

        # Validate table offset and length
        raise CrImage::FormatError.new("Table offset out of bounds") if table_offset + comp_length > @data.size

        # Write table directory entry
        tag.each_with_index { |byte, idx| output[table_dir_offset + idx] = byte }
        write_u32(output, table_dir_offset + 4, orig_checksum)
        write_u32(output, table_dir_offset + 8, data_offset.to_u32)
        write_u32(output, table_dir_offset + 12, orig_length)

        # Decompress or copy table data
        if comp_length < orig_length
          # Table is compressed, decompress it
          compressed_data = @data[table_offset, comp_length]
          decompressed = decompress_zlib(compressed_data)

          raise CrImage::FormatError.new("Decompressed size mismatch") if decompressed.size != orig_length

          decompressed.each_with_index { |byte, idx| output[data_offset + idx] = byte }
        else
          # Table is not compressed, copy directly
          orig_length.times { |idx| output[data_offset + idx] = @data[table_offset + idx] }
        end

        # Align to 4-byte boundary
        padded_length = ((orig_length + 3) // 4) * 4
        # Zero out padding bytes
        (orig_length...padded_length).each do |j|
          output[data_offset + j] = 0_u8 if data_offset + j < output.size
        end

        table_dir_offset += 16
        data_offset += padded_length
      end

      @decompressed_data = output
    end

    private def decompress_zlib(data : Bytes) : Bytes
      io = IO::Memory.new(data)
      output = IO::Memory.new

      Compress::Zlib::Reader.open(io) do |zlib|
        IO.copy(zlib, output)
      end

      output.to_slice
    end

    private def read_u16(offset : Int32) : UInt16
      (@data[offset].to_u16 << 8) | @data[offset + 1].to_u16
    end

    private def read_u32(offset : Int32) : UInt32
      (@data[offset].to_u32 << 24) | (@data[offset + 1].to_u32 << 16) |
        (@data[offset + 2].to_u32 << 8) | @data[offset + 3].to_u32
    end

    private def write_u16(buffer : Bytes, offset : Int32, value : UInt16)
      buffer[offset] = (value >> 8).to_u8
      buffer[offset + 1] = (value & 0xFF).to_u8
    end

    private def write_u32(buffer : Bytes, offset : Int32, value : UInt32)
      buffer[offset] = (value >> 24).to_u8
      buffer[offset + 1] = ((value >> 16) & 0xFF).to_u8
      buffer[offset + 2] = ((value >> 8) & 0xFF).to_u8
      buffer[offset + 3] = (value & 0xFF).to_u8
    end
  end

  # Load a WOFF font from file
  def self.load(path : String) : Font
    data = File.read(path).to_slice
    Font.new(data)
  end

  # Load a WOFF font and convert to TrueType
  def self.load_as_truetype(path : String) : FreeType::TrueType::Font
    woff = load(path)
    woff.to_truetype
  end
end
