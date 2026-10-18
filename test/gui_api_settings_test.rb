# frozen_string_literal: true

require "test_helper"
require "net/http"
require "json"
require "yaml"
require "timeout"
require "tmpdir"

class GuiApiSettingsTest < Minitest::Test
  TOKEN = "c" * 32

  # Instalador de mentira: mismos métodos públicos que Installer, sin red.
  class FakeInstaller
    attr_accessor :on_progress, :fail_with
    attr_reader :calls

    def initialize
      @calls = []
      @ytdlp = false
    end

    def ytdlp_path
      @ytdlp ? "/fake/yt-dlp" : nil
    end

    def ffmpeg_path
      nil
    end

    def ensure_ytdlp!
      @calls << :ensure_ytdlp
      @on_progress&.call("yt-dlp", 40)
      raise "sin red" if fail_with

      @ytdlp = true
    end

    def ensure_ffmpeg
      @calls << :ensure_ffmpeg
      true
    end

    def install_ytdlp
      @calls << :install_ytdlp
      @ytdlp = true
    end
  end

  def setup
    FileUtils.rm_f(VdlBtz::Paths.config_file)
    @opened = []
    @installer = FakeInstaller.new
    @queue = VdlBtz::GUI::JobQueue.new(runner: ->(_j, _c) { Struct.new(:ok, :file, :error, :canceled).new(true, "/tmp/vdl/a.mp4") })
    api = VdlBtz::GUI::Api.new(queue: @queue, config: VdlBtz::Config.load, installer: @installer, opener: ->(p) { @opened << p })
    @server = VdlBtz::GUI::Server.new(token: TOKEN, handler: api)
    @port = @server.start
  end

  def teardown
    @server.stop
    @queue.shutdown
  end

  def call(verb, path, body = nil)
    req = Net::HTTP.const_get(verb.capitalize).new(path)
    req["X-VDL-Token"] = TOKEN
    req.body = JSON.generate(body) if body
    res = Net::HTTP.start("127.0.0.1", @port) { |http| http.request(req) }
    [res.code.to_i, JSON.parse(res.body)]
  end

  def wait_setup_done
    Timeout.timeout(5) { sleep 0.02 while call(:get, "/api/state").last.dig("data", "setup", "running") }
  end

  def test_home_is_isolated_in_tests
    assert_equal ENV["VDL_BTZ_HOME"], Dir.home
  end

  def test_config_is_written_to_disk
    code, json = call(:post, "/api/config", output: "/tmp/vdl-x", quality: "720", cookies: "chrome")
    assert_equal 200, code
    assert_equal "720", json.dig("data", "config", "quality")
    saved = YAML.safe_load(File.read(VdlBtz::Paths.config_file))
    assert_equal({ "output" => File.expand_path("/tmp/vdl-x"), "quality" => "720", "cookies" => "chrome" }, saved)
  end

  def test_invalid_config_leaves_file_unchanged
    call(:post, "/api/config", quality: "480")
    before = File.read(VdlBtz::Paths.config_file)
    [{ quality: "999" }, { cookies: "netscape" }, { quality: "720", cookies: "netscape" }].each do |bad|
      code, json = call(:post, "/api/config", bad)
      assert_equal [400, "invalid_config"], [code, json.dig("error", "code")]
      assert_equal before, File.read(VdlBtz::Paths.config_file)
    end
  end

  def test_setup_runs_in_background_and_reports_progress
    code, = call(:post, "/api/setup")
    assert_equal 202, code
    wait_setup_done
    state = call(:get, "/api/state").last.dig("data", "setup")
    assert_equal [true, false, nil], [state["ytdlp"], state["running"], state["error"]]
    assert_equal %i[ensure_ytdlp ensure_ffmpeg], @installer.calls
  end

  def test_setup_error_is_reported
    @installer.fail_with = true
    call(:post, "/api/setup")
    wait_setup_done
    assert_equal "sin red", call(:get, "/api/state").last.dig("data", "setup", "error")
  end

  def test_second_install_while_running_is_rejected
    gate = Queue.new
    @installer.define_singleton_method(:install_ytdlp) { gate.pop }
    assert_equal 202, call(:post, "/api/engine/update").first
    code, json = call(:post, "/api/setup")
    assert_equal [409, "already_running"], [code, json.dig("error", "code")]
    gate << 1
    wait_setup_done
  end

  def test_engine_update_runs_install_ytdlp
    assert_equal 202, call(:post, "/api/engine/update").first
    wait_setup_done
    assert_equal [:install_ytdlp], @installer.calls
  end

  def test_open_folder
    Dir.mktmpdir do |out|
      out = File.join(out, "nested", "vdl")
      assert_equal 200, call(:post, "/api/config", output: out).first
      job = @queue.add(["https://youtu.be/a"], audio: false, quality: "best").first
      Timeout.timeout(5) { sleep 0.02 until @queue.list.first[:status] == "done" }
      assert_equal 200, call(:post, "/api/open", id: job.id).first
      assert_equal ["/tmp/vdl"], @opened
      code, json = call(:post, "/api/open", id: "nope")
      assert_equal [404, "no_file"], [code, json.dig("error", "code")]
      assert_equal 200, call(:post, "/api/open", {}).first
      assert_equal File.expand_path(out), @opened.last
      assert File.directory?(@opened.last)
    end
  end
end
