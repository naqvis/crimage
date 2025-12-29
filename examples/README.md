# CrImage Examples

This directory contains comprehensive examples demonstrating all features of the CrImage library.

## Edge Detection

**File:** `edge_detection_demo.cr`

Demonstrates various edge detection algorithms:

- Sobel operator (most common)
- Prewitt operator
- Roberts cross operator
- Scharr operator
- Binary edge maps with thresholding

```crystal
edges = img.sobel
binary_edges = img.sobel(threshold: 50)
```

### Visual Effects

**File:** `effects_demo.cr`

Artistic effects and filters:

- Sepia tone (vintage look)
- Emboss effect (3D raised appearance)
- Vignette (darkened edges)
- Color temperature adjustment (warm/cool tints)

```crystal
vintage = img.sepia
embossed = img.emboss
vignetted = img.vignette
warmer = img.temperature(30)
```

### Histogram Operations

**File:** `histogram_demo.cr`

Histogram analysis and contrast enhancement:

- Histogram computation and statistics
- Global histogram equalization
- Adaptive histogram equalization (CLAHE)
- Contrast improvement for low-contrast images

```crystal
hist = img.histogram
puts "Mean: #{hist.mean}, Median: #{hist.median}"
enhanced = img.equalize
adaptive = img.equalize_adaptive
```

### Advanced Dithering

**File:** `dithering_demo.cr`

Multiple dithering algorithms for color reduction:

- Floyd-Steinberg (most common)
- Atkinson (lighter, artistic)
- Sierra, Burkes, Stucki (various error diffusion)
- Ordered/Bayer matrix dithering

```crystal
dithered = img.dither(palette)
atkinson = img.dither(palette, DitheringAlgorithm::Atkinson)
```

### Image Comparison

**File:** `image_comparison_demo.cr`

Quality metrics and similarity detection:

- MSE (Mean Squared Error)
- PSNR (Peak Signal-to-Noise Ratio)
- SSIM (Structural Similarity Index)
- Perceptual hashing for duplicate detection

```crystal
mse = img1.mse(img2)
psnr = img1.psnr(img2)
ssim = img1.ssim(img2)
hash = img.perceptual_hash
```

### Visual Diff Generation

**File:** `visual_diff_demo.cr`

Image comparison and visual diff generation for regression testing:

- Generate diff images highlighting differences
- Count different pixels with configurable threshold
- Calculate difference percentage
- Check if images are identical within tolerance

```crystal
# Generate visual diff (differences in red)
diff_image = img1.visual_diff(img2, threshold: 10)

# Get statistics
diff_count = img1.diff_count(img2, threshold: 10)
diff_percent = CrImage::Util::VisualDiff.diff_percent(img1, img2)

# Check if identical
if img1.identical?(img2, threshold: 10, tolerance: 5)
  puts "Images match!"
end
```

**Use Cases:**

- Visual regression testing
- Screenshot comparison
- Change detection
- Quality assurance

### Pipeline/Fluent API

**File:** `pipeline_api_demo.cr`

Chain multiple image operations in a readable, fluent style:

- Transform operations (resize, crop, rotate, flip)
- Color adjustments (brightness, contrast, grayscale)
- Filters (blur, sharpen, edge detection)
- Effects (border, round corners, sepia, vignette)
- Drawing operations (rectangles, circles, lines)

```crystal
result = img.pipeline
  .resize(800, 600)
  .brightness(20)
  .contrast(1.2)
  .blur(2)
  .border(10, CrImage::Color::WHITE)
  .round_corners(15)
  .result

# Drawing in pipeline
canvas = CrImage.rgba(400, 300, CrImage::Color::WHITE)
  .pipeline
  .draw_rect(50, 50, 100, 80, CrImage::Color::RED)
  .draw_circle(200, 150, 40, CrImage::Color::BLUE)
  .result
```

**Use Cases:**

- Complex image processing workflows
- Readable transformation chains
- Batch processing scripts
- Quick prototyping

### Channel Operations

**File:** `channel_operations_demo.cr`

Extract, manipulate, and combine individual color channels:

- Extract single channels as grayscale images
- Split into R, G, B, A channels
- Swap channels (e.g., red ↔ blue)
- Multiply, invert, or set channels to constants
- Combine channels back into RGBA

```crystal
# Extract channels
red = img.extract_channel(:red)
r, g, b = img.split_rgb

# Manipulate channels
swapped = img.swap_channels(:red, :blue)
boosted = img.multiply_channel(:red, 1.5)
inverted = img.invert_channel(:green)

# Combine channels
combined = CrImage::Util::Channels.combine(blue, green, red)
```

**Use Cases:**

- Color correction and grading
- False color imaging
- Channel-based effects
- Image analysis

### Flood Fill and Selection

**File:** `flood_fill_demo.cr`

Flood fill, color-based selection, and color replacement:

- Flood fill connected regions (paint bucket tool)
- Create selection masks by color
- Contiguous or global selection
- Replace colors throughout image

```crystal
# Flood fill (paint bucket)
filled = img.flood_fill(x, y, CrImage::Color::BLUE, tolerance: 10)

# Create selection mask
mask = img.select_by_color(x, y, tolerance: 10, contiguous: true)

# Replace color globally
result = img.replace_color(CrImage::Color::RED, CrImage::Color::GREEN)
```

**Use Cases:**

- Paint bucket tool implementation
- Background removal
- Color replacement
- Selection tools

### Advanced Shape Drawing

**File:** `advanced_shapes_demo.cr`

Rounded rectangles, dashed lines, arcs, and pie slices:

