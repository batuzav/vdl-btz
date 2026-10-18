# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
require "stringio"

class GuiShellTest < Minitest::Test
  Shell = VdlBtz::GUI::Shell
  URL = "http://127.0.0.1:1234/?t=abc"

  def launch(os: :mac, existing: [], found: {}, open_ok: false)
    calls = { spawn: [], open: [] }
    spawner = ->(*args, **_opts) { calls[:spawn] << args; 4242 }
    result = Shell.launch(URL, os: os, spawner: spawner, exists: ->(p) { existing.include?(p) }, which: ->(n) { found[n] },
                               opener: ->(u) { calls[:open] << u; open_ok }, profile_dir: "/p")
    [result, calls]
  end

  def test_window_args_are_literal
    assert_equal ["/x/chrome", "--app=#{URL}", "--user-data-dir=/p", "--no-first-run", "--window-size=980,780"],
                 Shell.window_args("/x/chrome", URL, "/p")
  end

  def test_mac_candidates_in_order
    assert_equal ["/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
                  "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
                  "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser",
                  "/Applications/Chromium.app/Contents/MacOS/Chromium"], Shell.candidates(:mac)
  end

  def test_windows_and_linux_candidates
    env = { "ProgramFiles" => "C:\\PF", "LOCALAPPDATA" => "C:\\LA" }
    win = Shell.candidates(:windows, env: env)
    assert_equal "C:\\PF\\Microsoft\\Edge\\Application\\msedge.exe", win.first
    assert_equal 6, win.size
    assert_includes win, "C:\\LA\\BraveSoftware\\Brave-Browser\\Application\\brave.exe"
    assert_equal "google-chrome", Shell.candidates(:linux).first
  end

  def test_launch_app_window_browser_or_manual
    chrome = Shell.candidates(:mac).first
    result, calls = launch(existing: [chrome])
    assert_equal :app_window, result
    assert_equal [Shell.window_args(chrome, URL, "/p")], calls[:spawn]

    result, calls = launch(open_ok: true)
    assert_equal [:browser, [URL], []], [result, calls[:open], calls[:spawn]]
    assert_equal :manual, launch.first

    result, calls = launch(os: :linux, found: { "chromium" => "/usr/bin/chromium" })
    assert_equal [:app_window, "/usr/bin/chromium"], [result, calls[:spawn].first.first]
  end

  def test_open_url_uses_argument_arrays
    { windows: ["cmd", "/c", "start", "", URL], mac: ["open", URL], linux: ["xdg-open", URL] }.each do |os, expected|
      seen = nil
      VdlBtz::OS.stub(:windows?, os == :windows) do
        VdlBtz::OS.stub(:mac?, os == :mac) do
          Process.stub(:spawn, ->(*args, **_o) { seen = args; 1 }) do
            Process.stub(:detach, nil) { assert VdlBtz::OS.open_url(URL) }
          end
        end
      end
      assert_equal expected, seen, os.to_s
    end
  end

  def run_cli(argv, shell)
    cli = VdlBtz::CLI.new(installer: VdlBtz::Installer.new(bin_dir: Dir.mktmpdir),
                          config: VdlBtz::Config.new(File.join(ENV["VDL_BTZ_HOME"], "shell_cfg.yml")), shell: shell)
    out = StringIO.new
    old = $stdout
    $stdout = out
    [cli.run(argv), out.string]
  ensure
    $stdout = old
  end

  def test_cli_opens_the_window_and_stops_when_idle
    urls = []
    shell = Module.new { define_singleton_method(:launch) { |u| urls << u; :manual } }
    code, out = run_cli(%w[gui --idle-timeout 1], shell)
    assert_equal 0, code
    assert_match %r{\Ahttp://127\.0\.0\.1:\d+/\?t=\h{32}\z}, urls.first
    assert_includes out, "Abre esta dirección en tu navegador: #{urls.first}"
    assert_match(/\AURL: /, out.lines.first)
  end

  def test_no_window_never_calls_the_shell
    shell = Module.new { define_singleton_method(:launch) { |_u| raise "no debe abrirse" } }
    code, = run_cli(%w[gui --no-window --idle-timeout 1], shell)
    assert_equal 0, code
  end
end
