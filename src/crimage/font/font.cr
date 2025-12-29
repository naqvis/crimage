require "../image"
require "../draw"
require "../math/fixed"
require "./effects"

# CrImage::Font provides text rendering capabilities with TrueType font support.
#
# Features:
# - TrueType font rendering with glyph rasterization
# - Multi-line text with word wrapping
# - Text alignment (horizontal and vertical)
# - Text effects (shadows, outlines, decorations)
# - Kerning support
# - Font metrics and measurements
#
# This module defines the Face interface for font implementations.
# Font face implementations are provided by other modules (e.g., FreeType).
module CrImage::Font
  # Face is a font face. Its glyphs are often derived from a font file, such as
  # "Comic_Sans_MS.ttf", but a face has a specific size, style, weight and
  # hinting. For example, the 12pt and 18pt versions of Comic Sans are two
  # different faces, even if derived from the same font file.
  #
  # A Face is not safe for concurrent use by multiple fibers, as its methods
  # may re-use implementation-specific caches and mask image buffers.
  #
  # To create a Face, look to other modules that implement specific font file
  # formats.
  module Face
    # glyph returns the Draw.draw_mask parameters (dr, mask, maskp) to draw r's
    # glyph at the sub-pixel destination location dot, and that glyph's
    # advance width.
    #
    # It returns !ok if the face does not contain a glyph for r.
    #
    # The contents of the mask image returned by one glyph call may change
    # after the next glyph call. Callers that want to cache the mask must make
    # a copy.
    abstract def glyph(dot : Math::Fixed::Point26_6, r : Char) : {CrImage::Rectangle, CrImage::Image, CrImage::Point, Math::Fixed::Int26_6, Bool}

    # glyph_bounds returns the bounding box of r's glyph, drawn at a dot equal
    # to the origin, and that glyph's advance width.
    #
    # It returns !ok if the face does not contain a glyph for r.
    #
    # The glyph's ascent and descent equal -bounds.min.y and +bounds.max.y. A
    # visual depiction of what these metrics are is at
    # https://developer.apple.com/library/mac/documentation/TextFonts/Conceptual/CocoaTextArchitecture/Art/glyph_metrics_2x.png
    abstract def glyph_bounds(r : Char) : {Math::Fixed::Rectangle26_6, Math::Fixed::Int26_6, Bool}

    # glyph_advance returns the advance width of r's glyph.
    #
    # It returns !ok if the face does not contain a glyph for r.
    abstract def glyph_advance(r : Char) : {Math::Fixed::Int26_6, Bool}

    # kern returns the horizontal adjustment for the kerning pair (r0, r1). A
    # positive kern means to move the glyphs further apart.
    abstract def kern(r0 : Char, r1 : Char) : Math::Fixed::Int26_6

    # metrics returns the metrics for this Face.
    abstract def metrics : Metrics

    # Returns true if this face supports ligature substitution.
    # Default implementation returns false.
    def supports_ligatures? : Bool
      false
    end

    # Convert a character to its glyph index.
    # Returns 0 if the character is not in the font.
    def glyph_index(r : Char) : Int32
      0
    end

    # Lookup ligature substitution for a glyph sequence.
    # Returns {ligature_glyph, glyphs_consumed} or {0, 0} if no ligature.
    def lookup_ligature(glyphs : Array(UInt16), start_index : Int32 = 0) : {UInt16, Int32}
      {0_u16, 0}
    end

    # Render a glyph by its index.
    def glyph_by_index(dot : Math::Fixed::Point26_6, glyph_index : Int32) : {CrImage::Rectangle, CrImage::Image, CrImage::Point, Math::Fixed::Int26_6, Bool}
      {CrImage::Rectangle.zero, CrImage::Alpha.new(CrImage.rect(0, 0, 0, 0)), CrImage::Point.zero, Math::Fixed::Int26_6[0], false}
    end

    # Kerning by glyph index.
    def kern_by_index(glyph0 : Int32, glyph1 : Int32) : Math::Fixed::Int26_6
      Math::Fixed::Int26_6[0]
    end

    # Returns true if this face has vertical metrics (for vertical text layout).
    def has_vertical_metrics? : Bool
      false
    end

    # Get vertical advance for a character (used for vertical text layout).
    # Returns {advance, ok} where ok is false if glyph not found.
    def vertical_advance(r : Char) : {Math::Fixed::Int26_6, Bool}
      {Math::Fixed::Int26_6[0], false}
    end

    # Get vertical advance by glyph index.
    def vertical_advance_by_index(glyph_index : Int32) : Math::Fixed::Int26_6
      Math::Fixed::Int26_6[0]
    end

    # ============================================================
    # Convenience methods for text measurement
    # ============================================================

    # Measures the width of a string in pixels.
    #
    # This is a convenience method that returns the advance width
    # of the text as an integer pixel value.
    #
    # Parameters:
    # - `text` : The string to measure
    #
    # Returns: Width in pixels
    #
    # Example:
    # ```
    # width = face.measure("Hello, World!")
    # puts "Text is #{width} pixels wide"
    # ```
    def measure(text : String) : Int32
      Font.measure(self, text).ceil.to_i
    end

    # Returns the bounding rectangle for rendered text.
    #
    # The rectangle represents the visual bounds of the text,
    # with the origin at (0, 0). The min.y will typically be
    # negative (above baseline) and max.y positive (below baseline).
    #
    # Parameters:
    # - `text` : The string to measure
    #
    # Returns: Rectangle with text bounds in pixels
    #
    # Example:
    # ```
    # bounds = face.text_bounds("Hello")
    # puts "Width: #{bounds.width}, Height: #{bounds.height}"
    # ```
    def text_bounds(text : String) : CrImage::Rectangle
      fixed_bounds, _ = Font.bounds(self, text)
      CrImage.rect(
        fixed_bounds.min.x.floor.to_i,
        fixed_bounds.min.y.floor.to_i,
        fixed_bounds.max.x.ceil.to_i,
        fixed_bounds.max.y.ceil.to_i
      )
    end

    # Returns both width and height of text as a tuple.
    #
    # This is a convenience method for quickly getting text dimensions.
    #
    # Parameters:
    # - `text` : The string to measure
    #
    # Returns: Tuple of {width, height} in pixels
    #
    # Example:
    # ```
    # width, height = face.text_size("Hello")
    # ```
    def text_size(text : String) : {Int32, Int32}
      bounds = text_bounds(text)
      {bounds.width, bounds.height}
    end

    # Returns the line height for this face in pixels.
    #
    # This is the recommended vertical distance between baselines
    # of consecutive lines of text.
    #
    # Example:
    # ```
    # line_height = face.line_height
    # y = 50
    # lines.each do |line|
    #   drawer.draw_text(line, 10, y)
    #   y += line_height
    # end
    # ```
    def line_height : Int32
      metrics.height.ceil.to_i
    end

    # Returns the ascent (distance from baseline to top) in pixels.
    def ascent : Int32
      metrics.ascent.ceil.to_i
    end

    # Returns the descent (distance from baseline to bottom) in pixels.
    def descent : Int32
      metrics.descent.ceil.to_i
    end
  end

  # Metrics holds the metrics for a Face. A visual depiction is at
  # https://developer.apple.com/library/mac/documentation/TextFonts/Conceptual/CocoaTextArchitecture/Art/glyph_metrics_2x.png
  struct Metrics
    # height is the recommended amount of vertical space between two lines of text.
    property height : Math::Fixed::Int26_6

    # ascent is the distance from the top of a line to its baseline
    property ascent : Math::Fixed::Int26_6

    # descent is the distance from the bottom of a line to its baseline. The
    # value si typically positive, even though a descender goes below the baseline.
    property descent : Math::Fixed::Int26_6

    # x_height is the distance from the top of uppercase letters to the baseline.
    property x_height : Math::Fixed::Int26_6

    # cap_height is the distance from the top of uppercase letters to the baseline.
    property cap_height : Math::Fixed::Int26_6

    # caret_slope is the slope of a caret as a vactor with the y axis pointing up.
    # The slope(0,1) is the vertical caret.
    property caret_slope : CrImage::Point

    def initialize(@height = Math::Fixed::Int26_6[0], @ascent = Math::Fixed::Int26_6[0],
                   @descent = Math::Fixed::Int26_6[0], @x_height = Math::Fixed::Int26_6[0],
                   @cap_height = Math::Fixed::Int26_6[0], @caret_slope = CrImage::Point.zero)
    end
  end

  # Text rendering engine for drawing text on images.
  #
  # Drawer handles text rendering with support for kerning, effects, and decorations.
  # Use `draw_text` for the simple high-level API with x, y coordinates and named
  # parameters for effects.
  #
  # Example:
  # ```
  # # Create drawer
  # face = FreeType::TrueType.new_face(font, 48.0)
  # text_color = CrImage::Uniform.new(CrImage::Color::BLACK)
  # drawer = CrImage::Font::Drawer.new(image, text_color, face)
  #
  # # Draw text with effects
  # drawer.draw_text("Hello", 50, 100)
  # drawer.draw_text("World", 50, 200, underline: true)
  # drawer.draw_text("Title", 50, 300, shadow: true, outline: true)
  # ```
  #
  # Note: Not thread-safe. Create separate Drawer instances for concurrent use.
  class Drawer
    getter dest : CrImage::Image
    getter src : CrImage::Image
    # face provides the glyph mask images.
    getter face : Face
    # dot is the baseline location to draw the next glyph. The majority of the
    # affected pixels will be above and to the right of the dot, but some may
    # be below or to the left. For example, drawing a 'j' in an italic face
    # may affect pixels below and to the left of the dot.
    property dot : Math::Fixed::Point26_6

    def initialize(@dest, @src, @face, @dot = Math::Fixed::Point26_6.zero)
    end

    def draw(s : String)
      # Check if face supports ligatures
      if face.supports_ligatures?
        draw_with_ligatures(s)
      else
        draw_simple(s)
      end
    end

    # Simple drawing without ligature substitution
    private def draw_simple(s : String)
      cr = Char::Reader.new(s)
      prev = Char::ZERO
      cr.each do |char|
        dot.x += face.kern(prev, char) unless prev == Char::ZERO
        dr, mask, maskp, advance, ok = face.glyph(dot, char)
        if ok
          Draw.draw_mask(dest, dr, src, CrImage::Point.zero, mask, maskp, Draw::Op::OVER)
        end
        # Always advance, even for invisible glyphs like space
        dot.x += advance
        prev = char
      end
    end

    # Drawing with ligature substitution
    private def draw_with_ligatures(s : String)
      # Convert string to glyph indices
      glyphs = Array(UInt16).new(s.size)
      s.each_char do |char|
        glyph_idx = face.glyph_index(char)
        glyphs << glyph_idx.to_u16
      end

      # Apply ligature substitutions
      i = 0
      result_glyphs = Array(UInt16).new
      while i < glyphs.size
        lig_glyph, consumed = face.lookup_ligature(glyphs, i)
        if consumed > 1
          # Ligature found - use ligature glyph
          result_glyphs << lig_glyph
          i += consumed
        else
          # No ligature - keep original glyph
          result_glyphs << glyphs[i]
          i += 1
        end
      end

      # Render glyphs with kerning
      prev_glyph = 0
      result_glyphs.each do |glyph_idx|
        # Apply kerning
        if prev_glyph != 0
          dot.x += face.kern_by_index(prev_glyph, glyph_idx.to_i32)
        end

        # Render glyph
        dr, mask, maskp, advance, ok = face.glyph_by_index(dot, glyph_idx.to_i32)
        if ok
          Draw.draw_mask(dest, dr, src, CrImage::Point.zero, mask, maskp, Draw::Op::OVER)
        end

        dot.x += advance
        prev_glyph = glyph_idx.to_i32
      end
    end

    # Draw text vertically (top to bottom).
    # Used for CJK vertical text layout.
    # The dot position is the top-center of the first glyph.
    def draw_vertical(s : String)
      # Check if face supports ligatures (TrueType with GSUB)
      if face.supports_ligatures?
        draw_vertical_with_ligatures(s)
      else
        draw_vertical_simple(s)
      end
    end

    # Simple vertical drawing without ligature substitution
    private def draw_vertical_simple(s : String)
      s.each_char do |char|
        dr, mask, maskp, advance, ok = face.glyph(dot, char)
        if ok
          Draw.draw_mask(dest, dr, src, CrImage::Point.zero, mask, maskp, Draw::Op::OVER)
        end
        # Advance downward (increase Y)
        v_advance, _ = face.vertical_advance(char)
        dot.y += v_advance
      end
    end

    # Vertical drawing with ligature substitution
    private def draw_vertical_with_ligatures(s : String)
      # Convert string to glyph indices
      glyphs = Array(UInt16).new(s.size)
      s.each_char do |char|
        glyph_idx = face.glyph_index(char)
        glyphs << glyph_idx.to_u16
      end

      # Apply ligature substitutions
      i = 0
      result_glyphs = Array(UInt16).new
      while i < glyphs.size
        lig_glyph, consumed = face.lookup_ligature(glyphs, i)
        if consumed > 1
          result_glyphs << lig_glyph
          i += consumed
        else
          result_glyphs << glyphs[i]
          i += 1
        end
      end

      # Render glyphs vertically
      result_glyphs.each do |glyph_idx|
        dr, mask, maskp, advance, ok = face.glyph_by_index(dot, glyph_idx.to_i32)
        if ok
          Draw.draw_mask(dest, dr, src, CrImage::Point.zero, mask, maskp, Draw::Op::OVER)
        end
        # Advance downward
        dot.y += face.vertical_advance_by_index(glyph_idx.to_i32)
      end
    end

    # Draw text at specified coordinates with optional visual effects.
    #
    # This is the primary method for rendering text with decorations and effects.
    # The x, y coordinates specify the baseline position where text rendering begins.
    #
    # Parameters:
    # - `s` : The text string to render
    # - `x` : Horizontal position (baseline start)
    # - `y` : Vertical position (baseline)
    #
    # Text Decorations:
    # - `underline` : Add underline below text (default: false)
    # - `strikethrough` : Add line through text (default: false)
    # - `decoration_color` : Color for decorations (default: text color)
    #
    # Shadow Effect:
    # - `shadow` : Enable drop shadow (default: false)
    # - `shadow_offset_x` : Shadow horizontal offset in pixels (default: 2)
    # - `shadow_offset_y` : Shadow vertical offset in pixels (default: 2)
    # - `shadow_blur` : Shadow blur radius (default: 3)
    # - `shadow_color` : Shadow color (default: semi-transparent black)
    #
    # Outline Effect:
    # - `outline` : Enable text outline/stroke (default: false)
    # - `outline_thickness` : Outline width in pixels (default: 2)
    # - `outline_color` : Outline color (default: black)
    #
    # Examples:
    # ```
    # # Simple text
    # drawer.draw_text("Hello", 50, 100)
    #
    # # Underlined text
    # drawer.draw_text("Important", 50, 200, underline: true)
    #
    # # Text with red underline
    # drawer.draw_text("Error", 50, 300, underline: true, decoration_color: Color::RED)
    #
    # # Text with shadow
    # drawer.draw_text("Title", 50, 400, shadow: true)
    #
    # # Text with outline
    # drawer.draw_text("Bold", 50, 500, outline: true, outline_thickness: 3)
    #
    # # Combined effects
    # drawer.draw_text("Fancy", 50, 600, shadow: true, outline: true, underline: true)
    # ```
    def draw_text(s : String, x : Int32, y : Int32,
                  underline : Bool = false,
                  strikethrough : Bool = false,
                  decoration_color : Color::Color? = nil,
                  shadow : Bool = false,
                  shadow_offset_x : Int32 = 2,
                  shadow_offset_y : Int32 = 2,
                  shadow_blur : Int32 = 3,
                  shadow_color : Color::Color? = nil,
                  outline : Bool = false,
                  outline_thickness : Int32 = 2,
                  outline_color : Color::Color? = nil)
      @dot = Math::Fixed::Point26_6.new(
        Math::Fixed::Int26_6[x * 64],
        Math::Fixed::Int26_6[y * 64]
      )

      # If no effects, just draw normally
      if !underline && !strikethrough && !shadow && !outline
        draw(s)
        return
      end

      # Build style with requested effects
      shadow_obj = if shadow
                     shadow_color ||= Color::RGBA.new(0_u8, 0_u8, 0_u8, 150_u8)
                     Shadow.new(shadow_offset_x, shadow_offset_y, shadow_blur, shadow_color)
                   end

      outline_obj = if outline
                      outline_color ||= Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8)
                      Outline.new(outline_thickness, outline_color)
                    end

      style = TextStyle.new(
        shadow: shadow_obj,
        outline: outline_obj,
        underline: underline,
        strikethrough: strikethrough,
        decoration_color: decoration_color
      )

      draw_styled(s, style)
    end

    # Draw text vertically at specified coordinates.
    #
    # This renders text top-to-bottom, useful for CJK vertical layouts.
    # The x, y coordinates specify the starting position for the first glyph.
    #
    # Parameters:
    # - `s` : The text string to render
    # - `x` : Horizontal position (center of glyphs)
    # - `y` : Vertical position (top of first glyph baseline)
    #
    # Example:
    # ```
    # drawer.draw_vertical_text("HELLO", 100, 50)
    # ```
    def draw_vertical_text(s : String, x : Int32, y : Int32)
      @dot = Math::Fixed::Point26_6.new(
        Math::Fixed::Int26_6[x * 64],
        Math::Fixed::Int26_6[y * 64]
      )
      draw_vertical(s)
    end

    # returns the bounding box of s, drawn at the drawer dot, as well as the advance
    def bounds(s : String) : {Math::Fixed::Rectangle26_6, Math::Fixed::Int26_6}
      bounds, advance = Font.bounds(face, s)
      bounds.min += dot
      bounds.max += dot
      {bounds, advance}
    end

    # returns how far dot would advance by drawing s.
    def measure(s : String) : Math::Fixed::Int26_6
      Font.measure(face, s)
    end
  end

  # returns the bounding box of s with f, drawn at a dot equal to the origin,
  # as well as the advance.
  def self.bounds(f : Face, s : String) : {Math::Fixed::Rectangle26_6, Math::Fixed::Int26_6}
    cr = Char::Reader.new(s)
    prev = Char::ZERO
    advance = Math::Fixed::Int26_6[0]
    bounds = Math::Fixed::Rectangle26_6.zero
    cr.each do |char|
      advance += f.kern(prev, char) unless prev == Char::ZERO
      b, a, ok = f.glyph_bounds(char)
      if !ok
        # Fall back to replacement character U+FFFD if glyph not found
        char = '\ufffd'
        b, a, ok = f.glyph_bounds(char)
        # If replacement character also not found, skip this character
        next unless ok
      end
      b.min.x += advance
      b.max.x += advance
      bounds = bounds.union(b)
      advance += a
      prev = char
    end
    {bounds, advance}
  end

  # returns how far dot would advance by drawing s with f
  def self.measure(f : Face, s : String) : Math::Fixed::Int26_6
    cr = Char::Reader.new(s)
    prev = Char::ZERO
    advance = Math::Fixed::Int26_6[0]
    cr.each do |char|
      advance += f.kern(prev, char) unless prev == Char::ZERO
      a, ok = f.glyph_advance(char)
      if !ok
        # Fall back to replacement character U+FFFD if glyph not found
        char = '\ufffd'
        a, ok = f.glyph_advance(char)
        # If replacement character also not found, skip this character
        next unless ok
      end
      advance += a
      prev = char
    end
    advance
  end

  # Hinting selects how to quantize a vector font's glyph nodes.
  # Not all fonts supports hinting
  enum Hinting
    None     = 0
    Vertical
    Full
  end

  # Stretch selects a normal, condensed, or expanded face.
  # Not all fonts supports stretches
  enum Stretch
    UltraCondensed = -4
    ExtraCondensed = -3
    Condensed      = -2
    SemiCondensed  = -1
    Normal         =  0
    SemiExpanded   =  1
    Expanded       =  2
    ExtraExpanded  =  3
    UltraExpanded  =  4
  end

  # Style selects a normal, italic, or oblique face.
  # Not all fonts support styles.
  enum Style
    Normal  = 0
    Italic
    Oblique
  end

  # Weight selects a normal, light or bold face.
  # Not all fonts support weights.
  #
  # The named Weight contants(e.g Bold) corresponds to CSS' common
  # weight names (e.g. "Bold"), but the numerical values differ, so that in Crystal,
  # the zero value means to use a normal weight. For the CSS names and values
  # see https://developer.mozilla.org/en/docs/Web/CSS/font-weight
  enum Weight
    Thin       = -3 # CSS font-weight value 100.
    ExtraLight = -2 # CSS font-weight value 200.
    Light      = -1 # CSS font-weight value 300.
    Normal     =  0 # CSS font-weight value 400.
    Medium     =  1 # CSS font-weight value 500.
    SemiBold   =  2 # CSS font-weight value 600.
    Bold       =  3 # CSS font-weight value 700.
    ExtraBold  =  4 # CSS font-weight value 800.
    Black      =  5 # CSS font-weight value 900.
  end
end
