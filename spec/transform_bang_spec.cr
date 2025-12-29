require "./spec_helper"

describe "CrImage::Transform In-place Operations" do
  it "brightness! modifies image in-place" do
    img = CrImage.rgba(10, 10)
    img.fill(CrImage::Color.rgb(100, 100, 100))

    # Get original object_id
    original_id = img.object_id

    # Apply in-place transformation
    result = img.brightness!(50)

    # Should return same object
    result.object_id.should eq(original_id)

    # Check pixel was modified
    r, g, b, _ = img.at(5, 5).rgba
    ((r >> 8).to_i).should eq(150)
    ((g >> 8).to_i).should eq(150)
    ((b >> 8).to_i).should eq(150)
  end

  it "contrast! modifies image in-place" do
    img = CrImage.rgba(10, 10)
    img.fill(CrImage::Color.rgb(128, 128, 128))

    original_id = img.object_id
    result = img.contrast!(1.5)

    result.object_id.should eq(original_id)
  end

  it "invert! modifies image in-place" do
    img = CrImage.rgba(10, 10)
    img.fill(CrImage::Color.rgb(100, 150, 200))

    original_id = img.object_id
    result = img.invert!

    result.object_id.should eq(original_id)

    # Check inversion
    r, g, b, _ = img.at(5, 5).rgba
    ((r >> 8).to_i).should eq(155)
    ((g >> 8).to_i).should eq(105)
    ((b >> 8).to_i).should eq(55)
  end

  it "blur! modifies image in-place" do
    img = CrImage.rgba(20, 20)
    img.fill(CrImage::Color::WHITE)
    img[10, 10] = CrImage::Color::BLACK

    original_id = img.object_id
    result = img.blur!(2)

    result.object_id.should eq(original_id)
  end

  it "blur_gaussian! modifies image in-place" do
    img = CrImage.rgba(20, 20)
    img.fill(CrImage::Color::WHITE)
    img[10, 10] = CrImage::Color::BLACK

    original_id = img.object_id
    result = img.blur_gaussian!(3)

    result.object_id.should eq(original_id)
  end

  it "sharpen! modifies image in-place" do
    img = CrImage.rgba(20, 20)
    img.fill(CrImage::Color.rgb(128, 128, 128))

    original_id = img.object_id
    result = img.sharpen!(1.5)

    result.object_id.should eq(original_id)
  end

  it "raises error for non-RGBA images" do
    img = CrImage.gray(10, 10)

    expect_raises(ArgumentError, "In-place operations only work on RGBA images") do
      CrImage::Transform.brightness!(img, 50)
    end
  end

  it "chainable in-place operations" do
    img = CrImage.rgba(20, 20)
    img.fill(CrImage::Color.rgb(100, 100, 100))

    original_id = img.object_id

    # Chain multiple in-place operations
    result = img.brightness!(20).contrast!(1.2).sharpen!(1.0)

    # Should still be same object
    result.object_id.should eq(original_id)
  end

  it "memory comparison: in-place vs copy" do
    # Create test image
    img1 = CrImage.rgba(100, 100)
    img1.fill(CrImage::Color.rgb(128, 128, 128))

    img2 = CrImage.rgba(100, 100)
    img2.fill(CrImage::Color.rgb(128, 128, 128))

    # In-place operation
    img1.brightness!(50)

    # Copy operation
    img2_new = img2.brightness(50)

    # img1 should be modified, img2_new should be different object
    img2_new.object_id.should_not eq(img2.object_id)
  end
end
