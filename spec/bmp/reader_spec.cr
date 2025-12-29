require "./spec_helper"

module CrImage::BMP
  it "Test that decoding a PNG image and a BMP image result in the same pixel data" do
    FILE_NAMES.each do |tc|
      img0 = CrImage.read("#{TEST_DATA}#{tc}.png")
      img1 = CrImage.read("#{TEST_DATA}#{tc}.bmp")
      compare(img0, img1)
    end
  end

  it "Test that decoding an empty BMP image return Error" do
    expect_raises(CrImage::UnknownFormat) do
      CrImage.read(IO::Memory.new)
    end
  end
end
