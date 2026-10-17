# frozen_string_literal: true

require "socket"
require "json"
require "securerandom"
require "openssl"

module VdlBtz
  module GUI
    # Servidor HTTP local mínimo (solo 127.0.0.1).
    class Server
      REASONS = { 200 => "OK", 401 => "Unauthorized", 404 => "Not Found" }.freeze

      def initialize(token:, handler: nil, port: 0)
        @token = token
        @handler = handler
        @port = port
      end

      def start
        @tcp = TCPServer.new("127.0.0.1", @port)
        @thread = Thread.new { accept_loop }
        @tcp.addr[1]
      end

      def stop
        @tcp&.close
      end

      def join
        @thread&.join
      end

      private

      def accept_loop
        loop { Thread.new(@tcp.accept) { |sock| serve(sock) } }
      rescue IOError, Errno::EBADF
        nil
      end

      def serve(sock)
        line = sock.gets or return
        method, target = line.split(" ")
        headers = {}
        while (h = sock.gets) && h != "\r\n"
          k, v = h.split(":", 2)
          headers[k.downcase] = v.to_s.strip
        end
        sock.read(headers["content-length"].to_i)
        path = target.to_s.split("?", 2).first
        status, payload = route(method, path, headers)
        body = JSON.generate(payload)
        sock.write("HTTP/1.1 #{status} #{REASONS[status]}\r\nContent-Type: application/json; charset=utf-8\r\n" \
                   "Content-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}")
        stop if method == "POST" && path == "/api/shutdown" && status == 200
      rescue StandardError
        nil
      ensure
        sock.close
      end

      def route(method, path, headers)
        return [401, error("unauthorized", "Token inválido")] if path.start_with?("/api/") && !authorized?(headers)

        case [method, path]
        when ["GET", "/api/health"] then [200, { ok: true, data: { version: VERSION } }]
        when ["POST", "/api/shutdown"] then [200, { ok: true, data: {} }]
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
