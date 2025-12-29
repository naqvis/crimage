# Performance and Thread-Safety Guide

## Thread-Safety

### Thread-Safe Components

- **Image Reading**: All image decoders (PNG, JPEG, GIF, BMP, TIFF, WebP) are thread-safe for reading from different IO sources
- **Color Conversions**: All color model conversions are pure functions and thread-safe
- **Immutable Operations**: Methods that return new images are thread-safe

### Not Thread-Safe

- **Image Writing**: Concurrent writes to the same image instance will cause data races
- **Pixel Manipulation**: Calling `set()` on the same image from multiple threads requires external synchronization
- **Transform Operations**: In-place transforms (methods with `!` suffix) are not thread-safe

### Best Practices

```crystal
# Safe: Reading from different images in parallel
images = [img1, img2, img3]
channel = Channel(CrImage::RGBA).new
images.each do |img|
  spawn do
    result = img.resize(100, 100)
    channel.send(result)
  end
end

# Unsafe: Writing to same image from multiple threads
# DON'T DO THIS:
spawn { img.set(0, 0, color1) }
spawn { img.set(1, 1, color2) }  # Data race!

# Safe: Use separate images or synchronize access
mutex = Mutex.new
spawn { mutex.synchronize { img.set(0, 0, color1) } }
spawn { mutex.synchronize { img.set(1, 1, color2) } }
```

## Performance Characteristics

### Image Types

#### RGBA vs NRGBA

- **RGBA**: Alpha-premultiplied, faster for compositing operations
  - Use when: Blending multiple images, alpha compositing
  - Complexity: O(1) per pixel for blending
- **NRGBA**: Non-alpha-premultiplied, preserves original color values
  - Use when: Editing individual pixels, preserving color accuracy
  - Complexity: O(1) per pixel, but requires multiplication for compositing

**Recommendation**: Use RGBA for rendering pipelines, NRGBA for editing

#### YCbCr

- **Read**: O(1) per pixel
- **Write**: O(1) per pixel (now supported)
- **Conversion to RGB**: O(1) per pixel with integer-only arithmetic
- **Use when**: Working with JPEG images, video frames
- **Note**: Subsampling (4:2:0, 4:2:2) reduces memory by 50%

### Operations Complexity

#### Pixel Access

- `at(x, y)`: O(1) - Direct array access
- `set(x, y, color)`: O(1) - Direct array access
- Bounds checking: O(1) - Simple comparison

#### Drawing Operations

- `draw_line()`: O(length) - Bresenham's algorithm
- `draw_circle()`: O(radius) - Midpoint circle algorithm
- `draw_filled_circle()`: O(radius²) - Scanline filling
- `draw_polygon()`: O(vertices × height) - Scanline algorithm
- `draw_text()`: O(glyphs × glyph_complexity)

#### Transforms

- `resize()`: O(width × height × kernel_size²)
  - Nearest: O(width × height)
  - Bilinear: O(width × height × 4)
  - Bicubic: O(width × height × 16)
  - Lanczos: O(width × height × (2×a)²) where a is the filter size
- `rotate()`: O(width × height)
- `crop()`: O(1) - Returns sub-image view (no copy)
- `flip()`: O(width × height)

#### Filters

- `blur()`: O(width × height × kernel_size²)
- `sharpen()`: O(width × height × 9)
- `grayscale()`: O(width × height)
- `adjust_brightness()`: O(width × height)

### Memory Usage

#### Image Storage

```
RGBA:    4 bytes per pixel
NRGBA:   4 bytes per pixel
RGBA64:  8 bytes per pixel
NRGBA64: 8 bytes per pixel
Gray:    1 byte per pixel
Gray16:  2 bytes per pixel
YCbCr:   1.5 bytes per pixel (4:2:0 subsampling)
         2 bytes per pixel (4:2:2 subsampling)
         3 bytes per pixel (4:4:4 subsampling)
```

#### Memory Optimization Tips

1. Use `Gray` for grayscale images instead of `RGBA`
2. Use `sub_image()` to work on regions without copying
3. Use in-place operations (`!` suffix) when possible
4. Consider YCbCr for JPEG workflows
5. Use 8-bit types unless you need 16-bit precision

### Optimization Strategies

#### Bulk Operations

```crystal
# Slow: Pixel-by-pixel iteration
img.bounds.each_y do |y|
  img.bounds.each_x do |x|
    color = img.at(x, y)
    # process color
    img.set(x, y, new_color)
  end
end

# Fast: Direct pixel buffer access (when possible)
# Access img.pix directly for bulk operations
stride = img.stride
bounds = img.bounds
(bounds.min.y...bounds.max.y).each do |y|
  offset = y * stride
  (bounds.min.x...bounds.max.x).each do |x|
    idx = offset + x * 4
    # Direct buffer manipulation
    img.pix[idx] = r
    img.pix[idx + 1] = g
    img.pix[idx + 2] = b
    img.pix[idx + 3] = a
  end
end
```

#### Color Conversions

- Avoid repeated conversions: cache converted colors
- Use the appropriate color model for your operation
- Batch convert when processing multiple pixels

#### Font Rendering

- Cache font instances
- Reuse glyph data when rendering same text
- Consider pre-rendering common text to images

### Benchmarking

To measure performance in your application:

```crystal
require "benchmark"

img = CrImage::RGBA.new(1000, 1000)

Benchmark.ips do |x|
  x.report("pixel access") { img.at(500, 500) }
  x.report("pixel set") { img.set(500, 500, CrImage::Color::RED) }
  x.report("resize") { img.resize(500, 500) }
end
```

## Known Performance Limitations

### 1. Pixel-by-pixel iteration

Some operations still use `.each` loops instead of bulk operations.

**What it would take**:

- Refactor filter operations to use direct buffer access
- Replace `.each` loops with index-based iteration
- Add SIMD-friendly memory layouts where possible
- Example: `blur()`, `sharpen()`, `adjust_brightness()` could be 2-3x faster

## Future Optimizations

- SIMD operations for bulk pixel processing
- GPU acceleration for transforms and filters
- Parallel processing for large images
- More efficient scanline algorithms
