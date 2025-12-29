require "../spec_helper"

module CrImage::JPEG
  describe "Quantization API Tests" do
    describe "QuantTable" do
      it "creates quantization table with default values" do
        table = QuantTable.new
        table.table.size.should eq(64)
        table.table.all? { |v| v == 0 }.should be_true
      end

      it "creates quantization table with custom values" do
        values = Array(UInt16).new(64) { |i| (i + 1).to_u16 }
        table = QuantTable.new(values)
        table.table.size.should eq(64)
        table.table[0].should eq(1)
        table.table[63].should eq(64)
      end
    end

    describe "Standard Quantization Tables" do
      it "has standard luminance table" do
        STANDARD_LUMINANCE_QUANT_TABLE.size.should eq(64)
        STANDARD_LUMINANCE_QUANT_TABLE[0].should eq(16)
      end

      it "has standard chrominance table" do
        STANDARD_CHROMINANCE_QUANT_TABLE.size.should eq(64)
        STANDARD_CHROMINANCE_QUANT_TABLE[0].should eq(17)
      end
    end

    describe "scale_quant_table" do
      it "scales table with quality 50 (no change)" do
        scaled = JPEG.scale_quant_table(STANDARD_LUMINANCE_QUANT_TABLE, 50)
        scaled.size.should eq(64)
        # At quality 50, values should be close to original
        scaled[0].should be_close(16, 2)
      end

      it "scales table with quality 100 (best quality)" do
        scaled = JPEG.scale_quant_table(STANDARD_LUMINANCE_QUANT_TABLE, 100)
        scaled.size.should eq(64)
        # At quality 100, all values should be 1 (minimum quantization)
        scaled.all? { |v| v == 1 }.should be_true
      end

      it "scales table with quality 1 (worst quality)" do
        scaled = JPEG.scale_quant_table(STANDARD_LUMINANCE_QUANT_TABLE, 1)
        scaled.size.should eq(64)
        # At quality 1, values should be much larger
        scaled[0].should be > 100
      end

      it "scales table with quality 75 (common default)" do
        scaled = JPEG.scale_quant_table(STANDARD_LUMINANCE_QUANT_TABLE, 75)
        scaled.size.should eq(64)
        # At quality 75, values should be smaller than standard
        scaled[0].should be < 16
      end

      it "raises error for quality < 1" do
        expect_raises(FormatError, "Quality must be between 1 and 100") do
          JPEG.scale_quant_table(STANDARD_LUMINANCE_QUANT_TABLE, 0)
        end
      end

      it "raises error for quality > 100" do
        expect_raises(FormatError, "Quality must be between 1 and 100") do
          JPEG.scale_quant_table(STANDARD_LUMINANCE_QUANT_TABLE, 101)
        end
      end

      it "clamps scaled values between 1 and 255" do
        scaled = JPEG.scale_quant_table(STANDARD_LUMINANCE_QUANT_TABLE, 1)
        scaled.all? { |v| v >= 1 && v <= 255 }.should be_true
      end

      it "handles chrominance table scaling" do
        scaled = JPEG.scale_quant_table(STANDARD_CHROMINANCE_QUANT_TABLE, 50)
        scaled.size.should eq(64)
        scaled[0].should be_close(17, 2)
      end
    end

    describe "Quality to quantization relationship" do
      it "lower quality produces larger quantization values" do
        q25 = JPEG.scale_quant_table(STANDARD_LUMINANCE_QUANT_TABLE, 25)
        q75 = JPEG.scale_quant_table(STANDARD_LUMINANCE_QUANT_TABLE, 75)

        # Lower quality (25) should have larger values than higher quality (75)
        q25[0].should be > q75[0]
      end

      it "quality affects all table values" do
        q50 = JPEG.scale_quant_table(STANDARD_LUMINANCE_QUANT_TABLE, 50)
        q90 = JPEG.scale_quant_table(STANDARD_LUMINANCE_QUANT_TABLE, 90)

        # All values should be affected
        64.times do |i|
          q90[i].should be <= q50[i]
        end
      end
    end

    describe "Custom quantization tables" do
      it "can create custom table for specific use case" do
        # Create a custom table that emphasizes low frequencies
        custom = Array(UInt16).new(64) do |i|
          # Lower values for low frequencies (top-left)
          # Higher values for high frequencies (bottom-right)
          row = i // 8
          col = i % 8
          ((row + col) * 5 + 1).to_u16
        end

        table = QuantTable.new(custom)
        table.table[0].should eq(1)    # DC coefficient
        table.table[63].should be > 50 # High frequency
      end

      it "can scale custom tables" do
        custom = Array(UInt16).new(64, 50_u16)
        scaled = JPEG.scale_quant_table(custom, 75)

        # All values should be scaled
        scaled.all? { |v| v < 50 }.should be_true
      end
    end
  end
end
