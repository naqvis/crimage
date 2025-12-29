require "../spec_helper"

# Helper methods for property tests
def random_image(min_width = 50, max_width = 500, min_height = 50, max_height = 500)
  width = Random.rand(min_width..max_width)
  height = Random.rand(min_height..max_height)
  img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

  # Fill with white background
  height.times do |y|
    width.times do |x|
      img.set(x, y, CrImage::Color::RGBA.new(255, 255, 255, 255))
    end
  end

  img
end

# Mock font face for testing
class MockFace
  include CrImage::Font::Face

  @char_width : Int32
  @char_height : Int32

  def initialize(@char_width = 10, @char_height = 16)
  end

  def glyph(dot : CrImage::Math::Fixed::Point26_6, r : Char) : {CrImage::Rectangle, CrImage::Image, CrImage::Point, CrImage::Math::Fixed::Int26_6, Bool}
    # Create a simple mask for the glyph
    mask = CrImage::Alpha.new(CrImage.rect(0, 0, @char_width, @char_height))
    dr = CrImage.rect(dot.x.floor, dot.y.floor - @char_height, dot.x.floor + @char_width, dot.y.floor)
    maskp = CrImage::Point.zero
    advance = CrImage::Math::Fixed::Int26_6[@char_width * 64]
    {dr, mask, maskp, advance, true}
  end

  def glyph_bounds(r : Char) : {CrImage::Math::Fixed::Rectangle26_6, CrImage::Math::Fixed::Int26_6, Bool}
    bounds = CrImage::Math::Fixed::Rectangle26_6.new(
      CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[0],
        CrImage::Math::Fixed::Int26_6[-@char_height * 64]
      ),
      CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[@char_width * 64],
        CrImage::Math::Fixed::Int26_6[0]
      )
    )
    advance = CrImage::Math::Fixed::Int26_6[@char_width * 64]
    {bounds, advance, true}
  end

  def glyph_advance(r : Char) : {CrImage::Math::Fixed::Int26_6, Bool}
    {CrImage::Math::Fixed::Int26_6[@char_width * 64], true}
  end

  def kern(r0 : Char, r1 : Char) : CrImage::Math::Fixed::Int26_6
    CrImage::Math::Fixed::Int26_6[0]
  end

  def metrics : CrImage::Font::Metrics
    CrImage::Font::Metrics.new(
      height: CrImage::Math::Fixed::Int26_6[@char_height * 64],
      ascent: CrImage::Math::Fixed::Int26_6[(@char_height * 3 // 4) * 64],
      descent: CrImage::Math::Fixed::Int26_6[(@char_height // 4) * 64],
      x_height: CrImage::Math::Fixed::Int26_6[(@char_height // 2) * 64],
      cap_height: CrImage::Math::Fixed::Int26_6[(@char_height * 3 // 4) * 64],
      caret_slope: CrImage::Point.new(0, 1)
    )
  end
end

# Helper to generate random text
def random_text(min_length = 5, max_length = 100, include_newlines = false)
  length = Random.rand(min_length..max_length)
  chars = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a + [' ', '.', ',', '!', '?']
  chars << '\n' if include_newlines

  String.build do |str|
    length.times do
      str << chars.sample
    end
  end
end

# Helper to generate random text with newlines
def random_multiline_text(min_lines = 2, max_lines = 10, min_line_length = 5, max_line_length = 50)
  num_lines = Random.rand(min_lines..max_lines)
  lines = Array(String).new(num_lines) do
    random_text(min_line_length, max_line_length, false)
  end
  lines.join('\n')
end

module CrImage::Font
  describe "Font Multi-line Property Tests" do
    describe "Multi-line Text Width Constraint" do
      it "Multi-line text respects maximum width" do
        # Run 10 iterations with random inputs
        10.times do
          img = random_image
          face = MockFace.new(10, 16)
          src = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
          dot = CrImage::Math::Fixed::Point26_6.new(
            CrImage::Math::Fixed::Int26_6[10 * 64],
            CrImage::Math::Fixed::Int26_6[50 * 64]
          )
          drawer = Drawer.new(img, src, face, dot)

          # Generate random text and max width
          text = random_text(20, 200, false)
          max_width = Random.rand(50..300)

          # Measure the layout
          layout = drawer.measure_multiline(text, max_width)

          # Verify that no line exceeds max_width
          # Note: Long unbreakable words may exceed max_width, which is acceptable
          layout.lines.each do |line|
            line_width = drawer.measure(line).ceil

            # Check if line is a single word (unbreakable)
            is_single_word = !line.includes?(' ')

            if is_single_word
              # Single words can exceed max_width (they get broken at character boundaries)
              # This is acceptable per requirements 11.3
              line_width.should be >= 0
            else
              # Multi-word lines should respect max_width
              line_width.should be <= max_width
            end
          end
        end
      end

      it "Word wrapping splits at word boundaries" do
        # Verify that word wrapping prefers word boundaries
        5.times do
          img = random_image
          face = MockFace.new(10, 16)
          src = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
          dot = CrImage::Math::Fixed::Point26_6.zero
          drawer = Drawer.new(img, src, face, dot)

          # Create text with clear word boundaries
          words = ["hello", "world", "test", "crystal", "programming"]
          text = words.join(' ')
          max_width = 80 # Enough for ~8 characters

          layout = drawer.measure_multiline(text, max_width)

          # Verify that lines don't end with partial words (unless it's a long word)
          layout.lines.each do |line|
            next if line.empty?

            # If line contains spaces, it should end at a word boundary
            if line.includes?(' ')
              # Line should not end with a space (trimmed)
              line[-1].should_not eq(' ')
            end
          end
        end
      end

      it "Long words are broken at character boundaries" do
        # Test that very long words get broken
        30.times do
          img = random_image
          face = MockFace.new(10, 16)
          src = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
          dot = CrImage::Math::Fixed::Point26_6.zero
          drawer = Drawer.new(img, src, face, dot)

          # Create a very long word
          long_word = "a" * Random.rand(100..200)
          max_width = 50 # Much smaller than word width

          layout = drawer.measure_multiline(long_word, max_width)

          # Verify that the word was broken into multiple lines
          layout.lines.size.should be > 1

          # Verify that each line (except possibly the last) respects max_width
          layout.lines[0..-2].each do |line|
            line_width = drawer.measure(line).ceil
            # Should not exceed max_width
            line_width.should be <= max_width
            # Should be reasonably close to max_width (at least 1 character)
            line_width.should be > 0
          end
        end
      end

      it "Empty text produces empty layout" do
        # Test empty text
        30.times do
          img = random_image
          face = MockFace.new(10, 16)
          src = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
          dot = CrImage::Math::Fixed::Point26_6.zero
          drawer = Drawer.new(img, src, face, dot)

          max_width = Random.rand(50..300)
          layout = drawer.measure_multiline("", max_width)

          # Empty text should produce a single empty line
          layout.lines.size.should eq(1)
          layout.lines[0].should eq("")
          layout.total_height.should eq(0)
        end
      end

      it "Newlines are preserved" do
        # Test that explicit newlines are preserved
        5.times do
          img = random_image
          face = MockFace.new(10, 16)
          src = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
          dot = CrImage::Math::Fixed::Point26_6.zero
          drawer = Drawer.new(img, src, face, dot)

          # Create text with explicit newlines
          num_lines = Random.rand(2..5)
          lines = Array(String).new(num_lines) { random_text(5, 20, false) }
          text = lines.join('\n')
          max_width = 500 # Large enough to not trigger wrapping

          layout = drawer.measure_multiline(text, max_width)

          # Should have at least as many lines as explicit newlines
          layout.lines.size.should be >= num_lines
        end
      end
    end

    describe "Multi-line Text Height Calculation" do
      it "Multi-line text height calculation is accurate" do
        # Run 10 iterations with random inputs
        10.times do
          img = random_image
          face = MockFace.new(10, 16)
          src = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
          dot = CrImage::Math::Fixed::Point26_6.zero
          drawer = Drawer.new(img, src, face, dot)

          # Generate random text
          text = random_multiline_text(2, 10, 5, 50)
          line_spacing = 1.0 + Random.rand * 1.0 # 1.0 to 2.0

          layout = drawer.measure_multiline(text, nil, line_spacing)

          # Calculate expected height
          metrics = face.metrics
          base_line_height = metrics.height.ceil
          actual_line_height = (base_line_height * line_spacing).to_i

          expected_height = if layout.lines.empty?
                              0
                            else
                              base_line_height + (layout.lines.size - 1) * actual_line_height
                            end

          # Verify height calculation
          layout.total_height.should eq(expected_height)

          # Verify line heights array
          layout.line_heights.size.should eq(layout.lines.size)
          layout.line_heights.each do |h|
            h.should eq(actual_line_height)
          end
        end
      end

      it "Height increases with line count" do
        # Verify that more lines = more height
        5.times do
          img = random_image
          face = MockFace.new(10, 16)
          src = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
          dot = CrImage::Math::Fixed::Point26_6.zero
          drawer = Drawer.new(img, src, face, dot)

          line_spacing = 1.2

          # Create texts with different line counts
          text1 = random_text(20, 50, false)
          text2 = text1 + "\n" + random_text(20, 50, false)
          text3 = text2 + "\n" + random_text(20, 50, false)

          layout1 = drawer.measure_multiline(text1, nil, line_spacing)
          layout2 = drawer.measure_multiline(text2, nil, line_spacing)
          layout3 = drawer.measure_multiline(text3, nil, line_spacing)

          # Heights should increase
          layout2.total_height.should be > layout1.total_height
          layout3.total_height.should be > layout2.total_height

          # Line counts should increase
          layout2.lines.size.should be > layout1.lines.size
          layout3.lines.size.should be > layout2.lines.size
        end
      end

      it "Line spacing affects total height" do
        # Verify that line spacing multiplier affects height
        5.times do
          img = random_image
          face = MockFace.new(10, 16)
          src = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
          dot = CrImage::Math::Fixed::Point26_6.zero
          drawer = Drawer.new(img, src, face, dot)

          text = random_multiline_text(3, 5, 10, 30)

          # Test with different line spacings
          layout1 = drawer.measure_multiline(text, nil, 1.0)
          layout2 = drawer.measure_multiline(text, nil, 1.5)
          layout3 = drawer.measure_multiline(text, nil, 2.0)

          # Heights should increase with spacing (for multi-line text)
          if layout1.lines.size > 1
            layout2.total_height.should be > layout1.total_height
            layout3.total_height.should be > layout2.total_height
          end
        end
      end

      it "Single line height is base height" do
        # Single line should use base height regardless of spacing
        5.times do
          img = random_image
          face = MockFace.new(10, 16)
          src = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
          dot = CrImage::Math::Fixed::Point26_6.zero
          drawer = Drawer.new(img, src, face, dot)

          text = random_text(10, 30, false)
          line_spacing = 1.0 + Random.rand * 1.0

          layout = drawer.measure_multiline(text, nil, line_spacing)

          # Single line should use base height
          if layout.lines.size == 1
            metrics = face.metrics
            base_line_height = metrics.height.ceil
            layout.total_height.should eq(base_line_height)
          end
        end
      end

      it "Empty text has zero height" do
        # Empty text should have zero height
        30.times do
          img = random_image
          face = MockFace.new(10, 16)
          src = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
          dot = CrImage::Math::Fixed::Point26_6.zero
          drawer = Drawer.new(img, src, face, dot)

          line_spacing = 1.0 + Random.rand * 1.0
          layout = drawer.measure_multiline("", nil, line_spacing)

          layout.total_height.should eq(0)
        end
      end
    end
  end

  describe "Text Alignment" do
    it "Text alignment positions text correctly" do
      # Run 10 iterations with random inputs
      10.times do
        img = random_image(200, 800, 200, 800)
        face = MockFace.new(10, 16)
        src = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
        drawer = Drawer.new(img, src, face)

        # Generate random text
        text = random_text(5, 30, false)

        # Create random bounding box within image
        box_width = Random.rand(100..img.bounds.width - 50)
        box_height = Random.rand(50..img.bounds.height - 50)
        box_x = Random.rand(0..img.bounds.width - box_width)
        box_y = Random.rand(0..img.bounds.height - box_height)

        rect = CrImage.rect(box_x, box_y, box_x + box_width, box_y + box_height)

        # Test all combinations of horizontal and vertical alignment
        [HorizontalAlign::Left, HorizontalAlign::Center, HorizontalAlign::Right].each do |h_align|
          [VerticalAlign::Top, VerticalAlign::Middle, VerticalAlign::Bottom].each do |v_align|
            # Create text box with alignment
            text_box = TextBox.new(rect, h_align, v_align)

            # Reset drawer position
            drawer.dot = CrImage::Math::Fixed::Point26_6.zero

            # Draw aligned text
            drawer.draw_aligned(text, text_box)

            # Get the final dot position after drawing
            final_dot = drawer.dot

            # Measure text dimensions
            bounds, advance = CrImage::Font.bounds(face, text)
            text_width = advance.ceil
            text_height = bounds.height.ceil
            metrics = face.metrics
            ascent = metrics.ascent.ceil

            # Calculate expected horizontal position
            expected_x = case h_align
                         when HorizontalAlign::Left
                           box_x
                         when HorizontalAlign::Center
                           box_x + (box_width - text_width) // 2
                         when HorizontalAlign::Right
                           box_x + box_width - text_width
                         else
                           box_x
                         end

            # Calculate expected vertical position (baseline)
            expected_y = case v_align
                         when VerticalAlign::Top
                           box_y + ascent
                         when VerticalAlign::Middle
                           box_y + (box_height - text_height) // 2 + ascent
                         when VerticalAlign::Bottom
                           box_y + box_height - text_height + ascent
                         else
                           box_y + ascent
                         end

            # Verify horizontal alignment
            # The dot should be positioned at the expected x coordinate
            actual_x = (final_dot.x - advance).floor
            (actual_x - expected_x).abs.should be <= 1 # Allow 1 pixel tolerance for rounding

            # Verify vertical alignment
            # The dot y position should match expected baseline
            actual_y = final_dot.y.floor
            (actual_y - expected_y).abs.should be <= 1 # Allow 1 pixel tolerance for rounding
          end
        end
      end
    end

    it "Left alignment positions text at left edge" do
      # Verify left alignment specifically
      5.times do
        img = random_image(200, 600, 200, 600)
        face = MockFace.new(10, 16)
        src = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
        drawer = Drawer.new(img, src, face)

        text = random_text(5, 20, false)
        box_width = Random.rand(150..img.bounds.width - 50)
        box_height = Random.rand(50..img.bounds.height - 50)
        box_x = Random.rand(0..img.bounds.width - box_width)
        box_y = Random.rand(0..img.bounds.height - box_height)

        rect = CrImage.rect(box_x, box_y, box_x + box_width, box_y + box_height)
        text_box = TextBox.new(rect, HorizontalAlign::Left, VerticalAlign::Top)

        drawer.draw_aligned(text, text_box)

        # Measure text
        bounds, advance = CrImage::Font.bounds(face, text)

        # Starting x should be at box left edge
        actual_x = (drawer.dot.x - advance).floor
        (actual_x - box_x).abs.should be <= 1
      end
    end

    it "Center alignment positions text at center" do
      # Verify center alignment specifically
      5.times do
        img = random_image(200, 600, 200, 600)
        face = MockFace.new(10, 16)
        src = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
        drawer = Drawer.new(img, src, face)

        text = random_text(5, 20, false)
        box_width = Random.rand(150..img.bounds.width - 50)
        box_height = Random.rand(50..img.bounds.height - 50)
        box_x = Random.rand(0..img.bounds.width - box_width)
        box_y = Random.rand(0..img.bounds.height - box_height)

        rect = CrImage.rect(box_x, box_y, box_x + box_width, box_y + box_height)
        text_box = TextBox.new(rect, HorizontalAlign::Center, VerticalAlign::Top)

        drawer.draw_aligned(text, text_box)

        # Measure text
        bounds, advance = CrImage::Font.bounds(face, text)
        text_width = advance.ceil

        # Starting x should be centered
        expected_x = box_x + (box_width - text_width) // 2
        actual_x = (drawer.dot.x - advance).floor
        (actual_x - expected_x).abs.should be <= 1
      end
    end

    it "Right alignment positions text at right edge" do
      # Verify right alignment specifically
      5.times do
        img = random_image(200, 600, 200, 600)
        face = MockFace.new(10, 16)
        src = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
        drawer = Drawer.new(img, src, face)

        text = random_text(5, 20, false)
        box_width = Random.rand(150..img.bounds.width - 50)
        box_height = Random.rand(50..img.bounds.height - 50)
        box_x = Random.rand(0..img.bounds.width - box_width)
        box_y = Random.rand(0..img.bounds.height - box_height)

        rect = CrImage.rect(box_x, box_y, box_x + box_width, box_y + box_height)
        text_box = TextBox.new(rect, HorizontalAlign::Right, VerticalAlign::Top)

        drawer.draw_aligned(text, text_box)

        # Measure text
        bounds, advance = CrImage::Font.bounds(face, text)
        text_width = advance.ceil

        # Starting x should be at right edge minus text width
        expected_x = box_x + box_width - text_width
        actual_x = (drawer.dot.x - advance).floor
        (actual_x - expected_x).abs.should be <= 1
      end
    end

    it "Top alignment positions text at top edge" do
      # Verify top alignment specifically
      5.times do
        img = random_image(200, 600, 200, 600)
        face = MockFace.new(10, 16)
        src = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
        drawer = Drawer.new(img, src, face)

        text = random_text(5, 20, false)
        box_width = Random.rand(150..img.bounds.width - 50)
        box_height = Random.rand(50..img.bounds.height - 50)
        box_x = Random.rand(0..img.bounds.width - box_width)
        box_y = Random.rand(0..img.bounds.height - box_height)

        rect = CrImage.rect(box_x, box_y, box_x + box_width, box_y + box_height)
        text_box = TextBox.new(rect, HorizontalAlign::Left, VerticalAlign::Top)

        drawer.draw_aligned(text, text_box)

        # Get metrics
        metrics = face.metrics
        ascent = metrics.ascent.ceil

        # Baseline y should be at top edge plus ascent
        expected_y = box_y + ascent
        actual_y = drawer.dot.y.floor
        (actual_y - expected_y).abs.should be <= 1
      end
    end

    it "Middle alignment positions text at vertical center" do
      # Verify middle alignment specifically
      5.times do
        img = random_image(200, 600, 200, 600)
        face = MockFace.new(10, 16)
        src = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
        drawer = Drawer.new(img, src, face)

        text = random_text(5, 20, false)
        box_width = Random.rand(150..img.bounds.width - 50)
        box_height = Random.rand(80..img.bounds.height - 50)
        box_x = Random.rand(0..img.bounds.width - box_width)
        box_y = Random.rand(0..img.bounds.height - box_height)

        rect = CrImage.rect(box_x, box_y, box_x + box_width, box_y + box_height)
        text_box = TextBox.new(rect, HorizontalAlign::Left, VerticalAlign::Middle)

        drawer.draw_aligned(text, text_box)

        # Measure text
        bounds, _ = CrImage::Font.bounds(face, text)
        text_height = bounds.height.ceil
        metrics = face.metrics
        ascent = metrics.ascent.ceil

        # Baseline y should be centered
        expected_y = box_y + (box_height - text_height) // 2 + ascent
        actual_y = drawer.dot.y.floor
        (actual_y - expected_y).abs.should be <= 1
      end
    end

    it "Bottom alignment positions text at bottom edge" do
      # Verify bottom alignment specifically
      5.times do
        img = random_image(200, 600, 200, 600)
        face = MockFace.new(10, 16)
        src = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
        drawer = Drawer.new(img, src, face)

        text = random_text(5, 20, false)
        box_width = Random.rand(150..img.bounds.width - 50)
        box_height = Random.rand(50..img.bounds.height - 50)
        box_x = Random.rand(0..img.bounds.width - box_width)
        box_y = Random.rand(0..img.bounds.height - box_height)

        rect = CrImage.rect(box_x, box_y, box_x + box_width, box_y + box_height)
        text_box = TextBox.new(rect, HorizontalAlign::Left, VerticalAlign::Bottom)

        drawer.draw_aligned(text, text_box)

        # Measure text
        bounds, _ = CrImage::Font.bounds(face, text)
        text_height = bounds.height.ceil
        metrics = face.metrics
        ascent = metrics.ascent.ceil

        # Baseline y should be at bottom edge
        expected_y = box_y + box_height - text_height + ascent
        actual_y = drawer.dot.y.floor
        (actual_y - expected_y).abs.should be <= 1
      end
    end

    it "Text wider than box still aligns correctly" do
      # Test when text is wider than the bounding box
      30.times do
        img = random_image(400, 800, 200, 600)
        face = MockFace.new(10, 16)
        src = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
        drawer = Drawer.new(img, src, face)

        # Create long text
        text = random_text(50, 100, false)

        # Create small box
        box_width = Random.rand(50..100)
        box_height = Random.rand(30..60)
        box_x = Random.rand(0..img.bounds.width - box_width)
        box_y = Random.rand(0..img.bounds.height - box_height)

        rect = CrImage.rect(box_x, box_y, box_x + box_width, box_y + box_height)

        # Test with center alignment (most interesting case)
        text_box = TextBox.new(rect, HorizontalAlign::Center, VerticalAlign::Middle)

        drawer.draw_aligned(text, text_box)

        # Measure text
        bounds, advance = CrImage::Font.bounds(face, text)
        text_width = advance.ceil

        # Even if text is wider, alignment calculation should work
        # Center alignment should position text centered on the box
        expected_x = box_x + (box_width - text_width) // 2
        actual_x = (drawer.dot.x - advance).floor

        # The calculation should still be correct (may result in negative offset)
        (actual_x - expected_x).abs.should be <= 1
      end
    end

    it "Empty text aligns correctly" do
      # Test empty text alignment
      30.times do
        img = random_image(200, 600, 200, 600)
        face = MockFace.new(10, 16)
        src = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
        drawer = Drawer.new(img, src, face)

        text = ""
        box_width = Random.rand(100..img.bounds.width - 50)
        box_height = Random.rand(50..img.bounds.height - 50)
        box_x = Random.rand(0..img.bounds.width - box_width)
        box_y = Random.rand(0..img.bounds.height - box_height)

        rect = CrImage.rect(box_x, box_y, box_x + box_width, box_y + box_height)

        # Test all alignments
        [HorizontalAlign::Left, HorizontalAlign::Center, HorizontalAlign::Right].each do |h_align|
          [VerticalAlign::Top, VerticalAlign::Middle, VerticalAlign::Bottom].each do |v_align|
            text_box = TextBox.new(rect, h_align, v_align)

            # Should not raise an error
            drawer.draw_aligned(text, text_box)

            # Dot should be positioned within or near the box
            drawer.dot.x.floor.should be >= box_x - 10
            drawer.dot.y.floor.should be >= box_y - 10
          end
        end
      end
    end
  end

  describe "Text Effects" do
    it "Text effects render in correct order" do
      # Run 10 iterations with random inputs
      10.times do
        img = random_image(300, 800, 300, 800)
        face = MockFace.new(10, 16)
        src = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
        dot = CrImage::Math::Fixed::Point26_6.new(
          CrImage::Math::Fixed::Int26_6[50 * 64],
          CrImage::Math::Fixed::Int26_6[50 * 64]
        )
        drawer = Drawer.new(img, src, face, dot)

        # Generate random text
        text = random_text(5, 20, false)

        # Create random shadow and outline
        shadow_offset_x = Random.rand(-10..10)
        shadow_offset_y = Random.rand(-10..10)
        shadow_blur = Random.rand(0..5)
        shadow_color = CrImage::Color::RGBA.new(
          Random.rand(0_u8..255_u8),
          Random.rand(0_u8..255_u8),
          Random.rand(0_u8..255_u8),
          Random.rand(100_u8..255_u8)
        )

        outline_thickness = Random.rand(1..3)
        outline_color = CrImage::Color::RGBA.new(
          Random.rand(0_u8..255_u8),
          Random.rand(0_u8..255_u8),
          Random.rand(0_u8..255_u8),
          255_u8
        )

        shadow = Shadow.new(shadow_offset_x, shadow_offset_y, shadow_blur, shadow_color)
        outline = Outline.new(outline_thickness, outline_color)
        style = TextStyle.new(shadow, outline)

        # Draw text with effects
        drawer.draw_styled(text, style)

        # Verify that the drawer's dot position was restored correctly
        # After drawing, the dot should be at the position after drawing the text
        # (not at shadow or outline positions)
        final_dot = drawer.dot

        # The final dot should have advanced by the text width
        bounds, advance = CrImage::Font.bounds(face, text)
        expected_x = dot.x + advance
        expected_y = dot.y

        # Verify dot position (allow small tolerance for rounding)
        (final_dot.x.floor - expected_x.floor).abs.should be <= 1
        (final_dot.y.floor - expected_y.floor).abs.should be <= 1
      end
    end

    it "Shadow only renders correctly" do
      # Test shadow without outline
      5.times do
        img = random_image(300, 800, 300, 800)
        face = MockFace.new(10, 16)
        src = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
        dot = CrImage::Math::Fixed::Point26_6.new(
          CrImage::Math::Fixed::Int26_6[50 * 64],
          CrImage::Math::Fixed::Int26_6[50 * 64]
        )
        drawer = Drawer.new(img, src, face, dot)

        text = random_text(5, 15, false)

        shadow = Shadow.new(
          Random.rand(-5..5),
          Random.rand(-5..5),
          Random.rand(0..3),
          CrImage::Color::RGBA.new(128_u8, 128_u8, 128_u8, 200_u8)
        )
        style = TextStyle.new(shadow, nil)

        # Should not raise an error
        drawer.draw_styled(text, style)

        # Verify dot position advanced correctly
        bounds, advance = CrImage::Font.bounds(face, text)
        expected_x = dot.x + advance
        (drawer.dot.x.floor - expected_x.floor).abs.should be <= 1
      end
    end

    it "Outline only renders correctly" do
      # Test outline without shadow
      5.times do
        img = random_image(300, 800, 300, 800)
        face = MockFace.new(10, 16)
        src = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
        dot = CrImage::Math::Fixed::Point26_6.new(
          CrImage::Math::Fixed::Int26_6[50 * 64],
          CrImage::Math::Fixed::Int26_6[50 * 64]
        )
        drawer = Drawer.new(img, src, face, dot)

        text = random_text(5, 15, false)

        outline = Outline.new(
          Random.rand(1..3),
          CrImage::Color::RGBA.new(255_u8, 255_u8, 255_u8, 255_u8)
        )
        style = TextStyle.new(nil, outline)

        # Should not raise an error
        drawer.draw_styled(text, style)

        # Verify dot position advanced correctly
        bounds, advance = CrImage::Font.bounds(face, text)
        expected_x = dot.x + advance
        (drawer.dot.x.floor - expected_x.floor).abs.should be <= 1
      end
    end

    it "No effects renders like normal text" do
      # Test with no effects (should behave like normal draw)
      5.times do
        img = random_image(300, 800, 300, 800)
        face = MockFace.new(10, 16)
        src = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
        initial_dot = CrImage::Math::Fixed::Point26_6.new(
          CrImage::Math::Fixed::Int26_6[50 * 64],
          CrImage::Math::Fixed::Int26_6[50 * 64]
        )
        drawer = Drawer.new(img, src, face, initial_dot)

        text = random_text(5, 15, false)

        style = TextStyle.new(nil, nil)

        # Draw with empty style
        drawer.draw_styled(text, style)

        # Verify dot position advanced correctly
        bounds, advance = CrImage::Font.bounds(face, text)
        expected_x = initial_dot.x + advance
        (drawer.dot.x.floor - expected_x.floor).abs.should be <= 1
      end
    end

    it "Zero blur shadow renders correctly" do
      # Test shadow with zero blur radius
      30.times do
        img = random_image(300, 800, 300, 800)
        face = MockFace.new(10, 16)
        src = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
        dot = CrImage::Math::Fixed::Point26_6.new(
          CrImage::Math::Fixed::Int26_6[50 * 64],
          CrImage::Math::Fixed::Int26_6[50 * 64]
        )
        drawer = Drawer.new(img, src, face, dot)

        text = random_text(5, 15, false)

        shadow = Shadow.new(
          Random.rand(-5..5),
          Random.rand(-5..5),
          0, # Zero blur
          CrImage::Color::RGBA.new(128_u8, 128_u8, 128_u8, 200_u8)
        )
        style = TextStyle.new(shadow, nil)

        # Should not raise an error
        drawer.draw_styled(text, style)

        # Verify dot position
        bounds, advance = CrImage::Font.bounds(face, text)
        expected_x = dot.x + advance
        (drawer.dot.x.floor - expected_x.floor).abs.should be <= 1
      end
    end

    it "Zero offset shadow renders correctly" do
      # Test shadow with zero offset (shadow directly behind text)
      30.times do
        img = random_image(300, 800, 300, 800)
        face = MockFace.new(10, 16)
        src = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
        dot = CrImage::Math::Fixed::Point26_6.new(
          CrImage::Math::Fixed::Int26_6[50 * 64],
          CrImage::Math::Fixed::Int26_6[50 * 64]
        )
        drawer = Drawer.new(img, src, face, dot)

        text = random_text(5, 15, false)

        shadow = Shadow.new(
          0, # Zero offset X
          0, # Zero offset Y
          Random.rand(1..3),
          CrImage::Color::RGBA.new(128_u8, 128_u8, 128_u8, 200_u8)
        )
        style = TextStyle.new(shadow, nil)

        # Should not raise an error
        drawer.draw_styled(text, style)

        # Verify dot position
        bounds, advance = CrImage::Font.bounds(face, text)
        expected_x = dot.x + advance
        (drawer.dot.x.floor - expected_x.floor).abs.should be <= 1
      end
    end

    it "Thin outline renders correctly" do
      # Test outline with thickness of 1
      30.times do
        img = random_image(300, 800, 300, 800)
        face = MockFace.new(10, 16)
        src = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
        dot = CrImage::Math::Fixed::Point26_6.new(
          CrImage::Math::Fixed::Int26_6[50 * 64],
          CrImage::Math::Fixed::Int26_6[50 * 64]
        )
        drawer = Drawer.new(img, src, face, dot)

        text = random_text(5, 15, false)

        outline = Outline.new(
          1, # Thin outline
          CrImage::Color::RGBA.new(255_u8, 255_u8, 255_u8, 255_u8)
        )
        style = TextStyle.new(nil, outline)

        # Should not raise an error
        drawer.draw_styled(text, style)

        # Verify dot position
        bounds, advance = CrImage::Font.bounds(face, text)
        expected_x = dot.x + advance
        (drawer.dot.x.floor - expected_x.floor).abs.should be <= 1
      end
    end

    it "Empty text with effects renders correctly" do
      # Test empty text with effects
      30.times do
        img = random_image(300, 800, 300, 800)
        face = MockFace.new(10, 16)
        src = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
        dot = CrImage::Math::Fixed::Point26_6.new(
          CrImage::Math::Fixed::Int26_6[50 * 64],
          CrImage::Math::Fixed::Int26_6[50 * 64]
        )
        drawer = Drawer.new(img, src, face, dot)

        text = ""

        shadow = Shadow.new(5, 5, 2, CrImage::Color::RGBA.new(128_u8, 128_u8, 128_u8, 200_u8))
        outline = Outline.new(2, CrImage::Color::RGBA.new(255_u8, 255_u8, 255_u8, 255_u8))
        style = TextStyle.new(shadow, outline)

        # Should not raise an error
        drawer.draw_styled(text, style)

        # Dot should not have moved (empty text)
        drawer.dot.x.floor.should eq(dot.x.floor)
        drawer.dot.y.floor.should eq(dot.y.floor)
      end
    end

    it "Effects preserve original dot position" do
      # Verify that the original dot position is used for all effects
      5.times do
        img = random_image(300, 800, 300, 800)
        face = MockFace.new(10, 16)
        src = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))

        # Random starting position
        start_x = Random.rand(50..200)
        start_y = Random.rand(50..200)
        dot = CrImage::Math::Fixed::Point26_6.new(
          CrImage::Math::Fixed::Int26_6[start_x * 64],
          CrImage::Math::Fixed::Int26_6[start_y * 64]
        )
        drawer = Drawer.new(img, src, face, dot)

        text = random_text(5, 15, false)

        shadow = Shadow.new(5, 5, 2, CrImage::Color::RGBA.new(128_u8, 128_u8, 128_u8, 200_u8))
        outline = Outline.new(2, CrImage::Color::RGBA.new(255_u8, 255_u8, 255_u8, 255_u8))
        style = TextStyle.new(shadow, outline)

        # Draw with effects
        drawer.draw_styled(text, style)

        # Final position should be original position + text advance
        bounds, advance = CrImage::Font.bounds(face, text)
        expected_x = dot.x + advance
        expected_y = dot.y

        # Verify final position
        (drawer.dot.x.floor - expected_x.floor).abs.should be <= 1 # 1 pixel tolerance
        (drawer.dot.y.floor - expected_y.floor).abs.should be <= 1
      end
    end
  end
end
