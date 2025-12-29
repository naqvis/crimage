require "../spec_helper"

describe CrImage::EXIF do
  describe "Orientation enum" do
    it "has correct values" do
      CrImage::EXIF::Orientation::Normal.value.should eq(1)
      CrImage::EXIF::Orientation::Rotate90CW.value.should eq(6)
      CrImage::EXIF::Orientation::Rotate180.value.should eq(3)
      CrImage::EXIF::Orientation::Rotate270CW.value.should eq(8)
    end
  end

  describe "Rational" do
    it "converts to float" do
      r = CrImage::EXIF::Rational.new(1, 2)
      r.to_f.should eq(0.5)
    end

    it "handles zero denominator" do
      r = CrImage::EXIF::Rational.new(1, 0)
      r.to_f.should eq(0.0)
    end
  end

  describe "SRational" do
    it "converts to float" do
      r = CrImage::EXIF::SRational.new(-1, 2)
      r.to_f.should eq(-0.5)
    end
  end

  describe "GPSCoordinates" do
    it "stores latitude and longitude" do
      gps = CrImage::EXIF::GPSCoordinates.new(37.7749, -122.4194)
      gps.latitude.should eq(37.7749)
      gps.longitude.should eq(-122.4194)
      gps.altitude.should be_nil
    end

    it "stores altitude" do
      gps = CrImage::EXIF::GPSCoordinates.new(37.7749, -122.4194, 10.5)
      gps.altitude.should eq(10.5)
    end

    it "generates Google Maps URL" do
      gps = CrImage::EXIF::GPSCoordinates.new(37.7749, -122.4194)
      gps.google_maps_url.should eq("https://www.google.com/maps?q=37.7749,-122.4194")
    end

    it "converts to tuple" do
      gps = CrImage::EXIF::GPSCoordinates.new(37.7749, -122.4194)
      gps.to_tuple.should eq({37.7749, -122.4194})
    end
  end

  describe "Data" do
    it "returns default orientation when empty" do
      data = CrImage::EXIF::Data.new
      data.orientation.should eq(CrImage::EXIF::Orientation::Normal)
      data.needs_transform?.should be_false
    end

    it "reports empty correctly" do
      data = CrImage::EXIF::Data.new
      data.empty?.should be_true
    end

    it "reports has_gps? correctly when no GPS" do
      data = CrImage::EXIF::Data.new
      data.has_gps?.should be_false
    end
  end

  describe "TagValue" do
    it "converts u8 to various types" do
      val = CrImage::EXIF::TagValue.new(42_u8)
      val.as_u8.should eq(42_u8)
      val.as_u16.should eq(42_u16)
      val.as_u32.should eq(42_u32)
      val.as_string.should be_nil
    end

    it "converts u16 to various types" do
      val = CrImage::EXIF::TagValue.new(1000_u16)
      val.as_u8.should be_nil # Out of range
      val.as_u16.should eq(1000_u16)
      val.as_u32.should eq(1000_u32)

      # Value in range
      val2 = CrImage::EXIF::TagValue.new(200_u16)
      val2.as_u8.should eq(200_u8)
    end

    it "handles string values" do
      val = CrImage::EXIF::TagValue.new("Test Camera")
      val.as_string.should eq("Test Camera")
      val.as_u8.should be_nil
    end

    it "handles rational values" do
      r = CrImage::EXIF::Rational.new(1, 100)
      val = CrImage::EXIF::TagValue.new(r)
      val.as_rational.should eq(r)
      val.as_rational.not_nil!.to_f.should eq(0.01)
    end

    it "handles rational array values" do
      arr = [
        CrImage::EXIF::Rational.new(37, 1),
        CrImage::EXIF::Rational.new(46, 1),
        CrImage::EXIF::Rational.new(30, 1),
      ]
      val = CrImage::EXIF::TagValue.new(arr)
      val.as_rational_array.should eq(arr)
    end
  end

  describe "Reader" do
    describe ".read_raw" do
      it "returns nil for empty data" do
        CrImage::EXIF::Reader.read_raw(Bytes.empty).should be_nil
      end

      it "returns nil for data too small" do
        CrImage::EXIF::Reader.read_raw(Bytes.new(4)).should be_nil
      end

      it "returns nil for invalid byte order" do
        data = Bytes.new(8)
        data[0] = 'X'.ord.to_u8
        data[1] = 'X'.ord.to_u8
        CrImage::EXIF::Reader.read_raw(data).should be_nil
      end

      it "parses little-endian TIFF header" do
        # Minimal valid TIFF structure with no IFD entries
        data = Bytes.new(16)
        data[0] = 'I'.ord.to_u8 # Little-endian
        data[1] = 'I'.ord.to_u8
        data[2] = 42_u8 # TIFF magic (little-endian)
        data[3] = 0_u8
        data[4] = 8_u8 # IFD offset = 8
        data[5] = 0_u8
        data[6] = 0_u8
        data[7] = 0_u8
        # IFD at offset 8: 0 entries
        data[8] = 0_u8
        data[9] = 0_u8

        result = CrImage::EXIF::Reader.read_raw(data)
        result.should_not be_nil
        result.not_nil!.empty?.should be_true
      end

      it "parses big-endian TIFF header" do
        data = Bytes.new(16)
        data[0] = 'M'.ord.to_u8 # Big-endian
        data[1] = 'M'.ord.to_u8
        data[2] = 0_u8 # TIFF magic (big-endian)
        data[3] = 42_u8
        data[4] = 0_u8 # IFD offset = 8
        data[5] = 0_u8
        data[6] = 0_u8
        data[7] = 8_u8
        # IFD at offset 8: 0 entries
        data[8] = 0_u8
        data[9] = 0_u8

        result = CrImage::EXIF::Reader.read_raw(data)
        result.should_not be_nil
      end

      it "parses orientation tag" do
        # Build minimal EXIF with orientation = 6 (Rotate90CW)
        data = build_exif_with_orientation(6_u16)
        result = CrImage::EXIF::Reader.read_raw(data)

        result.should_not be_nil
        result.not_nil!.orientation.should eq(CrImage::EXIF::Orientation::Rotate90CW)
        result.not_nil!.needs_transform?.should be_true
      end

      it "parses string tags" do
        data = build_exif_with_string(CrImage::EXIF::Tag::Make.value, "TestMake")
        result = CrImage::EXIF::Reader.read_raw(data)

        result.should_not be_nil
        result.not_nil!.make.should eq("TestMake")
      end
    end

    describe ".read" do
      it "returns nil for non-existent file" do
        CrImage::EXIF.read("nonexistent.jpg").should be_nil
      end

      it "returns nil for PNG without EXIF" do
        CrImage::EXIF.read("spec/testdata/video-001.png").should be_nil
      end
    end
  end