- Rounded rectangles with configurable corner radius
- Dashed and dotted lines with presets
- Arc drawing (portions of circles)
- Pie slices (filled arcs with center lines)

```crystal
# Rounded rectangle
style = CrImage::Draw::RectStyle.new(
  fill_color: CrImage::Color::BLUE,
  corner_radius: 20)
CrImage::Draw.rectangle(img, rect, style)

# Dashed line
dashed = CrImage::Draw::DashedLineStyle.dashed(CrImage::Color::RED)
CrImage::Draw.dashed_line(img, p1, p2, dashed)

# Arc and pie
CrImage::Draw.arc(img, center, radius, start_angle, end_angle, style)
CrImage::Draw.pie(img, center, radius, start_angle, end_angle, style)
```

**Use Cases:**

- UI elements (buttons, cards)
- Charts and graphs (pie charts)
- Progress indicators
- Decorative borders

### Bezier Curves and Regular Polygons

**File:** `bezier_polygon_demo.cr`

Smooth curves and regular polygon shapes:

- Regular polygons (triangle, square, pentagon, hexagon, octagon, etc.)
- Thick circle outlines with configurable thickness
- Quadratic bezier curves (one control point)
- Cubic bezier curves (two control points)
- Smooth splines through multiple points

```crystal
# Regular polygons
style = CrImage::Draw::PolygonStyle.new(fill_color: CrImage::Color::BLUE)
CrImage::Draw.triangle(img, center, radius, style)
CrImage::Draw.hexagon(img, center, radius, style)
CrImage::Draw.regular_polygon(img, center, radius, 8, style)  # Octagon

# Thick circle outline
circle_style = CrImage::Draw::CircleStyle.new(CrImage::Color::RED).with_thickness(5)
CrImage::Draw.circle(img, center, radius, circle_style)

# Bezier curves
bezier_style = CrImage::Draw::BezierStyle.new(CrImage::Color::GREEN, thickness: 2)
CrImage::Draw.quadratic_bezier(img, start, control, end_pt, bezier_style)
CrImage::Draw.cubic_bezier(img, start, ctrl1, ctrl2, end_pt, bezier_style)

# Smooth spline through points
CrImage::Draw.spline(img, points, bezier_style, tension: 0.5)
```

**Use Cases:**

- Vector graphics and illustrations
- Smooth path drawing
- Game graphics (shapes, paths)
- Data visualization (smooth curves)
- UI design (icons, decorations)

### Charting Features (Comprehensive)

**File:** `charting_features_demo.cr`

All-in-one demo showcasing features for building charts and data visualizations:

- Bezier bands for Sankey/flow diagrams
- Path builder with fill/stroke (SVG-like API)
- Gradient fills for polygons
- Blend modes (multiply, screen, overlay, soft light)
- Pattern fills for accessibility (hatching)
- Per-corner rounded rectangles (bar charts)
- Arrow heads (6 types for flow diagrams)
- Scatter plot markers (8 types)
- Text along curves/arcs (pie chart labels)
- Annotations (callouts, dimensions, brackets)
- Gradient strokes (progress indicators)

```crystal
# Sankey-style bezier band
top = {CrImage.point(100, 100), CrImage.point(200, 100),
       CrImage.point(300, 150), CrImage.point(400, 150)}
bottom = {CrImage.point(100, 130), CrImage.point(200, 130),
          CrImage.point(300, 180), CrImage.point(400, 180)}
CrImage::Draw.fill_bezier_band(img, top, bottom, color, anti_alias: true)

# Path builder (SVG-like)
path = CrImage::Draw::Path.new
  .move_to(100, 100)
  .bezier_to(150, 50, 250, 50, 300, 100)
  .line_to(300, 200)
  .close
CrImage::Draw.fill_path_aa(img, path, color)

# Pattern fills for accessibility
pattern = CrImage::Draw::Pattern.crosshatch(CrImage::Color::BLUE, spacing: 8)
CrImage::Draw.fill_rect_pattern(img, rect, pattern)

# Text along arc (pie chart labels)
CrImage::Draw.text_on_arc(img, "LABEL", center, radius,
  start_angle, end_angle, face, color, text_offset: -15)

# Gradient stroke (progress indicator)
CrImage::Draw.stroke_arc_gradient(img, center, radius,
  start_angle, end_angle, color_stops, thickness: 8)
```

**Use Cases:**

- Sankey diagrams and flow charts
- Pie/donut charts with curved labels
- Bar charts with rounded corners
- Scatter plots with markers
- Gauge charts with gradient arcs
- Accessible charts (pattern fills)
- Annotated diagrams

### Sankey Diagram Demo

**File:** `sankey_demo.cr`

Dedicated demo for Sankey/flow diagram features:

- Multiple flow bands with bezier curves
- Semi-transparent overlapping flows
- Anti-aliased smooth edges
- Source and target node labels

```crystal
# Flow band between nodes
top_curve = {start_top, ctrl1_top, ctrl2_top, end_top}
bottom_curve = {start_bottom, ctrl1_bottom, ctrl2_bottom, end_bottom}
CrImage::Draw.fill_bezier_band(img, top_curve, bottom_curve,
  CrImage::Color.rgba(66_u8, 133_u8, 244_u8, 180_u8),
  anti_alias: true)
```

**Use Cases:**

- Energy flow diagrams
- Budget/financial flows
- Process flows
- Network traffic visualization

### Chart Helpers Demo

**File:** `chart_helpers_demo.cr`

Demonstrates chart-specific helper features:

- Pattern fills for pie/ring slices (accessibility)
- Color utilities (interpolate, luminance, contrasting)
- Legend boxes with color swatches
- Color scale bars for heatmaps
- Axes with ticks and grid lines
- Thick curves for KDE/density lines
- Data labels with backgrounds

