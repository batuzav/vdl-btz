# frozen_string_literal: true

require "test_helper"
require "net/http"
require "json"
require "open3"
require "timeout"

class GuiApiJobsTest < Minitest::Test
  TOKEN = "b" * 32
  Res = Struct.new(:ok, :file, :error, :canceled, keyword_init: true)
  FakeInstaller = Struct.new(:ytdlp_path, :ffmpeg_path, :deno_path)

  def boot(ytdlp: "/fake/yt-dlp", runner: ->(_j, _c) { Res.new(ok: true, file: "/v.mp4") })
    @queue = VdlBtz::GUI::JobQueue.new(runner: runner)
    config = VdlBtz::Config.new(File.join(ENV["VDL_BTZ_HOME"], "api_jobs_config.yml"))
    api = VdlBtz::GUI::Api.new(queue: @queue, config: config, installer: FakeInstaller.new(ytdlp, nil))
    @server = VdlBtz::GUI::Server.new(token: TOKEN, handler: api)
    @port = @server.start
  end

  def teardown
    @server&.stop
    @queue&.shutdown
  end

  def call(verb, path, body = nil)
    req = Net::HTTP.const_get(verb.capitalize).new(path)
    req["X-VDL-Token"] = TOKEN
    req.body = body.is_a?(String) ? body : JSON.generate(body) if body
    res = Net::HTTP.start("127.0.0.1", @port) { |http| http.request(req) }
    [res.code.to_i, JSON.parse(res.body)]
  end

  def test_state_has_the_documented_keys
    boot
    code, json = call(:get, "/api/state")
    assert_equal 200, code
    assert_equal %w[browsers config os qualities setup version], json["data"].keys.sort
    assert_equal %w[deno error ffmpeg label percent running ytdlp], json["data"]["setup"].keys.sort
  end

  def test_create_list_and_cancel_jobs
    boot
    code, json = call(:post, "/api/jobs", urls: ["https://youtu.be/abc123"], audio: false, quality: "720")
    assert_equal 202, code
    jobs = json["data"]["jobs"]
    assert_equal 1, jobs.size
    assert_includes %w[queued running done], jobs.first["status"]
    assert_equal 200, call(:get, "/api/jobs").first
    assert_equal 200, call(:post, "/api/jobs/#{jobs.first['id']}/cancel").first
    code, json = call(:post, "/api/jobs/deadbeef/cancel")
    assert_equal [404, "not_found"], [code, json.dig("error", "code")]
  end

  def test_validation_errors
    boot
    {
      "bad_json" => ["not json", 400], "no_urls" => [{ urls: [] }, 400],
      "invalid_url" => [{ urls: ["nope"] }, 400], "invalid_quality" => [{ urls: ["https://youtu.be/a"], quality: "999" }, 400]
    }.each do |expected, (body, status)|
      code, json = call(:post, "/api/jobs", body)
      assert_equal [status, expected], [code, json.dig("error", "code")]
    end
    assert_equal "no_urls", call(:post, "/api/jobs", urls: Array.new(21) { "https://youtu.be/a" }).last.dig("error", "code")
    assert_empty @queue.list
  end

  def test_setup_required_when_ytdlp_missing
    boot(ytdlp: nil)
    code, json = call(:post, "/api/jobs", urls: ["https://youtu.be/a"])
    assert_equal [409, "setup_required"], [code, json.dig("error", "code")]
    assert_empty @queue.list
  end

  def test_gui_process_serves_empty_jobs
    _in, out, _err, wait = Open3.popen3(RbConfig.ruby, "bin/vdl-btz", "gui", "--no-window")
    port, token = Timeout.timeout(10) { out.gets }.match(%r{:(\d+)/\?t=(\h{32})}).captures
    res = Net::HTTP.start("127.0.0.1", port.to_i) do |http|
      req = Net::HTTP::Get.new("/api/jobs")
      req["X-VDL-Token"] = token
      http.request(req)
    end
    assert_equal "200", res.code
    assert_equal [], JSON.parse(res.body).dig("data", "jobs")
    Net::HTTP.start("127.0.0.1", port.to_i) do |http|
      req = Net::HTTP::Post.new("/api/shutdown")
      req["X-VDL-Token"] = token
      http.request(req)
    end
    assert Timeout.timeout(5) { wait.value }.success?
  ensure
    Process.kill("KILL", wait.pid) if wait&.alive?
  end
end
