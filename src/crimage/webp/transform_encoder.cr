require "../color/color"

module CrImage::WEBP
  # TransformEncoder handles WebP lossless transform operations.
  #
  # Implements the four VP8L transforms that improve compression:
  # - Predictor: Predicts pixels from neighbors, encodes differences
  # - Color: Correlates color channels
  # - Subtract Green: Removes green from red and blue channels
  # - Color Indexing (Palette): Reduces to indexed colors
  class TransformEncoder
    # Transform types
    enum Transform
      Predict       = 0
      Color         = 1
      SubGreen      = 2
      ColorIndexing = 3
    end

    # Applies predictor transform to pixels.
    #
    # Divides image into tiles, selects best predictor mode for each tile
    # based on entropy, and encodes pixel differences from predictions.
    #
    # Returns: Tuple of {tile_bits, block_width, block_height, predictor_blocks}
    def self.apply_predictor(pixels : Array(CrImage::Color::NRGBA), width : Int32, height : Int32) : {Int32, Int32, Int32, Array(CrImage::Color::NRGBA)}
      tile_bits = 4
      tile_size = 1 << tile_bits
      bw = (width + tile_size - 1) // tile_size
      bh = (height + tile_size - 1) // tile_size

      blocks = Array(CrImage::Color::NRGBA).new(bw * bh, CrImage::Color::NRGBA.new(0_u8, 0_u8, 0_u8, 255_u8))
      deltas = Array(CrImage::Color::NRGBA).new(width * height, CrImage::Color::NRGBA.new(0_u8, 0_u8, 0_u8, 255_u8))

      # Accumulators for entropy calculation
      accum = Array.new(4) { Array.new(256, 0) }

      bh.times do |y|
        bw.times do |x|
          mx = {(x + 1) << tile_bits, width}.min
          my = {(y + 1) << tile_bits, height}.min

          # Find best predictor mode for this block
          best = 0
          best_entropy = 0.0

          14.times do |mode|
            # Create temporary histograms
            histos = Array.new(4) { |i| accum[i].dup }

            # Calculate entropy for this predictor mode
            (x << tile_bits).upto(mx - 1) do |tx|
              (y << tile_bits).upto(my - 1) do |ty|
                pred = apply_filter(pixels, width, tx, ty, mode)
                off = ty * width + tx

                histos[0][(pixels[off].r.to_i32 - pred.r.to_i32) & 0xff] += 1
                histos[1][(pixels[off].g.to_i32 - pred.g.to_i32) & 0xff] += 1
                histos[2][(pixels[off].b.to_i32 - pred.b.to_i32) & 0xff] += 1
                histos[3][(pixels[off].a.to_i32 - pred.a.to_i32) & 0xff] += 1
              end
            end

            # Calculate total entropy
            total = 0.0
            histos.each do |histo|
              sum = 0_i64
              sum_squares = 0_i64

              histo.each do |count|
                sum += count
                sum_squares += count.to_i64 * count.to_i64
              end

              next if sum == 0
              total += 1.0 - sum_squares.to_f / (sum.to_f * sum.to_f)
            end

            if mode == 0 || total < best_entropy
              best_entropy = total
              best = mode
            end
          end

          # Apply best predictor to block
          (x << tile_bits).upto(mx - 1) do |tx|
            (y << tile_bits).upto(my - 1) do |ty|
              pred = apply_filter(pixels, width, tx, ty, best)
              off = ty * width + tx

              deltas[off] = CrImage::Color::NRGBA.new(
                ((pixels[off].r.to_i32 - pred.r.to_i32) & 0xff).to_u8,
                ((pixels[off].g.to_i32 - pred.g.to_i32) & 0xff).to_u8,
                ((pixels[off].b.to_i32 - pred.b.to_i32) & 0xff).to_u8,
                ((pixels[off].a.to_i32 - pred.a.to_i32) & 0xff).to_u8
              )

              accum[0][(pixels[off].r.to_i32 - pred.r.to_i32) & 0xff] += 1
              accum[1][(pixels[off].g.to_i32 - pred.g.to_i32) & 0xff] += 1
              accum[2][(pixels[off].b.to_i32 - pred.b.to_i32) & 0xff] += 1
              accum[3][(pixels[off].a.to_i32 - pred.a.to_i32) & 0xff] += 1
            end
          end

          blocks[y * bw + x] = CrImage::Color::NRGBA.new(0_u8, best.to_u8, 0_u8, 255_u8)
        end
      end

      # Copy deltas back to pixels
      deltas.each_with_index { |d, i| pixels[i] = d }

      {tile_bits, bw, bh, blocks}
    end

    # Applies predictor filter at position (x, y) with given prediction mode.
    #
    # VP8L defines 14 predictor modes using combinations of neighboring
    # pixels (left, top, top-left, top-right).
    private def self.apply_filter(pixels : Array(CrImage::Color::NRGBA), width : Int32, x : Int32, y : Int32, prediction : Int32) : CrImage::Color::NRGBA
      # Edge cases
      return CrImage::Color::NRGBA.new(0_u8, 0_u8, 0_u8, 255_u8) if x == 0 && y == 0
      return pixels[(y - 1) * width + x] if x == 0
      return pixels[y * width + (x - 1)] if y == 0

      t = pixels[(y - 1) * width + x]        # top
      l = pixels[y * width + (x - 1)]        # left
      tl = pixels[(y - 1) * width + (x - 1)] # top-left
      tr = pixels[(y - 1) * width + (x + 1)] # top-right (may be out of bounds)

      case prediction
      when 0 # Black
        CrImage::Color::NRGBA.new(0_u8, 0_u8, 0_u8, 255_u8)
      when 1 # L
        l
      when 2 # T
        t
      when 3 # TR
        tr
      when 4 # TL
        tl
      when 5 # Average2(Average2(L, TR), T)
        avg1 = average2(l, tr)
        average2(avg1, t)
      when 6 # Average2(L, TL)
        average2(l, tl)
      when 7 # Average2(L, T)
        average2(l, t)
      when 8 # Average2(TL, T)
        average2(tl, t)
      when 9 # Average2(T, TR)
        average2(t, tr)
      when 10 # Average2(Average2(L, TL), Average2(T, TR))
        avg1 = average2(l, tl)
        avg2 = average2(t, tr)
        average2(avg1, avg2)
      when 11 # Select(L, T, TL)
        select_predictor(l, t, tl)
      when 12 # ClampAddSubtractFull(L, T, TL)
        clamp_add_subtract_full(l, t, tl)
      when 13 # ClampAddSubtractHalf(Average2(L, T), TL)
        avg = average2(l, t)
        clamp_add_subtract_half(avg, tl)
      else
        CrImage::Color::NRGBA.new(0_u8, 0_u8, 0_u8, 255_u8)
      end
    end

    # Computes average of two colors (component-wise).
    private def self.average2(a : CrImage::Color::NRGBA, b : CrImage::Color::NRGBA) : CrImage::Color::NRGBA
      CrImage::Color::NRGBA.new(
        ((a.r.to_i32 + b.r.to_i32) // 2).to_u8,
        ((a.g.to_i32 + b.g.to_i32) // 2).to_u8,
        ((a.b.to_i32 + b.b.to_i32) // 2).to_u8,
        ((a.a.to_i32 + b.a.to_i32) // 2).to_u8
      )
    end

    # Selects predictor based on Manhattan distance.
    #
    # Chooses between left and top pixel based on which is closer
    # to the predicted value (L + T - TL).
    private def self.select_predictor(l : CrImage::Color::NRGBA, t : CrImage::Color::NRGBA, tl : CrImage::Color::NRGBA) : CrImage::Color::NRGBA
      pr = l.r.to_f64 + t.r.to_f64 - tl.r.to_f64
      pg = l.g.to_f64 + t.g.to_f64 - tl.g.to_f64
      pb = l.b.to_f64 + t.b.to_f64 - tl.b.to_f64
      pa = l.a.to_f64 + t.a.to_f64 - tl.a.to_f64

      # Manhattan distances
      pl = (pa - l.a.to_f64).abs + (pr - l.r.to_f64).abs + (pg - l.g.to_f64).abs + (pb - l.b.to_f64).abs
      pt = (pa - t.a.to_f64).abs + (pr - t.r.to_f64).abs + (pg - t.g.to_f64).abs + (pb - t.b.to_f64).abs

      pl < pt ? l : t
    end

    # Clamp add subtract full
    private def self.clamp_add_subtract_full(l : CrImage::Color::NRGBA, t : CrImage::Color::NRGBA, tl : CrImage::Color::NRGBA) : CrImage::Color::NRGBA
      CrImage::Color::NRGBA.new(
        clamp(l.r.to_i32 + t.r.to_i32 - tl.r.to_i32),
        clamp(l.g.to_i32 + t.g.to_i32 - tl.g.to_i32),
        clamp(l.b.to_i32 + t.b.to_i32 - tl.b.to_i32),
        clamp(l.a.to_i32 + t.a.to_i32 - tl.a.to_i32)
      )
    end

    # Clamp add subtract half
    private def self.clamp_add_subtract_half(avg : CrImage::Color::NRGBA, tl : CrImage::Color::NRGBA) : CrImage::Color::NRGBA
      CrImage::Color::NRGBA.new(
        clamp(avg.r.to_i32 + (avg.r.to_i32 - tl.r.to_i32) // 2),
        clamp(avg.g.to_i32 + (avg.g.to_i32 - tl.g.to_i32) // 2),
        clamp(avg.b.to_i32 + (avg.b.to_i32 - tl.b.to_i32) // 2),
        clamp(avg.a.to_i32 + (avg.a.to_i32 - tl.a.to_i32) // 2)
      )
    end

    # Clamps value to 0-255 range for valid byte value.
    private def self.clamp(value : Int32) : UInt8
      {0, {255, value}.min}.max.to_u8
    end

    # Applies color transform to pixels.
    #
    # Decorrelates color channels by subtracting scaled green from
    # red and blue. Improves compression for natural images.
    #
    # Returns: Tuple of {tile_bits, block_width, block_height, transform_blocks}
    def self.apply_color(pixels : Array(CrImage::Color::NRGBA), width : Int32, height : Int32) : {Int32, Int32, Int32, Array(CrImage::Color::NRGBA)}
      tile_bits = 4
      tile_size = 1 << tile_bits
      bw = (width + tile_size - 1) // tile_size
      bh = (height + tile_size - 1) // tile_size

      blocks = Array(CrImage::Color::NRGBA).new(bw * bh, CrImage::Color::NRGBA.new(0_u8, 0_u8, 0_u8, 255_u8))
      deltas = Array(CrImage::Color::NRGBA).new(width * height, CrImage::Color::NRGBA.new(0_u8, 0_u8, 0_u8, 255_u8))

      # Color transform element (simplified - using fixed values)
      cte = CrImage::Color::NRGBA.new(1_u8, 2_u8, 3_u8, 255_u8)

      bh.times do |y|
        bw.times do |x|
          mx = {(x + 1) << tile_bits, width}.min
          my = {(y + 1) << tile_bits, height}.min

          (x << tile_bits).upto(mx - 1) do |tx|
            (y << tile_bits).upto(my - 1) do |ty|
              off = ty * width + tx

              r = pixels[off].r.to_i8!.to_i32
              g = pixels[off].g.to_i8!.to_i32
              b = pixels[off].b.to_i8!.to_i32

              # Apply color transform
              b -= ((cte.g.to_i8!.to_i16 * g.to_i16) >> 5).to_i32
              b -= ((cte.r.to_i8!.to_i16 * r.to_i16) >> 5).to_i32
              r -= ((cte.b.to_i8!.to_i16 * g.to_i16) >> 5).to_i32

              deltas[off] = CrImage::Color::NRGBA.new(
                (r & 0xff).to_u8,
                pixels[off].g,
                (b & 0xff).to_u8,
                pixels[off].a
              )
            end
          end

          blocks[y * bw + x] = cte
        end
      end

      # Copy deltas back to pixels
      deltas.each_with_index { |d, i| pixels[i] = d }

      {tile_bits, bw, bh, blocks}
    end

    # Applies subtract green transform.
    #
    # Subtracts green channel from red and blue channels. This simple
    # transform exploits correlation between color channels.
    def self.apply_subtract_green(pixels : Array(CrImage::Color::NRGBA)) : Nil
      pixels.each_with_index do |pixel, i|
        pixels[i] = CrImage::Color::NRGBA.new(
          (pixel.r &- pixel.g).to_u8,
          pixel.g,
          (pixel.b &- pixel.g).to_u8,
          pixel.a
        )
      end
    end

    # Applies palette transform.
    #
    # Extracts unique colors as palette, packs pixel indices efficiently
    # (1, 2, 4, or 8 pixels per byte depending on palette size), and
    # applies delta encoding to palette.
    #
    # Returns: Tuple of {palette, packed_width}
    #
    # Raises: `FormatError` if more than 256 unique colors
    def self.apply_palette(pixels : Array(CrImage::Color::NRGBA), width : Int32, height : Int32) : {Array(CrImage::Color::NRGBA), Int32}
      # Extract unique colors
      palette = [] of CrImage::Color::NRGBA
      pixels.each do |p|
        palette << p unless palette.includes?(p)
        raise CrImage::FormatError.new("Palette exceeds 256 colors") if palette.size > 256
      end

      # Determine packing size
      size = if palette.size <= 2
               8
             elsif palette.size <= 4
               4
             elsif palette.size <= 16
               2
             else
               1
             end

      pw = (width + size - 1) // size
      packed = Array(CrImage::Color::NRGBA).new(pw * height, CrImage::Color::NRGBA.new(0_u8, 0_u8, 0_u8, 255_u8))

      # Pack pixels
      height.times do |y|
        pw.times do |x|
          pack = 0
          size.times do |i|
            px = x * size + i
            break if px >= width

            idx = palette.index(pixels[y * width + px]).not_nil!
            pack |= idx << (i * (8 // size))
          end

          packed[y * pw + x] = CrImage::Color::NRGBA.new(0_u8, pack.to_u8, 0_u8, 255_u8)
        end
      end

      # Apply delta encoding to palette
      (palette.size - 1).downto(1) do |i|
        palette[i] = CrImage::Color::NRGBA.new(
          (palette[i].r &- palette[i - 1].r).to_u8,
          (palette[i].g &- palette[i - 1].g).to_u8,
          (palette[i].b &- palette[i - 1].b).to_u8,
          (palette[i].a &- palette[i - 1].a).to_u8
        )
      end

      # Update pixels array with packed data
      pixels.clear
      packed.each { |p| pixels << p }

      {palette, pw}
    end
  end
end
