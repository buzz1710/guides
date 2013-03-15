require "strscan"
require "cgi"

module Guides
  module HTMLFormatter
    include RedCloth::Formatters::HTML

    def br(opts)
      " "
    end
  end

  class TextileTransformer
    LANGUAGES = { "ruby" => "ruby", "sql" => "sql", "javascript" => "javascript",
                  "css" => "css", "plain" => "plain", "erb" => "ruby; html-script: true",
                  "html" => "xml", "xml" => "xml", "shell" => "plain", "yaml" => "yaml" }

    NOTES =     { "CAUTION" => "warning", "IMPORTANT" => "warning", "WARNING" => "warning",
                  "INFO" => "info", "TIP" => "info", "NOTE" => "note" }

    def initialize(production=false)
      @production = production
    end

    def transform(string)
      @string = string.dup

      @output  = ""
      @pending_textile = ""

      until @string.empty?
        notes     = NOTES.keys.map {|note| "#{note}" }.join("|")
        languages = LANGUAGES.keys.join("|")

        match = scan_until /(\+(\S.*?\S?)\+|<(#{languages})(?: filename=["']([^"']*)["'])?>|(#{notes}): |<(construction)>|\z)/m

        @pending_textile << match.pre_match

        if match[2]    # +foo+
          @pending_textile << "<notextile><tt>#{CGI.escapeHTML(match[2])}</tt></notextile>" if match[2]
        elsif match[3] # <language>
          flush_textile
          generate_brushes match[3], LANGUAGES[match[3]], match[4]
        elsif match[5] # NOTE:
          flush_textile
          consume_note NOTES[match[5]]
        elsif match[6] # <construction>
          consume_construction
        end
      end

      flush_textile

      @output
    end

    def generate_brushes(tag, replace, filename)
      match = scan_until %r{</#{tag}>}
      @output << %{<div class="code_container">\n}
      @output << %{<div class="filename">#{filename}</div>\n} if filename
      @output << %{<pre class="brush: #{replace}; gutter: false; toolbar: false">\n} <<
                 CGI.escapeHTML(match.pre_match) << %{</pre></div>}
    end

    def scan_until(regex)
      match = @string.match(regex)
      @string = match.post_match
      match
    end

    def consume_note(css_class)
      match = scan_until /((\r?\n){2,}|\z)/ # We need at least 2 line breaks but we want to match as many as exist
      note = match.pre_match.gsub(/\n\s*/, " ")
      note = RedCloth.new(note, [:lite_mode]).to_html
      @output << %{<div class="#{css_class}"><p>#{note}</p></div>\n}
    end

    def consume_construction
      match = scan_until(%r{</construction>})
      unless @production
        @string = match.pre_match + @string
      end
    end

    def flush_textile
      @output << RedCloth.new(@pending_textile).to(HTMLFormatter) << "\n"
      @pending_textile = ""
    end
  end
end
