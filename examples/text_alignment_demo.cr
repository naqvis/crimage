require "../src/crimage"
require "../src/freetype"

# This example demonstrates text alignment features
# It shows how to align text horizontally (left, center, right)
# and vertically (top, middle, bottom) within bounding boxes

# Load a font
font_path = "fonts/Roboto/static/Roboto-Regular.ttf"
unless File.exists?(font_path)
  puts "Font file not found: #{font_path}"
  exit 1
end

font = FreeType::TrueType.load(font_path)
face = FreeType::TrueType.new_face(font, 20.0)

# Create a canvas
width = 800
height = 600
img = CrImage.rgba(width, height)

# Fill with white background
img.fill(CrImage::Color::WHITE)

# Create a black color source for text
black = CrImage::Uniform.new(CrImage::Color::BLACK)

# Create a red color for box outlines
red = CrImage::Color::RED

# Helper to draw a rectangle outline using high-level API
def draw_rect_outline(img, rect, color)
  img.draw_rect(rect.min.x, rect.min.y, rect.width, rect.height, stroke: color)
end

# Demo 1: Horizontal alignment (top row)
y_offset = 50
box_width = 200
box_height = 80
spacing = 50

# Left alignment
rect1 = CrImage.rect(50, y_offset, 50 + box_width, y_offset + box_height)
draw_rect_outline(img, rect1, red)
text_box1 = CrImage::Font::TextBox.new(rect1, CrImage::Font::HorizontalAlign::Left, CrImage::Font::VerticalAlign::Top)
drawer1 = CrImage::Font::Drawer.new(img, black, face)
drawer1.draw_aligned("Left Aligned", text_box1)

# Center alignment
rect2 = CrImage.rect(50 + box_width + spacing, y_offset, 50 + 2 * box_width + spacing, y_offset + box_height)
draw_rect_outline(img, rect2, red)
text_box2 = CrImage::Font::TextBox.new(rect2, CrImage::Font::HorizontalAlign::Center, CrImage::Font::VerticalAlign::Top)
drawer2 = CrImage::Font::Drawer.new(img, black, face)
drawer2.draw_aligned("Center", text_box2)

# Right alignment
rect3 = CrImage.rect(50 + 2 * (box_width + spacing), y_offset, 50 + 3 * box_width + 2 * spacing, y_offset + box_height)
draw_rect_outline(img, rect3, red)
text_box3 = CrImage::Font::TextBox.new(rect3, CrImage::Font::HorizontalAlign::Right, CrImage::Font::VerticalAlign::Top)
drawer3 = CrImage::Font::Drawer.new(img, black, face)
drawer3.draw_aligned("Right Aligned", text_box3)

# Demo 2: Vertical alignment (middle column)
y_offset2 = 200
box_width2 = 180
box_height2 = 100

# Top alignment
rect4 = CrImage.rect(50, y_offset2, 50 + box_width2, y_offset2 + box_height2)
draw_rect_outline(img, rect4, red)
text_box4 = CrImage::Font::TextBox.new(rect4, CrImage::Font::HorizontalAlign::Center, CrImage::Font::VerticalAlign::Top)
drawer4 = CrImage::Font::Drawer.new(img, black, face)
drawer4.draw_aligned("Top", text_box4)

# Middle alignment
rect5 = CrImage.rect(50 + box_width2 + spacing, y_offset2, 50 + 2 * box_width2 + spacing, y_offset2 + box_height2)
draw_rect_outline(img, rect5, red)
text_box5 = CrImage::Font::TextBox.new(rect5, CrImage::Font::HorizontalAlign::Center, CrImage::Font::VerticalAlign::Middle)
drawer5 = CrImage::Font::Drawer.new(img, black, face)
drawer5.draw_aligned("Middle", text_box5)

# Bottom alignment
rect6 = CrImage.rect(50 + 2 * (box_width2 + spacing), y_offset2, 50 + 3 * box_width2 + 2 * spacing, y_offset2 + box_height2)
draw_rect_outline(img, rect6, red)
text_box6 = CrImage::Font::TextBox.new(rect6, CrImage::Font::HorizontalAlign::Center, CrImage::Font::VerticalAlign::Bottom)
drawer6 = CrImage::Font::Drawer.new(img, black, face)
drawer6.draw_aligned("Bottom", text_box6)

# Demo 3: Combined alignment (bottom section)
y_offset3 = 380
box_width3 = 220
box_height3 = 150

# Top-Left
rect7 = CrImage.rect(50, y_offset3, 50 + box_width3, y_offset3 + box_height3)
draw_rect_outline(img, rect7, red)
text_box7 = CrImage::Font::TextBox.new(rect7, CrImage::Font::HorizontalAlign::Left, CrImage::Font::VerticalAlign::Top)
drawer7 = CrImage::Font::Drawer.new(img, black, face)
drawer7.draw_aligned("Top-Left", text_box7)

# Center-Middle
rect8 = CrImage.rect(50 + box_width3 + spacing, y_offset3, 50 + 2 * box_width3 + spacing, y_offset3 + box_height3)
draw_rect_outline(img, rect8, red)
text_box8 = CrImage::Font::TextBox.new(rect8, CrImage::Font::HorizontalAlign::Center, CrImage::Font::VerticalAlign::Middle)
drawer8 = CrImage::Font::Drawer.new(img, black, face)
drawer8.draw_aligned("Center-Middle", text_box8)

# Bottom-Right
rect9 = CrImage.rect(50 + 2 * (box_width3 + spacing), y_offset3, 50 + 3 * box_width3 + 2 * spacing, y_offset3 + box_height3)
draw_rect_outline(img, rect9, red)
text_box9 = CrImage::Font::TextBox.new(rect9, CrImage::Font::HorizontalAlign::Right, CrImage::Font::VerticalAlign::Bottom)
drawer9 = CrImage::Font::Drawer.new(img, black, face)
drawer9.draw_aligned("Bottom-Right", text_box9)

# Save the result
output_path = "text_alignment_demo.png"
CrImage::PNG.write(output_path, img)

puts "Text alignment demo saved to #{output_path}"
puts "The image shows:"
puts "  - Top row: Left, Center, Right horizontal alignment"
puts "  - Middle row: Top, Middle, Bottom vertical alignment"
puts "  - Bottom row: Combined alignments (Top-Left, Center-Middle, Bottom-Right)"
