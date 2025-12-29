module CrImage::JPEG
  # Writer encodes JPEG images to IO streams
  class Writer
    @io : IO
    @image : CrImage::Image
    @quality : Int32
    @quant_tables : Array(QuantTable)
    @dc_tables : Array(HuffmanTable)
    @ac_tables : Array(HuffmanTable)
    @y_data : Array(UInt8)?
    @cb_data : Array(UInt8)?
    @cr_data : Array(UInt8)?
    @width : Int32
    @height : Int32
    @num_components : Int32

    private def initialize(@io : IO, @image : CrImage::Image, @quality : Int32)
      @quant_tables = [] of QuantTable
      @dc_tables = [] of HuffmanTable
      @ac_tables = [] of HuffmanTable
      @y_data = nil
      @cb_data = nil
      @cr_data = nil
      @width = @image.bounds.width
      @height = @image.bounds.height
      @num_components = 0
    end

    # Write JPEG image to file path
    def self.write(path : String, image : CrImage::Image, quality : Int32 = 75) : Nil
      File.open(path, "w") do |file|
        write(file, image, quality)
      end
    rescue ex : IO::Error
      raise FormatError.new("Failed to write file: #{ex.message}")
    end

    # Write JPEG image to IO stream
    def self.write(io : IO, image : CrImage::Image, quality : Int32 = 75) : Nil
      writer = new(io, image, quality)
      writer.encode
    rescue ex : FormatError
      raise ex
    rescue ex
      raise FormatError.new("Failed to encode JPEG: #{ex.message}")
    end

    # Main encode method - orchestrates the encoding process
    protected def encode : Nil
      # Validate quality parameter
      validate_quality

      # Convert image to YCbCr color space
      prepare_color_data

      # Initialize quantization tables
      initialize_quant_tables

      # Initialize Huffman tables
      initialize_huffman_tables

      # Write JPEG markers and segments
      write_soi
      write_app0
      write_dqt
      write_sof0
      write_dht
      write_sos

      # Encode and write scan data
      write_scan_data

      # Write end of image marker
      write_eoi
    end

    # Validate quality parameter (must be between 1 and 100)
    private def validate_quality : Nil
      unless @quality >= 1 && @quality <= 100
        raise FormatError.new("Quality must be between 1 and 100, got #{@quality}")
      end
    end

    # Initialize quantization tables based on quality
    private def initialize_quant_tables : Nil
      # Scale standard luminance table
      lum_table = JPEG.scale_quant_table(STANDARD_LUMINANCE_QUANT_TABLE, @quality)
      @quant_tables << QuantTable.new(lum_table)

      # Scale standard chrominance table (only needed for color images)
      if @num_components == 3
        chrom_table = JPEG.scale_quant_table(STANDARD_CHROMINANCE_QUANT_TABLE, @quality)
        @quant_tables << QuantTable.new(chrom_table)
      end
    end

    # Initialize standard Huffman tables
    private def initialize_huffman_tables : Nil
      # DC tables
      @dc_tables << HuffmanTable.new(STANDARD_DC_LUMINANCE_BITS.to_a, STANDARD_DC_LUMINANCE_VALUES.to_a)
      if @num_components == 3
        @dc_tables << HuffmanTable.new(STANDARD_DC_CHROMINANCE_BITS.to_a, STANDARD_DC_CHROMINANCE_VALUES.to_a)
      end

      # AC tables
      @ac_tables << HuffmanTable.new(STANDARD_AC_LUMINANCE_BITS.to_a, STANDARD_AC_LUMINANCE_VALUES.to_a)
      if @num_components == 3
        @ac_tables << HuffmanTable.new(STANDARD_AC_CHROMINANCE_BITS.to_a, STANDARD_AC_CHROMINANCE_VALUES.to_a)
      end
    end

    # Write a marker (0xFF followed by marker byte)
    private def write_marker(marker : UInt8) : Nil
      @io.write_byte(0xFF_u8)
      @io.write_byte(marker)
    end

    # Write a 16-bit big-endian value
    private def write_uint16(value : UInt16) : Nil
      @io.write_byte((value >> 8).to_u8)
      @io.write_byte((value & 0xFF).to_u8)
    end

    # Write SOI (Start of Image) marker
    private def write_soi : Nil
      write_marker(Marker::SOI.value)
    end

    # Write APP0 (JFIF) segment
    private def write_app0 : Nil
      write_marker(Marker::APP0.value)

      # Length (16 bytes total including length field)
      write_uint16(16_u16)

      # JFIF identifier
      @io.write("JFIF".to_slice)
      @io.write_byte(0_u8) # Null terminator

      # Version (1.01)
      @io.write_byte(1_u8)
      @io.write_byte(1_u8)

      # Density units (0 = no units, aspect ratio only)
      @io.write_byte(0_u8)

      # X density
      write_uint16(1_u16)

      # Y density
      write_uint16(1_u16)

      # Thumbnail width and height (0 = no thumbnail)
      @io.write_byte(0_u8)
      @io.write_byte(0_u8)
    end

    # Write DQT (Define Quantization Table) segments
    private def write_dqt : Nil
      @quant_tables.each_with_index do |table, index|
        write_marker(Marker::DQT.value)

        # Length (67 bytes: 2 for length + 1 for info + 64 for table)
        write_uint16(67_u16)

        # Table info: precision (0 = 8-bit) and index
        @io.write_byte(index.to_u8)

        # Write 64 quantization values in zigzag order
        64.times do |i|
          @io.write_byte(table.table[i].to_u8)
        end
      end
    end

    # Write SOF0 (Start of Frame - Baseline DCT) segment
    private def write_sof0 : Nil
      write_marker(Marker::SOF0.value)

      # Length (8 + 3 * num_components)
      length = 8 + 3 * @num_components
      write_uint16(length.to_u16)

      # Precision (8 bits)
      @io.write_byte(8_u8)

      # Height
      write_uint16(@height.to_u16)

      # Width
      write_uint16(@width.to_u16)

      # Number of components
      @io.write_byte(@num_components.to_u8)

      # Component specifications
      if @num_components == 1
        # Grayscale: 1 component (Y)
        @io.write_byte(1_u8)    # Component ID
        @io.write_byte(0x11_u8) # Sampling factors (1x1)
        @io.write_byte(0_u8)    # Quantization table index
      else
        # Color: 3 components (Y, Cb, Cr)
        # Y component
        @io.write_byte(1_u8)    # Component ID
        @io.write_byte(0x22_u8) # Sampling factors (2x2)
        @io.write_byte(0_u8)    # Quantization table index

        # Cb component
        @io.write_byte(2_u8)    # Component ID
        @io.write_byte(0x11_u8) # Sampling factors (1x1)
        @io.write_byte(1_u8)    # Quantization table index

        # Cr component
        @io.write_byte(3_u8)    # Component ID
        @io.write_byte(0x11_u8) # Sampling factors (1x1)
        @io.write_byte(1_u8)    # Quantization table index
      end
    end

    # Write DHT (Define Huffman Table) segments
    private def write_dht : Nil
      # Write DC tables
      @dc_tables.each_with_index do |table, index|
        write_marker(Marker::DHT.value)

        # Calculate length
        num_values = table.values.size
        length = 2 + 1 + 16 + num_values
        write_uint16(length.to_u16)

        # Table info: class (0 = DC) and index
        table_info = (0 << 4) | index
        @io.write_byte(table_info.to_u8)

        # Write 16 bytes of bit counts
        table.bits.each do |bit|
          @io.write_byte(bit)
        end

        # Write values
        table.values.each do |val|
          @io.write_byte(val)
        end
      end

      # Write AC tables
      @ac_tables.each_with_index do |table, index|
        write_marker(Marker::DHT.value)

        # Calculate length
        num_values = table.values.size
        length = 2 + 1 + 16 + num_values
        write_uint16(length.to_u16)

        # Table info: class (1 = AC) and index
        table_info = (1 << 4) | index
        @io.write_byte(table_info.to_u8)

        # Write 16 bytes of bit counts
        table.bits.each do |bit|
          @io.write_byte(bit)
        end

        # Write values
        table.values.each do |v|
          @io.write_byte(v)
        end
      end
    end

    # Write SOS (Start of Scan) segment
    private def write_sos : Nil
      write_marker(Marker::SOS.value)

      # Length (6 + 2 * num_components)
      length = 6 + 2 * @num_components
      write_uint16(length.to_u16)

      # Number of components
      @io.write_byte(@num_components.to_u8)

      # Component selectors
      if @num_components == 1
        # Grayscale
        @io.write_byte(1_u8)    # Component selector (Y)
        @io.write_byte(0x00_u8) # DC table 0, AC table 0
      else
        # Color
        # Y component
        @io.write_byte(1_u8)    # Component selector
        @io.write_byte(0x00_u8) # DC table 0, AC table 0

        # Cb component
        @io.write_byte(2_u8)    # Component selector
        @io.write_byte(0x11_u8) # DC table 1, AC table 1

        # Cr component
        @io.write_byte(3_u8)    # Component selector
        @io.write_byte(0x11_u8) # DC table 1, AC table 1
      end

      # Spectral selection (0, 63 for baseline)
      @io.write_byte(0_u8)
      @io.write_byte(63_u8)

      # Successive approximation (0 for baseline)
      @io.write_byte(0_u8)
    end

    # Write EOI (End of Image) marker
    private def write_eoi : Nil
      write_marker(Marker::EOI.value)
    end

    # Prepare color data by converting image to YCbCr or grayscale
    private def prepare_color_data : Nil
      bounds = @image.bounds
      width = bounds.width
      height = bounds.height

      # Check if image is grayscale
      if @image.is_a?(CrImage::Gray) || @image.is_a?(CrImage::Gray16)
        # Grayscale image - single component
        @num_components = 1
        @y_data = Array(UInt8).new(width * height, 0_u8)

        y_data = @y_data.not_nil!

        height.times do |y|
          width.times do |x|
            color = @image.at(x, y)
            # Convert to Gray model
            gray_color = CrImage::Color.gray_model.convert(color).as(CrImage::Color::Gray)
            y_data[y * width + x] = gray_color.y
          end
        end
      else
        # Color image - convert to YCbCr (3 components)
        @num_components = 3

        # Allocate arrays for Y, Cb, Cr components
        # Apply 4:2:0 chroma subsampling
        @y_data = Array(UInt8).new(width * height, 0_u8)

        # Subsampled dimensions for Cb and Cr (half resolution)
        cb_width = (width + 1) // 2
        cb_height = (height + 1) // 2
        @cb_data = Array(UInt8).new(cb_width * cb_height, 128_u8)
        @cr_data = Array(UInt8).new(cb_width * cb_height, 128_u8)

        y_data = @y_data.not_nil!
        cb_data = @cb_data.not_nil!
        cr_data = @cr_data.not_nil!

        # Convert each pixel to YCbCr
        height.times do |y|
          width.times do |x|
            color = @image.at(x, y)

            # Get RGB values
            r32, g32, b32, _ = color.rgba
            r = (r32 >> 8).to_u8
            g = (g32 >> 8).to_u8
            b = (b32 >> 8).to_u8

            # Convert to YCbCr
            yy, cb, cr = CrImage::Color.rgb_to_ycbcr(r, g, b)

            # Store Y component (full resolution)
            y_data[y * width + x] = yy

            # Store Cb and Cr components (subsampled - only for even pixels)
            if y % 2 == 0 && x % 2 == 0
              cb_x = x // 2
              cb_y = y // 2
              cb_data[cb_y * cb_width + cb_x] = cb
              cr_data[cb_y * cb_width + cb_x] = cr
            end
          end
        end
      end
    end

    # Zigzag order for quantization (same as in reader)
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

    # Write scan data (compressed image data)
    private def write_scan_data : Nil
      bit_writer = BitWriter.new(@io)

      # DC predictors for each component
      dc_predictors = Array(Int32).new(@num_components, 0)

      if @num_components == 1
        # Grayscale encoding
        encode_grayscale(bit_writer, dc_predictors)
      else
        # Color encoding with 4:2:0 subsampling
        encode_color(bit_writer, dc_predictors)
      end

      # Flush remaining bits
      bit_writer.flush
    end

    # Encode grayscale image
    private def encode_grayscale(bit_writer : BitWriter, dc_predictors : Array(Int32)) : Nil
      y_data = @y_data.not_nil!
      quant_table = @quant_tables[0]
      dc_table = @dc_tables[0]
      ac_table = @ac_tables[0]

      # Process image in 8x8 blocks
      mcu_rows = (@height + 7) // 8
      mcu_cols = (@width + 7) // 8

      mcu_rows.times do |mcu_y|
        mcu_cols.times do |mcu_x|
          encode_mcu(bit_writer, y_data, @width, @height,
            mcu_x, mcu_y, quant_table, dc_table, ac_table, dc_predictors, 0)
        end
      end
    end

    # Encode color image with 4:2:0 subsampling
    private def encode_color(bit_writer : BitWriter, dc_predictors : Array(Int32)) : Nil
      y_data = @y_data.not_nil!
      cb_data = @cb_data.not_nil!
      cr_data = @cr_data.not_nil!

      y_quant = @quant_tables[0]
      c_quant = @quant_tables[1]
      y_dc_table = @dc_tables[0]
      y_ac_table = @ac_tables[0]
      c_dc_table = @dc_tables[1]
      c_ac_table = @ac_tables[1]

      # Process image in 16x16 MCUs (2x2 Y blocks + 1 Cb block + 1 Cr block)
      mcu_rows = (@height + 15) // 16
      mcu_cols = (@width + 15) // 16

      cb_width = (@width + 1) // 2
      cb_height = (@height + 1) // 2

      mcu_rows.times do |mcu_y|
        mcu_cols.times do |mcu_x|
          # Encode 4 Y blocks (2x2)
          2.times do |block_y_offset|
            2.times do |block_x_offset|
              block_x = mcu_x * 2 + block_x_offset
              block_y = mcu_y * 2 + block_y_offset
              encode_mcu(bit_writer, y_data, @width, @height,
                block_x, block_y, y_quant, y_dc_table, y_ac_table, dc_predictors, 0)
            end
          end

          # Encode 1 Cb block
          encode_mcu(bit_writer, cb_data, cb_width, cb_height,
            mcu_x, mcu_y, c_quant, c_dc_table, c_ac_table, dc_predictors, 1)

          # Encode 1 Cr block
          encode_mcu(bit_writer, cr_data, cb_width, cb_height,
            mcu_x, mcu_y, c_quant, c_dc_table, c_ac_table, dc_predictors, 2)
        end
      end
    end

    # Encode one 8x8 MCU block
    private def encode_mcu(bit_writer : BitWriter, data : Array(UInt8),
                           data_width : Int32, data_height : Int32,
                           block_x : Int32, block_y : Int32,
                           quant_table : QuantTable,
                           dc_table : HuffmanTable, ac_table : HuffmanTable,
                           dc_predictors : Array(Int32), component_index : Int32) : Nil
      # Extract 8x8 block from data
      block = Array(Int32).new(64, 0)

      base_x = block_x * 8
      base_y = block_y * 8

      8.times do |delta_y|
        8.times do |delta_x|
          x = base_x + delta_x
          y = base_y + delta_y

          if x < data_width && y < data_height
            block[delta_y * 8 + delta_x] = data[y * data_width + x].to_i32
          else
            # Pad with 128 (neutral gray)
            block[delta_y * 8 + delta_x] = 128
          end
        end
      end

      # Apply forward DCT
      block = DCT.transform(block)

      # Quantize coefficients
      64.times do |i|
        block[i] = (block[i].to_f64 / quant_table.table[i].to_f64).round.to_i32
      end

      # Encode DC coefficient
      dc_value = block[0]
      dc_diff = dc_value - dc_predictors[component_index]
      dc_predictors[component_index] = dc_value

      encode_coefficient(bit_writer, dc_diff, dc_table)

      # Encode AC coefficients in zigzag order
      encode_ac_coefficients(bit_writer, block, ac_table)
    end

    # Encode a single coefficient (DC or AC)
    private def encode_coefficient(bit_writer : BitWriter, value : Int32, table : HuffmanTable) : Nil
      # Calculate size (number of bits needed)
      size = 0
      abs_value = value.abs

      if abs_value > 0
        size = 32 - abs_value.leading_zeros_count
      end

      # Encode size using Huffman table
      encode_huffman_symbol(bit_writer, size.to_u8, table)

      # Encode value bits if size > 0
      if size > 0
        if value > 0
          bit_writer.write_bits(value.to_u16, size)
        else
          # Negative values: write (value - 1) in size bits, masked to size bits
          bits = (value - 1) & ((1 << size) - 1)
          bit_writer.write_bits(bits.to_u16, size)
        end
      end
    end

    # Encode AC coefficients using run-length encoding
    private def encode_ac_coefficients(bit_writer : BitWriter, block : Array(Int32), ac_table : HuffmanTable) : Nil
      # Find last non-zero coefficient
      last_nonzero = 63
      while last_nonzero > 0 && block[ZIGZAG[last_nonzero]] == 0
        last_nonzero -= 1
      end

      # Encode AC coefficients
      k = 1
      while k <= last_nonzero
        # Count zeros
        zero_run = 0
        while k <= last_nonzero && block[ZIGZAG[k]] == 0
          zero_run += 1
          k += 1
        end

        # Handle runs of 16 zeros
        while zero_run >= 16
          # ZRL: 0xF0 (run of 16 zeros)
          encode_huffman_symbol(bit_writer, 0xF0_u8, ac_table)
          zero_run -= 16
        end

        if k <= last_nonzero
          # Encode coefficient
          value = block[ZIGZAG[k]]
          abs_value = value.abs
          size = 32 - abs_value.leading_zeros_count

          # Encode run/size
          rs = ((zero_run << 4) | size).to_u8
          encode_huffman_symbol(bit_writer, rs, ac_table)

          # Encode value bits
          if value > 0
            bit_writer.write_bits(value.to_u16, size)
          else
            # Negative values: write (value - 1) in size bits, masked to size bits
            bits = (value - 1) & ((1 << size) - 1)
            bit_writer.write_bits(bits.to_u16, size)
          end

          k += 1
        end
      end

      # EOB (End of Block) if we didn't reach the end
      if last_nonzero < 63
        encode_huffman_symbol(bit_writer, 0x00_u8, ac_table)
      end
    end

    # Encode a Huffman symbol
    private def encode_huffman_symbol(bit_writer : BitWriter, symbol : UInt8, table : HuffmanTable) : Nil
      # Build Huffman codes from bits and values arrays
      # This generates codes according to JPEG spec
      code = 0_u16
      value_index = 0

      table.bits.each_with_index do |count, length_idx|
        length = length_idx + 1 # Actual bit length (1-16)

        count.times do
          if table.values[value_index] == symbol
            # Found our symbol - write the code
            bit_writer.write_bits(code, length)
            return
          end

          value_index += 1
          code += 1
        end

        # Shift code left for next length
        code <<= 1
      end

      raise FormatError.new("Symbol #{symbol} not found in Huffman table")
    end
  end
end
