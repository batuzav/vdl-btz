# frozen_string_literal: true

require "test_helper"
require "net/http"
require "json"
require "open3"
require "timeout"

class GuiServerTest < Minitest::Test
  TOKEN = "a" * 32

  def setup
    @server = VdlBtz::GUI::Server.new(token: TOKEN)
    @port = @server.start
  end

  def teardown
    @server.stop
  end

  def call(klass, path, token: TOKEN, host: nil, port: @port)
    req = klass.new(path)
    req["X-VDL-Token"] = token if token
    req["Host"] = host if host
    Net::HTTP.start("127.0.0.1", port) { |http| http.request(req) }
  end

  def raw(text)
    TCPSocket.open("127.0.0.1", @port) do |s|
      s.write(text)
      s.read
    end
  end

  def test_foreign_host_is_forbidden
    res = call(Net::HTTP::Get, "/api/health", host: "evil.example")
    assert_equal "403", res.code
    assert_equal "bad_host", JSON.parse(res.body).dig("error", "code")
  end

  def test_oversized_body_is_rejected
    out = raw("POST /api/ping HTTP/1.1\r\nHost: 127.0.0.1:#{@port}\r\nX-VDL-Token: #{TOKEN}\r\nContent-Length: 70000\r\n\r\n")
    assert_match(%r{\AHTTP/1\.1 413 }, out)
    assert_includes out, "too_large"
  end

  def test_malformed_request_line_and_method_not_allowed
    assert_match(%r{\AHTTP/1\.1 400 }, raw("GARBAGE\r\n\r\n"))
    res = call(Net::HTTP::Post, "/api/health")
    assert_equal "405", res.code
    assert_equal "method_not_allowed", JSON.parse(res.body).dig("error", "code")
  end

  def test_security_headers_on_every_response
    [call(Net::HTTP::Get, "/api/health"), call(Net::HTTP::Get, "/api/nope"), call(Net::HTTP::Get, "/api/health", token: nil)].each do |res|
      assert_equal "no-store", res["Cache-Control"]
      assert_equal "nosniff", res["X-Content-Type-Options"]
      assert_equal "no-referrer", res["Referrer-Policy"]
      assert_equal "default-src 'self'; img-src 'self' data:; frame-ancestors 'none'", res["Content-Security-Policy"]
    end
  end

  def test_idle_timeout_stops_the_server_and_ping_keeps_it_alive
    server = VdlBtz::GUI::Server.new(token: TOKEN, idle_timeout: 1)
    port = server.start
    5.times do
      sleep 0.4
      assert_equal "200", call(Net::HTTP::Post, "/api/ping", port: port).code
    end
    Timeout.timeout(4) { server.join }
  end

  def test_gui_process_exits_by_itself_after_idle_timeout
    _in, out, _err, wait = Open3.popen3(RbConfig.ruby, "bin/vdl-btz", "gui", "--no-window", "--idle-timeout", "2")
    assert_match(/\AURL: /, Timeout.timeout(10) { out.gets })
    assert Timeout.timeout(6) { wait.value }.success?
  ensure
    Process.kill("KILL", wait.pid) if wait&.alive?
  end
end
