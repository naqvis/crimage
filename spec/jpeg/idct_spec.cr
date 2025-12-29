require "../spec_helper"

describe CrImage::JPEG::IDCT do
  describe ".transform" do
    it "raises error for invalid block size" do
      expect_raises(ArgumentError, "Block must have 64 elements") do
        CrImage::JPEG::IDCT.transform(Array(Int32).new(32, 0))
      end
    end

    it "performs IDCT on DC-only block" do
      # DC-only block (all AC coefficients are zero)
      block = Array(Int32).new(64, 0)
      block[0] = 1024 # DC coefficient

      result = CrImage::JPEG::IDCT.transform(block)

      # All pixels should be similar (uniform)
      result.size.should eq(64)
      result.all? { |v| v >= 0 && v <= 255 }.should be_true
    end

    it "clamps output values to valid pixel range" do
      # Create a block with large but realistic DCT coefficient values
      block = Array(Int32).new(64, 0)
      block[0] = 2048 # Large DC coefficient
      block[1] = 512  # Large AC coefficient
      block[8] = -512 # Negative AC coefficient

      result = CrImage::JPEG::IDCT.transform(block)

      # All values should be clamped to 0-255
      result.all? { |v| v >= 0 && v <= 255 }.should be_true
    end

    it "produces valid pixel values for typical DCT coefficients" do
      # Simulate typical DCT coefficients
      block = Array(Int32).new(64, 0)
      block[0] = 512 # DC
      block[1] = 100 # Low frequency AC
      block[2] = 50

      result = CrImage::JPEG::IDCT.transform(block)

      result.size.should eq(64)
      result.all? { |v| v >= 0 && v <= 255 }.should be_true
    end
  end
end
