# frozen_string_literal: true

require "test_helper"
require "open3"
require "tmpdir"
require "yaml"

class PackagingTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  MAKE_APP = File.join(ROOT, "packaging", "macos", "make_app.sh")
  BUILD_YML = File.join(ROOT, ".github", "workflows", "build.yml")

  def mac?
    RbConfig::CONFIG["host_os"].include?("darwin")
  end

  def sh(*cmd)
    out, status = Open3.capture2e(*cmd)
    [out, status]
  end

  # Binario de mentira: nunca se ejecuta Tebako en las pruebas.
  def fake_binary(dir)
    path = File.join(dir, "fake-bin")
    File.write(path, "#!/bin/sh\necho stub\n")
    File.chmod(0o755, path)
    path
  end

  def test_make_app_builds_a_signed_bundle_and_dmg
    skip "solo macOS" unless mac?
    Dir.mktmpdir do |dir|
      out = File.join(dir, "dist")
      FileUtils.mkdir_p(out)
      log, status = sh("sh", MAKE_APP, fake_binary(dir), "x64", "9.9.9", out)
      assert status.success?, log
      app = File.join(out, "vdl-btz.app", "Contents")
      assert File.file?(File.join(app, "MacOS", "vdl-btz"))
      launcher = File.join(app, "MacOS", "vdl-btz-launcher")
      assert File.executable?(launcher)
      assert_includes File.read(launcher), 'exec "$(dirname "$0")/vdl-btz" gui'

      plist = File.join(app, "Info.plist")
      assert sh("plutil", "-lint", plist).last.success?
      { "CFBundleIdentifier" => "com.batuzav.vdl-btz", "CFBundleExecutable" => "vdl-btz-launcher",
        "CFBundleShortVersionString" => "9.9.9", "LSMinimumSystemVersion" => "15.0" }.each do |key, value|
        assert_equal value, sh("plutil", "-extract", key, "raw", plist).first.strip, key
      end

      assert sh("codesign", "--verify", "--deep", "--strict", File.join(out, "vdl-btz.app")).last.success?
      assert sh("hdiutil", "verify", File.join(out, "vdl-btz-x64.dmg")).last.success?
    end
  end

  def test_make_app_without_arguments_exits_64_with_usage
    skip "no hay sh fiable en Windows" if VdlBtz::OS.windows?
    out, status = sh("sh", MAKE_APP)
    assert_equal 64, status.exitstatus
    assert_match(/Uso:/, out)
  end

  def test_workflow_packages_the_macos_app_and_uploads_the_dmg
    steps = YAML.load_file(BUILD_YML).dig("jobs", "binary", "steps")
    idx = steps.index { |s| s["run"].to_s.include?("packaging/macos/make_app.sh") }
    refute_nil idx, "falta el paso que ejecuta make_app.sh"
    assert_equal "runner.os == 'macOS'", steps[idx]["if"]
    upload = steps[(idx + 1)..].find { |s| s.dig("with", "path") == "dist/*.dmg" }
    refute_nil upload, "falta la subida de dist/*.dmg"
    assert_equal "runner.os == 'macOS'", upload["if"]
  end
end
