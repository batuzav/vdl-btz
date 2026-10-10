# frozen_string_literal: true

require "optparse"
require "openssl"

module VdlBtz
  # Interfaz de línea de comandos.
  class CLI
    COMMANDS = %w[setup update doctor info config help version].freeze

    def self.start(argv)
      exit(new.run(argv))
    end

    def initialize(installer: Installer.new, config: Config.load)
      @installer = installer
      @config = config
    end

    # Devuelve el código de salida.
    def run(argv)
      argv = argv.dup
      case argv.first
      when nil, "help", "-h", "--help" then help
      when "version", "-v", "--version" then version
      when "setup" then setup(argv.drop(1))
      when "update" then update
      when "doctor" then doctor
      when "info" then info(argv.drop(1))
      when "config" then config_cmd(argv.drop(1))
      else download(argv)
      end
    rescue OptionParser::ParseError, Error => e
      UI.error(e.message)
      UI.hint("Ayuda: vdl-btz help")
      1
    rescue Interrupt
      UI.end_progress
      UI.say
      UI.warn("Cancelado por el usuario")
      130
    rescue SocketError, SystemCallError, IOError, Timeout::Error, OpenSSL::SSL::SSLError => e
      UI.error("Error de conexión o del sistema: #{e.message}")
      UI.hint("Revisa tu conexión a internet y vuelve a intentarlo.")
      1
    end

    # ---------- Descargar ----------

    def parse_download_options(argv)
      opts = {
        output: @config["output"], quality: @config["quality"], cookies: @config["cookies"],
        audio: false, playlist: false, files: []
      }

      parser = OptionParser.new do |o|
        o.on("-a", "--audio") { opts[:audio] = true }
        o.on("-q", "--quality CALIDAD") do |v|
          opts[:quality] = Config.normalize_quality(v) ||
                           raise(Error, "Calidad inválida '#{v}'. Opciones: #{Config::QUALITIES.join(', ')}")
        end
        o.on("-o", "--output CARPETA") { |v| opts[:output] = File.expand_path(v) }
        o.on("-f", "--file ARCHIVO") { |v| opts[:files] << v }
        o.on("-c", "--cookies NAVEGADOR") do |v|
          opts[:cookies] = Config.normalize_browser(v) ||
                           raise(Error, "Navegador inválido '#{v}'. Opciones: #{Config::BROWSERS.join(', ')}")
        end
        o.on("-p", "--playlist") { opts[:playlist] = true }
      end

      urls = parser.parse(argv)
      opts[:files].each { |f| urls += read_url_file(f) }
      opts[:urls] = urls.map(&:strip).reject(&:empty?).uniq
      opts
    end

    def download(argv)
      opts = parse_download_options(argv)
      raise Error, "No indicaste ninguna URL. Ejemplo: vdl-btz https://youtu.be/xxxx" if opts[:urls].empty?

      invalid, urls = opts[:urls].partition { |u| !Platform.valid_url?(u) }
      invalid.each { |u| UI.error("URL inválida, se omite: #{u}") }
      return 1 if urls.empty?

      downloader = build_downloader(opts)
      results = urls.each_with_index.map do |url, i|
        download_one(downloader, url, i + 1, urls.size)
      end

      summary(results, invalid.size)
    end

    # ---------- Comandos ----------

    def info(argv)
      opts = parse_download_options(argv)
      url = opts[:urls].first
      raise Error, "Uso: vdl-btz info URL" unless url && Platform.valid_url?(url)

      downloader = Downloader.new(ytdlp: @installer.ensure_ytdlp!, cookies: opts[:cookies], output: opts[:output])
      UI.info("Consultando #{Platform.display_name(Platform.detect(url))}...")
      data = downloader.info(url)

      heights = Array(data["formats"]).select { |f| f["vcodec"] && f["vcodec"] != "none" }
                                      .map { |f| f["height"] }.compact.uniq.sort.reverse
      UI.say
      UI.title(data["title"].to_s)
      row("Autor", data["uploader"] || data["channel"])
      row("Duración", duration(data["duration"]))
      row("Vistas", data["view_count"])
      row("Calidades", heights.empty? ? "única" : heights.map { |h| "#{h}p" }.join(", "))
      row("Enlace", data["webpage_url"] || url)
      0
    end

    def setup(argv)
      force = argv.include?("--force")
      UI.title("Configurando vdl-btz en #{OS.name} (#{OS.arch})")

      if force || !@installer.ytdlp_path
        @installer.install_ytdlp
      else
        UI.success("yt-dlp ya está instalado: #{@installer.ytdlp_path}")
      end

      if force || !@installer.ffmpeg_path
        begin
          @installer.install_ffmpeg
        rescue StandardError => e
          UI.warn("No se pudo instalar ffmpeg: #{e.message}")
          UI.hint("vdl-btz seguirá funcionando, pero sin unir audio/video en alta calidad ni convertir a MP3.")
        end
      else
        UI.success("ffmpeg ya está instalado: #{@installer.ffmpeg_path}")
      end
      0
    end

    def update
      UI.info("Actualizando yt-dlp a la última versión...")
      @installer.install_ytdlp
      UI.hint("Para actualizar vdl-btz: gem update vdl-btz  (o git pull si lo usas desde el repositorio)")
      0
    end

    def doctor
      UI.title("Diagnóstico de vdl-btz #{VERSION}")
      row("Sistema", "#{OS.name} (#{OS.arch})")
      row("Ruby", RUBY_VERSION)

      ytdlp = @installer.ytdlp_path
      ffmpeg = @installer.ffmpeg_path
      ok_y = check("yt-dlp", ytdlp, @installer.version_of(ytdlp, "--version"))
      check("ffmpeg", ffmpeg, @installer.version_of(ffmpeg, "-version")&.split&.at(2))

      row("Carpeta", @config["output"])
      row("Calidad", @config["quality"])
      row("Cookies", @config["cookies"] || "ninguna")
      row("Config", @config.path)

      UI.say
      if ok_y
        UI.success("Todo listo para descargar")
        UI.hint("Sin ffmpeg: calidad limitada y sin MP3. Ejecuta: vdl-btz setup") unless ffmpeg
        0
      else
        UI.warn("Falta yt-dlp. Ejecuta: vdl-btz setup (o simplemente descarga algo y se instalará solo)")
        1
      end
    end

    def config_cmd(argv)
      case argv.first
      when nil, "show"
        UI.title("Configuración (#{@config.path})")
        @config.to_h.each { |k, v| row(k, v.nil? ? "ninguno" : v) }
        UI.say
        UI.hint("Cambiar: vdl-btz config set output ~/Videos | quality 720 | cookies chrome")
      when "set"
        key, value = argv[1], argv[2]
        raise Error, "Uso: vdl-btz config set CLAVE VALOR" unless key && value

        @config.set(key, value)
        UI.success("#{key} = #{@config[key] || 'ninguno'}")
      when "reset"
        @config.reset
        UI.success("Configuración restablecida a los valores por defecto")
      else
        raise Error, "Subcomando desconocido: config #{argv.first}. Usa: show, set, reset"
      end
      0
    end

    def version
      UI.say("vdl-btz #{VERSION}")
      0
    end

    def help
      UI.say(<<~HELP)
        #{UI.paint("vdl-btz #{VERSION}", :bold)} - Descarga videos de TikTok, YouTube, Instagram y Facebook

        #{UI.paint('USO', :bold)}
          vdl-btz URL [URL...] [opciones]     Descarga uno o varios videos
          vdl-btz info URL                    Muestra información sin descargar
          vdl-btz setup [--force]             Instala/reinstala yt-dlp y ffmpeg
          vdl-btz update                      Actualiza el motor de descarga
          vdl-btz doctor                      Revisa que todo funcione
          vdl-btz config [set CLAVE VALOR]    Ver o cambiar la configuración
          vdl-btz version                     Muestra la versión

        #{UI.paint('OPCIONES', :bold)}
          -a, --audio              Solo audio (MP3)
          -q, --quality CALIDAD    best, 2160, 1440, 1080, 720, 480, 360 (por defecto: best)
          -o, --output CARPETA     Carpeta de destino (por defecto: ~/Downloads/vdl-btz)
          -f, --file ARCHIVO       Lee URLs desde un archivo (una por línea)
          -c, --cookies NAVEGADOR  Usa tu sesión del navegador (chrome, firefox, edge, safari...)
          -p, --playlist           Descarga la playlist completa si la URL tiene una

        #{UI.paint('EJEMPLOS', :bold)}
          vdl-btz https://www.tiktok.com/@usuario/video/123
          vdl-btz https://youtu.be/abc123 -q 720
          vdl-btz https://youtu.be/abc123 --audio
          vdl-btz https://www.instagram.com/reel/xyz/ --cookies chrome
          vdl-btz -f lista.txt -o ~/Videos
      HELP
      0
    end

    private

    def build_downloader(opts)
      ytdlp = @installer.ensure_ytdlp!
      ffmpeg = @installer.ensure_ffmpeg
      UI.warn("ffmpeg no disponible: el audio se guardará en su formato original (no MP3)") if opts[:audio] && !ffmpeg

      Downloader.new(
        ytdlp: ytdlp, ffmpeg: ffmpeg,
        output: opts[:output], quality: opts[:quality], audio: opts[:audio],
        cookies: opts[:cookies], playlist: opts[:playlist]
      )
    end

    def download_one(downloader, url, index, total)
      counter = total > 1 ? UI.paint("[#{index}/#{total}] ", :gray) : ""
      UI.say
      UI.info("#{counter}#{UI.paint(Platform.display_name(Platform.detect(url)), :magenta)}  #{UI.paint(url, :gray)}")

      result = downloader.download(url) do |event, data|
        case event
        when :title
          UI.end_progress
          UI.say("  #{UI.paint(UI.sym(:arrow), :cyan)} #{data}")
        when :progress then UI.progress(data[0], "#{data[1]}  ETA #{data[2]}")
        when :done then UI.end_progress
        end
      end

      UI.end_progress
      if result.ok
        UI.success("Guardado en: #{result.file || downloader.options[:output]}")
      else
        UI.error(result.error)
        UI.hint(Hints.for(result.error))
      end
      result
    end

    def summary(results, invalid_count)
      ok = results.count(&:ok)
      failed = results.size - ok + invalid_count
      return (failed.zero? ? 0 : 1) if results.size + invalid_count <= 1

      UI.say
      UI.title("Resumen: #{UI.paint("#{ok} descargados", :green)}, #{UI.paint("#{failed} con error", failed.zero? ? :gray : :red)}")
      failed.zero? ? 0 : 1
    end

    def read_url_file(path)
      raise Error, "No existe el archivo: #{path}" unless File.file?(path)

      File.readlines(path, chomp: true).map(&:strip).reject { |l| l.empty? || l.start_with?("#") }
    end

    def row(label, value)
      UI.say(format("  %-10<label>s %<value>s", label: "#{label}:", value: value.nil? ? "-" : value))
    end

    def check(name, path, version)
      if path && version
        row(name, "#{UI.paint(UI.sym(:ok), :green)} #{version}  #{UI.paint(path, :gray)}")
        true
      else
        row(name, "#{UI.paint(UI.sym(:error), :red)} no instalado")
        false
      end
    end

    def duration(seconds)
      return nil unless seconds

      s = seconds.to_i
      h, rem = s.divmod(3600)
      m, sec = rem.divmod(60)
      h.positive? ? format("%d:%02d:%02d", h, m, sec) : format("%d:%02d", m, sec)
    end
  end
end
