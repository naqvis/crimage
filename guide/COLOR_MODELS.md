# Color Models Guide

## Overview

CrImage supports multiple color models, each optimized for different use cases. Understanding when to use each model is crucial for both correctness and performance.

## Color Models

### RGBA - Alpha-Premultiplied RGB

```crystal
color = CrImage::Color::RGBA.new(255, 0, 0, 128)  # Semi-transparent red
```

**Properties:**

- 8 bits per channel (32 bits total)
- Alpha-premultiplied: RGB values are multiplied by alpha
- Range: 0-255 for each channel

**When to use:**

- Compositing and blending operations
- Rendering pipelines
- When performance is critical for alpha blending
- Most common use case

**Advantages:**

- Fast blending: `result = src + dst * (1 - src.a)`
- No division needed for compositing
- Standard format for most graphics APIs

**Disadvantages:**

- Color values are not "pure" - they're scaled by alpha
- Converting back to NRGBA requires division
- Can lose precision with low alpha values

### NRGBA - Non-Alpha-Premultiplied RGB

```crystal
color = CrImage::Color::NRGBA.new(255, 0, 0, 128)  # Pure red, 50% transparent
```

**Properties:**

- 8 bits per channel (32 bits total)
- RGB values are independent of alpha
- Range: 0-255 for each channel

**When to use:**

- Image editing applications
- When you need to preserve original color values
- Converting between different alpha representations
- When accuracy is more important than speed

**Advantages:**

- Preserves original color values
- Easier to edit individual channels
- More intuitive for color manipulation

**Disadvantages:**

- Slower blending (requires multiplication)
- Needs conversion for most rendering operations

### RGBA64 / NRGBA64 - 16-bit Color

```crystal
color = CrImage::Color::RGBA64.new(65535, 0, 0, 32768)
```

**Properties:**

- 16 bits per channel (64 bits total)
- Higher precision than 8-bit
- Range: 0-65535 for each channel

**When to use:**

- High dynamic range (HDR) images
- Professional image editing
- When precision is critical
- Intermediate calculations to avoid rounding errors

**Advantages:**

- Much higher precision
- Reduces banding in gradients
- Better for multiple processing steps

**Disadvantages:**

- 2x memory usage
- Slower processing
- Not all formats support 16-bit

### YCbCr - Luma + Chroma

```crystal
color = CrImage::Color::YCbCr.new(128, 128, 128)
```

**Properties:**

- 8 bits per channel (24 bits total)
- Y = luma (brightness), Cb/Cr = chroma (color)
- Used by JPEG, video codecs

**When to use:**

- Working with JPEG images
- Video processing
- When chroma subsampling is beneficial
- Color space conversions

**Advantages:**

- Efficient compression (chroma subsampling)
- Matches JPEG internal format (no conversion needed)
- Separates brightness from color
- Can reduce memory by 50% with 4:2:0 subsampling

**Disadvantages:**

- Lossy conversion to/from RGB
- More complex to work with
- Not intuitive for direct manipulation

**Subsampling Ratios:**

- 4:4:4: Full resolution (no subsampling) - 3 bytes/pixel
- 4:2:2: Half horizontal chroma resolution - 2 bytes/pixel
- 4:2:0: Half horizontal and vertical chroma - 1.5 bytes/pixel

### Gray / Gray16 - Grayscale

```crystal
gray = CrImage::Color::Gray.new(128)      # 8-bit
gray16 = CrImage::Color::Gray16.new(32768) # 16-bit
```

**Properties:**

- Single channel (luminance only)
- 8-bit: 1 byte per pixel
- 16-bit: 2 bytes per pixel

**When to use:**

- Grayscale images
- Masks and alpha channels
- When color is not needed
- Memory-constrained environments

**Advantages:**

- Minimal memory usage
- Fast processing
- Simple to work with

### CMYK - Cyan, Magenta, Yellow, Black

```crystal
color = CrImage::Color::CMYK.new(0, 255, 255, 0)  # Red in CMYK
```

**Properties:**

- 8 bits per channel (32 bits total)
- Subtractive color model
- Used in printing

**When to use:**

- Print workflows
- Converting to/from print formats
- TIFF images with CMYK data

**Advantages:**

- Matches printer color model
- Better for print color accuracy

**Disadvantages:**

- Not suitable for screen display
- Requires conversion to RGB for viewing
- Color space is device-dependent

## Conversion Between Models

### Automatic Conversion

```crystal
# Any color can be converted to any model
rgba = CrImage::Color::RGBA.new(255, 0, 0, 255)
nrgba = CrImage::Color.nrgba_model.convert(rgba)
ycbcr = CrImage::Color.ycbcr_model.convert(rgba)
```

### Conversion Performance

