# Decompression Bomb Protection

## Overview

CrImage includes built-in protection against decompression bombs (also known as zip bombs or compression bombs). These are maliciously crafted compressed files that expand to enormous sizes when decompressed, potentially exhausting system memory and causing denial of service.

## How It Works

The protection system tracks two key metrics during image decoding:

1. **Expansion Ratio**: The ratio of decompressed data to compressed data
2. **Absolute Size**: The total amount of decompressed data

If either metric exceeds configured limits, decoding is aborted with a `MemoryError`.

## Default Limits

```crystal
# Maximum expansion ratio: 1000:1
# A 1KB compressed file can expand to at most 1MB
DEFAULT_MAX_EXPANSION_RATIO = 1000

# Maximum decompressed size: 500MB
DEFAULT_MAX_DECOMPRESSED_SIZE = 500_000_000

# Minimum compressed size to check ratio: 1KB
# Files smaller than this are exempt from ratio checks
MIN_COMPRESSED_SIZE_FOR_CHECK = 1024
```

## Configuration

### Using Default Configuration

By default, all image decoders use reasonable limits:

```crystal
# This uses default protection
img = CrImage::PNG.read("image.png")
img = CrImage::GIF.read("animation.gif")
```

### Custom Configuration

For trusted sources, you can use more permissive limits:

```crystal
# Create permissive config (10,000:1 ratio, 2GB max)
config = CrImage::DecompressionGuard::Config.permissive

# Apply to specific decoder (not yet exposed in public API)
# This will be added in a future update
```

For untrusted sources, use stricter limits:

```crystal
# Create strict config (100:1 ratio, 100MB max)
config = CrImage::DecompressionGuard::Config.strict
```

### Global Configuration

You can change the default configuration globally:

```crystal
# Set stricter defaults for all decoders
CrImage::DecompressionGuard.default_config =
  CrImage::DecompressionGuard::Config.strict
```

## Protected Formats

The following formats have decompression bomb protection:

- **PNG**: Protects against malicious zlib-compressed IDAT chunks
- **GIF**: Protects against malicious LZW-compressed image data
- **TIFF**: (Coming soon) Protection for LZW and other compression schemes

## Error Handling

When a decompression bomb is detected, a `MemoryError` is raised:

```crystal
begin
  img = CrImage::PNG.read("suspicious.png")
rescue ex : CrImage::MemoryError
  puts "Decompression bomb detected: #{ex.message}"
  # Example message:
  # "Decompression bomb detected in PNG: expansion ratio 5000.0:1
  #  exceeds limit of 1000:1 (1024 bytes compressed → 5120000 bytes decompressed)"
end
```

## Technical Details

### Ratio-Based Detection

The expansion ratio is calculated as:

```
ratio = decompressed_bytes / compressed_bytes
```

Small files (< 1KB compressed) are exempt from ratio checks to avoid false positives on tiny images.

### Size-Based Detection

The absolute decompressed size is checked against a maximum limit. This prevents attacks that use multiple small compressed chunks that individually pass ratio checks but collectively exhaust memory.

### Early Validation

Before starting decompression, the expected decompressed size is validated based on image dimensions:

```crystal
expected_size = width * height * bytes_per_pixel
```

This provides early rejection of oversized images before any decompression occurs.

## Performance Impact

The protection system has minimal performance impact:

- **Overhead**: < 1% for normal images
- **Memory**: Tracks two Int64 counters per decoder
- **CPU**: Simple arithmetic operations on each read

## Security Considerations

### What This Protects Against

✅ **Malicious compression bombs**: Files designed to expand to gigabytes  
✅ **Memory exhaustion attacks**: Prevents OOM crashes  
✅ **DoS attacks**: Limits resource consumption per image

### What This Doesn't Protect Against

❌ **CPU exhaustion**: Decompression still consumes CPU time  
❌ **Disk space attacks**: If writing decoded images to disk  
❌ **Multiple concurrent attacks**: Each decoder is protected individually

### Best Practices

1. **Use strict limits for untrusted input**: User uploads, external URLs
2. **Use permissive limits for trusted input**: Local files, internal systems
3. **Implement rate limiting**: Limit number of concurrent decodings
4. **Monitor resource usage**: Track memory and CPU consumption
5. **Validate file sizes**: Check compressed file size before decoding

## Examples

### Basic Usage

```crystal
# Decode with default protection
img = CrImage::PNG.read("image.png")
```

### Handling Suspicious Files

```crystal
def safe_decode(path : String) : CrImage::Image?
  begin
    CrImage.read(path)
  rescue ex : CrImage::MemoryError
    Log.warn { "Rejected suspicious file: #{path} - #{ex.message}" }
    nil
  rescue ex : CrImage::FormatError
    Log.warn { "Invalid image format: #{path}" }
    nil
  end
end
```

### Processing User Uploads

```crystal
# Use strict limits for user uploads
CrImage::DecompressionGuard.default_config =
  CrImage::DecompressionGuard::Config.strict

def process_upload(file : HTTP::FormData::Part)
  img = CrImage.read(file.body)
  # Process image...
rescue ex : CrImage::MemoryError
  # Reject upload
  {error: "File rejected: potential decompression bomb"}.to_json
end
```

## Testing

The protection system includes comprehensive tests:

```bash
crystal spec spec/util/decompression_guard_spec.cr
```

## Future Enhancements

- [ ] Expose configuration in public decoder API
- [ ] Add protection to TIFF decoder
- [ ] Add protection to WebP decoder
- [ ] Add streaming decompression with incremental checks
- [ ] Add configurable callbacks for monitoring
- [ ] Add metrics collection for security auditing

## References

- [Zip Bomb Wikipedia](https://en.wikipedia.org/wiki/Zip_bomb)
- [CWE-409: Improper Handling of Highly Compressed Data](https://cwe.mitre.org/data/definitions/409.html)
- [OWASP: Denial of Service](https://owasp.org/www-community/attacks/Denial_of_Service)
