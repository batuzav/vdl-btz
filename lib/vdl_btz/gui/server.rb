# frozen_string_literal: true

require "socket"
require "json"
require "securerandom"
require "openssl"

module VdlBtz
  module GUI
    # Servidor HTTP local mínimo (solo 127.0.0.1).
    class Server
      REASONS = { 200 => "OK", 400 => "Bad Request", 401 => "Unauthorized", 403 => "Forbidden", 404 => "Not Found",
                  405 => "Method Not Allowed", 413 => "Payload Too Large" }.freeze
      METHODS = { "/api/health" => "GET", "/api/shutdown" => "POST", "/api/ping" => "POST" }.freeze
      MAX_BODY = 65_536
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
        status, payload, method, path = handle(sock)
        body = JSON.generate(payload)
        head = { "Content-Type" => "application/json; charset=utf-8", "Content-Length" => body.bytesize.to_s,
                 "Connection" => "close" }.merge(SECURITY)
        sock.write("HTTP/1.1 #{status} #{REASONS[status]}\r\n#{head.map { |k, v| "#{k}: #{v}" }.join("\r\n")}\r\n\r\n#{body}")
        stop if method == "POST" && path == "/api/shutdown" && status == 200
      rescue StandardError
        nil
      ensure
        sock.close
      end

      def handle(sock)
        method, target, version = sock.gets.to_s.split(" ")
        return [400, error("bad_request", "Petición mal formada")] unless version.to_s.start_with?("HTTP/1.")

        headers = {}
        while (h = sock.gets) && h != "\r\n"
          k, v = h.split(":", 2)
          headers[k.downcase] = v.to_s.strip
        end
        path = target.split("?", 2).first
        return [403, error("bad_host", "Host no permitido")] unless allowed_host?(headers["host"])
        return [413, error("too_large", "Cuerpo demasiado grande")] if headers["content-length"].to_i > MAX_BODY

        sock.read(headers["content-length"].to_i)
        [*route(method, path, headers), method, path]
      end

      def allowed_host?(host)
        ["127.0.0.1:#{@port}", "localhost:#{@port}"].include?(host)
      end

      def route(method, path, headers)
        return [401, error("unauthorized", "Token inválido")] if path.start_with?("/api/") && !authorized?(headers)
        return [405, error("method_not_allowed", "Método no permitido")] if METHODS.key?(path) && METHODS[path] != method

        case path
        when "/api/health" then [200, { ok: true, data: { version: VERSION } }]
        when "/api/shutdown" then [200, { ok: true, data: {} }]
        when "/api/ping" then touch && [200, { ok: true, data: {} }]
        else [404, error("not_found", "Ruta no encontrada")]
        end
      end

      def authorized?(headers)
        given = headers["x-vdl-token"].to_s
        given.bytesize == @token.bytesize && OpenSSL.fixed_length_secure_compare(given, @token)
      end

      def error(code, message)
        { ok: false, error: { code: code, message: message } }
      end
    end
  end
end
