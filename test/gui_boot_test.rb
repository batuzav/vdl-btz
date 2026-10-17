# frozen_string_literal: true

require "test_helper"
require "open3"
require "net/http"
require "json"
require "timeout"

class GuiBootTest < Minitest::Test
  URL_LINE = %r{\AURL: http://127\.0\.0\.1:(\d+)/\?t=([0-9a-f]{32})\n\z}.freeze

  def request(klass, port, path, token)
    req = klass.new(path)
    req["X-VDL-Token"] = token if token
    Net::HTTP.start("127.0.0.1", port) { |http| http.request(req) }
  end

  def test_gui_no_window_boots_and_shuts_down
    stdin, stdout, _stderr, wait = Open3.popen3(RbConfig.ruby, "bin/vdl-btz", "gui", "--no-window")
    stdin.close
    line = Timeout.timeout(10) { stdout.gets }
    assert_match URL_LINE, line
    port, token = URL_LINE.match(line).captures
    port = port.to_i

    res = request(Net::HTTP::Get, port, "/api/health", token)
    assert_equal "200", res.code
    assert_equal VdlBtz::VERSION, JSON.parse(res.body).dig("data", "version")

    [nil, "wrong-token"].each do |bad|
      res = request(Net::HTTP::Get, port, "/api/health", bad)
      assert_equal "401", res.code
      assert_equal "unauthorized", JSON.parse(res.body).dig("error", "code")
    end

    res = request(Net::HTTP::Get, port, "/api/nope", token)
    assert_equal "404", res.code
    assert_equal "not_found", JSON.parse(res.body).dig("error", "code")

    assert_equal "200", request(Net::HTTP::Post, port, "/api/shutdown", token).code
    assert Timeout.timeout(5) { wait.value }.success?
  ensure
    Process.kill("KILL", wait.pid) if wait&.alive?
  end
end
