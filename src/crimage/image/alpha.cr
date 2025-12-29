require "./image_type_macro"

module CrImage
  # Alpha is an in-memory 8-bit alpha channel image.
  #
  # Each pixel is stored as a single byte representing opacity (0-255).
  # Used for masks and transparency maps.
  #
  # Memory layout: Contiguous byte array with 1 byte per pixel
  # Color model: Alpha only (8-bit)
  #
  # Example:
  # ```
  # mask = CrImage::Alpha.new(CrImage.rect(0, 0, 640, 480))
  # mask.set_alpha(100, 100, CrImage::Color::Alpha.new(128))
  # ```
  define_slice_image_type(
    Alpha,
    Color::Alpha,
    1,
    alpha_model,
    alpha_at,
    set_alpha,
    Color::Alpha.new(0),
    false,
    "a"
  )
end