```crystal
# Pattern-filled pie slice (accessible without color)
pattern = CrImage::Draw::Pattern.diagonal(CrImage::Color::BLUE, spacing: 6)
CrImage::Draw.fill_pie_pattern(img, center, radius, start_angle, end_angle, pattern)

# Legend box
items = [
  CrImage::Draw::LegendItem.new("Sales", CrImage::Color::BLUE),
  CrImage::Draw::LegendItem.new("Costs", CrImage::Color::RED),
]
CrImage::Draw.legend_box(img, position, items, style, font)

# Color scale for heatmaps
CrImage::Draw.color_scale(img, position, 0.0, 100.0, gradient, style, font)

# Thick smooth curve (KDE lines)
CrImage::Draw.thick_curve(img, points, color, thickness: 6)

# Auto-contrasting text color
text_color = CrImage::Color.contrasting(background)  # Returns black or white
```

**Use Cases:**

- Accessible charts (pattern fills for colorblind users)
- Chart legends and color scales
- Heatmap legends
- KDE/density curves in histograms
- Auto-contrast text on varying backgrounds

### Convenience Factory Methods

**File:** `factory_methods_demo.cr`

Quick image creation with common patterns:

- Checkerboard patterns (transparency backgrounds)
- Gradient images (horizontal, vertical, diagonal)
- Point and rectangle helpers
- Auto-format detection for read/write

```crystal
# Checkerboard (transparency background)
checker = CrImage.checkerboard(400, 300, cell_size: 16)

# Custom checkerboard (chess board)
chess = CrImage.checkerboard(400, 400, cell_size: 50,
  color1: CrImage::Color::RGBA.new(139_u8, 90_u8, 43_u8, 255_u8),
  color2: CrImage::Color::RGBA.new(222_u8, 184_u8, 135_u8, 255_u8))

# Gradients
horizontal = CrImage.gradient(300, 100, CrImage::Color::RED, CrImage::Color::BLUE, :horizontal)
vertical = CrImage.gradient(100, 300, CrImage::Color::GREEN, CrImage::Color::YELLOW, :vertical)
```

**Use Cases:**

- Transparency background visualization
- Gradient backgrounds
- Test image generation
- Quick prototyping

## Morphological Operations

**File:** `morphology_demo.cr`

Mathematical morphology for shape analysis and structure processing:

- **Erosion** - Remove noise (small bright spots)
- **Dilation** - Fill gaps (small dark holes)
- **Opening** - Clean noise removal while preserving shape
- **Closing** - Clean gap filling while preserving shape
- **Gradient** - Edge and boundary detection
- **Structuring Elements** - Rectangle, Cross, Ellipse shapes

```crystal
# Remove noise from scanned text
eroded = img.erode(5)
opened = img.morphology_open(5)

# Fill gaps in broken text
dilated = img.dilate(5)
closed = img.morphology_close(5)

# Detect edges
gradient = img.morphology_gradient(3)
```

**Note:** Morphology works on grayscale (brightness patterns), not colors. Output is black & white showing structure/shape.

**Use Cases:**

- Document scanning and OCR preprocessing
- Medical imaging analysis
- Fingerprint enhancement
- Object detection and separation

### Polaroid Effect

**File:** `polaroid_effect.cr`

Create authentic polaroid-style photos with vintage effects:

- **White border frame** - Classic polaroid proportions with larger bottom section
- **Vintage color effects** - Three styles: Classic (sepia), Faded (desaturated), Modern (minimal)
- **Subtle vignette** - Darkened edges for authentic look
- **Optional caption** - Text at bottom like handwritten notes
- **Rotation** - Slight tilt for realistic appearance
- **Soft shadow** - Depth effect with multi-pass blur
- **Paper texture** - Subtle noise on white border

```crystal
# Basic polaroid
crystal run examples/polaroid_effect.cr -- -i photo.jpg

# With caption and rotation
crystal run examples/polaroid_effect.cr -- \
  -i photo.jpg \
  -c "Summer 2024" \
  -r -3 \
  -s classic

# Faded vintage style
crystal run examples/polaroid_effect.cr -- \
  -i photo.jpg \
  -c "Memories" \
  -s faded
```

**Styles:**

- `classic` - Sepia tone, strong vintage look (default)
- `faded` - Desaturated colors, soft vintage
- `modern` - Minimal processing, clean look

**Use Cases:**

- Social media posts with retro aesthetic
- Photo albums and scrapbooking
- Vintage-themed designs
- Memory collections
- Artistic photo presentations

### Advanced Color Quantization

**File:** `quantization_demo.cr`

Optimal palette generation using sophisticated algorithms:

- **Median Cut** - Divides color space recursively, balanced quality/speed
- **Octree** - Tree-based clustering, excellent for natural images
- **Popularity** - Most frequent colors, fast and simple

```crystal
# Generate optimal palette
median_cut = img.generate_palette(16, QuantizationAlgorithm::MedianCut)
octree = img.generate_palette(16, QuantizationAlgorithm::Octree)
popularity = img.generate_palette(16, QuantizationAlgorithm::Popularity)

# Apply with dithering
dithered = img.dither(median_cut)
```

**Use Cases:**

- GIF optimization with better color selection
- Retro/pixel art with optimal palettes
- Color reduction for limited displays
- Image compression preprocessing

### Palette Extraction

**File:** `palette_extraction_demo.cr`

Extract dominant colors from images for theming and analysis:

- Extract N most dominant colors
- Get colors with their frequency weights
- Find single most dominant color
- Useful for generating color themes

