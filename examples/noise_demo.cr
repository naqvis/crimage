require "../src/crimage"

puts "=== Noise Generation and Addition Demo ===\n"

# Create a sample photo
puts "Creating sample photo..."
photo = CrImage.rgba(400, 300)
# Create a gradient background
300.times do |y|
  400.times do |x|
    r = (x * 255 // 400).clamp(0, 255)
    g = (y * 255 // 300).clamp(0, 255)
    b = 200
    photo.set(x, y, CrImage::Color.rgb(r, g, b))
  end
end
# Add some shapes
photo.draw_circle(200, 150, 80, color: CrImage::Color.rgb(255, 200, 150), fill: true, anti_alias: false)
photo.draw_rect(100, 100, 80, 80, fill: CrImage::Color.rgb(150, 255, 200))

CrImage::PNG.write("noise_original.png", photo)
puts "Saved: noise_original.png\n"

# 1. Gaussian noise (film grain)
puts "1. Adding Gaussian noise (film grain effect)..."
grain_light = photo.add_noise(0.05, CrImage::Util::NoiseType::Gaussian)
CrImage::PNG.write("noise_gaussian_light.png", grain_light)
puts "Saved: noise_gaussian_light.png (5% noise)"

grain_medium = photo.add_noise(0.15, CrImage::Util::NoiseType::Gaussian)
CrImage::PNG.write("noise_gaussian_medium.png", grain_medium)
puts "Saved: noise_gaussian_medium.png (15% noise)"

grain_heavy = photo.add_noise(0.3, CrImage::Util::NoiseType::Gaussian)
CrImage::PNG.write("noise_gaussian_heavy.png", grain_heavy)
puts "Saved: noise_gaussian_heavy.png (30% noise)"

# 2. Monochrome noise
puts "\n2. Adding monochrome noise..."
mono_noise = photo.add_noise(0.2, CrImage::Util::NoiseType::Gaussian, monochrome: true)
CrImage::PNG.write("noise_monochrome.png", mono_noise)
puts "Saved: noise_monochrome.png (same noise for all channels)"

# 3. Uniform noise
puts "\n3. Adding uniform noise..."
uniform = photo.add_noise(0.15, CrImage::Util::NoiseType::Uniform)
CrImage::PNG.write("noise_uniform.png", uniform)
puts "Saved: noise_uniform.png"

# 4. Salt and pepper noise
puts "\n4. Adding salt and pepper noise..."
salt_pepper = photo.add_noise(0.3, CrImage::Util::NoiseType::SaltAndPepper)
CrImage::PNG.write("noise_salt_pepper.png", salt_pepper)
puts "Saved: noise_salt_pepper.png"

# 5. Perlin noise overlay
puts "\n5. Adding Perlin noise..."
perlin = photo.add_noise(0.2, CrImage::Util::NoiseType::Perlin)
CrImage::PNG.write("noise_perlin.png", perlin)
puts "Saved: noise_perlin.png"

# 6. Generate noise textures
puts "\n6. Generating noise textures..."

# Gaussian noise texture
gaussian_texture = CrImage.generate_noise(400, 300, CrImage::Util::NoiseType::Gaussian)
CrImage::PNG.write("noise_texture_gaussian.png", gaussian_texture)
puts "Saved: noise_texture_gaussian.png"

# Uniform noise texture
uniform_texture = CrImage.generate_noise(400, 300, CrImage::Util::NoiseType::Uniform)
CrImage::PNG.write("noise_texture_uniform.png", uniform_texture)
puts "Saved: noise_texture_uniform.png"

# Perlin noise texture (different scales)
perlin_fine = CrImage.generate_noise(400, 300, CrImage::Util::NoiseType::Perlin, scale: 0.5)
CrImage::PNG.write("noise_texture_perlin_fine.png", perlin_fine)
puts "Saved: noise_texture_perlin_fine.png (fine scale)"

perlin_coarse = CrImage.generate_noise(400, 300, CrImage::Util::NoiseType::Perlin, scale: 2.0)
CrImage::PNG.write("noise_texture_perlin_coarse.png", perlin_coarse)
puts "Saved: noise_texture_perlin_coarse.png (coarse scale)"

# 7. Vintage film effect
puts "\n7. Creating vintage film effect..."
vintage = photo.add_noise(0.12, CrImage::Util::NoiseType::Gaussian, monochrome: true)
# Add sepia tone
vintage_sepia = vintage.sepia
CrImage::PNG.write("noise_vintage_film.png", vintage_sepia)
puts "Saved: noise_vintage_film.png (grain + sepia)"

# 8. Texture overlay
puts "\n8. Creating texture overlay..."
# Generate texture
texture = CrImage.generate_noise(400, 300, CrImage::Util::NoiseType::Perlin, scale: 1.5)
# Blend with photo (simple overlay)
textured = CrImage.rgba(400, 300)
300.times do |y|
  400.times do |x|
    photo_pixel = photo.at(x, y)
    texture_pixel = texture.at(x, y)

    pr, pg, pb, pa = photo_pixel.rgba
    tr, _, _, _ = texture_pixel.rgba

    # Blend texture as overlay
    blend_factor = (tr >> 8).to_f64 / 255.0
    new_r = ((pr >> 8).to_f64 * (0.7 + blend_factor * 0.3)).clamp(0, 255).to_i32
    new_g = ((pg >> 8).to_f64 * (0.7 + blend_factor * 0.3)).clamp(0, 255).to_i32
    new_b = ((pb >> 8).to_f64 * (0.7 + blend_factor * 0.3)).clamp(0, 255).to_i32

    textured.set(x, y, CrImage::Color.rgba(new_r.to_u8, new_g.to_u8, new_b.to_u8, (pa >> 8).to_u8))
  end
end
CrImage::PNG.write("noise_texture_overlay.png", textured)
puts "Saved: noise_texture_overlay.png"

# 9. Noise comparison
puts "\n9. Creating noise type comparison..."
comparison_images = [
  photo,
  photo.add_noise(0.15, CrImage::Util::NoiseType::Gaussian),
  photo.add_noise(0.15, CrImage::Util::NoiseType::Uniform),
  photo.add_noise(0.15, CrImage::Util::NoiseType::SaltAndPepper),
]
comparison = CrImage.create_grid(comparison_images, cols: 2, spacing: 10,
  background: CrImage::Color.rgb(240, 240, 240))
CrImage::PNG.write("noise_comparison.png", comparison)
puts "Saved: noise_comparison.png (comparison grid)"

# 10. Subtle grain for print
puts "\n10. Creating subtle grain for print quality..."
print_grain = photo.add_noise(0.03, CrImage::Util::NoiseType::Gaussian, monochrome: true)
CrImage::PNG.write("noise_print_grain.png", print_grain)
puts "Saved: noise_print_grain.png (3% subtle grain)"

puts "\n✓ Noise demo complete!"
puts "\nGenerated files:"
puts "  - noise_original.png - Original photo"
puts "  - noise_gaussian_light.png - Light film grain (5%)"
puts "  - noise_gaussian_medium.png - Medium grain (15%)"
puts "  - noise_gaussian_heavy.png - Heavy grain (30%)"
puts "  - noise_monochrome.png - Monochrome noise"
puts "  - noise_uniform.png - Uniform noise"
puts "  - noise_salt_pepper.png - Salt and pepper noise"
puts "  - noise_perlin.png - Perlin noise overlay"
puts "  - noise_texture_gaussian.png - Gaussian texture"
puts "  - noise_texture_uniform.png - Uniform texture"
puts "  - noise_texture_perlin_fine.png - Fine Perlin texture"
puts "  - noise_texture_perlin_coarse.png - Coarse Perlin texture"
puts "  - noise_vintage_film.png - Vintage film effect"
puts "  - noise_texture_overlay.png - Texture overlay"
puts "  - noise_comparison.png - Noise types comparison"
puts "  - noise_print_grain.png - Subtle print grain"
