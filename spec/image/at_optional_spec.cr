require "../spec_helper"

describe "Image at? method" do
  it "returns color for in-bounds coordinates" do
    img = CrImage.rgba(100, 100)
    img.set(50, 50, CrImage::Color::RED)

    color = img.at?(50, 50)
    color.should_not be_nil
    if c = color
      c.should be_a(CrImage::Color::RGBA)
      rgba = c.as(CrImage::Color::RGBA)
      rgba.r.should eq(255)
      rgba.g.should eq(0)
      rgba.b.should eq(0)
    end
  end

  it "returns nil for out-of-bounds coordinates" do
    img = CrImage.rgba(100, 100)

    img.at?(200, 200).should be_nil
    img.at?(-1, 50).should be_nil
    img.at?(50, -1).should be_nil
    img.at?(100, 100).should be_nil # max is exclusive
  end

  it "works with different image types" do
    # RGBA
    rgba_img = CrImage.rgba(10, 10)
    rgba_img.at?(5, 5).should_not be_nil
    rgba_img.at?(20, 20).should be_nil

    # Gray
    gray_img = CrImage.gray(10, 10)
    gray_img.at?(5, 5).should_not be_nil
    gray_img.at?(20, 20).should be_nil

    # NRGBA
    nrgba_img = CrImage.nrgba(10, 10)
    nrgba_img.at?(5, 5).should_not be_nil
    nrgba_img.at?(20, 20).should be_nil
  end

  it "can be used in conditional checks" do
    img = CrImage.rgba(100, 100)
    img.set(50, 50, CrImage::Color::BLUE)

    # Pattern matching style
    if color = img.at?(50, 50)
      color.should be_a(CrImage::Color::RGBA)
    else
      fail "Should have returned a color"
    end

    # Nil check
    if color = img.at?(200, 200)
      fail "Should have returned nil"
    else
      # Expected
    end
  end

  it "at? vs at behavior comparison" do
    img = CrImage.rgba(100, 100)

    # In bounds - both return color
    color_at = img.at(50, 50)
    color_at_opt = img.at?(50, 50)

    color_at.should be_a(CrImage::Color::RGBA)
    color_at_opt.should_not be_nil

    # Out of bounds - at returns default, at? returns nil
    default_color = img.at(200, 200)
    nil_color = img.at?(200, 200)

    default_color.should be_a(CrImage::Color::RGBA) # Returns default
    nil_color.should be_nil                         # Returns nil
  end
end
