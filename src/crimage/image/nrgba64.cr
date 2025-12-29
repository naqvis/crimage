require "./image_type_macro"

module CrImage
  # NRGBA64 is an in-memory 64-bit image with non-premultiplied alpha.
  #
  # Each pixel is stored as 8 bytes (16 bits per channel: R, G, B, A).
  # Provides higher color precision with independent alpha channel.
  #
  # Memory layout: Contiguous byte array with 8 bytes per pixel
  # Color model: NRGBA64 (non-premultiplied alpha, 16-bit per channel)
  #
  # Example:
  # ```
  # img = CrImage::NRGBA64.new(CrImage.rect(0, 0, 640, 480))
  # img.set_nrgba64(100, 100, CrImage::Color::NRGBA64.new(65535, 0, 0, 32768))
  # ```
  define_slice_image_type(
    NRGBA64,
    Color::NRGBA64,
    8,
    nrgba64_model,
    nrgba64_at,
    set_nrgba64,
    Color::NRGBA64.new(0, 0, 0, 0),
    false
  )
end
