require "../spec_helper"

describe "CrImage::GIF::Animation" do
  it "creates animation with frames" do
    img1 = CrImage.rgba(10, 10)
    img2 = CrImage.rgba(10, 10)

    frame1 = CrImage::GIF::Frame.new(img1, delay: 10)
    frame2 = CrImage::GIF::Frame.new(img2, delay: 20)

    animation = CrImage::GIF::Animation.new([frame1, frame2], 10, 10, 0)

    animation.frames.size.should eq(2)
    animation.width.should eq(10)
    animation.height.should eq(10)
    animation.loop_count.should eq(0)
  end

  it "calculates total duration" do
    img = CrImage.rgba(10, 10)

    frame1 = CrImage::GIF::Frame.new(img, delay: 10) # 100ms
    frame2 = CrImage::GIF::Frame.new(img, delay: 20) # 200ms
    frame3 = CrImage::GIF::Frame.new(img, delay: 15) # 150ms

    animation = CrImage::GIF::Animation.new([frame1, frame2, frame3], 10, 10, 0)

    # Total: 45 centiseconds = 450 milliseconds
    animation.duration.should eq(450)
  end

  it "frame has disposal method" do
    img = CrImage.rgba(10, 10)

    frame = CrImage::GIF::Frame.new(
      img,
      delay: 10,
      disposal: CrImage::GIF::DisposalMethod::RestoreToBackground
    )

    frame.disposal.should eq(CrImage::GIF::DisposalMethod::RestoreToBackground)
  end

  it "frame can have transparent index" do
    img = CrImage.rgba(10, 10)

    frame = CrImage::GIF::Frame.new(img, delay: 10, transparent_index: 5)

    frame.transparent_index.should eq(5)
  end
end
