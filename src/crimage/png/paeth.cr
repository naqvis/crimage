module CrImage::PNG
  # This file implements the Paeth predictor filter used in PNG compression.
  # The Paeth filter predicts pixel values based on neighboring pixels.
  # implements the Paeth filter function, as per the PNG specification
  def self.paeth(a : UInt8, b : UInt8, c : UInt8) : UInt8
    pc = c.to_i
    pa = b.to_i - pc
    pb = a.to_i - pc
    pc = (pa + pb).abs
    pa = pa.abs
    pb = pb.abs
    if pa <= pb && pa <= pc
      return a
    elsif pb <= pc
      return b
    end
    c
  end

  # applies the Paeth filter to the cdat slice.
  # cdat is the current row's data, pdat is the previous row's data
  # :nodoc
  def self.filter_paeth(cdat : Bytes, pdat : Bytes, bytes_per_pixel : Int32)
    0.upto(bytes_per_pixel - 1) do |i|
      a, c = 0, 0
      j = i
      while j < cdat.size
        b = pdat[j].to_i
        pa = b - c
        pb = a - c
        pc = (pa + pb).abs
        pa = pa.abs
        pb = pb.abs
        if pa <= pb && pa <= pc
          # No-op
        elsif pb <= pc
          a = b
        else
          a = c
        end
        a += cdat[j].to_i
        a &= 0xff
        cdat[j] = a.to_u8
        c = b
        j += bytes_per_pixel
      end
    end
  end

  private def self.abs(x)
    # 32 bit Ints
    m = x >> (32 - 1)
    (x ^ m) - m
  end
end
