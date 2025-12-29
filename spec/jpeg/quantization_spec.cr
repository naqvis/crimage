require "../spec_helper"

module CrImage::JPEG
  describe "Quantization Table Tests" do
    it "creates quantization table" do
      table = QuantTable.new
      table.table.size.should eq(64)
    end

    it "creates table with values" do
      values = Array(UInt16).new(64) { |i| i.to_u16 }
      table = QuantTable.new(values)

      table.table[0].should eq(0)
      table.table[63].should eq(63)
    end

    it "scales luminance table for quality 50" do
      scaled = JPEG.scale_quant_table(STANDARD_LUMINANCE_QUANT_TABLE, 50)

      # Quality 50 should use standard table
      scaled.should eq(STANDARD_LUMINANCE_QUANT_TABLE)
    end

    it "scales luminance table for quality 100" do
      scaled = JPEG.scale_quant_table(STANDARD_LUMINANCE_QUANT_TABLE, 100)

      # Quality 100 should have all 1s
      scaled.all? { |v| v == 1 }.should be_true
    end

    it "scales luminance table for quality 1" do
      scaled = JPEG.scale_quant_table(STANDARD_LUMINANCE_QUANT_TABLE, 1)

      # Quality 1 should have large values
      scaled.all? { |v| v >= 50 }.should be_true
    end

    it "scales luminance table for quality 75" do
      scaled = JPEG.scale_quant_table(STANDARD_LUMINANCE_QUANT_TABLE, 75)

      # Quality 75 should be smaller than standard
      64.times do |i|
        scaled[i].should be <= STANDARD_LUMINANCE_QUANT_TABLE[i]
      end
    end

    it "scales luminance table for quality 25" do
      scaled = JPEG.scale_quant_table(STANDARD_LUMINANCE_QUANT_TABLE, 25)

      # Quality 25 should be larger than standard
      64.times do |i|
        scaled[i].should be >= STANDARD_LUMINANCE_QUANT_TABLE[i]
      end
    end

    it "raises error for invalid quality" do
      expect_raises(FormatError, /Quality must be between/) do
        JPEG.scale_quant_table(STANDARD_LUMINANCE_QUANT_TABLE, 0)
      end

      expect_raises(FormatError, /Quality must be between/) do
        JPEG.scale_quant_table(STANDARD_LUMINANCE_QUANT_TABLE, 101)
      end
    end

    it "clamps values to valid range" do
      scaled = JPEG.scale_quant_table(STANDARD_LUMINANCE_QUANT_TABLE, 100)

      # All values should be between 1 and 255
      scaled.all? { |v| v >= 1 && v <= 255 }.should be_true
    end

    it "scales chrominance table" do
      scaled = JPEG.scale_quant_table(STANDARD_CHROMINANCE_QUANT_TABLE, 75)

      scaled.size.should eq(64)
      scaled.all? { |v| v >= 1 && v <= 255 }.should be_true
    end

    it "has correct standard luminance table" do
      STANDARD_LUMINANCE_QUANT_TABLE.size.should eq(64)
      STANDARD_LUMINANCE_QUANT_TABLE[0].should eq(16)
    end

    it "has correct standard chrominance table" do
      STANDARD_CHROMINANCE_QUANT_TABLE.size.should eq(64)
      STANDARD_CHROMINANCE_QUANT_TABLE[0].should eq(17)
    end
  end
end
