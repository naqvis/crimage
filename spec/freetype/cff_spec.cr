require "../spec_helper"

describe FreeType::CFF do
  describe "CFF Font Detection" do
    it "should detect CFF font by signature" do
      # Create minimal OpenType font with CFF outlines
      data = Bytes.new(2048, 0_u8)

      # OpenType signature (OTTO)
      data[0] = 'O'.ord.to_u8
      data[1] = 'T'.ord.to_u8
      data[2] = 'T'.ord.to_u8
      data[3] = 'O'.ord.to_u8

      # Number of tables: 5 (CFF, head, maxp, name, OS/2)
      data[4] = 0x00_u8
      data[5] = 0x05_u8

      # Table 1: CFF at offset 12
      offset = 12
      "CFF ".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x04_u8
      data[offset + 11] = 0x00_u8 # Offset 1024

      # Table 2: head
      offset = 28
      "head".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x01_u8
      data[offset + 11] = 0x00_u8 # Offset 256

      # Table 3: maxp
      offset = 44
      "maxp".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x02_u8
      data[offset + 11] = 0x00_u8 # Offset 512

      # Table 4: name
      offset = 60
      "name".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x03_u8
      data[offset + 11] = 0x00_u8 # Offset 768

      # Table 5: OS/2
      offset = 76
      "OS/2".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x05_u8
      data[offset + 11] = 0x00_u8 # Offset 1280

      # head table at offset 256
      offset = 256
      data[offset + 18] = 0x08_u8
      data[offset + 19] = 0x00_u8 # 2048 units per EM

      # maxp table at offset 512 (version 0.5 for CFF)
      offset = 512
      data[offset] = 0x00_u8
      data[offset + 1] = 0x00_u8
      data[offset + 2] = 0x50_u8
      data[offset + 3] = 0x00_u8 # Version 0.5
      data[offset + 4] = 0x00_u8
      data[offset + 5] = 0x0A_u8 # 10 glyphs

      # Minimal CFF table at offset 1024
      offset = 1024
      # CFF Header
      data[offset] = 0x01_u8     # Major version
      data[offset + 1] = 0x00_u8 # Minor version
      data[offset + 2] = 0x04_u8 # Header size
      data[offset + 3] = 0x01_u8 # Offset size

      font = FreeType::CFF::Font.new(data)
      font.should_not be_nil
      font.is_cff?.should be_true
    end

    it "should reject TrueType fonts" do
      # Create TrueType font
      data = Bytes.new(1024, 0_u8)

      # TrueType signature
      data[0] = 0x00_u8
      data[1] = 0x01_u8
      data[2] = 0x00_u8
      data[3] = 0x00_u8

      data[4] = 0x00_u8
      data[5] = 0x03_u8

      # Add required tables
      offset = 12
      "head".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x01_u8
      data[offset + 11] = 0x00_u8

      offset = 28
      "maxp".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x02_u8
      data[offset + 11] = 0x00_u8

      offset = 44
      "loca".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x03_u8
      data[offset + 11] = 0x00_u8

      offset = 256
      data[offset + 18] = 0x08_u8
      data[offset + 19] = 0x00_u8
      data[offset + 50] = 0x00_u8
      data[offset + 51] = 0x00_u8

      offset = 512
      data[offset] = 0x00_u8
      data[offset + 1] = 0x01_u8
      data[offset + 2] = 0x00_u8
      data[offset + 3] = 0x00_u8
      data[offset + 4] = 0x00_u8
      data[offset + 5] = 0x0A_u8

      expect_raises(CrImage::FormatError, /not a CFF font/) do
        FreeType::CFF::Font.new(data)
      end
    end
  end

  describe "CFF Charstring Parsing" do
    it "should parse Type 2 charstring operators" do
      parser = FreeType::CFF::CharstringParser.new

      # Simple charstring: moveto, lineto, endchar
      # 100 200 rmoveto, 50 0 rlineto, endchar
      charstring = Bytes[
        0x64, 0xC8, 0x15, # 100 200 rmoveto (opcode 21)
        0x32, 0x00, 0x05, # 50 0 rlineto (opcode 5)
        0x0E              # endchar (opcode 14)
      ]

      result = parser.parse(charstring)
      result.should_not be_nil
      result.commands.size.should be > 0
    end

    it "should handle integer operands" do
      parser = FreeType::CFF::CharstringParser.new

      # Test various integer encodings
      # -107 to 107: single byte (139 + value)
      # -1131 to 1131: two bytes
      # Larger: five bytes with 0xFF prefix

      charstring = Bytes[
        0x8B, # 0 (139 - 139)
        0xEF, # 100 (139 + 100)
        0x27, # -100 (139 - 100 - 256)
        0x0E  # endchar
      ]

      result = parser.parse(charstring)
      result.should_not be_nil
    end

    it "should handle cubic bezier curves" do
      parser = FreeType::CFF::CharstringParser.new

      # rrcurveto: dx1 dy1 dx2 dy2 dx3 dy3 (opcode 8)
      charstring = Bytes[
        0x64, 0xC8, 0x15,                   # 100 200 rmoveto
        0x0A, 0x14, 0x1E, 0x28, 0x32, 0x3C, # 10 20 30 40 50 60
        0x08,                               # rrcurveto
        0x0E                                # endchar
      ]

      result = parser.parse(charstring)
      result.should_not be_nil
      result.has_curves?.should be_true
    end

    it "should handle hinting operators" do
      parser = FreeType::CFF::CharstringParser.new

      # hstem: y dy (opcode 1)
      # vstem: x dx (opcode 3)
      charstring = Bytes[
        0x0A, 0x14, 0x01, # 10 20 hstem
        0x1E, 0x28, 0x03, # 30 40 vstem
        0x64, 0xC8, 0x15, # 100 200 rmoveto
        0x0E              # endchar
      ]

      result = parser.parse(charstring)
      result.should_not be_nil
    end
  end

  describe "CFF to TrueType Conversion" do
    it "should convert cubic bezier to quadratic" do
      converter = FreeType::CFF::CubicToQuadratic.new

      # Cubic: P0, P1, P2, P3
      p0 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[0],
        CrImage::Math::Fixed::Int26_6[0]
      )
      p1 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[100 * 64],
        CrImage::Math::Fixed::Int26_6[100 * 64]
      )
      p2 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[200 * 64],
        CrImage::Math::Fixed::Int26_6[100 * 64]
      )
      p3 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[300 * 64],
        CrImage::Math::Fixed::Int26_6[0]
      )

      quadratics = converter.convert(p0, p1, p2, p3)
      quadratics.should_not be_nil
      quadratics.size.should be > 0
    end

    it "should approximate cubic with multiple quadratics" do
      converter = FreeType::CFF::CubicToQuadratic.new

      # Sharp curve requiring multiple segments
      p0 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[0],
        CrImage::Math::Fixed::Int26_6[0]
      )
      p1 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[0],
        CrImage::Math::Fixed::Int26_6[200 * 64]
      )
      p2 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[200 * 64],
        CrImage::Math::Fixed::Int26_6[200 * 64]
      )
      p3 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[200 * 64],
        CrImage::Math::Fixed::Int26_6[0]
      )

      quadratics = converter.convert(p0, p1, p2, p3, tolerance: 1.0)
      quadratics.size.should be >= 2
    end
  end
end