end

# Helper to build minimal EXIF data with orientation
private def build_exif_with_orientation(orientation : UInt16) : Bytes
  # Little-endian TIFF with one IFD entry (orientation)
  # Total size: 8 (header) + 2 (count) + 12 (entry) + 4 (next IFD) = 26 bytes
  data = Bytes.new(26)

  # TIFF header
  data[0] = 'I'.ord.to_u8
  data[1] = 'I'.ord.to_u8
  data[2] = 42_u8
  data[3] = 0_u8
  data[4] = 8_u8 # IFD offset
  data[5] = 0_u8
  data[6] = 0_u8
  data[7] = 0_u8

  # IFD0 at offset 8
  data[8] = 1_u8 # 1 entry
  data[9] = 0_u8

  # Entry: Orientation (0x0112), SHORT (3), count=1, value=orientation
  data[10] = 0x12_u8 # Tag low byte
  data[11] = 0x01_u8 # Tag high byte
  data[12] = 3_u8    # Type = SHORT
  data[13] = 0_u8
  data[14] = 1_u8 # Count = 1
  data[15] = 0_u8
  data[16] = 0_u8
  data[17] = 0_u8
  data[18] = (orientation & 0xFF).to_u8        # Value low byte
  data[19] = ((orientation >> 8) & 0xFF).to_u8 # Value high byte
  data[20] = 0_u8
  data[21] = 0_u8

  # Next IFD offset = 0 (none)
  data[22] = 0_u8
  data[23] = 0_u8
  data[24] = 0_u8
  data[25] = 0_u8

  data
