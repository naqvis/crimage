module CrImage::JPEG
  # JPEG (Joint Photographic Experts Group) image decoder
  #
  # Implements JPEG decoding for baseline and progressive DCT modes.
  # Supports grayscale and YCbCr color spaces with various subsampling ratios.
  class Reader
    @[AlwaysInline]
    private def store_rgba4_simd(dst : UInt32*, p0 : UInt32, p1 : UInt32, p2 : UInt32, p3 : UInt32) : Nil
      packed = StaticArray[p0, p1, p2, p3]
      src = packed.to_unsafe

      {% if flag?(:x86_64) %}
        asm(
          "movdqu ($1), %xmm0
           movdqu %xmm0, ($0)"
                :: "r"(dst), "r"(src)
                : "xmm0", "memory"
                : "volatile"
        )
      {% elsif flag?(:aarch64) %}
        asm(
          "ld1 {v0.16b}, [$1]
           st1 {v0.16b}, [$0]"
                :: "r"(dst), "r"(src)
                : "v0", "memory"
                : "volatile"
        )
      {% else %}
        dst[0] = p0
        dst[1] = p1
        dst[2] = p2
        dst[3] = p3
      {% end %}
    end

    @io : IO
    @frame_header : FrameHeader?
    @quant_tables : Array(QuantTable?)
    @dc_tables : Array(HuffmanTable?)
    @ac_tables : Array(HuffmanTable?)
    @decoded_data : Array(Bytes)?
    @progressive : Bool
    @baseline : Bool
    @prog_coeffs : Array(Slice(Int32)?)
    @eob_run : UInt16
    @saved_marker : UInt8?
    @block_buf : Slice(Int32)
    @idct_buf : Slice(Int32)
    @pixel_buf : Bytes
    @block_nonzero : Slice(Int32)
    @block_nonzero_count : Int32

    private def initialize(@io : IO)
      @frame_header = nil
      @quant_tables = Array(QuantTable?).new(4, nil)
      @dc_tables = Array(HuffmanTable?).new(4, nil)
      @ac_tables = Array(HuffmanTable?).new(4, nil)
      @decoded_data = nil
      @progressive = false
      @baseline = true
      @prog_coeffs = Array(Slice(Int32)?).new(4, nil)
      @eob_run = 0_u16
      @saved_marker = nil
      @block_buf = Slice(Int32).new(64, 0)
      @idct_buf = Slice(Int32).new(64, 0)
      @pixel_buf = Bytes.new(64, 0_u8)
      @block_nonzero = Slice(Int32).new(64, 0)
      @block_nonzero_count = 0
    end

    @[AlwaysInline]
    private def uninitialized_bytes(size : Int32) : Bytes
      Slice.new(GC.malloc_atomic(size).as(UInt8*), size)
    end

    # Read JPEG image from file path
    def self.read(path : String) : CrImage::Image
      data = File.read(path)
      read(IO::Memory.new(data))
    rescue ex : IO::Error
      raise FormatError.new("Failed to read file: #{ex.message}")
    end

    # Read JPEG image from IO stream
    def self.read(io : IO) : CrImage::Image
      reader = new(io)
      reader.do_parse
    rescue ex : FormatError
      raise ex
    rescue ex
      raise FormatError.new("Failed to decode JPEG: #{ex.message}")
    end

    # Read JPEG config from file path
    def self.read_config(path : String) : CrImage::Config
      data = File.read(path)
      read_config(IO::Memory.new(data))
    rescue ex : IO::Error
      raise FormatError.new("Failed to read file: #{ex.message}")
    end

    # Read JPEG config from IO stream
    def self.read_config(io : IO) : CrImage::Config
      reader = new(io)
      reader.do_parse_config
    rescue ex : FormatError
      raise ex
    rescue ex
      raise FormatError.new("Failed to decode JPEG config: #{ex.message}")
    end

    # Parse the JPEG image and return a CrImage::Image
    protected def do_parse : CrImage::Image
      # Validate SOI marker
      check_header

      # Parse segments until we reach EOI (End of Image)
      loop do
        marker = read_marker

        case marker
        when Marker::SOF0.value
          # Start of Frame (Baseline DCT)
          @baseline = true
          @progressive = false
          parse_sof(marker)
        when Marker::SOF2.value
          # Start of Frame (Progressive DCT)
          @baseline = false
          @progressive = true
          parse_sof(marker)
        when Marker::DQT.value
          # Define Quantization Table
          parse_dqt
        when Marker::DHT.value
          # Define Huffman Table
          parse_dht
        when Marker::SOS.value
          # Start of Scan - decode the image data
          parse_sos
          decode_scan
          # For progressive JPEG, continue to next scan
          # For baseline, we're done after one scan
          break unless @progressive
        when Marker::APP0.value
          # Application segment (JFIF)
          parse_app0
        when Marker::COM.value
          # Comment
          skip_marker
        when Marker::EOI.value
          # End of Image
          break
        else
          # Unknown marker - skip it
          # Check if it's an APPn marker (0xE0-0xEF) or other valid marker
          if marker >= 0xE0 && marker <= 0xEF
            skip_marker
          elsif marker >= 0xC0 && marker <= 0xCF
            # Other SOF markers (extended sequential, etc.)
            raise FormatError.new("Unsupported JPEG type (marker 0x#{marker.to_s(16)})")
          else
            skip_marker
          end
        end
      end

      # For progressive JPEG, reconstruct the final image
      if @progressive
        reconstruct_progressive_image
      end

      # Convert color space and return image
      image = ycbcr_to_rgb

      # Verify EOI marker (optional - some JPEGs may not have it)
      begin
        marker = read_marker
        if marker != Marker::EOI.value
          # Not an error, just unexpected
        end
      rescue
        # End of file reached, that's okay
      end

      image
    end

    # Parse only the JPEG headers to extract config
    protected def do_parse_config : CrImage::Config
      # Validate SOI marker
      check_header

      # Parse segments until we find SOF0 (Start of Frame)
      loop do
        marker = read_marker

        case marker
        when Marker::SOF0.value, Marker::SOF2.value
          # Start of Frame - this contains the config we need
          @baseline = marker == Marker::SOF0.value
          @progressive = marker == Marker::SOF2.value
          parse_sof(marker)
          break
        when Marker::DQT.value
          # Define Quantization Table - skip it for config reading
          skip_marker
        when Marker::DHT.value
          # Define Huffman Table - skip it for config reading
          skip_marker
        when Marker::APP0.value
          # Application segment (JFIF) - skip it
          skip_marker
        when Marker::COM.value
          # Comment - skip it
          skip_marker
        when Marker::SOS.value
          # Start of Scan - shouldn't reach here before SOF0
          raise FormatError.new("Unexpected SOS marker before SOF0")
        when Marker::EOI.value
          # End of Image - shouldn't reach here before SOF0
          raise FormatError.new("Unexpected EOI marker before SOF0")
        else
          # Unknown marker - skip it
          # Check if it's an APPn marker (0xE0-0xEF) or other valid marker
          if marker >= 0xE0 && marker <= 0xEF
            skip_marker
          elsif marker >= 0xC0 && marker <= 0xCF
            # Other SOF markers (progressive, etc.)
            raise FormatError.new("Unsupported JPEG type (marker 0x#{marker.to_s(16)})")
          else
            skip_marker
          end
        end
      end

      # Extract config from frame header
      frame = @frame_header
      raise FormatError.new("No frame header found") if frame.nil?

      width = frame.width
      height = frame.height
      num_components = frame.components.size

      # Map component count to appropriate Color::Model
      # 1 component → Grayscale (Gray)
      # 3 components → RGB/YCbCr (RGBA)
      # 4 components → CMYK (RGBA after conversion)
      color_model = case num_components
                    when 1
                      Color.gray_model
                    when 3, 4
                      Color.rgba_model
                    else
                      raise FormatError.new("Unsupported number of components: #{num_components}")
                    end

      CrImage::Config.new(color_model, width, height)
    end

    # Check and validate JPEG SOI marker
    private def check_header : Nil
      # Read first two bytes - should be 0xFF 0xD8 (SOI marker)
      marker1 = @io.read_byte
      marker2 = @io.read_byte

      if marker1.nil? || marker2.nil?
        raise FormatError.new("Invalid JPEG: unexpected end of file")
      end

      if marker1 != 0xFF || marker2 != Marker::SOI.value
        raise FormatError.new("Invalid JPEG: missing SOI marker (expected FF D8, got #{marker1.to_s(16)} #{marker2.to_s(16)})")
      end
    end

    # Read the next marker from the stream
    # Returns the marker byte (without the 0xFF prefix)
    private def read_marker : UInt8
      if marker = @saved_marker
        @saved_marker = nil
        return marker
      end

      # Skip any padding bytes (0xFF)
      loop do
        byte = @io.read_byte
        raise FormatError.new("Unexpected end of file while reading marker") if byte.nil?

        # Found 0xFF, now read the marker byte
        if byte == 0xFF
          marker = @io.read_byte
          raise FormatError.new("Unexpected end of file after 0xFF") if marker.nil?

          # Skip padding 0xFF bytes
          next if marker == 0xFF

          # 0x00 is not a valid marker
          raise FormatError.new("Invalid marker: FF 00") if marker == 0x00

          return marker
        else
          raise FormatError.new("Expected marker (0xFF), got 0x#{byte.to_s(16)}")
        end
      end
    end

    # Skip an unknown or unsupported marker segment
    private def skip_marker : Nil
      # Read the length (2 bytes, big-endian)
      length_high = @io.read_byte
      length_low = @io.read_byte

      if length_high.nil? || length_low.nil?
        raise FormatError.new("Unexpected end of file while reading marker length")
      end

      length = (length_high.to_u16 << 8) | length_low.to_u16

      # Length includes the 2 bytes for the length field itself
      if length < 2
        raise FormatError.new("Invalid marker length: #{length}")
      end

      # Skip the remaining bytes
      bytes_to_skip = length - 2
      @io.skip(bytes_to_skip) if bytes_to_skip > 0
    end

    # Parse APP0 (JFIF) segment - optional, we just skip it for now
    private def parse_app0 : Nil
      skip_marker
    end

    # Parse DQT (Define Quantization Table) segment
    private def parse_dqt : Nil
      # Read length
      length_high = @io.read_byte
      length_low = @io.read_byte
      raise FormatError.new("Unexpected end of file in DQT") if length_high.nil? || length_low.nil?

      length = (length_high.to_u16 << 8) | length_low.to_u16
      length -= 2 # Subtract length field itself

      while length > 0
        # Read table info byte
        info = @io.read_byte
        raise FormatError.new("Unexpected end of file in DQT") if info.nil?
        length -= 1

        # High 4 bits: precision (0 = 8-bit, 1 = 16-bit)
        # Low 4 bits: table index (0-3)
        precision = (info >> 4) & 0x0F
        table_index = info & 0x0F

        raise FormatError.new("Invalid quantization table index: #{table_index}") if table_index > 3
        raise FormatError.new("16-bit quantization tables not supported") if precision != 0

        # Read 64 quantization values
        table = Array(UInt16).new(64) do
          byte = @io.read_byte
          raise FormatError.new("Unexpected end of file in DQT") if byte.nil?
          length -= 1
          byte.to_u16
        end

        @quant_tables[table_index] = QuantTable.new(table)
      end
    end

    # Parse SOF (Start of Frame) segment - handles both baseline and progressive
    private def parse_sof(marker : UInt8) : Nil
      # Read length
      length_high = @io.read_byte
      length_low = @io.read_byte
      raise FormatError.new("Unexpected end of file in SOF0") if length_high.nil? || length_low.nil?

      # Skip length - we read the segment based on its structure
      # length = (length_high.to_u16 << 8) | length_low.to_u16

      # Read precision (should be 8 for baseline)
      precision = @io.read_byte
      raise FormatError.new("JPEG: unexpected end of file while reading SOF0 precision") if precision.nil?
      raise FormatError.new("JPEG: unsupported precision #{precision} bits, only 8-bit baseline JPEG is supported") if precision != 8

      # Read height (2 bytes, big-endian)
      height_high = @io.read_byte
      height_low = @io.read_byte
      raise FormatError.new("Unexpected end of file in SOF0") if height_high.nil? || height_low.nil?
      height = ((height_high.to_u16 << 8) | height_low.to_u16).to_i32

      # Read width (2 bytes, big-endian)
      width_high = @io.read_byte
      width_low = @io.read_byte
      raise FormatError.new("Unexpected end of file in SOF0") if width_high.nil? || width_low.nil?
      width = ((width_high.to_u16 << 8) | width_low.to_u16).to_i32

      raise FormatError.new("JPEG: invalid image dimensions #{width}x#{height}, width and height must be positive") if width <= 0 || height <= 0

      # Read number of components
      num_components = @io.read_byte
      raise FormatError.new("JPEG: unexpected end of file while reading SOF0 component count") if num_components.nil?
      raise FormatError.new("JPEG: invalid number of components #{num_components}, must be 1 (grayscale), 3 (YCbCr), or 4 (CMYK)") if num_components < 1 || num_components > 4

      # Create frame header
      @frame_header = FrameHeader.new(width, height, precision)

      # Read component specifications
      num_components.times do
        # Component ID
        id = @io.read_byte
        raise FormatError.new("Unexpected end of file in SOF0") if id.nil?

        # Sampling factors (high 4 bits: horizontal, low 4 bits: vertical)
        sampling = @io.read_byte
        raise FormatError.new("Unexpected end of file in SOF0") if sampling.nil?
        h_samp = (sampling >> 4) & 0x0F
        v_samp = sampling & 0x0F

        # Quantization table index
        quant_table = @io.read_byte
        raise FormatError.new("JPEG: unexpected end of file while reading SOF0 quantization table index") if quant_table.nil?
        raise FormatError.new("JPEG: invalid quantization table index #{quant_table} for component #{id}, must be 0-3") if quant_table > 3

        component = Component.new(id, h_samp, v_samp, quant_table)
        @frame_header.not_nil!.components << component
      end
    end

    # Parse DHT (Define Huffman Table) segment
    private def parse_dht : Nil
      # Read length
      length_high = @io.read_byte
      length_low = @io.read_byte
      raise FormatError.new("Unexpected end of file in DHT") if length_high.nil? || length_low.nil?

      length = (length_high.to_u16 << 8) | length_low.to_u16
      length -= 2 # Subtract length field itself

      while length > 0
        # Read table info byte
        info = @io.read_byte
        raise FormatError.new("Unexpected end of file in DHT") if info.nil?
        length -= 1

        # High 4 bits: table class (0 = DC, 1 = AC)
        # Low 4 bits: table index (0-3)
        table_class = (info >> 4) & 0x0F
        table_index = info & 0x0F

        raise FormatError.new("Invalid Huffman table index: #{table_index}") if table_index > 3

        # Read 16 bytes of bit counts
        bits = Array(UInt8).new(16) do
          byte = @io.read_byte
          raise FormatError.new("Unexpected end of file in DHT") if byte.nil?
          length -= 1
          byte
        end

        # Calculate total number of values
        num_values = bits.sum

        # Read the values
        values = Array(UInt8).new(num_values) do
          byte = @io.read_byte
          raise FormatError.new("Unexpected end of file in DHT") if byte.nil?
          length -= 1
          byte
        end

        # Create Huffman table
        table = HuffmanTable.new(bits, values)

        # Store in appropriate array
        if table_class == 0
          @dc_tables[table_index] = table
        else
          @ac_tables[table_index] = table
        end
      end
    end

    # Parse SOS (Start of Scan) segment
    private def parse_sos : Nil
      # Read length
      length_high = @io.read_byte
      length_low = @io.read_byte
      raise FormatError.new("Unexpected end of file in SOS") if length_high.nil? || length_low.nil?

      # Read number of components in scan
      num_components = @io.read_byte
      raise FormatError.new("Unexpected end of file in SOS") if num_components.nil?

      frame = @frame_header
      raise FormatError.new("No frame header found before SOS") if frame.nil?

      # For baseline JPEG, num_components must equal frame.components.size
      # For progressive JPEG, it can be less (non-interleaved scans)
      if @baseline && num_components != frame.components.size
        raise FormatError.new("Invalid number of components in SOS: #{num_components}")
      end

      if num_components < 1 || num_components > frame.components.size
        raise FormatError.new("Invalid number of components in SOS: #{num_components}")
      end

      # Track which components are in this scan
      scan_components = Array(Int32).new(num_components, 0)

      # Read component selectors
      num_components.times do |i|
        # Component selector
        selector = @io.read_byte
        raise FormatError.new("Unexpected end of file in SOS") if selector.nil?

        # Find matching component index
        comp_index = -1
        frame.components.each_with_index do |comp, idx|
          if comp.id == selector
            comp_index = idx
            break
          end
        end
        raise FormatError.new("Unknown component ID in SOS: #{selector}") if comp_index < 0

        # Check for repeated component selectors
        if i > 0 && scan_components[0...i].includes?(comp_index)
          raise FormatError.new("Repeated component selector in SOS")
        end

        scan_components[i] = comp_index
        component = frame.components[comp_index]

        # Huffman table selectors (high 4 bits: DC, low 4 bits: AC)
        tables = @io.read_byte
        raise FormatError.new("Unexpected end of file in SOS") if tables.nil?

        dc_table = (tables >> 4) & 0x0F
        ac_table = tables & 0x0F

        raise FormatError.new("Invalid DC table index: #{dc_table}") if dc_table > 3
        raise FormatError.new("Invalid AC table index: #{ac_table}") if ac_table > 3

        # Modify the component directly (works because Component is a class)
        component.dc_table = dc_table
        component.ac_table = ac_table
      end

      # Store scan components in frame for use during decoding
      frame.scan_components = scan_components
      frame.num_scan_components = num_components.to_i32

      # Read spectral selection (start, end) and successive approximation
      # For baseline JPEG, these should be 0, 63, 0
      # For progressive JPEG, these define the scan parameters
      start_spectral = @io.read_byte
      end_spectral = @io.read_byte
      successive = @io.read_byte

      raise FormatError.new("Unexpected end of file in SOS") if start_spectral.nil? || end_spectral.nil? || successive.nil?

      # Store scan parameters in frame header for use during decoding
      frame.zig_start = start_spectral.to_i32
      frame.zig_end = end_spectral.to_i32
      frame.ah = ((successive >> 4) & 0x0F).to_u32
      frame.al = (successive & 0x0F).to_u32

      # Validate progressive parameters
      if @progressive
        if (start_spectral == 0 && end_spectral != 0) || start_spectral > end_spectral || end_spectral >= 64
          raise FormatError.new("JPEG: bad spectral selection bounds #{start_spectral}-#{end_spectral}")
        end
        if start_spectral != 0 && num_components != 1
          raise FormatError.new("JPEG: progressive AC coefficients for more than one component")
        end
        if frame.ah != 0 && frame.ah != frame.al + 1
          raise FormatError.new("JPEG: bad successive approximation values ah=#{frame.ah} al=#{frame.al}")
        end
      else
        # Baseline JPEG must have 0, 63, 0
        if start_spectral != 0 || end_spectral != 63 || successive != 0
          raise FormatError.new("JPEG: invalid spectral selection for baseline (expected 0, 63, 0)")
        end
      end
    end

    # Zigzag order for dequantization
    ZIGZAG = [
      0, 1, 8, 16, 9, 2, 3, 10,
      17, 24, 32, 25, 18, 11, 4, 5,
      12, 19, 26, 33, 40, 48, 41, 34,
      27, 20, 13, 6, 7, 14, 21, 28,
      35, 42, 49, 56, 57, 50, 43, 36,
      29, 22, 15, 23, 30, 37, 44, 51,
      58, 59, 52, 45, 38, 31, 39, 46,
      53, 60, 61, 54, 47, 55, 62, 63,
    ]

    # Decode the scan data (compressed image data)
    private def decode_scan : Nil
      frame = @frame_header
      raise FormatError.new("No frame header") if frame.nil?

      width = frame.width
      height = frame.height
      num_components = frame.components.size

      # Find maximum sampling factors
      max_h_samp = frame.components.max_of(&.h_samp).to_i32
      max_v_samp = frame.components.max_of(&.v_samp).to_i32

      # Calculate MCU dimensions
      mcu_width = max_h_samp * 8
      mcu_height = max_v_samp * 8
      mcu_cols = (width + mcu_width - 1) // mcu_width
      mcu_rows = (height + mcu_height - 1) // mcu_height

      # Allocate storage for decoded components (only for baseline)
      comp_widths = Array(Int32).new(num_components, 0)
      comp_heights = Array(Int32).new(num_components, 0)
      frame.components.each_with_index do |comp, i|
        comp_widths[i] = (width * comp.h_samp + max_h_samp - 1) // max_h_samp
        comp_heights[i] = (height * comp.v_samp + max_v_samp - 1) // max_v_samp
      end

      if !@progressive && @decoded_data.nil?
        @decoded_data = Array.new(num_components) do |i|
          uninitialized_bytes(comp_widths[i] * comp_heights[i])
        end
      end

      # For progressive JPEG, allocate coefficient storage for components in this scan
      if @progressive
        frame.scan_components.each do |comp_idx|
          component = frame.components[comp_idx]
          if @prog_coeffs[comp_idx].nil?
            num_blocks = mcu_cols * mcu_rows * component.h_samp * component.v_samp
            @prog_coeffs[comp_idx] = Slice(Int32).new(num_blocks * 64, 0)
          end
        end
      end

      # Create bit reader for scan data
      bit_reader = BitReader.new(@io)

      # Reset DC predictors for components in this scan
      frame.scan_components.each do |comp_idx|
        frame.components[comp_idx].dc_pred = 0
      end

      if @progressive && frame.num_scan_components == 1
        decode_progressive_single_scan(bit_reader, frame, mcu_cols, mcu_rows, comp_widths, comp_heights)
        bit_reader.finish
        @saved_marker = bit_reader.saved_marker
        return
      end

      if @progressive && frame.num_scan_components > 1 && frame.ah == 0 && frame.zig_start == 0 && frame.zig_end == 0
        decode_progressive_interleaved_dc_scan(bit_reader, frame, mcu_cols, mcu_rows)
        bit_reader.finish
        @saved_marker = bit_reader.saved_marker
        return
      end

      # Decode MCUs
      mcu_rows.times do |mcu_y|
        mcu_cols.times do |mcu_x|
          # Decode each component in the scan
          frame.scan_components.each do |comp_idx|
            component = frame.components[comp_idx]
            hi = component.h_samp.to_i32
            vi = component.v_samp.to_i32
            dc_table = @dc_tables[component.dc_table]
            ac_table = @ac_tables[component.ac_table]
            quant_table = @quant_tables[component.quant_table]

            # Each component may have multiple blocks based on sampling factors
            (hi * vi).times do |j|
              bx = hi * mcu_x + (j % hi)
              by = vi * mcu_y + (j // hi)

              if frame.num_scan_components == 1
                next if bx * 8 >= comp_widths[comp_idx] || by * 8 >= comp_heights[comp_idx]
              end

              if @progressive
                decode_progressive_block(bit_reader, component, comp_idx, bx, by, mcu_cols)
              else
                raise FormatError.new("DC Huffman table #{component.dc_table} not defined") if dc_table.nil?
                raise FormatError.new("AC Huffman table #{component.ac_table} not defined") if ac_table.nil?
                raise FormatError.new("Quantization table #{component.quant_table} not defined") if quant_table.nil?
                decode_mcu(bit_reader, component, bx, by, comp_widths[comp_idx], comp_heights[comp_idx],
                  dc_table, ac_table, quant_table, @decoded_data.not_nil![comp_idx])
              end
            end
          end
        end
      end

      bit_reader.finish
      @saved_marker = bit_reader.saved_marker
    end

    private def decode_progressive_interleaved_dc_scan(bit_reader : BitReader, frame : FrameHeader,
                                                       mcu_cols : Int32, mcu_rows : Int32) : Nil
      frame.scan_components.each do |comp_idx|
        component = frame.components[comp_idx]
        if @prog_coeffs[comp_idx].nil?
          num_blocks = mcu_cols * mcu_rows * component.h_samp * component.v_samp
          @prog_coeffs[comp_idx] = Slice(Int32).new(num_blocks * 64, 0)
        end
      end

      mcu_rows.times do |mcu_y|
        mcu_cols.times do |mcu_x|
          frame.scan_components.each do |comp_idx|
            component = frame.components[comp_idx]
            hi = component.h_samp.to_i32
            vi = component.v_samp.to_i32
            dc_table = @dc_tables[component.dc_table]
            raise FormatError.new("DC Huffman table #{component.dc_table} not defined") if dc_table.nil?
            dc = dc_table.not_nil!
            coeffs = @prog_coeffs[comp_idx]
            raise FormatError.new("Progressive coefficients not allocated") if coeffs.nil?
            coeffs_ptr = coeffs.not_nil!.to_unsafe
            stride = mcu_cols * hi
            dc_pred = component.dc_pred

            (hi * vi).times do |j|
              bx = hi * mcu_x + (j % hi)
              by = vi * mcu_y + (j // hi)
              block = coeffs_ptr + ((by * stride + bx) * 64)

              dc_size = dc.decode(bit_reader)
              dc_diff = 0
              if dc_size > 0
                dc_diff = receive_and_extend(bit_reader, dc_size)
              end
              dc_pred += dc_diff
              block[0] = dc_pred
            end

            component.dc_pred = dc_pred
          end
        end
      end
    end

    private def decode_progressive_single_scan(bit_reader : BitReader, frame : FrameHeader,
                                               mcu_cols : Int32, _mcu_rows : Int32,
                                               comp_widths : Array(Int32), comp_heights : Array(Int32)) : Nil
      comp_idx = frame.scan_components[0]
      component = frame.components[comp_idx]
      hi = component.h_samp.to_i32
      vi = component.v_samp.to_i32
      comp_width = comp_widths[comp_idx]
      comp_height = comp_heights[comp_idx]
      coeffs = @prog_coeffs[comp_idx]
      raise FormatError.new("Progressive coefficients not allocated") if coeffs.nil?
      coeffs = coeffs.not_nil!
      coeffs_ptr = coeffs.to_unsafe
      stride = mcu_cols * hi
      block_rows = (comp_height + 7) // 8
      block_cols = (comp_width + 7) // 8

      zig_start = frame.zig_start
      zig_end = frame.zig_end
      ah = frame.ah
      al = frame.al
      delta = 1_i32 << al
      zigzag = ZIGZAG

      dc_table : HuffmanTable? = nil
      ac_table : HuffmanTable? = nil

      if zig_start == 0
        dc_table = @dc_tables[component.dc_table]
        raise FormatError.new("DC Huffman table #{component.dc_table} not defined") if dc_table.nil?
      end
      if zig_end > 0
        ac_table = @ac_tables[component.ac_table]
        raise FormatError.new("AC Huffman table #{component.ac_table} not defined") if ac_table.nil?
      end

      by = 0
      while by < block_rows
        row_base = by * stride
        bx = 0
        while bx < block_cols
          block = coeffs_ptr + ((row_base + bx) * 64)
          if ah != 0
            if zig_start != 0 || zig_end != 0
              raise FormatError.new("AC table required for AC refinement") if ac_table.nil?
            end
            refine_block(bit_reader, block, ac_table, zig_start, zig_end, delta)
          else
            zig = zig_start
            if zig == 0
              raise FormatError.new("DC table required") if dc_table.nil?
              dc = dc_table.not_nil!
              zig += 1
              dc_size = dc.decode(bit_reader)
              dc_diff = 0
              if dc_size > 0
                dc_diff = receive_and_extend(bit_reader, dc_size)
              end
              component.dc_pred += dc_diff
              block[0] = component.dc_pred << al
            end

            if zig <= zig_end && @eob_run > 0
              @eob_run -= 1
            elsif zig <= zig_end
              raise FormatError.new("AC table required") if ac_table.nil?
              ac = ac_table.not_nil!
              while zig <= zig_end
                rs = ac.decode(bit_reader)
                run = (rs >> 4) & 0x0F
                size = rs & 0x0F

                if size != 0
                  zig += run
                  break if zig > zig_end

                  coeff = receive_and_extend(bit_reader, size)
                  block[zigzag[zig]] = coeff << al
                  zig += 1
                else
                  if run != 0x0F
                    @eob_run = 1_u16 << run
                    if run != 0
                      bits = bit_reader.read_bits(run.to_i32)
                      @eob_run |= bits
                    end
                    @eob_run -= 1
                    break
                  end
                  zig += 16
                end
              end
            end
          end
          bx += 1
        end
        by += 1
      end
    end

    # Decode one 8x8 block for a component
    private def decode_mcu(bit_reader : BitReader, component : Component,
                           block_x : Int32, block_y : Int32,
                           comp_width : Int32, comp_height : Int32,
                           dc_table : HuffmanTable, ac_table : HuffmanTable,
                           quant_table : QuantTable, decoded : Bytes) : Nil
      # Decode DC coefficient
      dc_size = dc_table.decode(bit_reader)
      dc_diff = 0
      if dc_size > 0
        dc_diff = receive_and_extend(bit_reader, dc_size)
      end
      component.dc_pred += dc_diff

      # Initialize block with DC value
      block = @block_buf
      count = @block_nonzero_count
      count.times do |i|
        block[@block_nonzero[i]] = 0
      end
      @block_nonzero_count = 1
      @block_nonzero[0] = 0
      block[0] = component.dc_pred

      # Decode AC coefficients using run-length encoding
      k = 1
      zigzag = ZIGZAG
      while k < 64
        rs = ac_table.decode(bit_reader)

        # rs high 4 bits = run length (number of zeros)
        # rs low 4 bits = size of coefficient
        run = (rs >> 4) & 0x0F
        size = rs & 0x0F

        if size == 0
          if run == 15
            # ZRL: skip 16 zeros
            k += 16
          else
            # EOB: end of block
            break
          end
        else
          # Skip run zeros
          k += run
          if k >= 64
            break
          end

          # Decode coefficient
          coeff = receive_and_extend(bit_reader, size)
          zigzag_idx = zigzag[k]
          block[zigzag_idx] = coeff
          @block_nonzero[@block_nonzero_count] = zigzag_idx
          @block_nonzero_count += 1
          k += 1
        end
      end

      # Apply IDCT
      pixels = @pixel_buf
      IDCT.transform_dequantize_pixels_into(block, quant_table.table, @idct_buf, pixels)

      base_x = block_x * 8
      base_y = block_y * 8

      if base_x + 8 <= comp_width && base_y + 8 <= comp_height
        decoded_ptr = decoded.to_unsafe
        pixels_ptr = pixels.to_unsafe
        8.times do |delta_y|
          src = delta_y * 8
          dst = (base_y + delta_y) * comp_width + base_x
          (decoded_ptr + dst).copy_from(pixels_ptr + src, 8)
        end
        return
      end

      8.times do |delta_y|
        8.times do |delta_x|
          x = base_x + delta_x
          y = base_y + delta_y
          next if x >= comp_width || y >= comp_height

          pixel_value = pixels[delta_y * 8 + delta_x]
          offset = y * comp_width + x
          decoded[offset] = pixel_value
        end
      end
    end

    # Receive and extend a value (JPEG spec Figure F.12)
    @[AlwaysInline]
    private def receive_and_extend(bit_reader : BitReader, size : UInt8) : Int32
      return 0 if size == 0

      value = bit_reader.read_bits(size.to_i32).to_i32
      vt = 1 << (size.to_i32 - 1)
      if value < vt
        value += (-1 << size.to_i32) + 1
      end

      value
    end

    # Decode one 8x8 block for progressive JPEG
    private def decode_progressive_block(bit_reader : BitReader, component : Component,
                                         comp_idx : Int32, block_x : Int32, block_y : Int32,
                                         mcu_cols : Int32) : Nil
      frame = @frame_header.not_nil!

      # Get the coefficient block
      stride = mcu_cols * component.h_samp.to_i32
      block_idx = block_y * stride + block_x
      coeffs = @prog_coeffs[comp_idx]
      raise FormatError.new("Progressive coefficients not allocated") if coeffs.nil?
      block_offset = block_idx * 64
      block = coeffs.to_unsafe + block_offset

      zig_start = frame.zig_start
      zig_end = frame.zig_end
      ah = frame.ah
      al = frame.al

      # Get Huffman tables (only get what we need)
      dc_table : HuffmanTable? = nil
      ac_table : HuffmanTable? = nil

      if zig_start == 0
        dc_table = @dc_tables[component.dc_table]
        raise FormatError.new("DC Huffman table #{component.dc_table} not defined") if dc_table.nil?
      end

      # Need AC table if decoding any AC coefficients (zig_end > 0)
      if zig_end > 0
        ac_table = @ac_tables[component.ac_table]
        raise FormatError.new("AC Huffman table #{component.ac_table} not defined") if ac_table.nil?
      end

      # Successive approximation refinement
      if ah != 0
        # For AC refinement, we need the AC table
        # For DC refinement (zig_start == 0 && zig_end == 0), we don't need it
        if zig_start != 0 || zig_end != 0
          raise FormatError.new("AC table required for AC refinement") if ac_table.nil?
        end
        # Pass ac_table even for DC refinement (it won't be used)
        refine_block(bit_reader, block, ac_table, zig_start, zig_end, 1_i32 << al)
      else
        zig = zig_start
        zigzag = ZIGZAG

        # Decode DC coefficient
        if zig == 0
          raise FormatError.new("DC table required") if dc_table.nil?
          dc_table = dc_table.not_nil!
          zig += 1
          dc_size = dc_table.decode(bit_reader)
          dc_diff = 0
          if dc_size > 0
            dc_diff = receive_and_extend(bit_reader, dc_size)
          end
          component.dc_pred += dc_diff
          block[0] = component.dc_pred << al
        end

        # Decode AC coefficients or handle EOB run
        if zig <= zig_end && @eob_run > 0
          @eob_run -= 1
        elsif zig <= zig_end
          # Decode AC coefficients
          raise FormatError.new("AC table required") if ac_table.nil?
          ac_table = ac_table.not_nil!
          while zig <= zig_end
            rs = ac_table.decode(bit_reader)
            run = (rs >> 4) & 0x0F
            size = rs & 0x0F

            if size != 0
              zig += run
              break if zig > zig_end

              coeff = receive_and_extend(bit_reader, size)
              block[zigzag[zig]] = coeff << al
              zig += 1
            else
              if run != 0x0F
                # EOB - End of Block
                @eob_run = 1_u16 << run
                if run != 0
                  bits = bit_reader.read_bits(run.to_i32)
                  @eob_run |= bits
                end
                @eob_run -= 1
                break
              end
              # ZRL - skip 16 zeros
              zig += 16
            end
          end
        end
      end
    end

    # Refine block for successive approximation (progressive JPEG)
    @[AlwaysInline]
    private def refine_block(bit_reader : BitReader, block : Int32*,
                             h : HuffmanTable?, zig_start : Int32, zig_end : Int32,
                             delta : Int32) : Nil
      # Refining DC component is trivial
      if zig_start == 0
        raise FormatError.new("Invalid zig_end for DC refinement") if zig_end != 0
        bit = bit_reader.read_bit
        if bit != 0
          block[0] |= delta
        end
        return
      end

      # Refining AC components
      raise FormatError.new("Huffman table required for AC refinement") if h.nil?
      h = h.not_nil!

      zig = zig_start
      if @eob_run == 0
        loop do
          break if zig > zig_end

          value = h.decode(bit_reader)
          val0 = (value >> 4) & 0x0F
          val1 = value & 0x0F

          z = 0_i32
          case val1
          when 0
            if val0 != 0x0F
              @eob_run = 1_u16 << val0
              if val0 != 0
                bits = bit_reader.read_bits(val0.to_i32)
                @eob_run |= bits
              end
              break
            end
          when 1
            z = delta
            bit = bit_reader.read_bit
            z = -z if bit == 0
          else
            raise FormatError.new("Unexpected Huffman code in refinement")
          end

          zig = refine_non_zeroes(bit_reader, block, zig, zig_end, val0.to_i32, delta)
          raise FormatError.new("Too many coefficients") if zig > zig_end

          if z != 0
            block[ZIGZAG[zig]] = z
          end

          # Increment zig for next iteration
          zig += 1
        end
      end

      if @eob_run > 0
        @eob_run -= 1
        refine_non_zeroes(bit_reader, block, zig, zig_end, -1, delta)
      end
    end

    # Refine non-zero entries in zig-zag order
    @[AlwaysInline]
    private def refine_non_zeroes(bit_reader : BitReader, block : Int32*,
                                  zig : Int32, zig_end : Int32, nz : Int32,
                                  delta : Int32) : Int32
      current_zig = zig
      zigzag = ZIGZAG
      while current_zig <= zig_end
        u = zigzag[current_zig]
        if block[u] == 0
          if nz == 0
            break
          end
          nz -= 1
          current_zig += 1
          next
        end

        bit = bit_reader.read_bit
        if bit != 0
          if block[u] >= 0
            block[u] += delta
          else
            block[u] -= delta
          end
        end
        current_zig += 1
      end
      current_zig
    end

    # Reconstruct the final image from progressive coefficients
    private def reconstruct_progressive_image : Nil
      frame = @frame_header
      raise FormatError.new("No frame header") if frame.nil?

      width = frame.width
      height = frame.height
      num_components = frame.components.size

      # Find maximum sampling factors
      max_h_samp = frame.components.max_of(&.h_samp).to_i32
      max_v_samp = frame.components.max_of(&.v_samp).to_i32

      mcu_cols = (width + max_h_samp * 8 - 1) // (max_h_samp * 8)

      # Allocate decoded data storage
      @decoded_data = Array.new(num_components) do |i|
        comp = frame.components[i]
        comp_width = (width * comp.h_samp + max_h_samp - 1) // max_h_samp
        comp_height = (height * comp.v_samp + max_v_samp - 1) // max_v_samp
        uninitialized_bytes(comp_width * comp_height)
      end

      # Process each component
      frame.components.each_with_index do |component, comp_idx|
        coeffs = @prog_coeffs[comp_idx]
        next if coeffs.nil?

        # Get quantization table
        quant_table = @quant_tables[component.quant_table]
        raise FormatError.new("Quantization table #{component.quant_table} not defined") if quant_table.nil?

        decoded = @decoded_data.not_nil![comp_idx]
        comp_width = (width * component.h_samp + max_h_samp - 1) // max_h_samp
        comp_height = (height * component.v_samp + max_v_samp - 1) // max_v_samp

        v = 8 * max_v_samp // component.v_samp
        h = 8 * max_h_samp // component.h_samp
        stride = mcu_cols * component.h_samp

        by = 0
        while by * v < height
          bx = 0
          while bx * h < width
            block_idx = by * stride + bx
            block_offset = block_idx * 64
            block = coeffs[block_offset, 64]

            # Apply IDCT
            pixels = @pixel_buf
            IDCT.transform_dequantize_pixels_into(block, quant_table.table, @idct_buf, pixels)

            # Copy to output buffer
            base_x = bx * 8
            base_y = by * 8

            if base_x + 8 <= comp_width && base_y + 8 <= comp_height
              decoded_ptr = decoded.to_unsafe
              pixels_ptr = pixels.to_unsafe
              8.times do |delta_y|
                src = delta_y * 8
                dst = (base_y + delta_y) * comp_width + base_x
                (decoded_ptr + dst).copy_from(pixels_ptr + src, 8)
              end
              bx += 1
              next
            end

            8.times do |delta_y|
              8.times do |delta_x|
                x = base_x + delta_x
                y = base_y + delta_y
                next if x >= comp_width || y >= comp_height

                pixel_value = pixels[delta_y * 8 + delta_x]
                offset = y * comp_width + x
                decoded[offset] = pixel_value
              end
            end

            bx += 1
          end
          by += 1
        end
      end
    end

    # Convert YCbCr to RGB and create output image
    private def ycbcr_to_rgb : CrImage::Image
      frame = @frame_header
      raise FormatError.new("No frame header") if frame.nil?

      decoded = @decoded_data
      raise FormatError.new("No decoded data") if decoded.nil?

      width = frame.width
      height = frame.height
      num_components = frame.components.size

      # Handle grayscale images (1 component)
      if num_components == 1
        rect = CrImage.rect(0, 0, width, height)
        gray_img = CrImage::Gray.new(uninitialized_bytes(width * height), width, rect)
        gray_img.pix.copy_from(decoded[0].to_unsafe, decoded[0].size)

        return gray_img
      end

      # Handle YCbCr images (3 components) - convert to RGBA
      if num_components == 3
        rect = CrImage.rect(0, 0, width, height)
        rgba_img = CrImage::RGBA.new(uninitialized_bytes(width * height * 4), width * 4, rect)

        y_data = decoded[0]
        cb_data = decoded[1]
        cr_data = decoded[2]
        pix = rgba_img.pix
        y_ptr = y_data.to_unsafe
        cb_ptr = cb_data.to_unsafe
        cr_ptr = cr_data.to_unsafe
        pix_ptr = pix.to_unsafe
        pix32 = pix_ptr.as(UInt32*)

        # Get sampling factors
        cb_comp = frame.components[1]
        cr_comp = frame.components[2]
        yy_table = CrImage::Color::YCBCR_YY1_TABLE
        cb_b_table = CrImage::Color::YCBCR_CB_B_TABLE
        cr_r_table = CrImage::Color::YCBCR_CR_R_TABLE
        cb_g_table = CrImage::Color::YCBCR_CB_G_TABLE
        cr_g_table = CrImage::Color::YCBCR_CR_G_TABLE

        max_h_samp = frame.components.max_of(&.h_samp).to_i32
        max_v_samp = frame.components.max_of(&.v_samp).to_i32

        cb_width = (width * cb_comp.h_samp + max_h_samp - 1) // max_h_samp
        cr_width = (width * cr_comp.h_samp + max_h_samp - 1) // max_h_samp

        if cb_comp.h_samp == cr_comp.h_samp && cb_comp.v_samp == cr_comp.v_samp
          h_ratio = max_h_samp // cb_comp.h_samp
          v_ratio = max_v_samp // cb_comp.v_samp

          if h_ratio == 2 && v_ratio == 2
            if width.even? && height.even?
              y = 0
              while y < height
                y_row0_ptr = y_ptr + (y * width)
                y_row1_ptr = y_row0_ptr + width
                out_row0 = pix32 + (y * width)
                out_row1 = out_row0 + width
                cb_row_ptr = cb_ptr + ((y >> 1) * cb_width)
                cr_row_ptr = cr_ptr + ((y >> 1) * cb_width)

                x = 0
                simd_width = width & ~3
                while x < simd_width
                  chroma = x >> 1
                  cb = cb_row_ptr[chroma]
                  cr = cr_row_ptr[chroma]
                  r_bias = cr_r_table[cr]
                  g_bias = -cb_g_table[cb] - cr_g_table[cr]
                  b_bias = cb_b_table[cb]

                  yy1 = yy_table[y_row0_ptr[x]]
                  r = CrImage::Color.clamp_ycbcr_8bit(yy1 + r_bias)
                  g = CrImage::Color.clamp_ycbcr_8bit(yy1 + g_bias)
                  b = CrImage::Color.clamp_ycbcr_8bit(yy1 + b_bias)
                  p00 = 0xFF000000_u32 | (b.to_u32 << 16) | (g.to_u32 << 8) | r.to_u32

                  yy1 = yy_table[y_row0_ptr[x + 1]]
                  r = CrImage::Color.clamp_ycbcr_8bit(yy1 + r_bias)
                  g = CrImage::Color.clamp_ycbcr_8bit(yy1 + g_bias)
                  b = CrImage::Color.clamp_ycbcr_8bit(yy1 + b_bias)
                  p01 = 0xFF000000_u32 | (b.to_u32 << 16) | (g.to_u32 << 8) | r.to_u32

                  yy1 = yy_table[y_row1_ptr[x]]
                  r = CrImage::Color.clamp_ycbcr_8bit(yy1 + r_bias)
                  g = CrImage::Color.clamp_ycbcr_8bit(yy1 + g_bias)
                  b = CrImage::Color.clamp_ycbcr_8bit(yy1 + b_bias)
                  q00 = 0xFF000000_u32 | (b.to_u32 << 16) | (g.to_u32 << 8) | r.to_u32

                  yy1 = yy_table[y_row1_ptr[x + 1]]
                  r = CrImage::Color.clamp_ycbcr_8bit(yy1 + r_bias)
                  g = CrImage::Color.clamp_ycbcr_8bit(yy1 + g_bias)
                  b = CrImage::Color.clamp_ycbcr_8bit(yy1 + b_bias)
                  q01 = 0xFF000000_u32 | (b.to_u32 << 16) | (g.to_u32 << 8) | r.to_u32

                  cb = cb_row_ptr[chroma + 1]
                  cr = cr_row_ptr[chroma + 1]
                  r_bias = cr_r_table[cr]
                  g_bias = -cb_g_table[cb] - cr_g_table[cr]
                  b_bias = cb_b_table[cb]

                  yy1 = yy_table[y_row0_ptr[x + 2]]
                  r = CrImage::Color.clamp_ycbcr_8bit(yy1 + r_bias)
                  g = CrImage::Color.clamp_ycbcr_8bit(yy1 + g_bias)
                  b = CrImage::Color.clamp_ycbcr_8bit(yy1 + b_bias)
                  p02 = 0xFF000000_u32 | (b.to_u32 << 16) | (g.to_u32 << 8) | r.to_u32

                  yy1 = yy_table[y_row0_ptr[x + 3]]
                  r = CrImage::Color.clamp_ycbcr_8bit(yy1 + r_bias)
                  g = CrImage::Color.clamp_ycbcr_8bit(yy1 + g_bias)
                  b = CrImage::Color.clamp_ycbcr_8bit(yy1 + b_bias)
                  p03 = 0xFF000000_u32 | (b.to_u32 << 16) | (g.to_u32 << 8) | r.to_u32

                  yy1 = yy_table[y_row1_ptr[x + 2]]
                  r = CrImage::Color.clamp_ycbcr_8bit(yy1 + r_bias)
                  g = CrImage::Color.clamp_ycbcr_8bit(yy1 + g_bias)
                  b = CrImage::Color.clamp_ycbcr_8bit(yy1 + b_bias)
                  q02 = 0xFF000000_u32 | (b.to_u32 << 16) | (g.to_u32 << 8) | r.to_u32

                  yy1 = yy_table[y_row1_ptr[x + 3]]
                  r = CrImage::Color.clamp_ycbcr_8bit(yy1 + r_bias)
                  g = CrImage::Color.clamp_ycbcr_8bit(yy1 + g_bias)
                  b = CrImage::Color.clamp_ycbcr_8bit(yy1 + b_bias)
                  q03 = 0xFF000000_u32 | (b.to_u32 << 16) | (g.to_u32 << 8) | r.to_u32

                  store_rgba4_simd(out_row0 + x, p00, p01, p02, p03)
                  store_rgba4_simd(out_row1 + x, q00, q01, q02, q03)
                  x += 4
                end

                while x < width
                  chroma = x >> 1
                  cb = cb_row_ptr[chroma]
                  cr = cr_row_ptr[chroma]
                  r_bias = cr_r_table[cr]
                  g_bias = -cb_g_table[cb] - cr_g_table[cr]
                  b_bias = cb_b_table[cb]

                  yy1 = yy_table[y_row0_ptr[x]]
                  r = CrImage::Color.clamp_ycbcr_8bit(yy1 + r_bias)
                  g = CrImage::Color.clamp_ycbcr_8bit(yy1 + g_bias)
                  b = CrImage::Color.clamp_ycbcr_8bit(yy1 + b_bias)
                  out_row0[x] = 0xFF000000_u32 | (b.to_u32 << 16) | (g.to_u32 << 8) | r.to_u32

                  yy1 = yy_table[y_row0_ptr[x + 1]]
                  r = CrImage::Color.clamp_ycbcr_8bit(yy1 + r_bias)
                  g = CrImage::Color.clamp_ycbcr_8bit(yy1 + g_bias)
                  b = CrImage::Color.clamp_ycbcr_8bit(yy1 + b_bias)
                  out_row0[x + 1] = 0xFF000000_u32 | (b.to_u32 << 16) | (g.to_u32 << 8) | r.to_u32

                  yy1 = yy_table[y_row1_ptr[x]]
                  r = CrImage::Color.clamp_ycbcr_8bit(yy1 + r_bias)
                  g = CrImage::Color.clamp_ycbcr_8bit(yy1 + g_bias)
                  b = CrImage::Color.clamp_ycbcr_8bit(yy1 + b_bias)
                  out_row1[x] = 0xFF000000_u32 | (b.to_u32 << 16) | (g.to_u32 << 8) | r.to_u32

                  yy1 = yy_table[y_row1_ptr[x + 1]]
                  r = CrImage::Color.clamp_ycbcr_8bit(yy1 + r_bias)
                  g = CrImage::Color.clamp_ycbcr_8bit(yy1 + g_bias)
                  b = CrImage::Color.clamp_ycbcr_8bit(yy1 + b_bias)
                  out_row1[x + 1] = 0xFF000000_u32 | (b.to_u32 << 16) | (g.to_u32 << 8) | r.to_u32

                  x += 2
                end
                y += 2
              end

              return rgba_img
            end

            y = 0
            while y < height
              y_row0 = y * width
              y_row1 = (y + 1) * width
              cbcr_row = (y // 2) * cb_width

              x = 0
              cb_idx = cbcr_row
              while x < width
                cb = cb_ptr[cb_idx]
                cr = cr_ptr[cb_idx]
                r_bias = cr_r_table[cr]
                g_bias = -cb_g_table[cb] - cr_g_table[cr]
                b_bias = cb_b_table[cb]

                yy1 = yy_table[y_ptr[y_row0 + x]]
                pixel_idx = y_row0 + x
                r = CrImage::Color.clamp_ycbcr_8bit(yy1 + r_bias)
                g = CrImage::Color.clamp_ycbcr_8bit(yy1 + g_bias)
                b = CrImage::Color.clamp_ycbcr_8bit(yy1 + b_bias)
                pix32[pixel_idx] = 0xFF000000_u32 | (b.to_u32 << 16) | (g.to_u32 << 8) | r.to_u32

                if x + 1 < width
                  yy1 = yy_table[y_ptr[y_row0 + x + 1]]
                  pixel_idx += 1
                  r = CrImage::Color.clamp_ycbcr_8bit(yy1 + r_bias)
                  g = CrImage::Color.clamp_ycbcr_8bit(yy1 + g_bias)
                  b = CrImage::Color.clamp_ycbcr_8bit(yy1 + b_bias)
                  pix32[pixel_idx] = 0xFF000000_u32 | (b.to_u32 << 16) | (g.to_u32 << 8) | r.to_u32
                end

                if y + 1 < height
                  yy1 = yy_table[y_ptr[y_row1 + x]]
                  pixel_idx = y_row1 + x
                  r = CrImage::Color.clamp_ycbcr_8bit(yy1 + r_bias)
                  g = CrImage::Color.clamp_ycbcr_8bit(yy1 + g_bias)
                  b = CrImage::Color.clamp_ycbcr_8bit(yy1 + b_bias)
                  pix32[pixel_idx] = 0xFF000000_u32 | (b.to_u32 << 16) | (g.to_u32 << 8) | r.to_u32

                  if x + 1 < width
                    yy1 = yy_table[y_ptr[y_row1 + x + 1]]
                    pixel_idx += 1
                    r = CrImage::Color.clamp_ycbcr_8bit(yy1 + r_bias)
                    g = CrImage::Color.clamp_ycbcr_8bit(yy1 + g_bias)
                    b = CrImage::Color.clamp_ycbcr_8bit(yy1 + b_bias)
                    pix32[pixel_idx] = 0xFF000000_u32 | (b.to_u32 << 16) | (g.to_u32 << 8) | r.to_u32
                  end
                end

                x += 2
                cb_idx += 1
              end
              y += 2
            end

            return rgba_img
          elsif h_ratio == 2 && v_ratio == 1
            if width.even?
              height.times do |y|
                y_row_ptr = y_ptr + (y * width)
                out_row = pix32 + (y * width)
                cb_row_ptr = cb_ptr + (y * cb_width)
                cr_row_ptr = cr_ptr + (y * cb_width)

                x = 0
                simd_width = width & ~3
                while x < simd_width
                  chroma = x >> 1
                  cb = cb_row_ptr[chroma]
                  cr = cr_row_ptr[chroma]
                  r_bias = cr_r_table[cr]
                  g_bias = -cb_g_table[cb] - cr_g_table[cr]
                  b_bias = cb_b_table[cb]

                  yy1 = yy_table[y_row_ptr[x]]
                  r = CrImage::Color.clamp_ycbcr_8bit(yy1 + r_bias)
                  g = CrImage::Color.clamp_ycbcr_8bit(yy1 + g_bias)
                  b = CrImage::Color.clamp_ycbcr_8bit(yy1 + b_bias)
                  p0 = 0xFF000000_u32 | (b.to_u32 << 16) | (g.to_u32 << 8) | r.to_u32

                  yy1 = yy_table[y_row_ptr[x + 1]]
                  r = CrImage::Color.clamp_ycbcr_8bit(yy1 + r_bias)
                  g = CrImage::Color.clamp_ycbcr_8bit(yy1 + g_bias)
                  b = CrImage::Color.clamp_ycbcr_8bit(yy1 + b_bias)
                  p1 = 0xFF000000_u32 | (b.to_u32 << 16) | (g.to_u32 << 8) | r.to_u32

                  cb = cb_row_ptr[chroma + 1]
                  cr = cr_row_ptr[chroma + 1]
                  r_bias = cr_r_table[cr]
                  g_bias = -cb_g_table[cb] - cr_g_table[cr]
                  b_bias = cb_b_table[cb]

                  yy1 = yy_table[y_row_ptr[x + 2]]
                  r = CrImage::Color.clamp_ycbcr_8bit(yy1 + r_bias)
                  g = CrImage::Color.clamp_ycbcr_8bit(yy1 + g_bias)
                  b = CrImage::Color.clamp_ycbcr_8bit(yy1 + b_bias)
                  p2 = 0xFF000000_u32 | (b.to_u32 << 16) | (g.to_u32 << 8) | r.to_u32

                  yy1 = yy_table[y_row_ptr[x + 3]]
                  r = CrImage::Color.clamp_ycbcr_8bit(yy1 + r_bias)
                  g = CrImage::Color.clamp_ycbcr_8bit(yy1 + g_bias)
                  b = CrImage::Color.clamp_ycbcr_8bit(yy1 + b_bias)
                  p3 = 0xFF000000_u32 | (b.to_u32 << 16) | (g.to_u32 << 8) | r.to_u32

                  store_rgba4_simd(out_row + x, p0, p1, p2, p3)
                  x += 4
                end

                while x < width
                  chroma = x >> 1
                  cb = cb_row_ptr[chroma]
                  cr = cr_row_ptr[chroma]
                  r_bias = cr_r_table[cr]
                  g_bias = -cb_g_table[cb] - cr_g_table[cr]
                  b_bias = cb_b_table[cb]

                  yy1 = yy_table[y_row_ptr[x]]
                  r = CrImage::Color.clamp_ycbcr_8bit(yy1 + r_bias)
                  g = CrImage::Color.clamp_ycbcr_8bit(yy1 + g_bias)
                  b = CrImage::Color.clamp_ycbcr_8bit(yy1 + b_bias)
                  out_row[x] = 0xFF000000_u32 | (b.to_u32 << 16) | (g.to_u32 << 8) | r.to_u32

                  yy1 = yy_table[y_row_ptr[x + 1]]
                  r = CrImage::Color.clamp_ycbcr_8bit(yy1 + r_bias)
                  g = CrImage::Color.clamp_ycbcr_8bit(yy1 + g_bias)
                  b = CrImage::Color.clamp_ycbcr_8bit(yy1 + b_bias)
                  out_row[x + 1] = 0xFF000000_u32 | (b.to_u32 << 16) | (g.to_u32 << 8) | r.to_u32

                  x += 2
                end
              end

              return rgba_img
            end

            height.times do |y|
              y_row = y * width
              cbcr_row = y * cb_width

              x = 0
              cb_idx = cbcr_row
              while x < width
                cb = cb_ptr[cb_idx]
                cr = cr_ptr[cb_idx]
                r_bias = cr_r_table[cr]
                g_bias = -cb_g_table[cb] - cr_g_table[cr]
                b_bias = cb_b_table[cb]

                yy1 = yy_table[y_ptr[y_row + x]]
                pixel_idx = y_row + x
                r = CrImage::Color.clamp_ycbcr_8bit(yy1 + r_bias)
                g = CrImage::Color.clamp_ycbcr_8bit(yy1 + g_bias)
                b = CrImage::Color.clamp_ycbcr_8bit(yy1 + b_bias)
                pix32[pixel_idx] = 0xFF000000_u32 | (b.to_u32 << 16) | (g.to_u32 << 8) | r.to_u32

                if x + 1 < width
                  yy1 = yy_table[y_ptr[y_row + x + 1]]
                  pixel_idx += 1
                  r = CrImage::Color.clamp_ycbcr_8bit(yy1 + r_bias)
                  g = CrImage::Color.clamp_ycbcr_8bit(yy1 + g_bias)
                  b = CrImage::Color.clamp_ycbcr_8bit(yy1 + b_bias)
                  pix32[pixel_idx] = 0xFF000000_u32 | (b.to_u32 << 16) | (g.to_u32 << 8) | r.to_u32
                end

                x += 2
                cb_idx += 1
              end
            end

            return rgba_img
          elsif h_ratio == 1 && v_ratio == 1
            idx = 0
            total = width * height
            simd_total = total & ~3
            while idx < simd_total
              yy1 = yy_table[y_ptr[idx]]
              cb = cb_ptr[idx]
              cr = cr_ptr[idx]
              r = CrImage::Color.clamp_ycbcr_8bit(yy1 + cr_r_table[cr])
              g = CrImage::Color.clamp_ycbcr_8bit(yy1 - cb_g_table[cb] - cr_g_table[cr])
              b = CrImage::Color.clamp_ycbcr_8bit(yy1 + cb_b_table[cb])
              p0 = 0xFF000000_u32 | (b.to_u32 << 16) | (g.to_u32 << 8) | r.to_u32

              yy1 = yy_table[y_ptr[idx + 1]]
              cb = cb_ptr[idx + 1]
              cr = cr_ptr[idx + 1]
              r = CrImage::Color.clamp_ycbcr_8bit(yy1 + cr_r_table[cr])
              g = CrImage::Color.clamp_ycbcr_8bit(yy1 - cb_g_table[cb] - cr_g_table[cr])
              b = CrImage::Color.clamp_ycbcr_8bit(yy1 + cb_b_table[cb])
              p1 = 0xFF000000_u32 | (b.to_u32 << 16) | (g.to_u32 << 8) | r.to_u32

              yy1 = yy_table[y_ptr[idx + 2]]
              cb = cb_ptr[idx + 2]
              cr = cr_ptr[idx + 2]
              r = CrImage::Color.clamp_ycbcr_8bit(yy1 + cr_r_table[cr])
              g = CrImage::Color.clamp_ycbcr_8bit(yy1 - cb_g_table[cb] - cr_g_table[cr])
              b = CrImage::Color.clamp_ycbcr_8bit(yy1 + cb_b_table[cb])
              p2 = 0xFF000000_u32 | (b.to_u32 << 16) | (g.to_u32 << 8) | r.to_u32

              yy1 = yy_table[y_ptr[idx + 3]]
              cb = cb_ptr[idx + 3]
              cr = cr_ptr[idx + 3]
              r = CrImage::Color.clamp_ycbcr_8bit(yy1 + cr_r_table[cr])
              g = CrImage::Color.clamp_ycbcr_8bit(yy1 - cb_g_table[cb] - cr_g_table[cr])
              b = CrImage::Color.clamp_ycbcr_8bit(yy1 + cb_b_table[cb])
              p3 = 0xFF000000_u32 | (b.to_u32 << 16) | (g.to_u32 << 8) | r.to_u32

              store_rgba4_simd(pix32 + idx, p0, p1, p2, p3)
              idx += 4
            end

            while idx < total
              yy1 = yy_table[y_ptr[idx]]
              cb = cb_ptr[idx]
              cr = cr_ptr[idx]
              r = CrImage::Color.clamp_ycbcr_8bit(yy1 + cr_r_table[cr])
              g = CrImage::Color.clamp_ycbcr_8bit(yy1 - cb_g_table[cb] - cr_g_table[cr])
              b = CrImage::Color.clamp_ycbcr_8bit(yy1 + cb_b_table[cb])
              pix32[idx] = 0xFF000000_u32 | (b.to_u32 << 16) | (g.to_u32 << 8) | r.to_u32
              idx += 1
            end

            return rgba_img
          end
        end

        cb_x_map = Array(Int32).new(width) { |x| (x * cb_comp.h_samp) // max_h_samp }
        cr_x_map = Array(Int32).new(width) { |x| (x * cr_comp.h_samp) // max_h_samp }

        height.times do |y|
          y_row = y * width
          cb_row = ((y * cb_comp.v_samp) // max_v_samp) * cb_width
          cr_row = ((y * cr_comp.v_samp) // max_v_samp) * cr_width

          width.times do |x|
            # Y component (full resolution)
            y_idx = y_row + x
            yy = y_data[y_idx]

            # Cb and Cr components (may be subsampled)
            cb = cb_data[cb_row + cb_x_map[x]]
            cr = cr_data[cr_row + cr_x_map[x]]

            yy1 = yy_table[yy]
            r = CrImage::Color.clamp_ycbcr_8bit(yy1 + cr_r_table[cr])
            g = CrImage::Color.clamp_ycbcr_8bit(yy1 - cb_g_table[cb] - cr_g_table[cr])
            b = CrImage::Color.clamp_ycbcr_8bit(yy1 + cb_b_table[cb])

            pix32[y_idx] = 0xFF000000_u32 | (b.to_u32 << 16) | (g.to_u32 << 8) | r.to_u32
          end
        end

        return rgba_img
      end

      # Handle CMYK images (4 components) - convert to RGBA
      if num_components == 4
        rect = CrImage.rect(0, 0, width, height)
        rgba_img = CrImage::RGBA.new(uninitialized_bytes(width * height * 4), width * 4, rect)

        c_data = decoded[0]
        m_data = decoded[1]
        y_data = decoded[2]
        k_data = decoded[3]

        height.times do |y|
          width.times do |x|
            idx = y * width + x

            # Get CMYK values (inverted for JPEG)
            c = 255_u8 - c_data[idx]
            m = 255_u8 - m_data[idx]
            yy = 255_u8 - y_data[idx]
            k = 255_u8 - k_data[idx]

            # Convert to RGB
            r, g, b = CrImage::Color.cmyk_to_rgb(c, m, yy, k)

            # Set RGBA pixel (alpha = 255)
            pix_idx = idx * 4
            rgba_img.pix[pix_idx] = r
            rgba_img.pix[pix_idx + 1] = g
            rgba_img.pix[pix_idx + 2] = b
            rgba_img.pix[pix_idx + 3] = 255_u8
          end
        end

        return rgba_img
      end

      raise FormatError.new("Unsupported number of components: #{num_components}")
    end
  end
end
