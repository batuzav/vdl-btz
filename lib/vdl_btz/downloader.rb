# frozen_string_literal: true

require "open3"
require "json"

module VdlBtz
  # Ejecuta yt-dlp con las opciones adecuadas e interpreta su salida.
  class Downloader
    TITLE_TAG = "VDLT:"
    PROGRESS_TAG = "VDLP:"
    FILE_TAG = "VDLF:"
    ANSI = /\e\[[\d;]*[A-Za-z]/.freeze

    Result = Struct.new(:url, :ok, :file, :error, :canceled, keyword_init: true)

    attr_reader :options, :pid

    # options: :output, :quality, :audio, :cookies, :playlist
    def initialize(ytdlp:, ffmpeg: nil, **options)
      @ytdlp = ytdlp
      @ffmpeg = ffmpeg
      @options = { quality: "best", audio: false, cookies: nil, playlist: false }.merge(options)
    end

    # Argumentos para yt-dlp (sin el ejecutable).
    def build_args(url)
      platform = Platform.detect(url) || "otros"
      dir = File.join(File.expand_path(options.fetch(:output)), platform).gsub("%", "%%")

      args = [
        "--newline", "--progress", "--no-simulate", "--no-mtime", "--windows-filenames",
        "--progress-template", "download:#{PROGRESS_TAG}%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s",
        "--print", "before_dl:#{TITLE_TAG}%(title)s",
        "--print", "after_move:#{FILE_TAG}%(filepath)s",
        "-o", File.join(dir, "%(title).80B [%(id)s].%(ext)s"),
        options[:playlist] ? "--yes-playlist" : "--no-playlist"
      ]
      args += ["--ffmpeg-location", @ffmpeg] if @ffmpeg
      args += ["--cookies-from-browser", options[:cookies]] if options[:cookies]
      args += format_args
      args + ["--", url]
    end

    # Descarga una URL. Emite eventos al bloque: (:title, str), (:progress, [pct, speed, eta]), (:done, file).
    def download(url)
      file = nil
      errors = []
      status = nil
      @canceled = false

      Open3.popen3(@ytdlp, *build_args(url)) do |stdin, stdout, stderr, wait|
        @pid = wait.pid
        stdin.close
        err_reader = Thread.new do
          stderr.each_line do |line|
            line = clean(line)
            errors << line.sub(/\AERROR:\s*/, "") if line.start_with?("ERROR:")
          end
        end

        stdout.each_line do |line|
          line = clean(line)
          if line.start_with?(TITLE_TAG)
            yield(:title, line.delete_prefix(TITLE_TAG)) if block_given?
          elsif line.start_with?(PROGRESS_TAG)
            yield(:progress, parse_progress(line)) if block_given?
          elsif line.start_with?(FILE_TAG)
            file = line.delete_prefix(FILE_TAG)
            yield(:done, file) if block_given?
          end
        end

        err_reader.join
        status = wait.value
      end
      @pid = nil

      if @canceled
        Result.new(url: url, ok: false, canceled: true, error: "Cancelado")
      elsif status.success?
        Result.new(url: url, ok: true, file: file)
      else
        Result.new(url: url, ok: false, error: errors.last || "yt-dlp terminó con código #{status.exitstatus}")
      end
    end

    # Termina la descarga en curso (si la hay).
    def cancel!
      return unless @pid

      @canceled = true
      Process.kill(OS.windows? ? "KILL" : "TERM", @pid)
    rescue Errno::ESRCH
      nil
    end

    # Obtiene metadatos del video sin descargarlo.
    def info(url)
      args = ["-J", "--no-warnings", "--no-playlist"]
      args += ["--cookies-from-browser", options[:cookies]] if options[:cookies]
      out, err, status = Open3.capture3(@ytdlp, *args, "--", url)
      unless status.success?
        message = clean(err).lines.map(&:strip).grep(/\AERROR:/).last.to_s.sub(/\AERROR:\s*/, "")
        raise Error, (message.empty? ? "No se pudo obtener la información del video" : message)
      end

      JSON.parse(out)
    end

    private

    def format_args
      if options[:audio]
        if @ffmpeg
          ["-f", "ba/b", "-x", "--audio-format", "mp3", "--audio-quality", "0"]
        else
          ["-f", "ba[ext=m4a]/ba/b"]
        end
      else
        quality = options[:quality].to_s
        sort = quality == "best" ? "res,ext:mp4:m4a" : "res:#{quality},ext:mp4:m4a"
        # Sin ffmpeg no se pueden unir pistas separadas: se usa el mejor archivo que ya trae audio y video.
        args = ["-f", @ffmpeg ? "bv*+ba/b" : "b", "-S", sort]
        args += ["--merge-output-format", "mp4"] if @ffmpeg
        args
      end
    end

    def parse_progress(line)
      pct, speed, eta = line.delete_prefix(PROGRESS_TAG).split("|").map(&:strip)
      [pct.to_f, speed.to_s, eta.to_s]
    end

    def clean(text)
      text.to_s.encode("UTF-8", invalid: :replace, undef: :replace).gsub(ANSI, "").chomp
    end
  end
end