end

# Helper to build minimal EXIF data with a string tag
private def build_exif_with_string(tag : UInt16, value : String) : Bytes
  str_bytes = value.to_slice
  str_len = str_bytes.size + 1 # Include null terminator

  # Header (8) + count (2) + entry (12) + next IFD (4) + string data
  total_size = 8 + 2 + 12 + 4 + str_len
  data = Bytes.new(total_size)

  # TIFF header
  data[0] = 'I'.ord.to_u8
  data[1] = 'I'.ord.to_u8
  data[2] = 42_u8
  data[3] = 0_u8
  data[4] = 8_u8
  data[5] = 0_u8
  data[6] = 0_u8
  data[7] = 0_u8

  # IFD0 at offset 8
  data[8] = 1_u8
  data[9] = 0_u8

  # Entry: tag, ASCII (2), count=str_len, offset to string
  data[10] = (tag & 0xFF).to_u8
  data[11] = ((tag >> 8) & 0xFF).to_u8
  data[12] = 2_u8 # Type = ASCII
  data[13] = 0_u8
  data[14] = (str_len & 0xFF).to_u8
  data[15] = ((str_len >> 8) & 0xFF).to_u8
  data[16] = 0_u8
  data[17] = 0_u8

  string_offset = 26_u32 # After IFD
  if str_len <= 4
    # Inline value
    str_bytes.each_with_index { |b, i| data[18 + i] = b }
  else
    # Offset to string
    data[18] = (string_offset & 0xFF).to_u8
    data[19] = ((string_offset >> 8) & 0xFF).to_u8
    data[20] = 0_u8
    data[21] = 0_u8
  end

  # Next IFD offset = 0
  data[22] = 0_u8
  data[23] = 0_u8
  data[24] = 0_u8
  data[25] = 0_u8

  # String data (if not inline)
  if str_len > 4
    str_bytes.each_with_index { |b, i| data[26 + i] = b }
    data[26 + str_bytes.size] = 0_u8 # Null terminator
  end

  data
end