```crystal
# Extract 5 dominant colors
colors = img.extract_palette(5)
colors.each { |c| puts c.to_hex }

# Get colors with frequencies
weighted = img.extract_palette_with_weights(5)
weighted.each do |color, weight|
  puts "#{color.to_hex}: #{(weight * 100).round(1)}%"
end

# Get most dominant color
dominant = img.dominant_color
```

**Use Cases:**

- Automatic color theme generation
- Image categorization by color
- Design tools and color pickers
- Color-based image search

### Smart Cropping

**File:** `smart_crop_demo.cr`

Content-aware cropping that preserves important image regions:

- **Entropy** - Keeps regions with most detail/information
- **Edge** - Keeps regions with most edges
- **CenterWeighted** - Prefers center but considers content
- **Attention** - Tries to keep faces and important subjects

```crystal
# Smart crop to 800x600 (default: entropy-based)
thumbnail = img.smart_crop(800, 600)

# Try different strategies
entropy_crop = img.smart_crop(800, 600, CrImage::Util::CropStrategy::Entropy)
edge_crop = img.smart_crop(800, 600, CrImage::Util::CropStrategy::Edge)
center_crop = img.smart_crop(800, 600, CrImage::Util::CropStrategy::CenterWeighted)
attention_crop = img.smart_crop(800, 600, CrImage::Util::CropStrategy::Attention)
```

**Use Cases:**

- Thumbnail generation for different aspect ratios
- Social media image optimization
- Responsive image cropping
- Automatic photo framing

### Sprite Sheet Generation

**File:** `sprite_generator_demo.cr`

Combine multiple images into optimized sprite sheets:

- **Horizontal** - Arrange sprites in a single row
- **Vertical** - Arrange sprites in a single column
- **Grid** - Arrange sprites in an optimal grid
- **Packed** - Efficiently pack sprites to minimize space

```crystal
# Create sprite sheet
sprites = [img1, img2, img3, img4]
sheet = CrImage.generate_sprite_sheet(
  sprites,
  CrImage::Util::SpriteLayout::Horizontal,
  spacing: 8,
  background: CrImage::Color::TRANSPARENT
)

# Save sprite sheet
CrImage::PNG.write("sprites.png", sheet.image)

# Access sprite positions
sheet.sprites.each_with_index do |sprite, i|
  puts "Sprite #{i}: x=#{sprite.x}, y=#{sprite.y}"
end

# Extract individual sprite
sprite_info = sheet[2]
extracted = sheet.image.crop(sprite_info.bounds)
```

**Use Cases:**

- Game sprite sheets for 2D games
- CSS sprites for web applications
- Texture atlases for mobile apps
- Animation frame sheets
- Icon sets and UI elements

### Borders and Frames

**File:** `border_demo.cr`

Add decorative borders, rounded corners, and drop shadows:

- **Simple Borders** - Solid color borders of any width
- **Rounded Corners** - Circular corner masking
- **Drop Shadows** - Gaussian-blurred shadows with offset
- **Rounded Frames** - Combined rounded borders with shadows
- **Nested Borders** - Multiple border layers

```crystal
img = CrImage.read("photo.jpg")

# Simple border
bordered = img.add_border(20, CrImage::Color::WHITE)

# Rounded corners
rounded = img.round_corners(30)

# Border with shadow
shadowed = img.add_border_with_shadow(20)

# Rounded border with shadow
framed = img.add_rounded_border(25, 40, shadow: true)
```

**Use Cases:**

- Social media posts and profile pictures
- Photo frames and prints
- UI elements and cards
- Instagram-style borders

### Image Tiling and Patterns

**File:** `tiling_demo.cr`

Create seamless patterns and tiled backgrounds:

- **Grid Tiling** - Repeat images in rows and columns
- **Tile to Size** - Fill exact dimensions
- **Seamless Patterns** - Edge blending for tileable textures
- **Pattern Generation** - Checkerboards, stripes, dots

```crystal
tile = CrImage.read("pattern.png")

# Tile in grid
tiled = tile.tile(4, 3)

# Tile to specific size
background = tile.tile_to_size(1920, 1080)

# Make seamless
seamless = tile.make_seamless(blend_width: 15)
```

**Use Cases:**

- Website backgrounds and wallpapers
- Texture generation for games
- Pattern design
- Repeating decorative elements

### Image Stacking and Comparison

**File:** `stacking_demo.cr`

Stack and compare images in various layouts:

- **Horizontal Stacking** - Side by side
- **Vertical Stacking** - Top to bottom
- **Alignment Options** - Top, center, bottom / left, center, right
- **Before/After Comparison** - With optional divider line
- **Grid Layouts** - Arrange in rows and columns

```crystal
# Horizontal stacking
horizontal = CrImage.stack_horizontal([img1, img2, img3], spacing: 10)

# Before/after comparison
comparison = CrImage.compare_images(before, after, divider: true)

# Grid layout
gallery = CrImage.create_grid(images, cols: 3, spacing: 15)
```

**Use Cases:**

- Before/after comparisons
- Photo galleries and portfolios
- Product comparison views
- Tutorial images
- Social media collages

### Noise Generation and Film Grain

**File:** `noise_demo.cr`

Add realistic noise and texture effects:

- **Gaussian Noise** - Natural film grain (normal distribution)
- **Uniform Noise** - Random noise with equal probability
- **Salt & Pepper** - Random black/white pixels
- **Perlin Noise** - Smooth, natural patterns
- **Monochrome Mode** - Same noise across channels
- **Texture Generation** - Create noise textures

