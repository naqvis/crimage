require "../spec_helper"

module CrImage::Draw
  record ClipTest, desc : String, r : Rectangle, dr : Rectangle, sr : Rectangle, mr : Rectangle,
    sp : Point, mp : Point, nil_mask : Bool, r0 : Rectangle, sp0 : Point, mp0 : Point

  CLIP_TESTS = [
    # The follow tests all have a nil mask.
    ClipTest.new(
      "basic",
      CrImage.rect(0, 0, 100, 100),
      CrImage.rect(0, 0, 100, 100),
      CrImage.rect(0, 0, 100, 100),
      Rectangle.zero,
      Point.zero,
      Point.zero,
      true,
      CrImage.rect(0, 0, 100, 100),
      Point.zero,
      Point.zero
    ),
    ClipTest.new(
      "clip dr",
      CrImage.rect(0, 0, 100, 100),
      CrImage.rect(40, 40, 60, 60),
      CrImage.rect(0, 0, 100, 100),
      Rectangle.zero,
      Point.zero,
      Point.zero,
      true,
      CrImage.rect(40, 40, 60, 60),
      Point.new(40, 40),
      Point.zero
    ),
    ClipTest.new(
      "clip sr",
      CrImage.rect(0, 0, 100, 100),
      CrImage.rect(0, 0, 100, 100),
      CrImage.rect(20, 20, 80, 80),
      Rectangle.zero,
      Point.zero,
      Point.zero,
      true,
      CrImage.rect(20, 20, 80, 80),
      Point.new(20, 20),
      Point.zero
    ),
    ClipTest.new(
      "clip dr and sr",
      CrImage.rect(0, 0, 100, 100),
      CrImage.rect(0, 0, 50, 100),
      CrImage.rect(20, 20, 80, 80),
      Rectangle.zero,
      Point.zero,
      Point.zero,
      true,
      CrImage.rect(20, 20, 50, 80),
      Point.new(20, 20),
      Point.zero
    ),
    ClipTest.new(
      "clip dr and sr, sp outside sr (top-left)",
      CrImage.rect(0, 0, 100, 100),
      CrImage.rect(0, 0, 50, 100),
      CrImage.rect(20, 20, 80, 80),
      Rectangle.zero,
      Point.new(15, 8),
      Point.zero,
      true,
      CrImage.rect(5, 12, 50, 72),
      Point.new(20, 20),
      Point.zero
    ),
    ClipTest.new(
      "clip dr and sr, sp outside sr (middle-left)",
      CrImage.rect(0, 0, 100, 100),
      CrImage.rect(0, 0, 50, 100),
      CrImage.rect(20, 20, 80, 80),
      Rectangle.zero,
      Point.new(15, 66),
      Point.zero,
      true,
      CrImage.rect(5, 0, 50, 14),
      Point.new(20, 66),
      Point.zero
    ),
    ClipTest.new(
      "clip dr and sr, sp outside sr (bottom-left)",
      CrImage.rect(0, 0, 100, 100),
      CrImage.rect(0, 0, 50, 100),
      CrImage.rect(20, 20, 80, 80),
      Rectangle.zero,
      Point.new(15, 91),
      Point.zero,
      true,
      Rectangle.zero,
      Point.new(15, 91),
      Point.zero
    ),
    ClipTest.new(
      "clip dr and sr, sp inside sr",
      CrImage.rect(0, 0, 100, 100),
      CrImage.rect(0, 0, 50, 100),
      CrImage.rect(20, 20, 80, 80),
      Rectangle.zero,
      Point.new(44, 33),
      Point.zero,
      true,
      CrImage.rect(0, 0, 36, 47),
      Point.new(44, 33),
      Point.zero
    ),

    # The following tests all have a non-nil mask.
    ClipTest.new(
      "basic mask",
      CrImage.rect(0, 0, 80, 80),
      CrImage.rect(20, 0, 100, 80),
      CrImage.rect(0, 0, 50, 49),
      CrImage.rect(0, 0, 46, 47),
      Point.zero,
      Point.zero,
      false,
      CrImage.rect(20, 0, 46, 47),
      Point.new(20, 0),
      Point.new(20, 0),
    ),
    ClipTest.new(
      "clip sr and mr",
      CrImage.rect(0, 0, 100, 100),
      CrImage.rect(0, 0, 100, 100),
      CrImage.rect(23, 23, 55, 86),
      CrImage.rect(44, 44, 87, 58),
      Point.new(10, 10),
      Point.new(11, 11),
      false,
      CrImage.rect(33, 33, 45, 47),
      Point.new(43, 43),
      Point.new(44, 44),
    ),
  ]

  it "Test Clip" do
    dst0 = RGBA.new(CrImage.rect(0, 0, 100, 100))
    src0 = RGBA.new(CrImage.rect(0, 0, 100, 100))
    mask0 = RGBA.new(CrImage.rect(0, 0, 100, 100))

    CLIP_TESTS.each do |c|
      dst = dst0.sub_image(c.dr).as(RGBA)
      src = src0.sub_image(c.sr).as(RGBA)
      r, sp, mp = c.r, c.sp, c.mp
      if c.nil_mask
        r, sp, _ = clip(dst, r, src, sp, nil, nil)
      else
        r, sp, mp = clip(dst, r, src, sp, mask0.sub_image(c.mr), mp)
      end

      # check that the actual results equal the expected result
      fail "#{c.desc}: clip rectangle want #{c.r0.to_s} got #{r.to_s}" unless c.r0 == r
      fail "#{c.desc}: sp want #{c.sp0.to_s} got #{sp.to_s}" unless c.sp0 == sp

      if !c.nil_mask
        fail "#{c.desc}: mp want #{c.mp.to_s} got #{mp.to_s}" unless c.mp0 == mp
      end

      # check that the clipped rectangle is contained by the dst / src / mask
      # rectangles, in their respective coordinate spaces.
      fail "#{c.desc}: c.dr #{c.dr} does not contain r #{r}" unless r.in(c.dr)

      # sr is r translated into src's coordinate space
      sr = r + (c.sp - c.dr.min)
      fail "#{c.desc}: c.sr #{c.sr} does not contain sr #{sr}" unless sr.in(c.sr)

      if !c.nil_mask
        # mr is r translated into mask's coordinate space
        mr = r + (c.mp - c.dr.min)
        fail "#{c.desc}: c.mr #{c.sr} does not contain mr #{sr}" unless mr.in(c.mr)
      end
    end
  end
end
