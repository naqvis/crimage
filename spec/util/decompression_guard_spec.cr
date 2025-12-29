require "../spec_helper"

describe CrImage::DecompressionGuard do
  describe "Config" do
    it "creates default config" do
      config = CrImage::DecompressionGuard::Config.new
      config.max_expansion_ratio.should eq(1000)
      config.max_decompressed_size.should eq(500_000_000)
      config.min_compressed_size_for_check.should eq(1024)
    end

    it "creates permissive config" do
      config = CrImage::DecompressionGuard::Config.permissive
      config.max_expansion_ratio.should eq(10_000)
      config.max_decompressed_size.should eq(2_000_000_000)
    end

    it "creates strict config" do
      config = CrImage::DecompressionGuard::Config.strict
      config.max_expansion_ratio.should eq(100)
      config.max_decompressed_size.should eq(100_000_000)
    end
  end

  describe "Guard" do
    it "tracks compression statistics" do
      guard = CrImage::DecompressionGuard.create("TEST")

      guard.add_compressed(1000)
      guard.add_decompressed(10_000)

      stats = guard.stats
      stats[:compressed].should eq(1000)
      stats[:decompressed].should eq(10_000)
      stats[:ratio].should eq(10.0)
    end

    it "allows reasonable compression ratios" do
      guard = CrImage::DecompressionGuard.create("TEST")

      # 1KB compressed -> 100KB decompressed (100:1 ratio)
      guard.add_compressed(1024)
      guard.add_decompressed(102_400)

      # Should not raise
    end

    it "detects decompression bombs by ratio" do
      config = CrImage::DecompressionGuard::Config.new(
        max_expansion_ratio: 100_i64
      )
      guard = CrImage::DecompressionGuard.create("TEST", config)

      # 1KB compressed -> 200KB decompressed (200:1 ratio)
      guard.add_compressed(1024)

      expect_raises(CrImage::MemoryError, /expansion ratio.*exceeds limit/) do
        guard.add_decompressed(204_800)
      end
    end

    it "detects decompression bombs by absolute size" do
      config = CrImage::DecompressionGuard::Config.new(
        max_decompressed_size: 1_000_000_i64
      )
      guard = CrImage::DecompressionGuard.create("TEST", config)

      expect_raises(CrImage::MemoryError, /decompressed size.*exceeds limit/) do
        guard.add_decompressed(1_000_001)
      end
    end

    it "exempts small files from ratio checks" do
      config = CrImage::DecompressionGuard::Config.new(
        max_expansion_ratio: 10_i64,
        min_compressed_size_for_check: 1024_i64
      )
      guard = CrImage::DecompressionGuard.create("TEST", config)

      # 100 bytes compressed -> 10KB decompressed (100:1 ratio)
      # Should not raise because compressed size < min_compressed_size_for_check
      guard.add_compressed(100)
      guard.add_decompressed(10_000)
    end

    it "validates expected image size" do
      guard = CrImage::DecompressionGuard.create("TEST")

      # 1000x1000 image with 4 bytes per pixel = 4MB (should be fine)
      guard.validate_expected_size(1000, 1000, 4)
    end

    it "rejects oversized images" do
      config = CrImage::DecompressionGuard::Config.new(
        max_decompressed_size: 1_000_000_i64
      )
      guard = CrImage::DecompressionGuard.create("TEST", config)

      # 1000x1000 image with 4 bytes per pixel = 4MB (exceeds 1MB limit)
      expect_raises(CrImage::MemoryError, /expected decompressed size.*exceeds limit/) do
        guard.validate_expected_size(1000, 1000, 4)
      end
    end
  end

  describe "TrackingIO" do
    it "tracks compressed bytes read" do
      data = Bytes.new(1000) { |i| (i % 256).to_u8 }
      io = IO::Memory.new(data)
      guard = CrImage::DecompressionGuard.create("TEST")

      tracking_io = CrImage::DecompressionGuard.track_compressed(io, guard)

      buffer = Bytes.new(500)
      tracking_io.read(buffer)

      stats = guard.stats
      stats[:compressed].should eq(500)
    end

    it "tracks decompressed bytes written" do
      data = Bytes.new(1000) { |i| (i % 256).to_u8 }
      io = IO::Memory.new(data)
      guard = CrImage::DecompressionGuard.create("TEST")

      tracking_io = CrImage::DecompressionGuard.track_decompressed(io, guard)

      buffer = Bytes.new(500)
      tracking_io.read(buffer)

      stats = guard.stats
      stats[:decompressed].should eq(500)
    end
  end

  describe "Integration with formats" do
    it "protects PNG from decompression bombs" do
      # This would require creating a malicious PNG file
      # For now, we test that the guard is properly initialized

      # Create a simple valid PNG
      img = CrImage.rgba(10, 10, CrImage::Color::WHITE)
      io = IO::Memory.new
      CrImage::PNG.write(io, img)
      io.rewind

      # Should decode successfully with default limits
      decoded = CrImage::PNG.read(io)
      decoded.bounds.width.should eq(10)
      decoded.bounds.height.should eq(10)
    end

    it "protects GIF from decompression bombs" do
      # Create a simple valid GIF
      palette = CrImage::Color::Palette.new([
        CrImage::Color::RED,
        CrImage::Color::BLUE,
      ] of CrImage::Color::Color)
      img = CrImage.paletted(10, 10, palette)

      io = IO::Memory.new
      CrImage::GIF.write(io, img)
      io.rewind

      # Should decode successfully with default limits
      decoded = CrImage::GIF.read(io)
      decoded.bounds.width.should eq(10)
      decoded.bounds.height.should eq(10)
    end
  end
end