```crystal
img = CrImage.read("photo.jpg")

# Add film grain
grainy = img.add_noise(0.1, CrImage::Util::NoiseType::Gaussian)

# Monochrome grain
vintage = img.add_noise(0.15, monochrome: true)

# Generate noise texture
texture = CrImage.generate_noise(800, 600, CrImage::Util::NoiseType::Perlin)
```

**Use Cases:**

- Vintage film and photo effects
- Texture generation for games
- Print quality enhancement
- Artistic effects and overlays

## ICO (Windows Icon) Format

**File:** `ico_demo.cr`

Multi-resolution icon file support:

- Read/write ICO files with multiple sizes
- Extract specific sizes or largest/smallest
- Create favicons for websites
- Windows application icons

```crystal
# Create multi-resolution icon
icons = [16, 32, 48].map { |size| CrImage.rgba(size, size) }
CrImage::ICO.write_multi("favicon.ico", icons)

# Read all sizes
all = CrImage::ICO.read_all("favicon.ico")
icon_32 = all.find_size(32, 32)
```

**Use Cases:**

- Website favicons
- Windows application icons
- Multi-DPI icon sets
- Icon conversion tools

## Blurhash - Compact Image Placeholders

**File:** `blurhash_demo.cr`

Encode images into compact strings for lazy-loading placeholders:

- Encode images to 20-30 character blurhash strings
- Decode blurhash to placeholder images of any size
- Extract average color without full decoding
- Configurable component count (1-9 per axis)
- Punch parameter for contrast adjustment

```crystal
# Encode image to blurhash
hash = img.to_blurhash(x_components: 4, y_components: 3)
# => "LKO2?U%2Tw=w]~RBVZRi};RPxuwH"

# Decode to placeholder
placeholder = CrImage::Util::Blurhash.decode(hash, 32, 32)

# Get average color (fast)
avg = CrImage::Util::Blurhash.average_color(hash)

# Validate hash
CrImage::Util::Blurhash.valid?(hash)  # => true
```

**Use Cases:**

- Lazy-loading image placeholders
- Progressive image loading (like Medium, Notion)
- Bandwidth-efficient previews
- Social media image previews

## QR Code Generation

**File:** `qrcode_demo.cr`

Generate QR codes following ISO/IEC 18004 specification:

- Versions 1-40 with automatic version selection
- All error correction levels (L, M, Q, H)
- Numeric, alphanumeric, and byte encoding modes
- Customizable colors, size, and margin
- Reed-Solomon error correction
- Logo/image overlay support

```crystal
# Simple QR code generation
img = CrImage.qr_code("https://example.com", size: 300)

# With options
img = CrImage.qr_code("Hello World",
  size: 400,
  error_correction: :high,
  margin: 4)

# With logo overlay (auto-uses high error correction)
logo = CrImage::PNG.read("logo.png")
img = CrImage.qr_code("https://example.com",
  size: 400,
  logo: logo,
  logo_scale: 0.2,    # 20% of QR size
  logo_border: 4)     # white border around logo

# Custom colors
img = CrImage::Util::QRCode.generate("Test",
  foreground: CrImage::Color::BLUE,
  background: CrImage::Color::WHITE)

# Low-level API
code = CrImage::Util::QRCode.encode("Data", version: 2)
img = code.to_image(module_size: 10, margin: 4)
```

**Use Cases:**

- URL and link sharing
- Contact information (vCard)
- WiFi network credentials
- Payment and ticketing
- Product labeling
- Branded QR codes with company logos

## Arbitrary Angle Rotation

**File:** `rotate_arbitrary_demo.cr`

Rotate images by any angle with interpolation:

- Rotate by arbitrary angles (not just 90° increments)
- Bilinear interpolation for smooth results
- Nearest neighbor for pixel-perfect rotation
- Custom background colors for empty areas

```crystal
# Rotate 45 degrees with bilinear interpolation
rotated = img.rotate(45.0)

# Rotate with nearest neighbor (faster, pixel-perfect)
rotated = img.rotate(30.0,
  interpolation: CrImage::Transform::RotationInterpolation::Nearest)

# Custom background color
rotated = img.rotate(15.0, background: CrImage::Color::WHITE)
```

**Use Cases:**

- Image straightening and alignment
- Artistic effects and transformations
- Document scanning corrections
- Game sprite rotation

## Decompression Bomb Protection

**File:** `decompression_bomb_demo.cr`

Security protection against malicious compressed images:

- Configurable decompression limits
- Protection against zip bombs and similar attacks
- Safe handling of untrusted images
- Customizable thresholds

```crystal
# Normal decoding (with default protection)
img = CrImage::PNG.read("image.png")

# Custom limits for strict environments
limits = CrImage::PNG::DecompressionLimits.new(
  max_pixels: 10_000_000,      # 10 megapixels
  max_decompressed_size: 100_000_000  # 100 MB
)
img = CrImage::PNG.read("image.png", limits)
```

**Use Cases:**

- Web applications accepting user uploads
- API endpoints processing images
- Automated image processing pipelines
- Security-sensitive applications

**Note:** See [Decompression Bomb Protection Guide](../guide/DECOMPRESSION_BOMB_PROTECTION.md) for details.

## Other Examples

This directory contains comprehensive examples demonstrating CrImage features, from basic operations to advanced techniques.

## Running Examples

```bash
# Create output directory
mkdir -p output

# Run any example
crystal run examples/example_name.cr

# For performance examples, build in release mode for accurate benchmarks
crystal build --release examples/performance_optimization.cr
./performance_optimization
```

**Note:** Always use `--release` flag when benchmarking! Debug builds are much slower.

## Basic Examples

### Image Format Support

