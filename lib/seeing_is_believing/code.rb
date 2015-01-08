# With new versioning, there's lots of small versions
# we don't need Parser to complain that we're on 2.1.1 and its parsing 2.1.5
# https://github.com/whitequark/parser/blob/e2249d7051b1adb6979139928e14a81bc62f566e/lib/parser/current.rb#L3
class << (Parser = Module.new)
  def warn(*) end
  require 'parser/current'
  remove_method :warn
end


class SeeingIsBelieving
  class Code
    InlineComment = Struct.new :line_number,
                               :whitespace_col,
                               :whitespace,
                               :text_col,
                               :text,
                               :full_range,
                               :whitespace_range,
                               :comment_range

    Syntax = Struct.new :error_message do
      def valid?
        !error_message
      end
    end

    attr_reader :code, :buffer, :parser, :rewriter, :inline_comments, :root, :raw_comments, :syntax

    def initialize(raw_ruby_code, name="SeeingIsBelieving")
      @code            = raw_ruby_code
      @buffer          = Parser::Source::Buffer.new(name)
      @buffer.source   = code
      builder          = Parser::Builders::Default.new.tap { |b| b.emit_file_line_as_literals = false }
      @rewriter        = Parser::Source::Rewriter.new @buffer
      @raw_comments    = extract_comments(builder, @buffer)
      @parser          = Parser::CurrentRuby.new builder
      @inline_comments = @raw_comments.select(&:inline?).map { |c| wrap_comment c }
      begin
        @root          = parser.parse(@buffer)
        @syntax        = Syntax.new
      rescue Parser::SyntaxError
        @syntax        = Syntax.new $!.message
      end
    end

    def range_for(start_index, end_index)
      Parser::Source::Range.new buffer, start_index, end_index
    end

    # this is the scardest fucking method I think I've ever written.
    # *anything* can go wrong!
    def heredoc?(ast)
      # some strings are fucking weird.
      # e.g. the "1" in `%w[1]` returns nil for ast.location.begin
      # and `__FILE__` is a string whose location is a Parser::Source::Map instead of a Parser::Source::Map::Collection,
      # so it has no #begin
      ast.kind_of?(Parser::AST::Node)           &&
        (ast.type == :dstr || ast.type == :str) &&
        (location  = ast.location)              &&
        (ast.location.kind_of? Parser::Source::Map::Heredoc)
    end

    def void_value?(ast)
      case ast && ast.type
      when :begin, :kwbegin, :resbody
        void_value?(ast.children[-1])
      when :rescue, :ensure
        ast.children.any? { |child| void_value? child }
      when :if
        void_value?(ast.children[1]) || void_value?(ast.children[2])
      when :return, :next, :redo, :retry, :break
        true
      else
        false
      end
    end

    private

    def extract_comments(builder, buffer)
      # THIS IS SO WE CAN EXTRACT COMMENTS FROM INVALID FILES.
      # We do it by telling Parser's diagnostic to not blow up.
      #   https://github.com/whitequark/parser/blob/2d69a1b5f34ef15b3a8330beb036ac4bf4775e29/lib/parser/diagnostic/engine.rb
      # However, this probably implies SiB won't work on Rbx/JRuby
      #   https://github.com/whitequark/parser/blob/2d69a1b5f34ef15b3a8330beb036ac4bf4775e29/lib/parser/base.rb#L129-134
      # Ideally we could just do this
      #   parser.diagnostics.all_errors_are_fatal = false
      #   parser.diagnostics.ignore_warnings      = false
      # But, the parser will still blow up on "fatal" errors (e.g. unterminated string) So we need to actually change it.
      #   https://github.com/whitequark/parser/blob/2d69a1b5f34ef15b3a8330beb036ac4bf4775e29/lib/parser/diagnostic/engine.rb#L99
      # We could make a NullDiagnostics like this:
      #   class NullDiagnostics < Parser::Diagnostic::Engine
      #     def process(*)
      #       # no op
      #     end
      #   end
      # But we don't control initialization of the variable, and the value gets passed around, at least into the lexer.
      #   https://github.com/whitequark/parser/blob/2d69a1b5f34ef15b3a8330beb036ac4bf4775e29/lib/parser/base.rb#L139
      #   and since it's all private, it could change at any time (Parser is very state based),
      #   so I think it's just generally safer to mutate that one object, as we do now.
      parser      = Parser::CurrentRuby.new builder
      diagnostics = parser.diagnostics
      def diagnostics.process(*)
        self
      end
      _, all_comments, _ = parser.tokenize(@buffer)
      all_comments
    end

    def wrap_comment(comment)
      last_char  = comment.location.expression.begin_pos
      first_char = last_char
      first_char -= 1 while first_char > 0 && code[first_char-1] =~ /[ \t]/
      preceding_whitespace        = buffer.source[first_char...last_char]
      preceding_whitespace_range  = range_for first_char, last_char

      InlineComment.new comment.location.line,
                        preceding_whitespace_range.column,
                        preceding_whitespace,
                        comment.location.column,
                        comment.text,
                        range_for(first_char, comment.location.expression.end_pos),
                        preceding_whitespace_range,
                        comment.location.expression
    end
  end
end