describe CrImage::Transform do
  describe ".auto_orient" do
    it "returns copy for normal orientation" do
      img = CrImage.rgba(100, 50, CrImage::Color::RED)
      result = CrImage::Transform.auto_orient(img, CrImage::EXIF::Orientation::Normal)
      result.bounds.width.should eq(100)
      result.bounds.height.should eq(50)
    end

    it "rotates 90 degrees for Rotate90CW orientation" do
      img = CrImage.rgba(100, 50, CrImage::Color::RED)
      result = CrImage::Transform.auto_orient(img, CrImage::EXIF::Orientation::Rotate90CW)
      # Width and height should be swapped
      result.bounds.width.should eq(50)
      result.bounds.height.should eq(100)
    end

    it "rotates 180 degrees for Rotate180 orientation" do
      img = CrImage.rgba(100, 50, CrImage::Color::RED)
      result = CrImage::Transform.auto_orient(img, CrImage::EXIF::Orientation::Rotate180)
      result.bounds.width.should eq(100)
      result.bounds.height.should eq(50)
    end

    it "rotates 270 degrees for Rotate270CW orientation" do
      img = CrImage.rgba(100, 50, CrImage::Color::RED)
      result = CrImage::Transform.auto_orient(img, CrImage::EXIF::Orientation::Rotate270CW)
      result.bounds.width.should eq(50)
      result.bounds.height.should eq(100)
    end

    it "flips horizontal for FlipHorizontal orientation" do
      img = CrImage.rgba(100, 50)
      img.set(0, 0, CrImage::Color::RED)
      result = CrImage::Transform.auto_orient(img, CrImage::EXIF::Orientation::FlipHorizontal)
      # Red pixel should now be at right edge
      result.at(99, 0).rgba[0].should be > 0 # Red channel
    end

    it "flips vertical for FlipVertical orientation" do
      img = CrImage.rgba(100, 50)
      img.set(0, 0, CrImage::Color::RED)
      result = CrImage::Transform.auto_orient(img, CrImage::EXIF::Orientation::FlipVertical)
      # Red pixel should now be at bottom
      result.at(0, 49).rgba[0].should be > 0 # Red channel
    end

    it "accepts integer orientation value" do
      img = CrImage.rgba(100, 50, CrImage::Color::RED)
      result = CrImage::Transform.auto_orient(img, 6) # Rotate90CW
      result.bounds.width.should eq(50)
      result.bounds.height.should eq(100)
    end

    it "handles invalid integer orientation as normal" do
      img = CrImage.rgba(100, 50, CrImage::Color::RED)
      result = CrImage::Transform.auto_orient(img, 99) # Invalid
      result.bounds.width.should eq(100)
      result.bounds.height.should eq(50)
    end
  end
end

describe CrImage::Image do
  describe "#auto_orient" do
    it "applies orientation transform via extension method" do
      img = CrImage.rgba(100, 50, CrImage::Color::RED)
      result = img.auto_orient(CrImage::EXIF::Orientation::Rotate90CW)
      result.bounds.width.should eq(50)
      result.bounds.height.should eq(100)
    end

    it "accepts integer orientation" do
      img = CrImage.rgba(100, 50, CrImage::Color::RED)
      result = img.auto_orient(6)
      result.bounds.width.should eq(50)
      result.bounds.height.should eq(100)
    end
  end
end

