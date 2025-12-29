require "../src/crimage"

# Create a simple animated GIF with a bouncing ball

WIDTH       = 200
HEIGHT      = 200
BALL_RADIUS =  15
FRAMES      =  20

frames = [] of CrImage::GIF::Frame

FRAMES.times do |i|
  # Create frame with white background
  img = CrImage.rgba(WIDTH, HEIGHT, CrImage::Color::WHITE)

  # Calculate ball position (bounce up and down)
  progress = i.to_f / FRAMES
  y_pos = (HEIGHT / 2 + Math.sin(progress * Math::PI * 2) * 60).to_i
  x_pos = (WIDTH / 2).to_i

  # Draw the ball (no anti-aliasing to reduce colors)
  img.draw_circle(x_pos, y_pos, BALL_RADIUS,
    color: CrImage::Color::RED,
    fill: true,
    anti_alias: false)

  # Add shadow (no anti-aliasing)
  shadow_y = HEIGHT - 30
  shadow_size = (BALL_RADIUS * (1.0 - (y_pos - HEIGHT/2).abs / 100.0)).to_i
  img.draw_circle(x_pos, shadow_y, shadow_size,
    color: CrImage::Color.rgba(128, 128, 128, 255),
    fill: true,
    anti_alias: false)

  # Create frame with 5 centiseconds delay (50ms)
  frame = CrImage::GIF::Frame.new(img, delay: 5)
  frames << frame
end

# Create animation (loop infinitely)
animation = CrImage::GIF::Animation.new(frames, WIDTH, HEIGHT, loop_count: 0)

puts "Created animation with #{animation.frames.size} frames"
puts "Total duration: #{animation.duration}ms"
puts "Animation will loop infinitely"

# Write the animated GIF
output_file = "animated_bouncing_ball.gif"
CrImage::GIF.write_animation(output_file, animation)

puts "\nSaved animated GIF: #{output_file}"
puts "Open it in a browser or image viewer to see the animation!"
