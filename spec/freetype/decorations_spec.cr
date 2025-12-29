require "../spec_helper"

describe "Text Decorations" do
  it "creates text style with underline" do
    style = CrImage::Font::TextStyle.new(underline: true)
    style.underline.should be_true
    style.strikethrough.should be_false
  end

  it "creates text style with strikethrough" do
    style = CrImage::Font::TextStyle.new(strikethrough: true)
    style.strikethrough.should be_true
    style.underline.should be_false
  end

  it "creates text style with both decorations" do
    style = CrImage::Font::TextStyle.new(underline: true, strikethrough: true)
    style.underline.should be_true
    style.strikethrough.should be_true
  end

  it "creates text style with custom decoration color" do
    red = CrImage::Color::RGBA.new(255_u8, 0_u8, 0_u8, 255_u8)
    style = CrImage::Font::TextStyle.new(underline: true, decoration_color: red)
    style.decoration_color.should eq(red)
  end

  it "renders text with underline" do
    # Create a simple image
    img = CrImage::RGBA.new(CrImage.rect(0, 0, 200, 100))

    # Load font (skip if not available)
    font_path = "fonts/Roboto/static/Roboto-Regular.ttf"
    next unless File.exists?(font_path)

    ttf = FreeType::TrueType.load(font_path)
    face = FreeType::TrueType::Face.new(ttf, 24.0)

    # Create drawer
    white = CrImage::Uniform.new(CrImage::Color::RGBA.new(255_u8, 255_u8, 255_u8, 255_u8))
    drawer = CrImage::Font::Drawer.new(img, white, face)
    drawer.dot = CrImage::Math::Fixed::Point26_6.new(
      CrImage::Math::Fixed::Int26_6[10 * 64],
      CrImage::Math::Fixed::Int26_6[50 * 64]
    )

    # Draw with underline
    style = CrImage::Font::TextStyle.new(underline: true)
    drawer.draw_styled("Hello", style)

    # Check that something was drawn
    has_pixels = false
    img.each_pixel do |x, y|
      pixel = img.at(x, y)
      if pixel.a > 0
        has_pixels = true
        break
      end
    end

    has_pixels.should be_true
  end

  it "renders text with strikethrough" do
    # Create a simple image
    img = CrImage::RGBA.new(CrImage.rect(0, 0, 200, 100))

    # Load font (skip if not available)
    font_path = "fonts/Roboto/static/Roboto-Regular.ttf"
    next unless File.exists?(font_path)

    ttf = FreeType::TrueType.load(font_path)
    face = FreeType::TrueType::Face.new(ttf, 24.0)

    # Create drawer
    white = CrImage::Uniform.new(CrImage::Color::RGBA.new(255_u8, 255_u8, 255_u8, 255_u8))
    drawer = CrImage::Font::Drawer.new(img, white, face)
    drawer.dot = CrImage::Math::Fixed::Point26_6.new(
      CrImage::Math::Fixed::Int26_6[10 * 64],
      CrImage::Math::Fixed::Int26_6[50 * 64]
    )

    # Draw with strikethrough
    style = CrImage::Font::TextStyle.new(strikethrough: true)
    drawer.draw_styled("Hello", style)

    # Check that something was drawn
    has_pixels = false
    img.each_pixel do |x, y|
      pixel = img.at(x, y)
      if pixel.a > 0
        has_pixels = true
        break
      end
    end

    has_pixels.should be_true
  end

  it "renders text with simple underline API" do
    # Create a simple image
    img = CrImage::RGBA.new(CrImage.rect(0, 0, 200, 100))

    # Load font (skip if not available)
    font_path = "fonts/Roboto/static/Roboto-Regular.ttf"
    next unless File.exists?(font_path)

    ttf = FreeType::TrueType.load(font_path)
    face = FreeType::TrueType::Face.new(ttf, 24.0)

    # Create drawer
    white = CrImage::Uniform.new(CrImage::Color::RGBA.new(255_u8, 255_u8, 255_u8, 255_u8))
    drawer = CrImage::Font::Drawer.new(img, white, face)

    # Draw with simple API
    drawer.draw_text("Hello", 10, 50, underline: true)

    # Check that something was drawn
    has_pixels = false
    img.each_pixel do |x, y|
      pixel = img.at(x, y)
      if pixel.a > 0
        has_pixels = true
        break
      end
    end

    has_pixels.should be_true
  end

  it "renders text with simple strikethrough API" do
    # Create a simple image
    img = CrImage::RGBA.new(CrImage.rect(0, 0, 200, 100))

    # Load font (skip if not available)
    font_path = "fonts/Roboto/static/Roboto-Regular.ttf"
    next unless File.exists?(font_path)

    ttf = FreeType::TrueType.load(font_path)
    face = FreeType::TrueType::Face.new(ttf, 24.0)

    # Create drawer
    white = CrImage::Uniform.new(CrImage::Color::RGBA.new(255_u8, 255_u8, 255_u8, 255_u8))
    drawer = CrImage::Font::Drawer.new(img, white, face)

    # Draw with simple API
    drawer.draw_text("Hello", 10, 50, strikethrough: true)

    # Check that something was drawn
    has_pixels = false
    img.each_pixel do |x, y|
      pixel = img.at(x, y)
      if pixel.a > 0
        has_pixels = true
        break
      end
    end

    has_pixels.should be_true
  end

  it "renders text with colored underline using simple API" do
    # Create a simple image
    img = CrImage::RGBA.new(CrImage.rect(0, 0, 200, 100))

    # Load font (skip if not available)
    font_path = "fonts/Roboto/static/Roboto-Regular.ttf"
    next unless File.exists?(font_path)

    ttf = FreeType::TrueType.load(font_path)
    face = FreeType::TrueType::Face.new(ttf, 24.0)

    # Create drawer
    white = CrImage::Uniform.new(CrImage::Color::RGBA.new(255_u8, 255_u8, 255_u8, 255_u8))
    drawer = CrImage::Font::Drawer.new(img, white, face)

    # Draw with colored underline
    red = CrImage::Color::RGBA.new(255_u8, 0_u8, 0_u8, 255_u8)
    drawer.draw_text("Hello", 10, 50, underline: true, decoration_color: red)

    # Check that something was drawn
    has_pixels = false
    img.each_pixel do |x, y|
      pixel = img.at(x, y)
      if pixel.a > 0
        has_pixels = true
        break
      end
    end

    has_pixels.should be_true
  end
end