# Tests using real EXIF sample images from https://github.com/ianare/exif-samples
describe "Real EXIF samples" do
  describe "Canon_40D.jpg" do
    it "reads camera make and model" do
      exif = CrImage::EXIF.read("spec/testdata/exif/Canon_40D.jpg")
      exif.should_not be_nil
      exif = exif.not_nil!

      exif.make.should eq("Canon")
      exif.model.should eq("Canon EOS 40D")
      exif.camera.should eq("Canon Canon EOS 40D")
    end

    it "reads orientation" do
      exif = CrImage::EXIF.read("spec/testdata/exif/Canon_40D.jpg").not_nil!
      exif.orientation.should eq(CrImage::EXIF::Orientation::Normal)
      exif.needs_transform?.should be_false
    end

    it "reads date/time" do
      exif = CrImage::EXIF.read("spec/testdata/exif/Canon_40D.jpg").not_nil!
      exif.date_time.should_not be_nil
      exif.date_time.not_nil!.year.should eq(2008)
      exif.date_time.not_nil!.month.should eq(7)
      exif.date_time.not_nil!.day.should eq(31)

      exif.date_time_original.should_not be_nil
      exif.date_time_original.not_nil!.year.should eq(2008)
      exif.date_time_original.not_nil!.month.should eq(5)
      exif.date_time_original.not_nil!.day.should eq(30)
    end

    it "reads exposure settings" do
      exif = CrImage::EXIF.read("spec/testdata/exif/Canon_40D.jpg").not_nil!
      exif.iso.should eq(100)
      exif.f_number.should eq(7.1)
      exif.focal_length.should eq(135.0)
    end

    it "has no GPS data" do
      exif = CrImage::EXIF.read("spec/testdata/exif/Canon_40D.jpg").not_nil!
      exif.has_gps?.should be_false
      exif.gps.should be_nil
    end
  end

  describe "Fujifilm_FinePix_E500.jpg" do
    it "reads camera info" do
      exif = CrImage::EXIF.read("spec/testdata/exif/Fujifilm_FinePix_E500.jpg")
      exif.should_not be_nil
      exif = exif.not_nil!

      exif.make.should eq("FUJIFILM")
      exif.model.not_nil!.should contain("FinePix E500")
    end

    it "reads exposure settings" do
      exif = CrImage::EXIF.read("spec/testdata/exif/Fujifilm_FinePix_E500.jpg").not_nil!
      exif.iso.should eq(100)
      exif.f_number.not_nil!.should be_close(2.9, 0.1)
      exif.focal_length.not_nil!.should be_close(4.7, 0.1)
    end
  end

  describe "gps_sample.jpg (DSCN0010)" do
    it "reads camera info" do
      exif = CrImage::EXIF.read("spec/testdata/exif/gps_sample.jpg")
      exif.should_not be_nil
      exif = exif.not_nil!

      exif.make.should eq("NIKON")
      exif.model.should eq("COOLPIX P6000")
    end

    it "has GPS data" do
      exif = CrImage::EXIF.read("spec/testdata/exif/gps_sample.jpg").not_nil!
      exif.has_gps?.should be_true
      exif.gps.should_not be_nil
    end

    it "reads GPS coordinates correctly" do
      exif = CrImage::EXIF.read("spec/testdata/exif/gps_sample.jpg").not_nil!
      gps = exif.gps.not_nil!

      # Location is in Tuscany, Italy (approximately 43.467°N, 11.885°E)
      gps.latitude.should be_close(43.467, 0.01)
      gps.longitude.should be_close(11.885, 0.01)
    end

    it "generates Google Maps URL" do
      exif = CrImage::EXIF.read("spec/testdata/exif/gps_sample.jpg").not_nil!
      gps = exif.gps.not_nil!

      url = gps.google_maps_url
      url.should contain("google.com/maps")
      url.should contain("43.46")
      url.should contain("11.88")
    end

    it "reads exposure settings" do
      exif = CrImage::EXIF.read("spec/testdata/exif/gps_sample.jpg").not_nil!
      exif.iso.should eq(64)
      exif.f_number.not_nil!.should be_close(5.9, 0.1)
      exif.focal_length.should eq(24.0)
    end
  end

  describe "Nikon_D70.jpg" do
    it "reads camera info" do
      exif = CrImage::EXIF.read("spec/testdata/exif/Nikon_D70.jpg")
      exif.should_not be_nil
      exif = exif.not_nil!

      exif.make.should eq("NIKON CORPORATION")
      exif.model.should eq("NIKON D70")
    end

    it "reads exposure settings" do
      exif = CrImage::EXIF.read("spec/testdata/exif/Nikon_D70.jpg").not_nil!
      exif.iso.should eq(200)
      exif.f_number.should eq(9.0)
      exif.focal_length.should eq(100.0)
    end
  end

  describe "Image loading with EXIF" do
    it "loads image and reads EXIF separately" do
      img = CrImage::JPEG.read("spec/testdata/exif/Canon_40D.jpg")
      exif = CrImage::EXIF.read("spec/testdata/exif/Canon_40D.jpg")

      img.should_not be_nil
      exif.should_not be_nil

      img.bounds.width.should be > 0
      img.bounds.height.should be > 0
      exif.not_nil!.make.should eq("Canon")
    end

    it "can auto-orient image based on EXIF" do
      img = CrImage::JPEG.read("spec/testdata/exif/Canon_40D.jpg")
      exif = CrImage::EXIF.read("spec/testdata/exif/Canon_40D.jpg").not_nil!

      # This image has normal orientation, so dimensions should stay the same
      original_width = img.bounds.width
      original_height = img.bounds.height

      oriented = img.auto_orient(exif.orientation)
      oriented.bounds.width.should eq(original_width)
      oriented.bounds.height.should eq(original_height)
    end
  end
end
