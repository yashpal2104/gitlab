# frozen_string_literal: true

require 'uri'

# Generated HTML is transformed back to GFM by:
# - app/assets/javascripts/behaviors/markdown/marks/math.js
# - app/assets/javascripts/behaviors/markdown/nodes/code_block.js
module Banzai
  module Filter
    # HTML filter that implements our math syntax, adding class="code math"
    #
    class MathFilter < HTML::Pipeline::Filter
      CSS_MATH   = 'pre.code.language-math'
      XPATH_MATH = Gitlab::Utils::Nokogiri.css_to_xpath(CSS_MATH).freeze
      CSS_CODE   = 'code'
      XPATH_CODE = Gitlab::Utils::Nokogiri.css_to_xpath(CSS_CODE).freeze

      # These are based on the Pandoc heuristics,
      # https://pandoc.org/MANUAL.html#extension-tex_math_dollars
      # Note: at this time, using a dollar sign literal, `\$` inside
      # a math statement does not work correctly.
      # Corresponds to the "$...$" syntax
      DOLLAR_INLINE_PATTERN = %r{
        (?<matched>\$(?<math>\S[^$\n]+?\S)\$)(?:[^\d]|$)
      }x.freeze
      DOLLAR_INLINE_PATTERN_COMBO = %r{
        (?<inline>\$(?<inline_math>\S[^$\n]+?\S)\$)(?:[^\d]|$)
      }x.freeze

      # Corresponds to the "$$...$$" syntax
      DOLLAR_DISPLAY_INLINE_PATTERN = %r{
        (?<matched>\$\$(?<math>\S[^$\n]+?\S)\$\$)(?:[^\d]|$)
      }x.freeze
      DOLLAR_DISPLAY_INLINE_PATTERN_COMBO = %r{
        (?<display_inline>\$\$(?<display_inline_math>\S[^$\n]+?\S)\$\$)(?:[^\d]|$)
      }x.freeze

      # Corresponds to the $$\n...\n$$ syntax
      DOLLAR_DISPLAY_BLOCK_PATTERN = %r{
        ^(?<matched>\$\$\ *\n(?<math>.*)\n\$\$\ *)$
      }x.freeze
      DOLLAR_DISPLAY_BLOCK_PATTERN_COMBO = %r{
        ^(?<display_block>\$\$\ *\n(?<display_block_math>.*)\n\$\$\ *)$
      }x.freeze

      # Order dependent. Handle the `$$` syntax before the `$` syntax
      DOLLAR_MATH_PIPELINE = [
        { pattern: DOLLAR_DISPLAY_INLINE_PATTERN, tag: :code, style: :display },
        { pattern: DOLLAR_DISPLAY_BLOCK_PATTERN, tag: :pre, style: :display },
        { pattern: DOLLAR_INLINE_PATTERN, tag: :code, style: :inline }
      ].freeze

      # Order dependent. Handle the `$$` syntax before the `$` syntax
      DOLLAR_MATH_PATTERN = %r{
          #{DOLLAR_DISPLAY_INLINE_PATTERN_COMBO}
        |
          #{DOLLAR_DISPLAY_BLOCK_PATTERN_COMBO}
        |
          #{DOLLAR_INLINE_PATTERN_COMBO}
      }mx.freeze

      # Do not recognize math inside these tags
      IGNORED_ANCESTOR_TAGS = %w[pre code tt].to_set

      # Attribute indicating inline or display math.
      STYLE_ATTRIBUTE = 'data-math-style'

      # Class used for tagging elements that should be rendered
      TAG_CLASS = 'js-render-math'

      MATH_CLASSES = "code math #{TAG_CLASS}"
      DOLLAR_SIGN = '$'

      # Limit to how many nodes can be marked as math elements.
      # Prevents timeouts for large notes.
      # For more information check: https://gitlab.com/gitlab-org/gitlab/-/issues/341832
      RENDER_NODES_LIMIT = 50

      def call
        @nodes_count = 0

        # process_dollar_math if Feature.enabled?(:markdown_dollar_math, group)
        process_dollar_pipeline if Feature.enabled?(:markdown_dollar_math, group)

        process_dollar_backtick_inline
        process_math_codeblock

        doc
      end

      def process_dollar_pipeline
        doc.xpath('descendant-or-self::text()').each do |node|
          next if has_ancestor?(node, IGNORED_ANCESTOR_TAGS)
          next unless node.content.include?(DOLLAR_SIGN)

          temp_doc = Nokogiri::HTML.fragment(node.content)
          DOLLAR_MATH_PIPELINE.each do |pipeline|
            temp_doc.xpath('descendant-or-self::text()').each do |temp_node|
              next if has_ancestor?(node, IGNORED_ANCESTOR_TAGS)
              next unless temp_node.content.match?(pipeline[:pattern])

              html = temp_node.content
              temp_node.content.scan(pipeline[:pattern]).each do |matched, math|
                html.sub!(matched, math_html(tag: pipeline[:tag], style: pipeline[:style], math: math))

                @nodes_count += 1
                break if @nodes_count >= RENDER_NODES_LIMIT
              end

              temp_node.replace(html)

              break if @nodes_count >= RENDER_NODES_LIMIT
            end
          end

          node.replace(temp_doc)
        end
      end

      # Corresponds to the "$`...`$" syntax
      def process_dollar_backtick_inline
        doc.xpath(XPATH_CODE).each do |code|
          closing = code.next
          opening = code.previous

          # We need a sibling before and after.
          # They should end and start with $ respectively.
          if closing && opening &&
              closing.text? && opening.text? &&
              closing.content.first == DOLLAR_SIGN &&
              opening.content.last == DOLLAR_SIGN

            code[:class] = MATH_CLASSES
            code[STYLE_ATTRIBUTE] = 'inline'
            closing.content = closing.content[1..]
            opening.content = opening.content[0..-2]

            @nodes_count += 1
            break if @nodes_count >= RENDER_NODES_LIMIT
          end
        end
      end

      # corresponds to the "```math...```" syntax
      def process_math_codeblock
        doc.xpath(XPATH_MATH).each do |el|
          el[STYLE_ATTRIBUTE] = 'display'
          el[:class] += " #{TAG_CLASS}"
        end
      end

      def process_dollar_math
        doc.xpath('descendant-or-self::text()').each do |node|
          next if has_ancestor?(node, IGNORED_ANCESTOR_TAGS)

          if node.content.match?(DOLLAR_MATH_PATTERN)
            html = node.content
            node.content.scan(DOLLAR_MATH_PATTERN).each do |display_inline, display_inline_math,
                                              display_block, display_block_math, inline, inline_math|

              if display_inline
                html.sub!(display_inline, math_html(tag: :code, style: :display, math: display_inline_math))
              elsif display_block
                html.sub!(display_block, math_html(tag: :pre, style: :display, math: display_block_math))
              else
                html.sub!(inline, math_html(tag: :code, style: :inline, math: inline_math))
              end

              @nodes_count += 1
              break if @nodes_count >= RENDER_NODES_LIMIT
            end

            node.replace(html)

            break if @nodes_count >= RENDER_NODES_LIMIT
          end
        end
      end

      private

      def math_html(tag:, math:, style:)
        case tag
        when :code
          "<code class=\"#{MATH_CLASSES}\" data-math-style=\"#{style}\">#{math}</code>"
        when :pre
          "<pre class=\"#{MATH_CLASSES}\" data-math-style=\"#{style}\"><code>#{math}</code></pre>"
        end
      end

      def group
        context[:group] || context[:project]&.group
      end
    end
  end
end