- **`webp_demo.cr`** - WebP format reading and writing
- **`webp_converter.cr`** - Convert images to WebP format
- **`webp_transparency.cr`** - WebP with alpha channel
- **`read_animated_gif.cr`** - Read animated GIF files
- **`animated_gif_demo.cr`** - Create animated GIFs

### Drawing Operations

- **`draw_lines.cr`** - Line drawing with Bresenham and anti-aliasing
- **`draw_circles.cr`** - Circle and ellipse drawing
- **`draw_polygons.cr`** - Polygon drawing with fill
- **`gradient_demo.cr`** - Linear and radial gradients
- **`charting_features_demo.cr`** - Comprehensive charting features (paths, patterns, markers, arrows, annotations)
- **`sankey_demo.cr`** - Sankey/flow diagrams with bezier bands

### Text Rendering

- **`draw_text.cr`** - Basic TrueType font rendering
- **`multiline_text_demo.cr`** - Word wrapping and line spacing
- **`text_alignment_demo.cr`** - Text alignment options
- **`text_effects_demo.cr`** - Shadows and outlines
- **`text_decorations_simple.cr`** - Simple underline/strikethrough API (recommended)
- **`text_decorations_demo.cr`** - Advanced text decorations with full control
- **`generate_captcha.cr`** - CAPTCHA generation
- **`vertical_text_demo.cr`** - Vertical text layout with vhea/vmtx tables
- **`woff_demo.cr`** - WOFF (Web Open Font Format) support
- **`kerning_demo.cr`** - Kerning (character pair spacing adjustment)
- **`font_info_demo.cr`** - Font metadata and character coverage inspection
- **`font_metrics_demo.cr`** - Extended font metrics (underline, strikeout, x-height)

### Image Processing

- **`image_filters.cr`** - Blur, sharpen, brightness, contrast
- **`test_advanced_resize.cr`** - Resize algorithms comparison
- **`rotate_arbitrary_demo.cr`** - Arbitrary angle rotation with interpolation
- **`thumbnail_demo.cr`** - Thumbnail generation
- **`smart_crop_demo.cr`** - Content-aware cropping
- **`watermark_demo.cr`** - Image and text watermarks
- **`photo_collage.cr`** - Combine multiple images
- **`sprite_generator_demo.cr`** - Generate sprite sheets
- **`border_demo.cr`** - Borders, rounded corners, and drop shadows
- **`tiling_demo.cr`** - Image tiling and seamless patterns
- **`stacking_demo.cr`** - Stack and compare images
- **`noise_demo.cr`** - Noise generation and film grain effects
- **`polaroid_effect.cr`** - Create polaroid-style photos with vintage effects
- **`decompression_bomb_demo.cr`** - Security protection against malicious images
- **`visual_diff_demo.cr`** - Visual diff generation for regression testing
- **`channel_operations_demo.cr`** - Extract, manipulate, and combine color channels
- **`flood_fill_demo.cr`** - Flood fill and color selection tools
- **`pipeline_api_demo.cr`** - Fluent API for chaining operations
- **`advanced_shapes_demo.cr`** - Rounded rectangles, dashed lines, arcs, pie slices
- **`factory_methods_demo.cr`** - Checkerboard patterns, gradients, convenience methods

### Color and Palettes

- **`color_space_demo.cr`** - Color space conversions
- **`palette_visualizer.cr`** - Visualize color palettes
- **`palette_extraction_demo.cr`** - Extract dominant colors
- **`draw_floyd_steinberg.cr`** - Floyd-Steinberg dithering

### Advanced

- **`raytracer.cr`** - Simple ray tracer demonstration

## Advanced Examples (New!)

### Performance Optimization

**`performance_optimization.cr`** - Performance techniques and benchmarks

Demonstrates:

- Bulk operations vs pixel-by-pixel iteration
- In-place operations vs creating new images
- Color model selection impact on memory
- Resize algorithm performance comparison
- Sub-image operations (zero-copy)
- Color conversion caching

Run with:

```bash
# IMPORTANT: Build in release mode for accurate benchmarks!
crystal build --release examples/performance_optimization.cr
./performance_optimization
```

### Thread Safety

**`thread_safety_demo.cr`** - Thread-safe and unsafe patterns

Demonstrates:

- Safe: Parallel image processing
- Safe: Immutable operations
- Unsafe: Concurrent writes (what to avoid)
- Safe: Synchronized writes with mutex
- Safe: In-place operations (single-threaded)

Run with:

```bash
crystal run examples/thread_safety_demo.cr
```

### Advanced Color Spaces

**`advanced_color_spaces.cr`** - Color space conversions and manipulations

Demonstrates:

- YCbCr color space (JPEG/video)
- CMYK color space (printing)
- Multiple grayscale conversion methods
- Color space properties comparison
- Desaturation in YCbCr space

Run with:

```bash
crystal run examples/advanced_color_spaces.cr
```

Output files:

- `output/color_space_original.png` - Rainbow gradient
- `output/color_space_ycbcr_desaturated.png` - Desaturated in YCbCr
- `output/color_space_cmyk_channels.png` - CMYK channels
- `output/color_space_gray_weighted.png` - Perceptually weighted grayscale
- `output/color_space_gray_luminance.png` - YCbCr luminance grayscale

### YCbCr Image Editing

**`ycbcr_editing_demo.cr`** - Edit images in YCbCr color space (NEW FEATURE!)

Demonstrates:

- Creating YCbCr images with chroma subsampling
- Setting pixels directly in YCbCr space
- Editing JPEG images without RGB conversion
- Brightness adjustment preserving color
- Benefits of YCbCr editing

Run with:

