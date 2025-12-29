require "../spec_helper"

module CrImage::JPEG
  describe "DCT Tests" do
    it "raises error for invalid block size" do
      expect_raises(ArgumentError, "Block must have 64 elements") do
        DCT.transform(Array(Int32).new(32, 0))
      end
    end

    it "transforms DC-only block" do
      # All pixels are 128 (neutral gray)
      block = Array(Int32).new(64, 128)

      result = DCT.transform(block)

      # DC coefficient should be zero for uniform 128 (shifted to 0)
      result[0].should eq(0)

      # All AC coefficients should be near zero for uniform block
      result[1..63].count { |v| v.abs < 10 }.should be > 50
    end

    it "transforms gradient block" do
      # Create a gradient from 0 to 255
      block = Array(Int32).new(64) { |i| (i * 4) }

      result = DCT.transform(block)

      # Should have non-zero DC and some AC coefficients
      result[0].should_not eq(0)
      result[1..63].any? { |v| v.abs > 10 }.should be_true
    end

    it "produces integer output" do
      block = Array(Int32).new(64) { |i| (i * 2) % 256 }

      result = DCT.transform(block)

      result.each do |val|
        val.should be_a(Int32)
      end
    end

    it "handles all-zero block" do
      block = Array(Int32).new(64, 0)

      result = DCT.transform(block)

      # DC will be non-zero (0 shifted to -128), AC should be near zero
      result[0].should_not eq(0)
      result[1..63].count { |v| v.abs < 10 }.should be > 50
    end

    it "handles all-max block" do
      block = Array(Int32).new(64, 255)

      result = DCT.transform(block)

      # DC should be large, AC should be near zero
      result[0].abs.should be > 1000
      result[1..63].count { |v| v.abs < 10 }.should be > 50
    end

    it "is deterministic" do
      block = Array(Int32).new(64) { |i| (i * 3) % 256 }

      result1 = DCT.transform(block.dup)
      result2 = DCT.transform(block.dup)

      result1.should eq(result2)
    end
  end
end
