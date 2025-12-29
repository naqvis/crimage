require "../spec_helper"

describe FreeType::WOFF do
  describe "WOFF detection" do
    it "detects WOFF signature" do
      # Create minimal WOFF header
      data = Bytes.new(44)
      # Write 'wOFF' signature
      data[0] = 0x77_u8 # 'w'
      data[1] = 0x4F_u8 # 'O'
      data[2] = 0x46_u8 # 'F'
      data[3] = 0x46_u8 # 'F'

      FreeType::WOFF::Font.is_woff?(data).should be_true
    end

    it "rejects non-WOFF data" do
      # TrueType signature
      data = Bytes.new(44)
      data[0] = 0x00_u8
      data[1] = 0x01_u8
      data[2] = 0x00_u8
      data[3] = 0x00_u8

      FreeType::WOFF::Font.is_woff?(data).should be_false
    end

    it "rejects too small data" do
      data = Bytes.new(3)
      FreeType::WOFF::Font.is_woff?(data).should be_false
    end
  end

  describe "WOFF validation" do
    it "rejects data too small for header" do
      data = Bytes.new(20)
      data[0] = 0x77_u8
      data[1] = 0x4F_u8
      data[2] = 0x46_u8
      data[3] = 0x46_u8

      expect_raises(CrImage::FormatError, "WOFF data too small") do
        FreeType::WOFF::Font.new(data)
      end
    end

    it "rejects invalid signature" do
      data = Bytes.new(44)
      data[0] = 0x00_u8
      data[1] = 0x01_u8
      data[2] = 0x00_u8
      data[3] = 0x00_u8

      expect_raises(CrImage::FormatError, "Invalid WOFF signature") do
        FreeType::WOFF::Font.new(data)
      end
    end

    it "rejects length mismatch" do
      data = Bytes.new(44)
      # Write 'wOFF' signature
      data[0] = 0x77_u8
      data[1] = 0x4F_u8
      data[2] = 0x46_u8
      data[3] = 0x46_u8
      # Write wrong length (100 instead of 44)
      data[8] = 0x00_u8
      data[9] = 0x00_u8
      data[10] = 0x00_u8
      data[11] = 0x64_u8 # 100

      expect_raises(CrImage::FormatError, "WOFF length mismatch") do
        FreeType::WOFF::Font.new(data)
      end
    end

    it "rejects zero tables" do
      data = Bytes.new(44)
      # Write 'wOFF' signature
      data[0] = 0x77_u8
      data[1] = 0x4F_u8
      data[2] = 0x46_u8
      data[3] = 0x46_u8
      # Write correct length
      data[8] = 0x00_u8
      data[9] = 0x00_u8
      data[10] = 0x00_u8
      data[11] = 0x2C_u8 # 44
      # Write 0 tables
      data[12] = 0x00_u8
      data[13] = 0x00_u8

      expect_raises(CrImage::FormatError, "Invalid number of tables") do
        FreeType::WOFF::Font.new(data)
      end
    end

    it "rejects excessive tables" do
      data = Bytes.new(44)
      # Write 'wOFF' signature
      data[0] = 0x77_u8
      data[1] = 0x4F_u8
      data[2] = 0x46_u8
      data[3] = 0x46_u8
      # Write correct length
      data[8] = 0x00_u8
      data[9] = 0x00_u8
      data[10] = 0x00_u8
      data[11] = 0x2C_u8 # 44
      # Write 300 tables (> 256)
      data[12] = 0x01_u8
      data[13] = 0x2C_u8 # 300

      expect_raises(CrImage::FormatError, "Invalid number of tables") do
        FreeType::WOFF::Font.new(data)
      end
    end
  end
end