```bash
crystal run examples/ycbcr_editing_demo.cr
```

Output files:

- `output/ycbcr_gradient.png` - YCbCr gradient
- `output/ycbcr_brightness_edit.png` - Brightness-adjusted image

### Advanced Text Rendering

**`advanced_text_rendering.cr`** - Advanced text features

Demonstrates:

- Basic text rendering with TrueType fonts
- Multi-line text with word wrapping
- Text alignment (left, center, right)
- Text with shadow effects
- Text with outline effects

Run with:

```bash
crystal run examples/advanced_text_rendering.cr
```

Output files:

- `output/advanced_text.png` - Multiple text styles
- `output/text_shadow.png` - Text with shadow
- `output/text_outline.png` - Text with outline

**Note:** Requires Roboto font. See `fonts/README.md` for installation.

### Font Features

**`font_features_demo.cr`** - Font metrics, kerning, and hinting

Demonstrates:

- Font metrics (ascent, descent, height)
- Glyph metrics (advance width)
- Kerning API (documented for future implementation)
- Font hinting options (None, Vertical, Full)
- Character spacing and rendering

Run with:

```bash
crystal run examples/font_features_demo.cr
```

Output files:

- `output/font_features.png` - Font rendering examples
- `output/font_hinting.png` - Hinting comparison

**Note:** Requires Roboto font. See `fonts/README.md` for installation.

### Vertical Text Layout

**`vertical_text_demo.cr`** - Vertical text rendering with font metrics

Demonstrates:

- Vertical text layout using vhea/vmtx tables
- Horizontal text for comparison
- Rotated text (90° clockwise)
- Font vertical metrics (vertical ascent/descent)
- Character-by-character vertical positioning

Run with:

```bash
crystal run examples/vertical_text_demo.cr
```

Output files:

- `vertical_text.png` - Horizontal, vertical, and rotated text comparison

**Note:** Requires fonts with vertical metrics support. Most CJK (Chinese, Japanese, Korean) fonts include vertical metrics.

### WOFF Font Support

**`woff_demo.cr`** - Web Open Font Format (WOFF) support

Demonstrates:

- WOFF signature detection
- Automatic decompression from WOFF to TrueType
- Rendering text with WOFF fonts
- Compression statistics (file size comparison)
- Transparent font format handling

Run with:

```bash
crystal run examples/woff_demo.cr
```

Output files:

- `woff_demo.png` - Text rendered from WOFF font (if font available)

**Features:**

- Zlib decompression of compressed font tables
- Full TrueType compatibility after decompression
- Validation and error handling
- Compression ratio reporting

**Note:** WOFF fonts are commonly used on the web. Download from Google Fonts or convert TTF fonts to WOFF format.

### Kerning Support

**`kerning_demo.cr`** - Character pair spacing adjustment (kerning)

Demonstrates:

- Legacy kern table parsing (format 0)
- Binary search for kerning pairs
- Visual comparison: with vs without kerning
- Kerning value inspection for common pairs (AV, To, WA, etc.)
- Font size scaling of kerning values

Run with:

```bash
crystal run examples/kerning_demo.cr
```

Output files:

- `kerning_demo.png` - Side-by-side comparison of text with and without kerning

**Features:**

- Kern table format 0 with binary search
- Proper signed 16-bit kerning values
- Automatic scaling by font size
- Validation and bounds checking

**Note on Modern Fonts:**

Most modern fonts (like Roboto, Open Sans) use **GPOS** (OpenType positioning) instead of the legacy kern table. The library currently supports:

- ✅ **Legacy kern table** - Fully implemented
- ❌ **GPOS kerning** - Detection only, not applied

**Fonts with legacy kern tables:**

- Times New Roman
- Arial
- Georgia
- Verdana
- Liberation fonts (free): https://github.com/liberationfonts/liberation-fonts
- DejaVu fonts (free): https://dejavu-fonts.github.io/

If your font has no kern table data, the demo will show identical text on both lines and display a warning message.

### Font Information & Metadata

**`font_info_demo.cr`** - Font metadata extraction and character coverage

Demonstrates:

- Name table parsing for font metadata
- Family name, style, version, copyright extraction
- PostScript name, manufacturer, designer information
- Glyph count and font properties
- Character coverage checking (`has_char?`, `has_chars?`)
- Missing character detection
- Unicode range testing (Latin, Cyrillic, Greek, Arabic, CJK, Emoji)

Run with:

```bash
crystal run examples/font_info_demo.cr
```

**Features:**

- Parse name table (format 0 and 1)
- UTF-16 Big Endian string decoding
- Platform-specific encoding support (Unicode, Windows, Macintosh)
- Character presence validation
- Unicode coverage analysis

**Use Cases:**

- Font selection and validation
- Character set verification before rendering
- Font metadata display in applications
- Unicode support checking
- Font library management

**Example Output:**

```
Family Name:      Roboto
Style Name:       Regular
Version:          Version 3.009
Glyph Count:      1321
Has Kerning:      No

✓ Latin           100.0%
✓ Greek           100.0%
✗ Arabic          0.0%
✗ CJK             0.0%
```

### Extended Font Metrics

**`font_metrics_demo.cr`** - Underline, strikeout, and typographic metrics

Demonstrates:

- Post table parsing for underline metrics
- OS/2 table parsing for strikeout and typographic metrics
- Hhea table parsing for line gap
- Scaled metrics calculation for any font size
- Visual demonstration with metric lines
- x-height and cap height extraction
- Subscript/superscript sizing information

Run with:

```bash
crystal run examples/font_metrics_demo.cr
```

Output files:

- `font_metrics_demo.png` - Visual demonstration with colored metric lines

