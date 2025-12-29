require "../spec_helper"

describe "FreeType Ligatures" do
  describe "GSUB ligature lookup" do
    it "detects GSUB table in Roboto font" do
      font = load_roboto_bold
      font.has_gsub?.should be_true
    end

    it "finds fi ligature" do
      font = load_roboto_bold
      f_glyph = font.glyph_index('f').to_u16
      i_glyph = font.glyph_index('i').to_u16

      glyphs = [f_glyph, i_glyph]
      lig, consumed = font.lookup_ligature(glyphs)

      lig.should be > 0
      consumed.should eq(2)
    end

    it "finds fl ligature" do
      font = load_roboto_bold
      f_glyph = font.glyph_index('f').to_u16
      l_glyph = font.glyph_index('l').to_u16

      glyphs = [f_glyph, l_glyph]
      lig, consumed = font.lookup_ligature(glyphs)

      lig.should be > 0
      consumed.should eq(2)
    end

    it "finds ffi ligature (3 glyphs)" do
      font = load_roboto_bold
      f_glyph = font.glyph_index('f').to_u16
      i_glyph = font.glyph_index('i').to_u16

      glyphs = [f_glyph, f_glyph, i_glyph]
      lig, consumed = font.lookup_ligature(glyphs)

      lig.should be > 0
      consumed.should eq(3)
    end

    it "returns zero for non-ligature pairs" do
      font = load_roboto_bold
      a_glyph = font.glyph_index('a').to_u16
      b_glyph = font.glyph_index('b').to_u16

      glyphs = [a_glyph, b_glyph]
      lig, consumed = font.lookup_ligature(glyphs)

      lig.should eq(0)
      consumed.should eq(0)
    end

    it "handles start_index parameter" do
      font = load_roboto_bold
      a_glyph = font.glyph_index('a').to_u16
      f_glyph = font.glyph_index('f').to_u16
      i_glyph = font.glyph_index('i').to_u16

      # "afi" - ligature starts at index 1
      glyphs = [a_glyph, f_glyph, i_glyph]

      # No ligature at index 0
      lig, consumed = font.lookup_ligature(glyphs, 0)
      lig.should eq(0)

      # fi ligature at index 1
      lig, consumed = font.lookup_ligature(glyphs, 1)
      lig.should be > 0
      consumed.should eq(2)
    end

    it "prefers longer ligatures" do
      font = load_roboto_bold
      f_glyph = font.glyph_index('f').to_u16
      i_glyph = font.glyph_index('i').to_u16

      # "ffi" should match ffi ligature (3), not fi (2)
      glyphs = [f_glyph, f_glyph, i_glyph]
      lig, consumed = font.lookup_ligature(glyphs)

      consumed.should eq(3) # ffi, not fi
    end

    it "returns zero for empty glyph array" do
      font = load_roboto_bold
      glyphs = [] of UInt16

      lig, consumed = font.lookup_ligature(glyphs)
      lig.should eq(0)
      consumed.should eq(0)
    end

    it "returns zero for out of bounds start_index" do
      font = load_roboto_bold
      f_glyph = font.glyph_index('f').to_u16
      i_glyph = font.glyph_index('i').to_u16

      glyphs = [f_glyph, i_glyph]
      lig, consumed = font.lookup_ligature(glyphs, 5)

      lig.should eq(0)
      consumed.should eq(0)
    end
  end

  describe "Face ligature support" do
    it "reports supports_ligatures? for TrueType face" do
      font = load_roboto_bold
      face = FreeType::TrueType::Face.new(font, 48.0)

      face.supports_ligatures?.should be_true
    end

    it "exposes glyph_index through Face" do
      font = load_roboto_bold
      face = FreeType::TrueType::Face.new(font, 48.0)

      face.glyph_index('A').should be > 0
      face.glyph_index('f').should be > 0
    end

    it "exposes lookup_ligature through Face" do
      font = load_roboto_bold
      face = FreeType::TrueType::Face.new(font, 48.0)

      f_glyph = face.glyph_index('f').to_u16
      i_glyph = face.glyph_index('i').to_u16

      glyphs = [f_glyph, i_glyph]
      lig, consumed = face.lookup_ligature(glyphs)

      lig.should be > 0
      consumed.should eq(2)
    end

    it "renders glyph by index" do
      font = load_roboto_bold
      face = FreeType::TrueType::Face.new(font, 48.0)

      a_glyph = face.glyph_index('A')
      dot = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[100 * 64],
        CrImage::Math::Fixed::Int26_6[100 * 64]
      )

      dr, mask, maskp, advance, ok = face.glyph_by_index(dot, a_glyph)

      ok.should be_true
      advance.to_i.should be > 0
    end

    it "returns kerning by glyph index" do
      font = load_roboto_bold
      face = FreeType::TrueType::Face.new(font, 48.0)

      a_glyph = face.glyph_index('A')
      v_glyph = face.glyph_index('V')

      kern = face.kern_by_index(a_glyph, v_glyph)
      kern.to_i.should be < 0 # AV should have negative kerning
    end
  end
end

private def load_roboto_bold : FreeType::TrueType::Font
  path = "spec/testdata/fonts/Roboto/Roboto-Bold.ttf"
  data = File.read(path).to_slice
  FreeType::TrueType::Font.new(data)
end
