require "../spec_helper"

module CrImage::BMP
  TEST_DATA  = "#{__DIR__}/../testdata/bmp/"
  FILE_NAMES = [
    "colormap",
    "video-001",
    "gradient-small",
    "gradient-small-v5",
  ]

  def self.compare(img0, img1)
    b = img1.bounds
    fail "wrong image size: want #{img0.bounds}, got: #{b}" unless b == img0.bounds
    b.min.y.step(to: b.max.y - 1, by: 1) do |y|
      b.min.x.step(to: b.max.x - 1, by: 1) do |x|
        c0 = img0.at(x, y)
        c1 = img1.at(x, y)
        r0, g0, b0, a0 = c0.rgba
        r1, g1, b1, a1 = c1.rgba
        fail "pixel at (#{x},#{y}) has wrong color: want #{c0}, got #{c1}" unless r0 == r1 && g0 == g1 && b0 == b1 && a0 == a1
      end
    end
  end
end