**Features:**

- Underline position and thickness (post table)
- Strikeout position and size (OS/2 table)
- x-height (lowercase letter height)
- Cap height (uppercase letter height)
- Line gap (extra spacing between lines)
- Subscript/superscript metrics
- Automatic scaling by font size

**Use Cases:**

- Text decoration (underline, strikethrough)
- Proper line spacing calculation
- Subscript/superscript rendering (H₂O, E=mc²)
- Typography tools and editors
- Layout engines

**Example Output:**

```
Underline:
  Position:   -3px
  Thickness:  1px

Strikeout:
  Position:   8px
  Size:       1px

Typographic Metrics:
  x-height:    16px
  Cap height:  22px
  Line gap:    0px
```

## Example Categories

### By Feature

**Image I/O:**

- Format support: `webp_demo.cr`, `animated_gif_demo.cr`
- Format conversion: `webp_converter.cr`

**Drawing:**

- Primitives: `draw_lines.cr`, `draw_circles.cr`, `draw_polygons.cr`
- Gradients: `gradient_demo.cr`
- Text: `draw_text.cr`, `multiline_text_demo.cr`, `advanced_text_rendering.cr`, `vertical_text_demo.cr`, `woff_demo.cr`, `kerning_demo.cr`, `font_info_demo.cr`, `font_metrics_demo.cr`
- Charting: `charting_features_demo.cr`, `sankey_demo.cr`, `chart_helpers_demo.cr`

**Image Processing:**

- Filters: `image_filters.cr`
- Transforms: `test_advanced_resize.cr`
- Utilities: `thumbnail_demo.cr`, `smart_crop_demo.cr`, `watermark_demo.cr`, `sprite_generator_demo.cr`
- Borders: `border_demo.cr`
- Tiling: `tiling_demo.cr`
- Stacking: `stacking_demo.cr`
- Noise: `noise_demo.cr`
- Blurhash: `blurhash_demo.cr`

**Color:**

- Spaces: `color_space_demo.cr`, `advanced_color_spaces.cr`
- YCbCr: `ycbcr_editing_demo.cr`
- Palettes: `palette_visualizer.cr`, `palette_extraction_demo.cr`

**Performance:**

- Optimization: `performance_optimization.cr`
- Thread safety: `thread_safety_demo.cr`

### By Skill Level

**Beginner:**

- `draw_lines.cr` - Simple line drawing
- `draw_circles.cr` - Basic shapes
- `image_filters.cr` - Apply filters
- `thumbnail_demo.cr` - Generate thumbnails

**Intermediate:**

- `gradient_demo.cr` - Gradient fills
- `multiline_text_demo.cr` - Text layout
- `vertical_text_demo.cr` - Vertical text rendering
- `woff_demo.cr` - WOFF font support
- `kerning_demo.cr` - Character pair spacing
- `font_info_demo.cr` - Font metadata inspection
- `font_metrics_demo.cr` - Extended font metrics
- `watermark_demo.cr` - Image composition
- `animated_gif_demo.cr` - Animation
- `palette_extraction_demo.cr` - Color analysis
- `smart_crop_demo.cr` - Content-aware cropping
- `sprite_generator_demo.cr` - Sprite sheet generation
- `border_demo.cr` - Borders and frames
- `tiling_demo.cr` - Pattern generation
- `stacking_demo.cr` - Image comparison
- `noise_demo.cr` - Texture effects
- `blurhash_demo.cr` - Compact image placeholders
- `visual_diff_demo.cr` - Visual diff for testing
- `channel_operations_demo.cr` - Channel manipulation
- `flood_fill_demo.cr` - Flood fill and selection
- `pipeline_api_demo.cr` - Fluent API chains
- `advanced_shapes_demo.cr` - Advanced drawing primitives
- `bezier_polygon_demo.cr` - Bezier curves and regular polygons
- `factory_methods_demo.cr` - Convenience factory methods
- `charting_features_demo.cr` - Comprehensive charting features
- `sankey_demo.cr` - Sankey/flow diagrams
- `chart_helpers_demo.cr` - Chart helpers (legends, axes, patterns)

**Advanced:**

- `performance_optimization.cr` - Performance tuning
- `thread_safety_demo.cr` - Concurrent programming
- `advanced_color_spaces.cr` - Color theory
- `ycbcr_editing_demo.cr` - Color space manipulation
- `raytracer.cr` - Complex rendering

## Tips

### Performance

1. Use direct buffer access for bulk operations (see `performance_optimization.cr`)
2. Use in-place operations when you don't need the original
3. Choose the right color model for your use case
4. Cache color conversions when processing same colors repeatedly

### Thread Safety

1. Reading from different images in parallel is safe
2. Immutable operations (resize, blur, etc.) are safe
3. Concurrent writes to the same image require synchronization
4. In-place operations should be single-threaded

### Color Spaces

1. Use RGBA for rendering and compositing
2. Use NRGBA for editing and color accuracy
3. Use YCbCr for JPEG workflows
4. Use Gray for grayscale to save memory

### Text Rendering

1. Cache font faces for better performance
2. Use appropriate font size for your output
3. Consider text effects for better readability
4. Use word wrapping for long text

## Documentation

For more information, see:

- [Color Models Guide](../guide/COLOR_MODELS.md)
- [Performance and Thread-Safety](../guide/PERFORMANCE.md)
- [Main README](../README.md)

## Contributing Examples

When adding new examples:

1. Include clear comments explaining what the code does
2. Demonstrate one feature or concept clearly
3. Save output to `output/` directory
4. Update this README with a description
5. Keep examples focused and concise
