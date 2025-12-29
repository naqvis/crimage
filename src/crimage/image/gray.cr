require "./image_type_macro"

module CrImage
  # Gray is an in-memory 8-bit grayscale image.
  #
  # Each pixel is stored as a single byte representing luminance (0-255).
  # This format uses 4x less memory than RGBA for grayscale images.
  #
  # Memory layout: Contiguous byte array with 1 byte per pixel
  # Color model: Grayscale (8-bit)
  #
  # Example:
  # ```
  # img = CrImage::Gray.new(CrImage.rect(0, 0, 640, 480))
  # img.set_gray(100, 100, CrImage::Color::Gray.new(128))
  # ```
  define_slice_image_type(
    Gray,
    Color::Gray,
    1,
    gray_model,
    gray_at,
    set_gray,
    Color::Gray.new(0),
    true
  )
end
