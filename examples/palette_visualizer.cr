require "../src/crimage"

# Visualize color palettes by creating organized images with color swatches
module PaletteVisualizer
  extend self

  # Create a visualization showing palette organization by color families
  def visualize(palette : Array(CrImage::Color::Color), name : String,
                colors_per_row : Int32, rows_per_group : Int32)
    swatch_size = 60
    gap = 2        # Gap between swatches
    group_gap = 10 # Gap between color groups

    cols = colors_per_row
    total_groups = (palette.size / (colors_per_row * rows_per_group).to_f).ceil.to_i

    # Calculate dimensions
    width = (cols * swatch_size) + ((cols - 1) * gap)
    height_per_group = (rows_per_group * swatch_size) + ((rows_per_group - 1) * gap)
    height = (total_groups * height_per_group) + ((total_groups - 1) * group_gap)

    # Create image with light gray background for empty spaces
    img = CrImage.rgba(width, height)
    background = CrImage::Color.rgb(240, 240, 240)

    # Fill entire image with background color first
    height.times do |y|
      width.times do |x|
        img.set(x, y, background)
      end
    end

    # Fill with swatches
    palette.each_with_index do |color, index|
      rgba = color.as(CrImage::Color::RGBA)

      group = index // (colors_per_row * rows_per_group)
      index_in_group = index % (colors_per_row * rows_per_group)

      col = index_in_group % colors_per_row
      row_in_group = index_in_group // colors_per_row

      x_start = col * (swatch_size + gap)
      y_start = (group * (height_per_group + group_gap)) + (row_in_group * (swatch_size + gap))

      # Fill the swatch
      swatch_size.times do |dy|
        swatch_size.times do |dx|
          x = x_start + dx
          y = y_start + dy
          if x < width && y < height
            img.set(x, y, rgba)
          end
        end
      end
    end

    # Save the image
    filename = "palette_#{name.downcase.gsub(" ", "_")}.png"
    CrImage::PNG.write(filename, img)
    puts "Created #{filename} (#{width}x#{height}px, #{palette.size} colors)"
  end
end

puts "Generating Palette Visualizations"
puts "=" * 60

# Material Design - organized by color family (7 colors + grays)
# 10 shades per color family
PaletteVisualizer.visualize(
  CrImage::Pallete::MATERIAL,
  "material",
  colors_per_row: 10, # 10 shades per row
  rows_per_group: 1   # Each color family in one row
)

# Tailwind CSS - organized by color family (8 colors)
# 10 shades per color family
PaletteVisualizer.visualize(
  CrImage::Pallete::TAILWIND,
  "tailwind",
  colors_per_row: 10, # 10 shades per row
  rows_per_group: 1   # Each color family in one row
)

# WebSafe - organized in a grid
PaletteVisualizer.visualize(
  CrImage::Pallete::WEB_SAFE,
  "websafe",
  colors_per_row: 18, # 18 colors per row
  rows_per_group: 2   # Group every 2 rows
)

puts "=" * 60
puts "All palette visualizations created successfully!"
puts "\nGenerated files:"
puts "  - palette_material.png (Material Design - 82 colors)"
puts "  - palette_tailwind.png (Tailwind CSS - 80 colors)"
puts "  - palette_websafe.png (WebSafe - 216 colors)"
puts "\nEach image shows colors organized by families with shade progression."
