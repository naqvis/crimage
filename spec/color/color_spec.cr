require "../spec_helper"

# canonical sq_diff implementation
private def orig(x, y)
  if x > y
    d = (x - y).to_u32
  else
    d = (y - x).to_u32
  end
  ((d &* d) >> 2).to_u32
end

module CrImage::Color
  describe "Color" do
    it "Test Square Diff" do
      tests = [
        0,
        1,
        2,
        0x0fffd,
        0x0fffe,
        0x0ffff,
        0x10000,
        0x10001,
        0x10002,
        0xfffffffd,
        0xfffffffe,
        0xffffffff,
      ]

      tests.each do |x|
        tests.each do |y|
          got = sq_diff(x.to_u32, y.to_u32)
          want = orig(x.to_u32, y.to_u32)
          got.should eq(want)
        end
      end
    end
  end
end

describe "Color blending and distance" do
  it "blends two colors at 0.0 ratio" do
    result = CrImage::Color.blend(CrImage::Color::RED, CrImage::Color::BLUE, 0.0)
    result.r.should eq(255)
    result.g.should eq(0)
    result.b.should eq(0)
  end

  it "blends two colors at 1.0 ratio" do
    result = CrImage::Color.blend(CrImage::Color::RED, CrImage::Color::BLUE, 1.0)
    result.r.should eq(0)
    result.g.should eq(0)
    result.b.should eq(255)
  end

  it "blends two colors at 0.5 ratio" do
    result = CrImage::Color.blend(CrImage::Color::RED, CrImage::Color::BLUE, 0.5)
    result.r.should eq(128) # 255 * 0.5 = 127.5, rounds to 128
    result.b.should eq(128)
  end

  it "mixes multiple colors" do
    colors = [CrImage::Color::RED, CrImage::Color::GREEN, CrImage::Color::BLUE] of CrImage::Color::Color
    result = CrImage::Color.mix(colors)
    result.r.should eq(85) # 255/3
    result.g.should eq(85)
    result.b.should eq(85)
  end

  it "calculates distance between identical colors" do
    dist = CrImage::Color.distance(CrImage::Color::RED, CrImage::Color::RED)
    dist.should eq(0.0)
  end

  it "calculates distance between different colors" do
    dist = CrImage::Color.distance(CrImage::Color::RED, CrImage::Color::BLUE)
    dist.should be > 300.0 # sqrt(255^2 + 255^2) ≈ 360.6
  end

  it "calculates distance between black and white" do
    black = CrImage::Color::RGBA.new(0, 0, 0, 255)
    white = CrImage::Color::RGBA.new(255, 255, 255, 255)
    dist = CrImage::Color.distance(black, white)
    dist.should be_close(441.67, 0.1) # sqrt(3 * 255^2)
  end
end

describe "RGBA methods" do
  it "blends with another color" do
    result = CrImage::Color::RED.blend(CrImage::Color::BLUE, 0.5)
    result.r.should eq(128) # 255 * 0.5 = 127.5, rounds to 128
    result.b.should eq(128)
  end

  it "calculates distance to another color" do
    dist = CrImage::Color::RED.distance(CrImage::Color::BLUE)
    dist.should be > 300.0
  end

  it "checks similarity within threshold" do
    c1 = CrImage::Color::RGBA.new(100, 100, 100, 255)
    c2 = CrImage::Color::RGBA.new(110, 100, 100, 255)
    c1.similar?(c2, threshold: 20.0).should be_true
    c1.similar?(c2, threshold: 5.0).should be_false
  end

  it "gets complement color" do
    comp = CrImage::Color::RED.complement
    comp.r.should eq(0)
    comp.g.should eq(255)
    comp.b.should eq(255)
  end

  it "calculates luminance" do
    # White should have high luminance
    white = CrImage::Color::RGBA.new(255, 255, 255, 255)
    white.luminance.should eq(255)

    # Black should have zero luminance
    black = CrImage::Color::RGBA.new(0, 0, 0, 255)
    black.luminance.should eq(0)

    # Red has specific luminance based on coefficients
    red_lum = CrImage::Color::RED.luminance
    red_lum.should be > 50
    red_lum.should be < 100
  end
end

describe "Color.to_rgba8" do
  it "converts 16-bit color to 8-bit RGBA" do
    color = CrImage::Color::RGBA64.new(0xFFFF_u16, 0x8000_u16, 0x0000_u16, 0xFFFF_u16)
    rgba8 = color.to_rgba8

    rgba8.r.should eq(255)
    rgba8.g.should eq(128)
    rgba8.b.should eq(0)
    rgba8.a.should eq(255)
  end

  it "converts Gray16 to 8-bit RGBA" do
    gray = CrImage::Color::Gray16.new(0x8080_u16)
    rgba8 = gray.to_rgba8

    rgba8.r.should eq(128)
    rgba8.g.should eq(128)
    rgba8.b.should eq(128)
  end

  it "works with standard colors" do
    rgba8 = CrImage::Color::RED.to_rgba8
    rgba8.r.should eq(255)
    rgba8.g.should eq(0)
    rgba8.b.should eq(0)
    rgba8.a.should eq(255)
  end

  it "preserves 8-bit RGBA values" do
    original = CrImage::Color::RGBA.new(100_u8, 150_u8, 200_u8, 250_u8)
    rgba8 = original.to_rgba8

    rgba8.r.should eq(100)
    rgba8.g.should eq(150)
    rgba8.b.should eq(200)
    rgba8.a.should eq(250)
  end
end
