require "../image"
require "./font"
require "../math/fixed"

module CrImage::Font
  # TextLayout represents the layout information for multi-line text.
  #
  # Contains the split lines, their heights, and total dimensions after
  # word wrapping and line breaking calculations.
  #
  # Properties:
  # - `lines` : Array of text lines after wrapping
  # - `line_heights` : Height of each line in pixels
  # - `total_height` : Total height of all lines
  # - `max_width` : Maximum width of any line
  class TextLayout
    property lines : Array(String)
    property line_heights : Array(Int32)
    property total_height : Int32
    property max_width : Int32

    def initialize(@lines, @line_heights, @total_height, @max_width)
    end
  end

  class Drawer
    # Calculate text layout for multi-line text with optional word wrapping.
    # Splits text on newlines and calculates line heights.
    #
    # Parameters:
    # - text: The text to layout (may contain newline characters)
    # - max_width: Optional maximum width for word wrapping (in pixels)
    # - line_spacing: Multiplier for line spacing (default 1.2)
    #
    # Returns: TextLayout with line information
    def measure_multiline(text : String, max_width : Int32? = nil, line_spacing : Float64 = 1.2) : TextLayout
      # Split text on newlines first
      raw_lines = text.split('\n')

      # If max_width is specified, apply word wrapping to each line
      lines = if max_width
                wrap_lines(raw_lines, max_width)
              else
                raw_lines
              end

      # Calculate line heights based on font metrics
      metrics = face.metrics
      base_line_height = metrics.height.ceil
      actual_line_height = (base_line_height * line_spacing).to_i

      line_heights = Array(Int32).new(lines.size, actual_line_height)

      # Calculate total height
      total_height = if lines.empty? || (lines.size == 1 && lines[0].empty?)
                       0
                     else
                       # First line uses base height, rest use spacing
                       base_line_height + (lines.size - 1) * actual_line_height
                     end

      # Calculate max width from actual rendered lines
      max_width_actual = 0
      lines.each do |line|
        line_width = measure(line).ceil
        max_width_actual = line_width if line_width > max_width_actual
      end

      TextLayout.new(lines, line_heights, total_height, max_width_actual)
    end

    # Render multi-line text with word wrapping.
    # This method draws text split across multiple lines.
    #
    # Parameters:
    # - text: The text to render (may contain newline characters)
    # - max_width: Optional maximum width for word wrapping (in pixels)
    # - line_spacing: Multiplier for line spacing (default 1.2)
    def draw_multiline(text : String, max_width : Int32? = nil, line_spacing : Float64 = 1.2)
      layout = measure_multiline(text, max_width, line_spacing)

      # Save original dot position
      original_x = dot.x
      current_y = dot.y

      # Draw each line
      layout.lines.each_with_index do |line, index|
        # Set position for this line
        @dot = Math::Fixed::Point26_6.new(original_x, current_y)

        # Draw the line
        draw(line)

        # Move to next line position
        current_y += Math::Fixed::Int26_6[layout.line_heights[index] * 64]
      end

      # Set final position
      @dot = Math::Fixed::Point26_6.new(original_x, current_y)
    end

    # Wrap lines to fit within max_width.
    # Breaks at word boundaries when possible, breaks long words when necessary.
    private def wrap_lines(lines : Array(String), max_width : Int32) : Array(String)
      wrapped = [] of String
      max_width_fixed = Math::Fixed::Int26_6[max_width * 64]

      lines.each do |line|
        # Skip empty lines but preserve them
        if line.empty?
          wrapped << line
          next
        end

        words = line.split(/\s+/)
        current_line = ""
        current_width = Math::Fixed::Int26_6[0]

        words.each do |word|
          # Measure the word
          word_width = measure(word)

          # Check if word itself is too long
          if word_width > max_width_fixed
            # If current line has content, flush it first
            unless current_line.empty?
              wrapped << current_line.strip
              current_line = ""
              current_width = Math::Fixed::Int26_6[0]
            end

            # Break the long word
            wrapped.concat(break_long_word(word, max_width))
            next
          end

          # Calculate width with space separator
          space_width = measure(" ")
          test_width = if current_line.empty?
                         word_width
                       else
                         current_width + space_width + word_width
                       end

          # Check if adding this word would exceed max width
          if test_width > max_width_fixed && !current_line.empty?
            # Flush current line and start new one
            wrapped << current_line.strip
            current_line = word
            current_width = word_width
          else
            # Add word to current line
            if current_line.empty?
              current_line = word
              current_width = word_width
            else
              current_line += " " + word
              current_width = test_width
            end
          end
        end

        # Flush remaining content
        unless current_line.empty?
          wrapped << current_line.strip
        end
      end

      wrapped
    end

    # Break a long word that exceeds max_width into multiple lines.
    # Breaks at character boundaries.
    private def break_long_word(word : String, max_width : Int32) : Array(String)
      result = [] of String
      max_width_fixed = Math::Fixed::Int26_6[max_width * 64]

      current_line = ""
      current_width = Math::Fixed::Int26_6[0]

      word.each_char do |char|
        char_width = measure(char.to_s)
        test_width = current_width + char_width

        if test_width > max_width_fixed && !current_line.empty?
          # Flush current line and start new one
          result << current_line
          current_line = char.to_s
          current_width = char_width
        else
          current_line += char
          current_width = test_width
        end
      end

      # Flush remaining content
      unless current_line.empty?
        result << current_line
      end

      result
    end
  end
end
