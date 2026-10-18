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
      assert File.file?(File.join(app, "Resources", "vdl-btz"))
      launcher = File.join(app, "MacOS", "vdl-btz-launcher")
      assert File.executable?(launcher)
      assert_includes File.read(launcher), 'exec "$(dirname "$0")/../Resources/vdl-btz" gui'

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

  LINUX = File.join(ROOT, "packaging", "linux")
  MAKE_APPIMAGE = File.join(LINUX, "make_appimage.sh")

  def test_appimage_appdir_has_the_expected_layout
    skip "no hay sh fiable en Windows" if VdlBtz::OS.windows?
    Dir.mktmpdir do |dir|
      log, status = sh("sh", MAKE_APPIMAGE, fake_binary(dir), "x86_64", dir, "--appdir-only")
      assert status.success?, log
      appdir = File.join(dir, "vdl-btz.AppDir")
      assert File.file?(File.join(appdir, "usr", "bin", "vdl-btz"))
      assert File.file?(File.join(appdir, "vdl-btz.desktop"))
      assert File.file?(File.join(appdir, "vdl-btz.svg"))
      app_run = File.join(appdir, "AppRun")
      assert File.executable?(app_run)
      assert_includes File.read(app_run), 'exec "$HERE/usr/bin/vdl-btz" gui'
    end
  end

  def test_desktop_entry_and_icon
    desktop = File.read(File.join(LINUX, "vdl-btz.desktop"))
    ["Type=Application", "Name=vdl-btz", "Exec=vdl-btz gui", "Icon=vdl-btz", "Terminal=false", "Categories=Network;Utility;"].each do |line|
      assert_includes desktop.lines.map(&:chomp), line
    end
    svg = File.read(File.join(LINUX, "vdl-btz.svg"))
    assert svg.start_with?("<svg")
    assert_includes svg, 'xmlns="http://www.w3.org/2000/svg"'
  end

  def test_appimage_without_appimagetool_exits_2_and_without_arguments_64
    skip "no hay sh fiable en Windows" if VdlBtz::OS.windows?
    Dir.mktmpdir do |dir|
      out, status = Open3.capture2e({ "PATH" => "/usr/bin:/bin" }, "/bin/sh", MAKE_APPIMAGE, fake_binary(dir), "x86_64", dir)
      assert_equal 2, status.exitstatus
      assert_includes out, "appimagetool no encontrado"
    end
    assert_equal 64, sh("sh", MAKE_APPIMAGE).last.exitstatus
  end

  def test_workflow_packages_the_linux_appimage
    steps = YAML.load_file(BUILD_YML).dig("jobs", "binary", "steps")
    idx = steps.index { |s| s["run"].to_s.include?("packaging/linux/make_appimage.sh") }
    refute_nil idx, "falta el paso que ejecuta make_appimage.sh"
    assert_equal "runner.os == 'Linux'", steps[idx]["if"]
    upload = steps[(idx + 1)..].find { |s| s.dig("with", "path") == "dist/*.AppImage" }
    refute_nil upload, "falta la subida de dist/*.AppImage"
  end

  WINDOWS = File.join(ROOT, "packaging", "windows")

  def test_windows_launcher_runs_the_exe_hidden_without_waiting
    vbs = File.read(File.join(WINDOWS, "vdl-btz-launcher.vbs"))
    ["Run", 'vdl-btz.exe"" gui', ", 0, False"].each { |frag| assert_includes vbs, frag }
  end

  def test_windows_installer_script
    iss = File.read(File.join(WINDOWS, "vdl-btz.iss"))
    ["AppName=vdl-btz", "PrivilegesRequired=lowest", "OutputBaseFilename=vdl-btz-windows-x64-setup", "{sys}\\wscript.exe",
     "vdl-btz-launcher.vbs", "vdl-btz.exe"].each { |frag| assert_includes iss, frag }
  end

  def test_workflow_matrix_has_experimental_windows_and_guards_generic_steps
    binary = YAML.load_file(BUILD_YML).dig("jobs", "binary")
    include = binary.dig("strategy", "matrix", "include")
    assert_equal %w[macos-15 macos-15-intel ubuntu-24.04 windows-latest], include.map { |e| e["os"] }
    assert_equal true, include.find { |e| e["os"] == "windows-latest" }["experimental"]
    assert binary.key?("continue-on-error")
    steps = binary["steps"]
    named = ->(n) { steps.find { |s| s["name"] == n } }
    ["Preparar entorno de Tebako", "Empaquetar con Tebako", "Prueba rápida del binario"].each do |n|
      assert_equal "runner.os != 'Windows'", named.(n)["if"], n
    end
    assert_equal "bash", named.("Preparar carpeta de empaquetado")["shell"]
  end

  def test_workflow_windows_steps
    steps = YAML.load_file(BUILD_YML).dig("jobs", "binary", "steps")
    windows = steps.select { |s| s["if"] == "runner.os == 'Windows'" }
    runs = windows.map { |s| s["run"].to_s }.join("\n")
    assert_includes runs, "ridk enable ucrt64"
    assert_match(/tebako press .*--output=vdl-btz-windows-x64\.exe/, runs)
    assert_includes runs, "ISCC.exe"
    assert_includes runs, "packaging\\windows\\vdl-btz.iss"
    assert windows.any? { |s| s.dig("with", "path") == "dist/vdl-btz-windows-x64-setup.exe" }
  end
end
