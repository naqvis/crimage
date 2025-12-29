require "./image_type_macro"

module CrImage
  # NRGBA is an in-memory image with non-premultiplied alpha.
  #
  # Each pixel is stored as 4 bytes (R, G, B, A) with color values
  # independent of alpha. This format preserves color accuracy when
  # editing transparent pixels.
  #
  # Memory layout: Contiguous byte array with 4 bytes per pixel
  # Color model: NRGBA (non-premultiplied alpha)
  #
  # Use NRGBA when:
  # - Editing images with transparency
  # - Preserving color values of transparent pixels
  # - Converting between formats without color loss
  #
  # Example:
  # ```
  # img = CrImage::NRGBA.new(CrImage.rect(0, 0, 640, 480))
  # img.set_nrgba(100, 100, CrImage::Color::NRGBA.new(255, 0, 0, 128))
  # ```
  define_slice_image_type(
    NRGBA,
    Color::NRGBA,
    4,
    nrgba_model,
    nrgba_at,
    set_nrgba,
    Color::NRGBA.new(0, 0, 0, 0),
    false
  )
end
