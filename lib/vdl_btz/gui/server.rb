# frozen_string_literal: true

require "socket"
require "json"
require "securerandom"
require "openssl"
require "uri"

module VdlBtz
  module GUI
    Request = Struct.new(:method, :path, :query, :headers, :body, keyword_init: true)

    # Servidor HTTP local mínimo (solo 127.0.0.1). Las rutas que no son suyas las delega en `handler`.
    class Server
      REASONS = { 200 => "OK", 202 => "Accepted", 400 => "Bad Request", 401 => "Unauthorized", 403 => "Forbidden",
                  404 => "Not Found", 405 => "Method Not Allowed", 409 => "Conflict", 413 => "Payload Too Large" }.freeze
      METHODS = { "/api/health" => "GET", "/api/shutdown" => "POST", "/api/ping" => "POST" }.freeze
      MAX_BODY = 65_536
      ASSETS_DIR = File.expand_path("assets", __dir__)
      # Lista blanca fija de lo que se sirve en /assets/ (nada de rutas armadas con lo que pide el cliente).
      ASSETS = {
        "app.css" => "text/css; charset=utf-8", "app.js" => "text/javascript; charset=utf-8",
        "fonts/hanken-grotesk-var.woff2" => "font/woff2", "fonts/space-mono-400.woff2" => "font/woff2",
        "fonts/space-mono-700.woff2" => "font/woff2"
      }.freeze
      SECURITY = {
        "Cache-Control" => "no-store", "X-Content-Type-Options" => "nosniff", "Referrer-Policy" => "no-referrer",
        "Content-Security-Policy" => "default-src 'self'; img-src 'self' data:; frame-ancestors 'none'"
      }.freeze

      def initialize(token:, handler: nil, port: 0, idle_timeout: nil)
        @token = token
        @handler = handler
        @port = port
        @idle_timeout = idle_timeout
      end

      def start
        @tcp = TCPServer.new("127.0.0.1", @port)
        @port = @tcp.addr[1]
        @thread = Thread.new { accept_loop }
        touch
        Thread.new { watch_idle } if @idle_timeout
        @port
      end

      def stop
        @tcp&.close
      end

      def join
        @thread&.join
      end

      private

      def now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def touch
        @last_ping = now
      end

      def watch_idle
        loop do
          sleep 0.25
          return stop if now - @last_ping > @idle_timeout
        end
      end

      def accept_loop
        loop { Thread.new(@tcp.accept) { |sock| serve(sock) } }
      rescue IOError, Errno::EBADF
        nil
      end

      def serve(sock)
        status, extra, body, method, path = handle(sock)
        head = { "Content-Type" => "application/json; charset=utf-8", "Content-Length" => body.bytesize.to_s,
                 "Connection" => "close" }.merge(SECURITY).merge(extra)
        sock.write("HTTP/1.1 #{status} #{REASONS[status]}\r\n#{head.map { |k, v| "#{k}: #{v}" }.join("\r\n")}\r\n\r\n")
        sock.write(body)
        stop if method == "POST" && path == "/api/shutdown" && status == 200
      rescue StandardError
        nil
      ensure
        sock.close
      end

      def handle(sock)
        method, target, version = sock.gets.to_s.split(" ")
        return [400, {}, error("bad_request", "Petición mal formada")] unless version.to_s.start_with?("HTTP/1.")

        headers = {}
        while (h = sock.gets) && h != "\r\n"
          k, v = h.split(":", 2)
          headers[k.downcase] = v.to_s.strip
        end
        path, query = target.split("?", 2)
        return [403, {}, error("bad_host", "Host no permitido")] unless allowed_host?(headers["host"])
        return [413, {}, error("too_large", "Cuerpo demasiado grande")] if headers["content-length"].to_i > MAX_BODY

        body = sock.read(headers["content-length"].to_i).to_s
        req = Request.new(method: method, path: path, query: URI.decode_www_form(query.to_s).to_h, headers: headers, body: body)
        [*route(req), method, path]
      end

      def allowed_host?(host)
        ["127.0.0.1:#{@port}", "localhost:#{@port}"].include?(host)
      end

      def route(req)
        path = req.path
        return [401, {}, error("unauthorized", "Token inválido")] if path.start_with?("/api/") && !authorized?(req.headers)
        return [405, {}, error("method_not_allowed", "Método no permitido")] if METHODS.key?(path) && METHODS[path] != req.method

        case path
        when "/api/health" then [200, {}, JSON.generate(ok: true, data: { version: VERSION })]
        when "/api/shutdown" then [200, {}, JSON.generate(ok: true, data: {})]
        when "/api/ping" then touch && [200, {}, JSON.generate(ok: true, data: {})]
        when "/" then page(req)
        when %r{\A/assets/} then asset(path.delete_prefix("/assets/"))
        else @handler&.call(req) || [404, {}, error("not_found", "Ruta no encontrada")]
        end
      end

      # index.html con el token incrustado en <meta name="vdl-token">; sin `t` válido no se sirve.
      def page(req)
        return [401, {}, error("unauthorized", "Token inválido")] unless token_ok?(req.query["t"])

        html = File.binread(File.join(ASSETS_DIR, "index.html")).sub("__VDL_TOKEN__", @token)
        [200, { "Content-Type" => "text/html; charset=utf-8" }, html]
      end

      def asset(name)
        file = File.join(ASSETS_DIR, name)
        return [404, {}, error("not_found", "Ruta no encontrada")] unless ASSETS.key?(name) && File.file?(file)

        [200, { "Content-Type" => ASSETS[name] }, File.binread(file)]
      end

      def authorized?(headers)
        token_ok?(headers["x-vdl-token"])
      end

      def token_ok?(given)
        given = given.to_s
        given.bytesize == @token.bytesize && OpenSSL.fixed_length_secure_compare(given, @token)
      end

      def error(code, message)
        JSON.generate(ok: false, error: { code: code, message: message })
      end
    end
  end
end
