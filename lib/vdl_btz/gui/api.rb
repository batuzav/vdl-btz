# frozen_string_literal: true

require "json"

module VdlBtz
  module GUI
    # Rutas JSON de la aplicación. Recibe un Request y devuelve [estado, cabeceras, cuerpo] (o nil).
    class Api
      def initialize(queue:, config:, installer:)
        @queue = queue
        @config = config
        @installer = installer
      end

      def call(req)
        case [req.method, req.path]
        when ["GET", "/api/state"] then ok(state)
        when ["GET", "/api/jobs"] then ok(jobs: @queue.list)
        when ["POST", "/api/jobs"] then create_jobs(req)
        else
          m = req.path.match(%r{\A/api/jobs/([0-9a-f]+)/cancel\z})
          cancel(m[1]) if m && req.method == "POST"
        end
      end

      private

      def state
        { version: VERSION, os: OS.name, config: @config.to_h, qualities: Config::QUALITIES, browsers: Config::BROWSERS,
          setup: { ytdlp: !@installer.ytdlp_path.nil?, ffmpeg: !@installer.ffmpeg_path.nil?, running: false,
                   label: nil, percent: nil, error: nil } }
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
