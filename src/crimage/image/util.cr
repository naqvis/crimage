module CrImage
  # draws the YCbCr source image on the RGBA destination image with
  # r.min in dst aligned with sp in src. It reports whether the draw was
  # successful. If it returns false, no dst pixels were changed.
  #
  # This function assumes that r is entrirely within dst's bounds and the
  # translation of r from dst coordinates space to src coordinate space is
  # entirely within src's bounds.
  def self.draw_ycbcr(dst : RGBA, r : Rectangle, src : YCbCr, sp : Point) : Bool
    x0 = (r.min.x - dst.rect.min.x) * 4
    x1 = (r.max.x - dst.rect.min.x) * 4
    y0 = r.min.y - dst.rect.min.y
    y1 = r.max.y - dst.rect.min.y

    case src.sub_sample_ratio
    when YCbCrSubSampleRatio::YCbCrSubsampleRatio444
      y, sy = y0, sp.y
      while y != y1
        dpix = dst.pix[y*dst.stride..]
        yi = (sy - src.rect.min.y)*src.y_stride + (sp.x - src.rect.min.x)
        ci = (sy - src.rect.min.y)*src.c_stride + (sp.x - src.rect.min.x)

        x = x0
        while x != x1
          r, g, b = CrImage::Color.ycbcr_to_rgb_16bit(src.y[yi], src.cb[ci], src.cr[ci])

          rgba = dpix[x...x + 4]
          rgba[0] = (r >> 8).to_u8
          rgba[1] = (g >> 8).to_u8
          rgba[2] = (b >> 8).to_u8
          rgba[3] = 255_u8

          x, yi, ci = x + 4, yi + 1, ci + 1
        end
        y, sy = y + 1, sy + 1
      end
    when YCbCrSubSampleRatio::YCbCrSubsampleRatio422
      y, sy = y0, sp.y
      while y != y1
        dpix = dst.pix[y*dst.stride..]
        yi = (sy - src.rect.min.y)*src.y_stride + (sp.x - src.rect.min.x)
        ci_base = (sy - src.rect.min.y)*src.c_stride - (src.rect.min.x / 2).to_i

        x, sx = x0, sp.x
        while x != x1
          ci = ci_base + (sx/2).to_i
          r, g, b = CrImage::Color.ycbcr_to_rgb_16bit(src.y[yi], src.cb[ci], src.cr[ci])

          rgba = dpix[x...x + 4]
          rgba[0] = (r >> 8).to_u8
          rgba[1] = (g >> 8).to_u8
          rgba[2] = (b >> 8).to_u8
          rgba[3] = 255_u8

          x, sx, yi = x + 4, sx + 1, yi + 1
        end
        y, sy = y + 1, sy + 1
      end
    when YCbCrSubSampleRatio::YCbCrSubsampleRatio420
      y, sy = y0, sp.y
      while y != y1
        dpix = dst.pix[y*dst.stride..]
        yi = (sy - src.rect.min.y)*src.y_stride + (sp.x - src.rect.min.x)
        ci_base = ((sy/2).to_i - (src.rect.min.y/2).to_i)*src.c_stride - (src.rect.min.x / 2).to_i

        x, sx = x0, sp.x
        while x != x1
          ci = ci_base + (sx/2).to_i
          r, g, b = CrImage::Color.ycbcr_to_rgb_16bit(src.y[yi], src.cb[ci], src.cr[ci])

          rgba = dpix[x...x + 4]
          rgba[0] = (r >> 8).to_u8
          rgba[1] = (g >> 8).to_u8
          rgba[2] = (b >> 8).to_u8
          rgba[3] = 255_u8

          x, sx, yi = x + 4, sx + 1, yi + 1
        end
        y, sy = y + 1, sy + 1
      end
    when YCbCrSubSampleRatio::YCbCrSubsampleRatio440
      y, sy = y0, sp.y
      while y != y1
        dpix = dst.pix[y*dst.stride..]
        yi = (sy - src.rect.min.y)*src.y_stride + (sp.x - src.rect.min.x)
        ci = ((sy/2).to_i - (src.rect.min.y/2).to_i)*src.c_stride + (sp.x - src.rect.min.x)

        x = x0
        while x != x1
          r, g, b = CrImage::Color.ycbcr_to_rgb_16bit(src.y[yi], src.cb[ci], src.cr[ci])

          rgba = dpix[x...x + 4]
          rgba[0] = (r >> 8).to_u8
          rgba[1] = (g >> 8).to_u8
          rgba[2] = (b >> 8).to_u8
          rgba[3] = 255_u8

          x, yi, ci = x + 4, yi + 1, ci + 1
        end
        y, sy = y + 1, sy + 1
      end
    else
      return false
    end
    true
  end
end
