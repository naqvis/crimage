require "../spec_helper"

# Helper methods for property tests
def random_image(min_width = 5, max_width = 100, min_height = 5, max_height = 100)
  width = Random.rand(min_width..max_width)
  height = Random.rand(min_height..max_height)
  img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

  # Fill with random colors
  height.times do |y|
    width.times do |x|
      img.set(x, y, CrImage::Color::RGBA.new(
        Random.rand(256).to_u8,
        Random.rand(256).to_u8,
        Random.rand(256).to_u8,
        Random.rand(256).to_u8
      ))
    end
  end

  img
end

def random_point(min_x = -50, max_x = 150, min_y = -50, max_y = 150)
  CrImage::Point.new(
    Random.rand(min_x..max_x),
    Random.rand(min_y..max_y)
  )
end

def random_color
  CrImage::Color::RGBA.new(
    Random.rand(256).to_u8,
    Random.rand(256).to_u8,
    Random.rand(256).to_u8,
    Random.rand(256).to_u8
  )
end

# Helper to create random color stops
def random_color_stops(count = 3)
  stops = [] of CrImage::Draw::ColorStop
  positions = Array.new(count) { Random.rand }.sort

  positions.each do |pos|
    stops << CrImage::Draw::ColorStop.new(pos, random_color)
  end

  stops
end

