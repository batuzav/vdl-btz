# frozen_string_literal: true

require "net/http"
require "uri"
require "fileutils"
require "tmpdir"
require "open3"
require "digest"

module VdlBtz
  # Instala y localiza las dependencias externas (yt-dlp y ffmpeg).
  # Los binarios se guardan en ~/.vdl-btz/bin, sin necesitar permisos de administrador.
  class Installer
    YTDLP_RELEASES = "https://github.com/yt-dlp/yt-dlp/releases/latest/download/"
    FFMPEG_BUILDS = "https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/"
    EVERMEET = "https://evermeet.cx/ffmpeg/getrelease/"

    def initialize(bin_dir: Paths.bin_dir, on_progress: nil)
      @bin_dir = bin_dir
      @on_progress = on_progress
    end

    attr_reader :bin_dir
    attr_accessor :on_progress

    # Comprueba el SHA-256 de `path` contra la línea de `asset` en el texto de SHA2-256SUMS.
    def self.verify_sha256!(path, sums_text, asset)
      expected = sums_text.each_line.filter_map { |l| l.chomp.match(/\A([0-9a-f]{64})  (.+)\z/) }
                          .find { |m| m[2] == asset }&.then { |m| m[1] }
      return true if expected && Digest::SHA256.file(path).hexdigest == expected

      raise Error, "La verificación SHA-256 de #{asset} falló"
    end

    # ---------- Localizar ----------

    def managed_path(name)
      File.join(bin_dir, OS.exe(name))
    end

    # Prioriza el binario propio de vdl-btz; si no existe, usa el del sistema.
    def find(name)
      own = managed_path(name)
      return own if File.file?(own)

      OS.which(name)
    end

    def ytdlp_path
      find("yt-dlp")
    end

    def ffmpeg_path
      find("ffmpeg")
    end

    def version_of(path, *args)
      return nil unless path

      out, status = Open3.capture2e(path, *args)
      status.success? ? out.lines.first.to_s.strip : nil
    rescue SystemCallError
      nil
    end

    # ---------- Asegurar (primer uso) ----------

    def ensure_ytdlp!
      ytdlp_path || begin
        UI.info("Primer uso: instalando el motor de descarga (yt-dlp)...")
        install_ytdlp
      end
    end

    # ffmpeg es opcional: si no se puede instalar, devuelve nil y se descarga sin él.
    def ensure_ffmpeg
      path = ffmpeg_path
      return path if path
      return nil if File.exist?(Paths.ffmpeg_skip_file)

      UI.info("Primer uso: instalando ffmpeg (para mejor calidad y MP3)...")
      install_ffmpeg
    rescue StandardError => e
      UI.warn("No se pudo instalar ffmpeg: #{e.message}")
      UI.hint("Se descargará en la mejor calidad disponible sin ffmpeg. Reintenta con: vdl-btz setup")
      FileUtils.mkdir_p(File.dirname(Paths.ffmpeg_skip_file))
      FileUtils.touch(Paths.ffmpeg_skip_file)
      nil
    end

    # ---------- Instalar ----------

    def install_ytdlp
      FileUtils.mkdir_p(bin_dir)
      target = managed_path("yt-dlp")
      tmp = "#{target}.part"
      sums = "#{target}.sums.part"
      download(YTDLP_RELEASES + ytdlp_asset, tmp, label: "yt-dlp")
      download(YTDLP_RELEASES + "SHA2-256SUMS", sums, label: "SHA2-256SUMS")
      Installer.verify_sha256!(tmp, File.read(sums), ytdlp_asset)
      FileUtils.chmod(0o755, tmp)
      FileUtils.mv(tmp, target, force: true)

      version = version_of(target, "--version")
      raise Error, "yt-dlp se descargó pero no se puede ejecutar en este sistema." unless version

      UI.success("yt-dlp #{version} instalado")
      target
    ensure
      FileUtils.rm_f([tmp, sums].compact)
    end

    def install_ffmpeg
      FileUtils.mkdir_p(bin_dir)

      if OS.mac? && OS.arm? && OS.which("brew")
        install_ffmpeg_with_brew
      else
        install_ffmpeg_static
      end

      path = ffmpeg_path
      raise Error, "ffmpeg no quedó instalado correctamente." unless version_of(path, "-version")

      FileUtils.rm_f(Paths.ffmpeg_skip_file)
      UI.success("ffmpeg instalado")
      path
    end

    # Nombre del archivo de yt-dlp publicado para cada sistema.
    def ytdlp_asset
      if OS.windows? then "yt-dlp.exe"
      elsif OS.mac? then "yt-dlp_macos"
      elsif OS.linux? && OS.arm? then "yt-dlp_linux_aarch64"
      elsif OS.linux? then "yt-dlp_linux"
      else "yt-dlp" # versión genérica (requiere Python 3)
      end
    end

    # URLs de los paquetes de ffmpeg (estáticos) para cada sistema.
    def ffmpeg_archives
      if OS.windows?
        [FFMPEG_BUILDS + "ffmpeg-master-latest-win64-gpl.zip"]
      elsif OS.mac?
        [EVERMEET + "zip", EVERMEET + "ffprobe/zip"]
      elsif OS.linux? && OS.arm?
        [FFMPEG_BUILDS + "ffmpeg-master-latest-linuxarm64-gpl.tar.xz"]
      elsif OS.linux?
        [FFMPEG_BUILDS + "ffmpeg-master-latest-linux64-gpl.tar.xz"]
      else
        raise Error, "No hay ffmpeg automático para #{OS.name}. Instálalo manualmente."
      end
    end

    private

    def install_ffmpeg_with_brew
      UI.info("Usando Homebrew: brew install ffmpeg (puede tardar unos minutos)")
      raise Error, "brew install ffmpeg falló" unless system("brew", "install", "ffmpeg")
    end

    def install_ffmpeg_static
      Dir.mktmpdir("vdl-btz") do |tmp|
        ffmpeg_archives.each_with_index do |url, i|
          ext = url.end_with?(".tar.xz") ? ".tar.xz" : ".zip"
          archive = File.join(tmp, "pkg#{i}#{ext}")
          download(url, archive, label: "ffmpeg (#{i + 1}/#{ffmpeg_archives.size})")
          extract(archive, File.join(tmp, "out#{i}"))
        end

        %w[ffmpeg ffprobe].each do |name|
          found = Dir.glob(File.join(tmp, "out*", "**", OS.exe(name))).find { |f| File.file?(f) }
          raise Error, "No se encontró #{name} dentro del paquete descargado." unless found

          FileUtils.cp(found, managed_path(name))
          FileUtils.chmod(0o755, managed_path(name))
        end
      end
    end

    # `tar` viene incluido en macOS, Linux y Windows 10+ y entiende .zip y .tar.xz.
    def extract(archive, dest)
      FileUtils.mkdir_p(dest)
      _out, status = Open3.capture2e("tar", "-xf", archive, "-C", dest)
      raise Error, "No se pudo descomprimir #{File.basename(archive)} (¿está instalado 'tar'?)" unless status.success?
    rescue Errno::ENOENT
      raise Error, "No se encontró el comando 'tar' para descomprimir ffmpeg."
    end

    # Descarga HTTP(S) con soporte de redirecciones y barra de progreso.
    def download(url, dest, label:, redirects: 10)
      raise Error, "Demasiadas redirecciones al descargar #{label}" if redirects.zero?

      uri = URI(url)
      redirect = nil
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 20, read_timeout: 60) do |http|
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = "vdl-btz/#{VERSION}"
        http.request(request) do |res|
          case res
          when Net::HTTPRedirection
            redirect = URI.join(url, res["location"]).to_s
          when Net::HTTPSuccess
            write_body(res, dest, label)
          else
            raise Error, "Error HTTP #{res.code} al descargar #{label}"
          end
        end
      end
      download(redirect, dest, label: label, redirects: redirects - 1) if redirect
    end

    def write_body(res, dest, label)
      total = res["content-length"].to_i
      done = 0
      File.open(dest, "wb") do |file|
        res.read_body do |chunk|
          file.write(chunk)
          done += chunk.bytesize
          pct = total.positive? ? done * 100.0 / total : 0
          UI.progress(pct, "#{label}  #{UI.human_size(done)} / #{UI.human_size(total)}")
          @on_progress&.call(label, pct)
        end
      end
      UI.end_progress
    end
  end
end
