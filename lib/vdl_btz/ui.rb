# frozen_string_literal: true

module VdlBtz
  # Salida en terminal: colores, mensajes y barra de progreso.
  module UI
    COLORS = {
      bold: 1, red: 31, green: 32, yellow: 33, blue: 34, magenta: 35, cyan: 36, gray: 90
    }.freeze

    SYMBOLS = {
      ok: ["✔", "[OK]"], error: ["✖", "[X]"], warn: ["!", "[!]"], info: ["›", ">"], arrow: ["↓", "v"]
    }.freeze

    module_function

    def out
      $stdout
    end

    def tty?
      out.respond_to?(:tty?) && out.tty?
    end

    def color?
      !ENV.key?("NO_COLOR") && tty?
    end

    def paint(text, *styles)
      return text.to_s unless color? && !styles.empty?

      "\e[#{styles.map { |s| COLORS.fetch(s) }.join(';')}m#{text}\e[0m"
    end

    def sym(name)
      plain = OS.windows? && !ENV["WT_SESSION"] # la consola clásica de Windows no muestra bien Unicode
      SYMBOLS.fetch(name)[plain ? 1 : 0]
    end

    def say(msg = "")
      out.puts(msg)
    end

    def info(msg)
      say("#{paint(sym(:info), :cyan)} #{msg}")
    end

    def success(msg)
      say("#{paint(sym(:ok), :green)} #{msg}")
    end

    def warn(msg)
      say("#{paint(sym(:warn), :yellow)} #{paint(msg, :yellow)}")
    end

    def error(msg)
      say("#{paint(sym(:error), :red)} #{paint(msg, :red)}")
    end

    def hint(msg)
      say("  #{paint(msg, :gray)}")
    end

    def title(msg)
      say(paint(msg, :bold))
    end

    # Dibuja (o redibuja) una línea de progreso. Solo en terminales interactivas.
    def progress(percent, detail = "")
      return unless tty?

      width = 30
      filled = (percent.to_f / 100 * width).round.clamp(0, width)
      bar = ("=" * filled) + (filled < width ? ">" : "") + (" " * [width - filled - 1, 0].max)
      line = format("  [%<bar>s] %<pct>5.1f%%  %<detail>s", bar: paint(bar, :cyan), pct: percent, detail: detail)
      out.print("\r#{line}\e[K")
      out.flush
    end

    def end_progress
      out.print("\r\e[K") if tty?
    end

    def human_size(bytes)
      return "?" unless bytes&.positive?

      units = %w[B KB MB GB]
      i = (Math.log(bytes) / Math.log(1024)).floor.clamp(0, units.size - 1)
      format("%.1f %s", bytes.to_f / (1024**i), units[i])
    end
  end
end
