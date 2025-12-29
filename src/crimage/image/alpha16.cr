require "./image_type_macro"

module CrImage
  # Alpha16 is an in-memory 16-bit alpha channel image.
  #
  # Each pixel is stored as 2 bytes representing opacity (0-65535).
  # Provides higher precision than 8-bit Alpha for smooth transparency gradients.
  #
  # Memory layout: Contiguous byte array with 2 bytes per pixel
  # Color model: Alpha only (16-bit)
  #
  # Example:
  # ```
  # mask = CrImage::Alpha16.new(CrImage.rect(0, 0, 640, 480))
  # mask.set_alpha16(100, 100, CrImage::Color::Alpha16.new(32768))
  # ```
  define_slice_image_type(
    Alpha16,
    Color::Alpha16,
    2,
    alpha16_model,
    alpha16_at,
    set_alpha16,
    Color::Alpha16.new(0),
    false,
    "a"
  )
end
