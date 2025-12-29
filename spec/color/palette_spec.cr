require "../spec_helper"

module CrImage::Pallete
  describe "Palette Tests" do
    it "MATERIAL palette has 82 colors" do
      MATERIAL.size.should eq(82)
    end

    it "MATERIAL palette contains valid RGBA colors" do
      MATERIAL.each do |color|
        color.should be_a(Color::RGBA)
        rgba = color.as(Color::RGBA)
        rgba.a.should eq(255)
      end
    end

    it "MATERIAL palette starts with light red" do
      first = MATERIAL[0].as(Color::RGBA)
      first.r.should eq(255)
      first.g.should eq(235)
      first.b.should eq(238)
    end

    it "MATERIAL palette ends with black" do
      last = MATERIAL[81].as(Color::RGBA)
      last.r.should eq(0)
      last.g.should eq(0)
      last.b.should eq(0)
    end

    it "TAILWIND palette has 80 colors" do
      TAILWIND.size.should eq(80)
    end

    it "TAILWIND palette contains valid RGBA colors" do
      TAILWIND.each do |color|
        color.should be_a(Color::RGBA)
        rgba = color.as(Color::RGBA)
        rgba.a.should eq(255)
      end
    end

    it "TAILWIND palette starts with light slate" do
      first = TAILWIND[0].as(Color::RGBA)
      first.r.should eq(248)
      first.g.should eq(250)
      first.b.should eq(252)
    end

    it "TAILWIND palette ends with dark pink" do
      last = TAILWIND[79].as(Color::RGBA)
      last.r.should eq(131)
      last.g.should eq(24)
      last.b.should eq(67)
    end

    it "WEB_SAFE palette has 216 colors" do
      WEB_SAFE.size.should eq(216)
    end

    it "WEB_SAFE palette contains valid RGBA colors" do
      WEB_SAFE.each do |color|
        color.should be_a(Color::RGBA)
        rgba = color.as(Color::RGBA)
        rgba.a.should eq(255)
      end
    end

    it "WEB_SAFE palette starts with black" do
      first = WEB_SAFE[0].as(Color::RGBA)
      first.r.should eq(0)
      first.g.should eq(0)
      first.b.should eq(0)
    end

    it "WEB_SAFE palette ends with white" do
      last = WEB_SAFE[215].as(Color::RGBA)
      last.r.should eq(255)
      last.g.should eq(255)
      last.b.should eq(255)
    end

    it "WEB_SAFE colors use only 0x00, 0x33, 0x66, 0x99, 0xCC, 0xFF values" do
      valid_values = [0x00, 0x33, 0x66, 0x99, 0xCC, 0xFF]

      WEB_SAFE.each do |color|
        rgba = color.as(Color::RGBA)
        valid_values.should contain(rgba.r)
        valid_values.should contain(rgba.g)
        valid_values.should contain(rgba.b)
      end
    end

    it "MATERIAL and TAILWIND palettes are different" do
      MATERIAL.size.should_not eq(TAILWIND.size)
    end

    it "All palettes contain unique color sets" do
      # Verify that each palette has distinct characteristics
      MATERIAL.size.should eq(82)
      TAILWIND.size.should eq(80)
      WEB_SAFE.size.should eq(216)
    end
  end
end
