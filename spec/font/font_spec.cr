require "../spec_helper"

module CrImage::Font
  describe "Font Metrics Tests" do
    it "creates metrics" do
      metrics = Metrics.new(
        height: Math::Fixed::Int26_6[1000],
        ascent: Math::Fixed::Int26_6[800],
        descent: Math::Fixed::Int26_6[200],
        x_height: Math::Fixed::Int26_6[500],
        cap_height: Math::Fixed::Int26_6[700],
        caret_slope: CrImage::Point.new(0, 1)
      )

      metrics.height.floor.should eq(15)
      metrics.ascent.floor.should eq(12)
      metrics.descent.floor.should eq(3)
    end

    it "creates default metrics" do
      metrics = Metrics.new
      metrics.height.floor.should eq(0)
    end
  end

  describe "Font Enums Tests" do
    it "defines hinting values" do
      Hinting::None.value.should eq(0)
      Hinting::Vertical.value.should eq(1)
      Hinting::Full.value.should eq(2)
    end

    it "defines stretch values" do
      Stretch::Normal.value.should eq(0)
      Stretch::Condensed.value.should eq(-2)
      Stretch::Expanded.value.should eq(2)
    end

    it "defines style values" do
      Style::Normal.value.should eq(0)
      Style::Italic.value.should eq(1)
      Style::Oblique.value.should eq(2)
    end

    it "defines weight values" do
      Weight::Normal.value.should eq(0)
      Weight::Light.value.should eq(-1)
      Weight::Bold.value.should eq(3)
      Weight::Black.value.should eq(5)
    end
  end
end