- RGBA ↔ NRGBA: Fast (simple multiplication/division)
- RGB ↔ YCbCr: Medium (integer arithmetic, no floating point)
- RGB ↔ CMYK: Medium (integer arithmetic)
- Any ↔ Gray: Fast (weighted sum)

### Conversion Quality

- RGBA ↔ NRGBA: Lossless (with sufficient precision)
- RGB ↔ YCbCr: Lossy (rounding errors)
- RGB ↔ CMYK: Lossy (different color gamuts)
- Color ↔ Gray: Lossy (discards color information)

## Best Practices

### Choosing a Color Model

1. **For rendering and compositing**: Use RGBA
2. **For editing**: Use NRGBA
3. **For JPEG workflows**: Use YCbCr
4. **For high precision**: Use RGBA64/NRGBA64
5. **For grayscale**: Use Gray/Gray16
6. **For printing**: Use CMYK

### Minimizing Conversions

```crystal
# Bad: Multiple conversions
img = load_jpeg()  # YCbCr internally
rgba = img.to_rgba()  # Convert to RGBA
nrgba = rgba.to_nrgba()  # Convert to NRGBA
result = process(nrgba)

# Good: Single conversion
img = load_jpeg()  # YCbCr internally
nrgba = img.to_nrgba()  # Direct conversion
result = process(nrgba)
```

### Working with Alpha

```crystal
# RGBA: Alpha is premultiplied
rgba = CrImage::Color::RGBA.new(128, 0, 0, 128)
# RGB values are already scaled by alpha
# To get "pure" color: multiply by 255/alpha

# NRGBA: Alpha is separate
nrgba = CrImage::Color::NRGBA.new(255, 0, 0, 128)
# RGB values are pure, alpha is separate
# To composite: multiply RGB by alpha first
```

### Memory Considerations

```crystal
# Memory usage for 1920x1080 image:
# RGBA:    8.3 MB
# NRGBA:   8.3 MB
# RGBA64:  16.6 MB
# Gray:    2.1 MB
# YCbCr (4:2:0): 3.1 MB
# YCbCr (4:4:4): 6.2 MB
```

## Examples

### Creating Colors

```crystal
# From RGB values
red = CrImage::Color::RGBA.new(255, 0, 0, 255)

# From hex string
blue = CrImage::Color.parse("#0000FF")

# From CSS
green = CrImage::Color.parse("rgb(0, 255, 0)")

# Named colors
white = CrImage::Color::WHITE
black = CrImage::Color::BLACK
```

### Color Manipulation

```crystal
# Lighten/darken
lighter = color.lighten(0.2)  # 20% lighter
darker = color.darken(0.3)    # 30% darker

# Adjust alpha
semi_transparent = color.with_alpha(128)

# Convert to hex
hex = color.to_hex  # "#FF0000FF"

# Convert any color to 8-bit RGBA
# Useful when working with 16-bit colors (RGBA64, Gray16, etc.)
rgba8 = color.to_rgba8  # Returns RGBA with 8-bit components
```

### Image Color Model Conversion

```crystal
# Load image (format determines initial color model)
img = CrImage.load("photo.jpg")  # Likely YCbCr or RGBA

# Convert to specific model
rgba_img = CrImage::RGBA.new(img.bounds)
img.bounds.each_y do |y|
  img.bounds.each_x do |x|
    rgba_img.set(x, y, img.at(x, y))
  end
end

# Or use built-in conversion if available
gray_img = img.to_gray()
```

## Color Space Considerations

### sRGB

- Default color space for web and most displays
- Non-linear (gamma corrected)
- CrImage assumes sRGB for RGB colors

### Linear RGB

- Required for physically accurate blending
- CrImage does not automatically handle gamma correction
- Apply gamma correction manually if needed:

```crystal
def srgb_to_linear(value : UInt8) : Float64
  v = value / 255.0
  v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4
end

def linear_to_srgb(value : Float64) : UInt8
  v = value <= 0.0031308 ? value * 12.92 : 1.055 * (value ** (1.0/2.4)) - 0.055
  (v * 255).clamp(0, 255).to_u8
end
```

## Summary

| Model  | Size   | Use Case         | Speed     | Precision |
| ------ | ------ | ---------------- | --------- | --------- |
| RGBA   | 4B     | Rendering        | Fast      | Good      |
| NRGBA  | 4B     | Editing          | Medium    | Good      |
| RGBA64 | 8B     | HDR/Professional | Slow      | Excellent |
| YCbCr  | 1.5-3B | JPEG/Video       | Fast      | Good      |
| Gray   | 1B     | Grayscale        | Very Fast | Good      |
| CMYK   | 4B     | Printing         | Medium    | Good      |
