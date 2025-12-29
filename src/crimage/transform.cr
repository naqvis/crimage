require "./image"
require "./draw"

# Image transformation and filtering operations.
#
# Provides a comprehensive set of image manipulation functions including:
# - Resizing with multiple interpolation algorithms (nearest, bilinear, bicubic, Lanczos)
# - Rotation (arbitrary angles and optimized 90°/180°/270°)
# - Flipping (horizontal and vertical)
# - Cropping to rectangles
# - Filters (blur, sharpen, Gaussian blur)
# - Adjustments (brightness, contrast, grayscale, inversion)
# - Edge detection (Sobel, Prewitt, Roberts, Scharr)
# - Visual effects (sepia, emboss, vignette, temperature)
# - In-place operations for memory efficiency
#
# Example:
# ```
# img = CrImage.read("input.png")
#
# # Resize with high quality
# resized = img.resize(800, 600, method: :lanczos)
#
# # Rotate 45 degrees
# rotated = img.rotate(45.0)
#
# # Apply filters
# blurred = img.blur_gaussian(radius: 5)
# sharpened = img.sharpen(amount: 1.5)
#
# # Adjust colors
# brighter = img.brightness(50)
# contrasted = img.contrast(1.2)
#
# # Edge detection
# edges = img.sobel
#
# # Visual effects
# vintage = img.sepia
# embossed = img.emboss
# ```
module CrImage::Transform
end

# Load transform submodules
require "./transform/resize"
require "./transform/rotate"
require "./transform/filters"
require "./transform/adjustments"
require "./transform/inplace"
require "./transform/edge_detection"
require "./transform/effects"
