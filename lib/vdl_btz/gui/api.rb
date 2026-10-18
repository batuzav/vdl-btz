# frozen_string_literal: true

require "json"
require "fileutils"

module VdlBtz
  module GUI
    # Rutas JSON de la aplicación. Recibe un Request y devuelve [estado, cabeceras, cuerpo] (o nil).
    class Api
      def initialize(queue:, config:, installer:, opener: OS.method(:open_path))
        @queue = queue
        @config = config
        @installer = installer
        @opener = opener
        @lock = Mutex.new
        @setup = { running: false, label: nil, percent: nil, error: nil }
      end

      def call(req)
        case [req.method, req.path]
        when ["GET", "/api/state"] then ok(state)
        when ["GET", "/api/jobs"] then ok(jobs: @queue.list)
        when ["POST", "/api/jobs"] then create_jobs(req)
        when ["POST", "/api/config"] then save_config(req)
        when ["POST", "/api/setup"] then install { @installer.ensure_ytdlp! && @installer.ensure_ffmpeg }
        when ["POST", "/api/engine/update"] then install { @installer.install_ytdlp }
        when ["POST", "/api/open"] then open_folder(req)
        else
          m = req.path.match(%r{\A/api/jobs/([0-9a-f]+)/cancel\z})
          cancel(m[1]) if m && req.method == "POST"
        end
      end

      private

      def state
        { version: VERSION, os: OS.name, config: @config.to_h, qualities: Config::QUALITIES, browsers: Config::BROWSERS,
          setup: setup_state }
      end

      def setup_state
        { ytdlp: !@installer.ytdlp_path.nil?, ffmpeg: !@installer.ffmpeg_path.nil? }.merge(@lock.synchronize { @setup.dup })
      end

      def save_config(req)
        body = parse(req.body) or return fail_with(400, "bad_json", "El cuerpo debe ser un objeto JSON")
        bad = body.find { |k, v| !valid_config?(k, v) }
        return fail_with(400, "invalid_config", "Valor inválido para #{bad[0]}") if bad || body.empty?

        body.each { |k, v| @config.set(k, v) }
        ok(config: @config.to_h)
      end

      # Config#set guarda en disco al validar, así que se valida aparte y sin escribir.
      def valid_config?(key, value)
        case key
        when "quality" then !Config.normalize_quality(value).nil?
        when "cookies" then %w[none ninguno no off].include?(value.to_s.downcase) || !Config.normalize_browser(value).nil?
        when "output" then value.is_a?(String) && !value.strip.empty?
        else false
        end
      end

      def install(&work)
        @lock.synchronize do
          return fail_with(409, "already_running", "Ya hay una instalación en marcha") if @setup[:running]

          @setup = { running: true, label: nil, percent: nil, error: nil }
        end
        @installer.on_progress = ->(label, pct) { @lock.synchronize { @setup.merge!(label: label, percent: pct) } }
        Thread.new { run_install(&work) }
        [202, {}, JSON.generate(ok: true, data: { setup: setup_state })]
      end

      def run_install
        yield
      rescue StandardError => e
        @lock.synchronize { @setup[:error] = e.message }
      ensure
        @lock.synchronize { @setup.merge!(running: false, label: nil, percent: nil) }
      end

      def open_folder(req)
        id = (parse(req.body) || {})["id"]
        if id
          file = @queue.list.find { |j| j[:id] == id }&.dig(:file)
          return fail_with(404, "no_file", "El trabajo no tiene archivo") unless file

          dir = File.dirname(file)
        else
          dir = @config["output"]
          FileUtils.mkdir_p(dir)
        end
        @opener.call(dir)
        ok(opened: true)
      end

      def create_jobs(req)
        body = parse(req.body) or return fail_with(400, "bad_json", "El cuerpo debe ser un objeto JSON")
        urls = body["urls"]
        unless urls.is_a?(Array) && (1..20).cover?(urls.size) && urls.all?(String)
          return fail_with(400, "no_urls", "Indica entre 1 y 20 enlaces")
        end

        quality = body.key?("quality") ? Config.normalize_quality(body["quality"]) : @config["quality"]
        return fail_with(400, "invalid_quality", "Calidad inválida") unless quality
        return fail_with(409, "setup_required", "Falta instalar el motor de descarga") unless @installer.ytdlp_path

        jobs = @queue.add(urls, audio: body["audio"] == true, quality: quality)
        [202, {}, JSON.generate(ok: true, data: { jobs: jobs.map(&:to_h) })]
      rescue Error => e
        fail_with(400, "invalid_url", e.message)
      end

      def cancel(id)
        return fail_with(404, "not_found", "Trabajo no encontrado") unless @queue.cancel(id)

        ok(jobs: @queue.list.select { |j| j[:id] == id })
      end

      def parse(text)
        data = JSON.parse(text)
        data.is_a?(Hash) ? data : nil
      rescue JSON::ParserError
        nil
      end

      def ok(data)
        [200, {}, JSON.generate(ok: true, data: data)]
      end

      def fail_with(status, code, message)
        [status, {}, JSON.generate(ok: false, error: { code: code, message: message })]
      end
    end
  end
end
