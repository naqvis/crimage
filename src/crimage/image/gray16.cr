require "./image_type_macro"

module CrImage
  # Gray16 is an in-memory 16-bit grayscale image.
  #
  # Each pixel is stored as 2 bytes representing luminance (0-65535).
  # Provides higher precision than 8-bit Gray for smooth gradients and scientific imaging.
  #
  # Memory layout: Contiguous byte array with 2 bytes per pixel
  # Color model: Grayscale (16-bit)
  #
  # Example:
  # ```
  # img = CrImage::Gray16.new(CrImage.rect(0, 0, 640, 480))
  # img.set_gray16(100, 100, CrImage::Color::Gray16.new(32768))
  # ```
  define_slice_image_type(
    Gray16,
    Color::Gray16,
    2,
    gray16_model,
    gray16_at,
    set_gray16,
    Color::Gray16.new(0),
    true
  )
end