module CrImage::Draw
  describe "Draw Primitives Property Tests" do
    describe "Line Drawing Properties" do
      it "Line drawing respects image bounds" do
        # Run 10 iterations with random inputs
        10.times do
          img = random_image(20, 80, 20, 80)
          bounds = img.bounds

          # Generate random points that may be inside or outside bounds
          p1 = random_point(-20, bounds.max.x + 20, -20, bounds.max.y + 20)
          p2 = random_point(-20, bounds.max.x + 20, -20, bounds.max.y + 20)

          color = random_color
          style = LineStyle.new(color, 1, false)

          # Draw the line
          Draw.line(img, p1, p2, style)

          # Verify no pixels were set outside bounds
          # We can't directly check this, but we can verify the image bounds haven't changed
          # and that accessing pixels outside bounds would fail
          img.bounds.should eq(bounds)

          # Verify we can still access all pixels within bounds without error
          bounds.height.times do |y|
            bounds.width.times do |x|
              # This should not raise an error
              img.at(x, y)
            end
          end
        end
      end

      it "Line drawing only modifies pixels within bounds" do
        # Create a test where we can verify pixels outside bounds are not touched
        5.times do
          width = Random.rand(30..60)
          height = Random.rand(30..60)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with a known background color
          bg_color = CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8)
          height.times do |y|
            width.times do |x|
              img.set(x, y, bg_color)
            end
          end

          # Draw a line that extends outside bounds
          p1 = CrImage::Point.new(-10, height // 2)
          p2 = CrImage::Point.new(width + 10, height // 2)

          line_color = CrImage::Color::RGBA.new(255_u8, 0_u8, 0_u8, 255_u8)
          style = LineStyle.new(line_color, 1, false)

          Draw.line(img, p1, p2, style)

          # Verify that pixels on the line within bounds are modified
          mid_y = height // 2
          has_line_color = false

          width.times do |x|
            c = img.at(x, mid_y).as(CrImage::Color::RGBA)
            if c.r == 255 && c.g == 0 && c.b == 0
              has_line_color = true
              break
            end
          end

          has_line_color.should be_true
        end
      end

      it "Line completely outside bounds doesn't crash" do
        # Test lines that are completely outside the image bounds
        5.times do
          img = random_image(20, 60, 20, 60)
          bounds = img.bounds

          # Generate points completely outside bounds
          outside_x = bounds.max.x + Random.rand(10..50)
          outside_y = bounds.max.y + Random.rand(10..50)

          p1 = CrImage::Point.new(outside_x, outside_y)
          p2 = CrImage::Point.new(outside_x + 10, outside_y + 10)

          color = random_color
          style = LineStyle.new(color, 1, false)

          # This should not crash
          Draw.line(img, p1, p2, style)

          # Image should be unchanged
          img.bounds.should eq(bounds)
        end
      end

      it "Line with one endpoint outside bounds" do
        # Test lines where one endpoint is inside and one is outside
        5.times do
          img = random_image(30, 60, 30, 60)
          bounds = img.bounds

          # One point inside, one outside
          inside_x = Random.rand(bounds.min.x...bounds.max.x)
          inside_y = Random.rand(bounds.min.y...bounds.max.y)
          outside_x = bounds.max.x + Random.rand(10..30)
          outside_y = bounds.max.y + Random.rand(10..30)

          p1 = CrImage::Point.new(inside_x, inside_y)
          p2 = CrImage::Point.new(outside_x, outside_y)

          color = random_color
          style = LineStyle.new(color, 1, false)

          # This should not crash and should clip properly
          Draw.line(img, p1, p2, style)

          img.bounds.should eq(bounds)
        end
      end

      it "Diagonal lines respect bounds" do
        # Test diagonal lines that cross boundaries
        30.times do
          width = Random.rand(30..60)
          height = Random.rand(30..60)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with background
          bg_color = CrImage::Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8)
          height.times do |y|
            width.times do |x|
              img.set(x, y, bg_color)
            end
          end

          # Draw diagonal line from outside to outside
          p1 = CrImage::Point.new(-10, -10)
          p2 = CrImage::Point.new(width + 10, height + 10)

          line_color = CrImage::Color::RGBA.new(255_u8, 255_u8, 255_u8, 255_u8)
          style = LineStyle.new(line_color, 1, false)

          Draw.line(img, p1, p2, style)

          # Verify some pixels were drawn (the line crosses the image)
          has_line = false
          height.times do |y|
            width.times do |x|
              c = img.at(x, y).as(CrImage::Color::RGBA)
              if c.r == 255 && c.g == 255 && c.b == 255
                has_line = true
                break
              end
            end
            break if has_line
          end

          has_line.should be_true
        end
      end

      it "Line pixels have specified color" do
        # Run 10 iterations with random inputs
        10.times do
          width = Random.rand(30..80)
          height = Random.rand(30..80)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with a different background color
          bg_color = CrImage::Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8)
          height.times do |y|
            width.times do |x|
              img.set(x, y, bg_color)
            end
          end

          # Draw a line within bounds
          p1 = CrImage::Point.new(
            Random.rand(5...width - 5),
            Random.rand(5...height - 5)
          )
          p2 = CrImage::Point.new(
            Random.rand(5...width - 5),
            Random.rand(5...height - 5)
          )

          # Use a distinct line color
          line_color = CrImage::Color::RGBA.new(
            Random.rand(200..255).to_u8,
            Random.rand(200..255).to_u8,
            Random.rand(200..255).to_u8,
            255_u8
          )
          style = LineStyle.new(line_color, 1, false)

          Draw.line(img, p1, p2, style)

          # Verify that at least some pixels have the line color
          # (the line should have drawn something)
          has_line_color = false
          height.times do |y|
            width.times do |x|
              c = img.at(x, y).as(CrImage::Color::RGBA)
              # Check if pixel matches line color (for non-anti-aliased lines)
              if c.r >= 200 && c.g >= 200 && c.b >= 200
                has_line_color = true
                break
              end
            end
            break if has_line_color
          end

          # Unless the line is a single point at the same location, we should have drawn something
          if p1.x != p2.x || p1.y != p2.y
            has_line_color.should be_true
          end
        end
      end

      it "Horizontal line has correct color" do
        # Test horizontal lines specifically
        5.times do
          width = Random.rand(40..80)
          height = Random.rand(40..80)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with black
          height.times do |y|
            width.times do |x|
              img.set(x, y, CrImage::Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8))
            end
          end

          # Draw horizontal line
          y_pos = height // 2
          p1 = CrImage::Point.new(10, y_pos)
          p2 = CrImage::Point.new(width - 10, y_pos)

          line_color = CrImage::Color::RGBA.new(255_u8, 0_u8, 0_u8, 255_u8)
          style = LineStyle.new(line_color, 1, false)

          Draw.line(img, p1, p2, style)

          # Verify all pixels on the line have the correct color
          (10...width - 10).each do |x|
            c = img.at(x, y_pos).as(CrImage::Color::RGBA)
            c.r.should eq(255)
            c.g.should eq(0)
            c.b.should eq(0)
            c.a.should eq(255)
          end
        end
      end

      it "Vertical line has correct color" do
        # Test vertical lines specifically
        5.times do
          width = Random.rand(40..80)
          height = Random.rand(40..80)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with black
          height.times do |y|
            width.times do |x|
              img.set(x, y, CrImage::Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8))
            end
          end

          # Draw vertical line
          x_pos = width // 2
          p1 = CrImage::Point.new(x_pos, 10)
          p2 = CrImage::Point.new(x_pos, height - 10)

          line_color = CrImage::Color::RGBA.new(0_u8, 255_u8, 0_u8, 255_u8)
          style = LineStyle.new(line_color, 1, false)

          Draw.line(img, p1, p2, style)

          # Verify all pixels on the line have the correct color
          (10...height - 10).each do |y|
            c = img.at(x_pos, y).as(CrImage::Color::RGBA)
            c.r.should eq(0)
            c.g.should eq(255)
            c.b.should eq(0)
            c.a.should eq(255)
          end
        end
      end

      it "Diagonal line has correct color" do
        # Test diagonal lines
        5.times do
          width = Random.rand(40..80)
          height = Random.rand(40..80)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with black
          height.times do |y|
            width.times do |x|
              img.set(x, y, CrImage::Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8))
            end
          end

          # Draw diagonal line
          p1 = CrImage::Point.new(10, 10)
          p2 = CrImage::Point.new(width - 10, height - 10)

          line_color = CrImage::Color::RGBA.new(0_u8, 0_u8, 255_u8, 255_u8)
          style = LineStyle.new(line_color, 1, false)

          Draw.line(img, p1, p2, style)

          # Verify that pixels on the line have the correct color
          # Check a few points along the expected line
          line_pixel_count = 0
          height.times do |y|
            width.times do |x|
              c = img.at(x, y).as(CrImage::Color::RGBA)
              if c.r == 0 && c.g == 0 && c.b == 255
                line_pixel_count += 1
              end
            end
          end

          # Should have drawn a significant number of pixels
          line_pixel_count.should be > 10
        end
      end

      it "Single point line has correct color" do
        # Test line where both endpoints are the same
        5.times do
          width = Random.rand(20..60)
          height = Random.rand(20..60)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with black
          height.times do |y|
            width.times do |x|
              img.set(x, y, CrImage::Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8))
            end
          end

          # Draw single point
          x_pos = width // 2
          y_pos = height // 2
          p1 = CrImage::Point.new(x_pos, y_pos)
          p2 = CrImage::Point.new(x_pos, y_pos)

          line_color = CrImage::Color::RGBA.new(255_u8, 255_u8, 0_u8, 255_u8)
          style = LineStyle.new(line_color, 1, false)

          Draw.line(img, p1, p2, style)

          # Verify the single pixel has the correct color
          c = img.at(x_pos, y_pos).as(CrImage::Color::RGBA)
          c.r.should eq(255)
          c.g.should eq(255)
          c.b.should eq(0)
          c.a.should eq(255)
        end
      end

      it "Thick lines have correct color" do
        # Test lines with thickness > 1
        30.times do
          width = Random.rand(50..80)
          height = Random.rand(50..80)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with black
          height.times do |y|
            width.times do |x|
              img.set(x, y, CrImage::Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8))
            end
          end

          # Draw thick line
          p1 = CrImage::Point.new(width // 4, height // 2)
          p2 = CrImage::Point.new(3 * width // 4, height // 2)

          line_color = CrImage::Color::RGBA.new(255_u8, 128_u8, 0_u8, 255_u8)
          thickness = Random.rand(2..5)
          style = LineStyle.new(line_color, thickness, false)

          Draw.line(img, p1, p2, style)

          # Verify that pixels on the thick line have the correct color
          line_pixel_count = 0
          height.times do |y|
            width.times do |x|
              c = img.at(x, y).as(CrImage::Color::RGBA)
              if c.r == 255 && c.g == 128 && c.b == 0
                line_pixel_count += 1
              end
            end
          end

          # Thick line should have more pixels than thin line
          expected_min_pixels = (p2.x - p1.x) * thickness // 2
          line_pixel_count.should be > expected_min_pixels
        end
      end

      it "Anti-aliased lines blend with background" do
        # Test anti-aliased lines
        30.times do
          width = Random.rand(50..80)
          height = Random.rand(50..80)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with white background
          height.times do |y|
            width.times do |x|
              img.set(x, y, CrImage::Color::RGBA.new(255_u8, 255_u8, 255_u8, 255_u8))
            end
          end

          # Draw anti-aliased line
          p1 = CrImage::Point.new(10, 10)
          p2 = CrImage::Point.new(width - 10, height - 10)

          line_color = CrImage::Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8)
          style = LineStyle.new(line_color, 1, true)

          Draw.line(img, p1, p2, style)

          # Verify that we have some pixels that are not pure black or pure white
          # (indicating anti-aliasing is working)
          has_gray_pixels = false
          height.times do |y|
            width.times do |x|
              c = img.at(x, y).as(CrImage::Color::RGBA)
              # Gray pixels (not pure black or white)
              if c.r > 10 && c.r < 245
                has_gray_pixels = true
                break
              end
            end
            break if has_gray_pixels
          end

          has_gray_pixels.should be_true
        end
      end

      it "Line connects endpoints" do
        # Verify that the line actually connects the two endpoints
        5.times do
          width = Random.rand(40..80)
          height = Random.rand(40..80)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with black
          height.times do |y|
            width.times do |x|
              img.set(x, y, CrImage::Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8))
            end
          end

          # Draw line
          p1 = CrImage::Point.new(
            Random.rand(5...width - 5),
            Random.rand(5...height - 5)
          )
          p2 = CrImage::Point.new(
            Random.rand(5...width - 5),
            Random.rand(5...height - 5)
          )

          line_color = CrImage::Color::RGBA.new(255_u8, 255_u8, 255_u8, 255_u8)
          style = LineStyle.new(line_color, 1, false)

          Draw.line(img, p1, p2, style)

          # Verify both endpoints are colored (or very close to them)
          # Check p1
          c1 = img.at(p1.x, p1.y).as(CrImage::Color::RGBA)
          c1.r.should eq(255)
          c1.g.should eq(255)
          c1.b.should eq(255)

          # Check p2
          c2 = img.at(p2.x, p2.y).as(CrImage::Color::RGBA)
          c2.r.should eq(255)
          c2.g.should eq(255)
          c2.b.should eq(255)
        end
      end
    end

    describe "Circle and Ellipse Drawing Properties" do
      it "Circle pixels are equidistant from center" do
        # Run 10 iterations with random inputs
        10.times do
          width = Random.rand(80..120)
          height = Random.rand(80..120)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with black background
          height.times do |y|
            width.times do |x|
              img.set(x, y, CrImage::Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8))
            end
          end

          # Generate random circle parameters
          radius = Random.rand(5..20)
          # Ensure valid range for center coordinates
          min_x = radius + 5
          max_x = width - radius - 5
          min_y = radius + 5
          max_y = height - radius - 5

          # Skip if image is too small for this radius
          next if min_x >= max_x || min_y >= max_y

          center = CrImage::Point.new(
            Random.rand(min_x..max_x),
            Random.rand(min_y..max_y)
          )

          circle_color = CrImage::Color::RGBA.new(255_u8, 255_u8, 255_u8, 255_u8)
          style = CrImage::Draw::CircleStyle.new(circle_color, fill: false, anti_alias: false)

          # Draw the circle
          CrImage::Draw.circle(img, center, radius, style)

          # Verify that all colored pixels are approximately equidistant from center
          # For midpoint circle algorithm, pixels should be within radius ± 1
          height.times do |y|
            width.times do |x|
              c = img.at(x, y).as(CrImage::Color::RGBA)

              # If pixel is colored (not black), check distance
              if c.r == 255 && c.g == 255 && c.b == 255
                dx = (x - center.x).to_f64
                dy = (y - center.y).to_f64
                distance = ::Math.sqrt(dx * dx + dy * dy)

                # Distance should be within radius ± 1 (allowing for discrete pixels)
                (distance >= radius - 1 && distance <= radius + 1).should be_true
              end
            end
          end
        end
      end

      it "Circle outline forms closed loop" do
        # Verify that circle pixels form a connected outline
        5.times do
          width = Random.rand(60..100)
          height = Random.rand(60..100)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with black
          height.times do |y|
            width.times do |x|
              img.set(x, y, CrImage::Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8))
            end
          end

          # Draw circle
          radius = Random.rand(10..20)
          center = CrImage::Point.new(width // 2, height // 2)

          circle_color = CrImage::Color::RGBA.new(255_u8, 0_u8, 0_u8, 255_u8)
          style = CrImage::Draw::CircleStyle.new(circle_color, fill: false, anti_alias: false)

          CrImage::Draw.circle(img, center, radius, style)

          # Count colored pixels - should have drawn something
          colored_count = 0
          height.times do |y|
            width.times do |x|
              c = img.at(x, y).as(CrImage::Color::RGBA)
              colored_count += 1 if c.r == 255 && c.g == 0 && c.b == 0
            end
          end

          # Circle should have approximately 2*pi*radius pixels
          expected_pixels = (2 * ::Math::PI * radius).to_i
          # Allow for some variation due to discrete pixels
          (colored_count >= expected_pixels * 0.7).should be_true
        end
      end

      it "Zero radius circle" do
        # Test circle with radius 0
        30.times do
          width = Random.rand(30..60)
          height = Random.rand(30..60)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with black
          height.times do |y|
            width.times do |x|
              img.set(x, y, CrImage::Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8))
            end
          end

          center = CrImage::Point.new(width // 2, height // 2)
          circle_color = CrImage::Color::RGBA.new(255_u8, 255_u8, 255_u8, 255_u8)
          style = CrImage::Draw::CircleStyle.new(circle_color, fill: false, anti_alias: false)

          # Draw circle with radius 0 - should not crash
          CrImage::Draw.circle(img, center, 0, style)

          # Image should remain unchanged (all black)
          all_black = true
          height.times do |y|
            width.times do |x|
              c = img.at(x, y).as(CrImage::Color::RGBA)
              if c.r != 0 || c.g != 0 || c.b != 0
                all_black = false
                break
              end
            end
            break unless all_black
          end

          all_black.should be_true
        end
      end

      it "Large circles maintain distance property" do
        # Test with larger circles
        30.times do
          width = Random.rand(150..200)
          height = Random.rand(150..200)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with black
          height.times do |y|
            width.times do |x|
              img.set(x, y, CrImage::Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8))
            end
          end

          radius = Random.rand(40..60)
          center = CrImage::Point.new(width // 2, height // 2)

          circle_color = CrImage::Color::RGBA.new(100_u8, 200_u8, 100_u8, 255_u8)
          style = CrImage::Draw::CircleStyle.new(circle_color, fill: false, anti_alias: false)

          CrImage::Draw.circle(img, center, radius, style)

          # Sample some pixels and verify distance
          sample_count = 0
          valid_count = 0

          height.times do |y|
            width.times do |x|
              c = img.at(x, y).as(CrImage::Color::RGBA)

              if c.r == 100 && c.g == 200 && c.b == 100
                sample_count += 1
                dx = (x - center.x).to_f64
                dy = (y - center.y).to_f64
                distance = ::Math.sqrt(dx * dx + dy * dy)

                valid_count += 1 if distance >= radius - 1 && distance <= radius + 1
              end
            end
          end

          # All sampled pixels should be at correct distance
          if sample_count > 0
            (valid_count.to_f64 / sample_count >= 0.95).should be_true
          end
        end
      end

      it "Filled shapes fill interior completely" do
        # Run 10 iterations with random inputs
        10.times do
          width = Random.rand(80..120)
          height = Random.rand(80..120)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with black background
          height.times do |y|
            width.times do |x|
              img.set(x, y, CrImage::Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8))
            end
          end

          # Test filled circle
          radius = Random.rand(10..20)
          min_x = radius + 5
          max_x = width - radius - 5
          min_y = radius + 5
          max_y = height - radius - 5

          # Skip if image is too small
          next if min_x >= max_x || min_y >= max_y

          center = CrImage::Point.new(
            Random.rand(min_x..max_x),
            Random.rand(min_y..max_y)
          )

          fill_color = CrImage::Color::RGBA.new(255_u8, 0_u8, 0_u8, 255_u8)
          style = CrImage::Draw::CircleStyle.new(fill_color, fill: true, anti_alias: false)

          # Draw filled circle
          CrImage::Draw.circle(img, center, radius, style)

          # Verify that all interior points are filled
          # Check points that should definitely be inside (within radius - 2)
          interior_radius = [radius - 2, 1].max

          (-interior_radius..interior_radius).each do |dy|
            (-interior_radius..interior_radius).each do |dx|
              distance = ::Math.sqrt((dx * dx + dy * dy).to_f64)

              if distance <= interior_radius
                x = center.x + dx
                y = center.y + dy

                # Skip if outside image bounds
                next if x < 0 || x >= width || y < 0 || y >= height

                c = img.at(x, y).as(CrImage::Color::RGBA)
                # Interior point should be filled
                (c.r == 255 && c.g == 0 && c.b == 0).should be_true
              end
            end
          end
        end
      end

      it "Filled ellipse fills interior" do
        # Test filled ellipses
        5.times do
          width = Random.rand(100..140)
          height = Random.rand(100..140)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with black
          height.times do |y|
            width.times do |x|
              img.set(x, y, CrImage::Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8))
            end
          end

          # Draw filled ellipse
          rx = Random.rand(15..25)
          ry = Random.rand(15..25)

          min_x = rx + 5
          max_x = width - rx - 5
          min_y = ry + 5
          max_y = height - ry - 5

          # Skip if image is too small
          next if min_x >= max_x || min_y >= max_y

          center = CrImage::Point.new(
            Random.rand(min_x..max_x),
            Random.rand(min_y..max_y)
          )

          fill_color = CrImage::Color::RGBA.new(0_u8, 255_u8, 0_u8, 255_u8)
          style = CrImage::Draw::CircleStyle.new(fill_color, fill: true, anti_alias: false)

          CrImage::Draw.ellipse(img, center, rx, ry, style)

          # Verify interior points are filled
          # Check center point (should definitely be filled)
          c_center = img.at(center.x, center.y).as(CrImage::Color::RGBA)
          (c_center.r == 0 && c_center.g == 255 && c_center.b == 0).should be_true

          # Check some points along major and minor axes
          if rx > 3
            c_x = img.at(center.x + rx // 2, center.y).as(CrImage::Color::RGBA)
            (c_x.r == 0 && c_x.g == 255 && c_x.b == 0).should be_true
          end

          if ry > 3
            c_y = img.at(center.x, center.y + ry // 2).as(CrImage::Color::RGBA)
            (c_y.r == 0 && c_y.g == 255 && c_y.b == 0).should be_true
          end
        end
      end

      it "Filled circle has no gaps" do
        # Verify filled circles have no interior gaps
        30.times do
          width = Random.rand(80..120)
          height = Random.rand(80..120)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with white background
          height.times do |y|
            width.times do |x|
              img.set(x, y, CrImage::Color::RGBA.new(255_u8, 255_u8, 255_u8, 255_u8))
            end
          end

          radius = Random.rand(15..30)
          center = CrImage::Point.new(width // 2, height // 2)

          fill_color = CrImage::Color::RGBA.new(0_u8, 0_u8, 255_u8, 255_u8)
          style = CrImage::Draw::CircleStyle.new(fill_color, fill: true, anti_alias: false)

          CrImage::Draw.circle(img, center, radius, style)

          # Count filled pixels
          filled_count = 0
          height.times do |y|
            width.times do |x|
              c = img.at(x, y).as(CrImage::Color::RGBA)
              filled_count += 1 if c.r == 0 && c.g == 0 && c.b == 255
            end
          end

          # Filled circle should have approximately pi*r^2 pixels
          expected_area = (::Math::PI * radius * radius).to_i
          # Allow for some variation
          (filled_count >= expected_area * 0.8 && filled_count <= expected_area * 1.2).should be_true
        end
      end

      it "Small filled circles" do
        # Test very small filled circles
        5.times do
          width = Random.rand(30..60)
          height = Random.rand(30..60)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with black
          height.times do |y|
            width.times do |x|
              img.set(x, y, CrImage::Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8))
            end
          end

          # Small radius
          radius = Random.rand(1..3)
          center = CrImage::Point.new(width // 2, height // 2)

          fill_color = CrImage::Color::RGBA.new(255_u8, 255_u8, 0_u8, 255_u8)
          style = CrImage::Draw::CircleStyle.new(fill_color, fill: true, anti_alias: false)

          CrImage::Draw.circle(img, center, radius, style)

          # At minimum, center should be filled
          c_center = img.at(center.x, center.y).as(CrImage::Color::RGBA)
          (c_center.r == 255 && c_center.g == 255 && c_center.b == 0).should be_true
        end
      end

      it "Filled ellipse area is correct" do
        # Verify filled ellipse has approximately correct area
        30.times do
          width = Random.rand(100..150)
          height = Random.rand(100..150)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with black
          height.times do |y|
            width.times do |x|
              img.set(x, y, CrImage::Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8))
            end
          end

          rx = Random.rand(20..40)
          ry = Random.rand(20..40)
          center = CrImage::Point.new(width // 2, height // 2)

          fill_color = CrImage::Color::RGBA.new(128_u8, 0_u8, 128_u8, 255_u8)
          style = CrImage::Draw::CircleStyle.new(fill_color, fill: true, anti_alias: false)

          CrImage::Draw.ellipse(img, center, rx, ry, style)

          # Count filled pixels
          filled_count = 0
          height.times do |y|
            width.times do |x|
              c = img.at(x, y).as(CrImage::Color::RGBA)
              filled_count += 1 if c.r == 128 && c.g == 0 && c.b == 128
            end
          end

          # Filled ellipse should have approximately pi*rx*ry pixels
          expected_area = (::Math::PI * rx * ry).to_i
          # Allow for variation
          (filled_count >= expected_area * 0.8 && filled_count <= expected_area * 1.2).should be_true
        end
      end
    end

    describe "Polygon Drawing Properties" do
      it "Polygon with insufficient points raises error" do
        # Run 10 iterations with random inputs
        10.times do
          width = Random.rand(50..100)
          height = Random.rand(50..100)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Generate random number of points (0, 1, or 2)
          num_points = Random.rand(0..2)
          points = Array(CrImage::Point).new(num_points) do
            CrImage::Point.new(
              Random.rand(0...width),
              Random.rand(0...height)
            )
          end

          color = random_color
          style = CrImage::Draw::PolygonStyle.new(outline_color: color)

          # Attempting to draw polygon with < 3 points should raise error
          expect_raises(CrImage::InsufficientPointsError) do
            CrImage::Draw.polygon(img, points, style)
          end
        end
      end

      it "Polygon with exactly 3 points succeeds" do
        # Verify that 3 points (minimum valid) works correctly
        5.times do
          width = Random.rand(50..100)
          height = Random.rand(50..100)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with black
          height.times do |y|
            width.times do |x|
              img.set(x, y, CrImage::Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8))
            end
          end

          # Create triangle (3 points)
          points = [
            CrImage::Point.new(width // 4, height // 4),
            CrImage::Point.new(3 * width // 4, height // 4),
            CrImage::Point.new(width // 2, 3 * height // 4),
          ]

          color = CrImage::Color::RGBA.new(255_u8, 255_u8, 255_u8, 255_u8)
          style = CrImage::Draw::PolygonStyle.new(outline_color: color)

          # This should not raise an error
          CrImage::Draw.polygon(img, points, style)

          # Verify something was drawn
          has_white = false
          height.times do |y|
            width.times do |x|
              c = img.at(x, y).as(CrImage::Color::RGBA)
              if c.r == 255 && c.g == 255 && c.b == 255
                has_white = true
                break
              end
            end
            break if has_white
          end

          has_white.should be_true
        end
      end

      it "Polygon with many points succeeds" do
        # Verify that polygons with many points work correctly
        30.times do
          width = Random.rand(80..120)
          height = Random.rand(80..120)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with black
          height.times do |y|
            width.times do |x|
              img.set(x, y, CrImage::Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8))
            end
          end

          # Create polygon with random number of points (4-10)
          num_points = Random.rand(4..10)
          points = Array(CrImage::Point).new(num_points) do
            CrImage::Point.new(
              Random.rand(10...width - 10),
              Random.rand(10...height - 10)
            )
          end

          color = CrImage::Color::RGBA.new(0_u8, 255_u8, 0_u8, 255_u8)
          style = CrImage::Draw::PolygonStyle.new(outline_color: color)

          # This should not raise an error
          CrImage::Draw.polygon(img, points, style)

          # Verify something was drawn
          has_green = false
          height.times do |y|
            width.times do |x|
              c = img.at(x, y).as(CrImage::Color::RGBA)
              if c.r == 0 && c.g == 255 && c.b == 0
                has_green = true
                break
              end
            end
            break if has_green
          end

          has_green.should be_true
        end
      end

      it "Empty points array raises error" do
        # Test with empty array
        30.times do
          width = Random.rand(30..60)
          height = Random.rand(30..60)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          points = [] of CrImage::Point
          color = random_color
          style = CrImage::Draw::PolygonStyle.new(outline_color: color)

          # Should raise error
          expect_raises(CrImage::InsufficientPointsError) do
            CrImage::Draw.polygon(img, points, style)
          end
        end
      end

      it "Single point raises error" do
        # Test with single point
        30.times do
          width = Random.rand(30..60)
          height = Random.rand(30..60)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          points = [CrImage::Point.new(width // 2, height // 2)]
          color = random_color
          style = CrImage::Draw::PolygonStyle.new(outline_color: color)

          # Should raise error
          expect_raises(CrImage::InsufficientPointsError) do
            CrImage::Draw.polygon(img, points, style)
          end
        end
      end

      it "Two points raise error" do
        # Test with two points
        30.times do
          width = Random.rand(30..60)
          height = Random.rand(30..60)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          points = [
            CrImage::Point.new(10, 10),
            CrImage::Point.new(width - 10, height - 10),
          ]
          color = random_color
          style = CrImage::Draw::PolygonStyle.new(outline_color: color)

          # Should raise error
          expect_raises(CrImage::InsufficientPointsError) do
            CrImage::Draw.polygon(img, points, style)
          end
        end
      end

      it "Filled polygon with 3 points works" do
        # Test filled triangles
        30.times do
          width = Random.rand(60..100)
          height = Random.rand(60..100)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with black
          height.times do |y|
            width.times do |x|
              img.set(x, y, CrImage::Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8))
            end
          end

          # Create triangle
          points = [
            CrImage::Point.new(width // 2, 10),
            CrImage::Point.new(width - 10, height - 10),
            CrImage::Point.new(10, height - 10),
          ]

          fill_color = CrImage::Color::RGBA.new(255_u8, 0_u8, 0_u8, 255_u8)
          style = CrImage::Draw::PolygonStyle.new(fill_color: fill_color)

          # This should not raise an error
          CrImage::Draw.polygon(img, points, style)

          # Verify interior is filled
          # Check center point (should be inside triangle)
          center_x = width // 2
          center_y = 2 * height // 3
          c = img.at(center_x, center_y).as(CrImage::Color::RGBA)
          (c.r == 255 && c.g == 0 && c.b == 0).should be_true
        end
      end

      it "Polygon with outline and fill works" do
        # Test polygon with both outline and fill
        30.times do
          width = Random.rand(80..120)
          height = Random.rand(80..120)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with black
          height.times do |y|
            width.times do |x|
              img.set(x, y, CrImage::Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8))
            end
          end

          # Create square
          points = [
            CrImage::Point.new(20, 20),
            CrImage::Point.new(width - 20, 20),
            CrImage::Point.new(width - 20, height - 20),
            CrImage::Point.new(20, height - 20),
          ]

          fill_color = CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8)
          outline_color = CrImage::Color::RGBA.new(255_u8, 255_u8, 255_u8, 255_u8)
          style = CrImage::Draw::PolygonStyle.new(
            outline_color: outline_color,
            fill_color: fill_color
          )

          # This should not raise an error
          CrImage::Draw.polygon(img, points, style)

          # Verify center is filled
          center_x = width // 2
          center_y = height // 2
          c_center = img.at(center_x, center_y).as(CrImage::Color::RGBA)
          (c_center.r == 100 && c_center.g == 100 && c_center.b == 100).should be_true

          # Verify outline exists (check edge pixels)
          has_outline = false
          # Check top edge
          (20..width - 20).each do |x|
            c = img.at(x, 20).as(CrImage::Color::RGBA)
            if c.r == 255 && c.g == 255 && c.b == 255
              has_outline = true
              break
            end
          end

          has_outline.should be_true
        end
      end

      it "Anti-aliased polygon outline works" do
        # Test anti-aliased polygon
        20.times do
          width = Random.rand(80..120)
          height = Random.rand(80..120)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with white background
          height.times do |y|
            width.times do |x|
              img.set(x, y, CrImage::Color::RGBA.new(255_u8, 255_u8, 255_u8, 255_u8))
            end
          end

          # Create pentagon
          points = [
            CrImage::Point.new(width // 2, 10),
            CrImage::Point.new(width - 10, height // 3),
            CrImage::Point.new(3 * width // 4, height - 10),
            CrImage::Point.new(width // 4, height - 10),
            CrImage::Point.new(10, height // 3),
          ]

          outline_color = CrImage::Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8)
          style = CrImage::Draw::PolygonStyle.new(
            outline_color: outline_color,
            anti_alias: true
          )

          # This should not raise an error
          CrImage::Draw.polygon(img, points, style)

          # Verify some pixels are not pure white or pure black (anti-aliasing)
          has_gray = false
          height.times do |y|
            width.times do |x|
              c = img.at(x, y).as(CrImage::Color::RGBA)
              if c.r > 10 && c.r < 245
                has_gray = true
                break
              end
            end
            break if has_gray
          end

          has_gray.should be_true
        end
      end
    end

    describe "Gradient Fill Properties" do
      it "Gradient color stops are interpolated correctly" do
        # Run 10 iterations with random inputs
        10.times do
          # Test linear gradients
          width = Random.rand(50..100)
          height = Random.rand(50..100)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Create gradient with known color stops
          start_point = CrImage::Point.new(0, height // 2)
          end_point = CrImage::Point.new(width - 1, height // 2)

          # Create stops at known positions
          color1 = CrImage::Color::RGBA.new(255_u8, 0_u8, 0_u8, 255_u8) # Red
          color2 = CrImage::Color::RGBA.new(0_u8, 0_u8, 255_u8, 255_u8) # Blue

          stops = [
            CrImage::Draw::ColorStop.new(0.0, color1),
            CrImage::Draw::ColorStop.new(1.0, color2),
          ]

          gradient = CrImage::Draw::LinearGradient.new(start_point, end_point, stops)
          rect = CrImage.rect(0, 0, width, height)

          # Fill with gradient
          CrImage::Draw.fill_linear_gradient(img, rect, gradient)

          # Verify color at start position (should be red)
          c_start = img.at(0, height // 2).as(CrImage::Color::RGBA)
          c_start.r.should eq(255)
          c_start.g.should eq(0)
          c_start.b.should eq(0)

          # Verify color at end position (should be blue)
          c_end = img.at(width - 1, height // 2).as(CrImage::Color::RGBA)
          c_end.r.should eq(0)
          c_end.g.should eq(0)
          c_end.b.should eq(255)

          # Verify color at middle position (should be purple-ish)
          c_mid = img.at(width // 2, height // 2).as(CrImage::Color::RGBA)
          # Middle should have roughly equal red and blue
          (c_mid.r > 100 && c_mid.b > 100).should be_true
        end
      end

      it "Linear gradient with multiple stops" do
        # Test gradients with multiple color stops
        5.times do
          width = Random.rand(80..120)
          height = Random.rand(80..120)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          start_point = CrImage::Point.new(0, 0)
          end_point = CrImage::Point.new(width - 1, height - 1)

          # Create three stops: red, green, blue
          stops = [
            CrImage::Draw::ColorStop.new(0.0, CrImage::Color::RGBA.new(255_u8, 0_u8, 0_u8, 255_u8)),
            CrImage::Draw::ColorStop.new(0.5, CrImage::Color::RGBA.new(0_u8, 255_u8, 0_u8, 255_u8)),
            CrImage::Draw::ColorStop.new(1.0, CrImage::Color::RGBA.new(0_u8, 0_u8, 255_u8, 255_u8)),
          ]

          gradient = CrImage::Draw::LinearGradient.new(start_point, end_point, stops)
          rect = CrImage.rect(0, 0, width, height)

          CrImage::Draw.fill_linear_gradient(img, rect, gradient)

          # Verify start is red
          c_start = img.at(0, 0).as(CrImage::Color::RGBA)
          c_start.r.should eq(255)
          c_start.g.should eq(0)
          c_start.b.should eq(0)

          # Verify middle is green
          c_mid = img.at(width // 2, height // 2).as(CrImage::Color::RGBA)
          c_mid.g.should be > 200 # Should be mostly green

          # Verify end is blue
          c_end = img.at(width - 1, height - 1).as(CrImage::Color::RGBA)
          c_end.r.should eq(0)
          c_end.g.should eq(0)
          c_end.b.should eq(255)
        end
      end

      it "Radial gradient interpolates from center" do
        # Test radial gradients
        5.times do
          width = Random.rand(80..120)
          height = Random.rand(80..120)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          center = CrImage::Point.new(width // 2, height // 2)
          radius = [width, height].min // 2 - 5

          # Create gradient from white to black
          stops = [
            CrImage::Draw::ColorStop.new(0.0, CrImage::Color::RGBA.new(255_u8, 255_u8, 255_u8, 255_u8)),
            CrImage::Draw::ColorStop.new(1.0, CrImage::Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8)),
          ]

          gradient = CrImage::Draw::RadialGradient.new(center, radius, stops)
          rect = CrImage.rect(0, 0, width, height)

          CrImage::Draw.fill_radial_gradient(img, rect, gradient)

          # Verify center is white
          c_center = img.at(center.x, center.y).as(CrImage::Color::RGBA)
          c_center.r.should eq(255)
          c_center.g.should eq(255)
          c_center.b.should eq(255)

          # Verify a point at radius distance is black (or close to it)
          edge_x = center.x + radius
          if edge_x < width
            c_edge = img.at(edge_x, center.y).as(CrImage::Color::RGBA)
            c_edge.r.should be < 50
            c_edge.g.should be < 50
            c_edge.b.should be < 50
          end
        end
      end

      it "Radial gradient with multiple stops" do
        # Test radial gradients with multiple color stops
        30.times do
          width = Random.rand(100..150)
          height = Random.rand(100..150)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          center = CrImage::Point.new(width // 2, height // 2)
          radius = [width, height].min // 2 - 5

          # Create gradient: red -> yellow -> green
          stops = [
            CrImage::Draw::ColorStop.new(0.0, CrImage::Color::RGBA.new(255_u8, 0_u8, 0_u8, 255_u8)),
            CrImage::Draw::ColorStop.new(0.5, CrImage::Color::RGBA.new(255_u8, 255_u8, 0_u8, 255_u8)),
            CrImage::Draw::ColorStop.new(1.0, CrImage::Color::RGBA.new(0_u8, 255_u8, 0_u8, 255_u8)),
          ]

          gradient = CrImage::Draw::RadialGradient.new(center, radius, stops)
          rect = CrImage.rect(0, 0, width, height)

          CrImage::Draw.fill_radial_gradient(img, rect, gradient)

          # Verify center is red
          c_center = img.at(center.x, center.y).as(CrImage::Color::RGBA)
          c_center.r.should eq(255)
          c_center.g.should eq(0)
          c_center.b.should eq(0)

          # Verify middle distance is yellow-ish
          mid_x = center.x + radius // 2
          c_mid = img.at(mid_x, center.y).as(CrImage::Color::RGBA)
          (c_mid.r > 200 && c_mid.g > 200).should be_true
        end
      end

      it "Single color stop gradient" do
        # Test gradient with only one stop
        30.times do
          width = Random.rand(40..80)
          height = Random.rand(40..80)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          start_point = CrImage::Point.new(0, 0)
          end_point = CrImage::Point.new(width - 1, height - 1)

          single_color = CrImage::Color::RGBA.new(100_u8, 150_u8, 200_u8, 255_u8)
          stops = [CrImage::Draw::ColorStop.new(0.5, single_color)]

          gradient = CrImage::Draw::LinearGradient.new(start_point, end_point, stops)
          rect = CrImage.rect(0, 0, width, height)

          CrImage::Draw.fill_linear_gradient(img, rect, gradient)

          # All pixels should be the same color
          height.times do |y|
            width.times do |x|
              c = img.at(x, y).as(CrImage::Color::RGBA)
              c.r.should eq(100)
              c.g.should eq(150)
              c.b.should eq(200)
            end
          end
        end
      end

      it "Gradient with degenerate line" do
        # Test linear gradient where start == end
        30.times do
          width = Random.rand(40..80)
          height = Random.rand(40..80)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Same start and end point
          point = CrImage::Point.new(width // 2, height // 2)

          stops = [
            CrImage::Draw::ColorStop.new(0.0, CrImage::Color::RGBA.new(255_u8, 0_u8, 0_u8, 255_u8)),
            CrImage::Draw::ColorStop.new(1.0, CrImage::Color::RGBA.new(0_u8, 0_u8, 255_u8, 255_u8)),
          ]

          gradient = CrImage::Draw::LinearGradient.new(point, point, stops)
          rect = CrImage.rect(0, 0, width, height)

          # Should not crash
          CrImage::Draw.fill_linear_gradient(img, rect, gradient)

          # All pixels should be the first color
          height.times do |y|
            width.times do |x|
              c = img.at(x, y).as(CrImage::Color::RGBA)
              c.r.should eq(255)
              c.g.should eq(0)
              c.b.should eq(0)
            end
          end
        end
      end

      it "Radial gradient with zero radius" do
        # Test radial gradient with radius 0
        30.times do
          width = Random.rand(40..80)
          height = Random.rand(40..80)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with black first
          height.times do |y|
            width.times do |x|
              img.set(x, y, CrImage::Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8))
            end
          end

          center = CrImage::Point.new(width // 2, height // 2)

          stops = [
            CrImage::Draw::ColorStop.new(0.0, CrImage::Color::RGBA.new(255_u8, 255_u8, 255_u8, 255_u8)),
          ]

          gradient = CrImage::Draw::RadialGradient.new(center, 0, stops)
          rect = CrImage.rect(0, 0, width, height)

          # Should not crash
          CrImage::Draw.fill_radial_gradient(img, rect, gradient)

          # Only center pixel should be white
          c_center = img.at(center.x, center.y).as(CrImage::Color::RGBA)
          c_center.r.should eq(255)
          c_center.g.should eq(255)
          c_center.b.should eq(255)
        end
      end

      it "Gradient with invalid stops raises error" do
        # Run 10 iterations with random inputs
        10.times do
          # Generate stops in descending order (invalid)
          num_stops = Random.rand(2..5)
          positions = Array.new(num_stops) { Random.rand }.sort.reverse # Descending order

          stops = [] of CrImage::Draw::ColorStop
          positions.each do |pos|
            stops << CrImage::Draw::ColorStop.new(pos, random_color)
          end

          # Ensure they're actually out of order
          if stops.size >= 2 && stops[0].position > stops[1].position
            start_point = CrImage::Point.new(0, 0)
            end_point = CrImage::Point.new(100, 100)

            # Creating gradient with invalid stops should raise error
            expect_raises(CrImage::InvalidGradientError) do
              CrImage::Draw::LinearGradient.new(start_point, end_point, stops)
            end

            # Same for radial gradient
            center = CrImage::Point.new(50, 50)
            expect_raises(CrImage::InvalidGradientError) do
              CrImage::Draw::RadialGradient.new(center, 50, stops)
            end
          end
        end
      end

      it "Stops in ascending order succeed" do
        # Verify that properly ordered stops work
        5.times do
          width = Random.rand(50..100)
          height = Random.rand(50..100)

          # Generate stops in ascending order (valid)
          num_stops = Random.rand(2..5)
          positions = Array.new(num_stops) { Random.rand }.sort # Ascending order

          stops = [] of CrImage::Draw::ColorStop
          positions.each do |pos|
            stops << CrImage::Draw::ColorStop.new(pos, random_color)
          end

          start_point = CrImage::Point.new(0, 0)
          end_point = CrImage::Point.new(width - 1, height - 1)

          # This should not raise an error
          gradient = CrImage::Draw::LinearGradient.new(start_point, end_point, stops)
          gradient.should_not be_nil

          # Same for radial gradient
          center = CrImage::Point.new(width // 2, height // 2)
          radius = [width, height].min // 2
          radial_gradient = CrImage::Draw::RadialGradient.new(center, radius, stops)
          radial_gradient.should_not be_nil
        end
      end

      it "Two stops with same position" do
        # Test stops at the same position (edge case)
        30.times do
          # Two stops at position 0.5
          stops = [
            CrImage::Draw::ColorStop.new(0.5, CrImage::Color::RGBA.new(255_u8, 0_u8, 0_u8, 255_u8)),
            CrImage::Draw::ColorStop.new(0.5, CrImage::Color::RGBA.new(0_u8, 0_u8, 255_u8, 255_u8)),
          ]

          start_point = CrImage::Point.new(0, 0)
          end_point = CrImage::Point.new(100, 100)

          # This should not raise an error (equal positions are valid, not descending)
          gradient = CrImage::Draw::LinearGradient.new(start_point, end_point, stops)
          gradient.should_not be_nil
        end
      end

      it "Stops with small differences work" do
        # Test stops with very small position differences
        30.times do
          stops = [
            CrImage::Draw::ColorStop.new(0.0, random_color),
            CrImage::Draw::ColorStop.new(0.001, random_color),
            CrImage::Draw::ColorStop.new(0.002, random_color),
            CrImage::Draw::ColorStop.new(1.0, random_color),
          ]

          start_point = CrImage::Point.new(0, 0)
          end_point = CrImage::Point.new(100, 100)

          # This should not raise an error
          gradient = CrImage::Draw::LinearGradient.new(start_point, end_point, stops)
          gradient.should_not be_nil
        end
      end

      it "Out of order stops in middle raise error" do
        # Test stops that are mostly ordered but have one out of place
        30.times do
          # Create stops: 0.0, 0.8, 0.3, 1.0 (0.8 and 0.3 are out of order)
          stops = [
            CrImage::Draw::ColorStop.new(0.0, random_color),
            CrImage::Draw::ColorStop.new(0.8, random_color),
            CrImage::Draw::ColorStop.new(0.3, random_color), # Out of order
            CrImage::Draw::ColorStop.new(1.0, random_color),
          ]

          start_point = CrImage::Point.new(0, 0)
          end_point = CrImage::Point.new(100, 100)

          # Should raise error
          expect_raises(CrImage::InvalidGradientError) do
            CrImage::Draw::LinearGradient.new(start_point, end_point, stops)
          end
        end
      end
    end
  end
end
