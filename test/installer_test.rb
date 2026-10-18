# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "digest"
require "minitest/mock"

class InstallerTest < Minitest::Test
  BYTES = "fake-ytdlp-bytes"

  # Instalador sin red: escribe bytes de prueba y un SHA2-256SUMS correcto o incorrecto.
  class FakeInstaller < VdlBtz::Installer
    attr_accessor :good_sums

    def version_of(_path, *_args)
      "test"
    end

    private

    def download(url, dest, label:)
      sum = good_sums ? Digest::SHA256.hexdigest(BYTES) : "0" * 64
      File.write(dest, url.end_with?("SHA2-256SUMS") ? "#{sum}  #{ytdlp_asset}\n" : BYTES)
    end
  end

  def with_file
    Dir.mktmpdir do |dir|
      path = File.join(dir, "f")
      File.write(path, BYTES)
      yield path, Digest::SHA256.hexdigest(BYTES)
    end
  end

  def test_verify_ok
    with_file { |path, sum| assert VdlBtz::Installer.verify_sha256!(path, "#{sum}  yt-dlp_macos\n", "yt-dlp_macos") }
  end

  def test_verify_mismatch_and_missing_asset
    with_file do |path, sum|
      bad = sum.sub(/.\z/) { |c| c == "0" ? "1" : "0" }
      e = assert_raises(VdlBtz::Error) { VdlBtz::Installer.verify_sha256!(path, "#{bad}  yt-dlp_macos\n", "yt-dlp_macos") }
      assert_includes e.message, "SHA-256"
      e = assert_raises(VdlBtz::Error) { VdlBtz::Installer.verify_sha256!(path, "#{sum}  other\n", "yt-dlp_macos") }
      assert_includes e.message, "SHA-256"
    end
  end

  def test_install_ytdlp_verifies_before_installing
    Dir.mktmpdir do |dir|
      inst = FakeInstaller.new(bin_dir: dir)
      inst.good_sums = true
      assert File.file?(inst.install_ytdlp)
    end

    Dir.mktmpdir do |dir|
      bad = FakeInstaller.new(bin_dir: dir)
      bad.good_sums = false
      assert_raises(VdlBtz::Error) { bad.install_ytdlp }
      refute File.exist?(File.join(dir, VdlBtz::OS.exe("yt-dlp")))
      assert_empty Dir.glob(File.join(dir, "*.part"))
    end
  end

  def test_write_body_reports_progress
    res = Class.new do
      def [](key)
        key == "content-length" ? "6" : nil
      end

      def read_body
        yield "abc"
        yield "def"
      end
    end.new
    seen = []
    Dir.mktmpdir do |dir|
      progress = ->(label, pct) { seen << [label, pct.round] }
      VdlBtz::Installer.new(bin_dir: dir, on_progress: progress).send(:write_body, res, File.join(dir, "x"), "x")
    end
    assert_equal [["x", 50], ["x", 100]], seen
  end

  # Instalador de Deno sin red ni descompresión real.
  class DenoInstaller < VdlBtz::Installer
    attr_accessor :good_sums

    def version_of(_path, *_args)
      "deno 9.9.9"
    end

    private

    def download(url, dest, label:)
      sum = good_sums ? Digest::SHA256.hexdigest("zip-bytes") : "0" * 64
      File.write(dest, url.end_with?(".sha256sum") ? "#{sum}  #{deno_asset}\n" : "zip-bytes")
    end

    def extract(_archive, dest)
      FileUtils.mkdir_p(File.join(dest, "x"))
      File.write(File.join(dest, "x", VdlBtz::OS.exe("deno")), "deno-bin")
    end
  end

  def test_deno_asset_names
    {
      [:mac, true] => "deno-aarch64-apple-darwin.zip", [:mac, false] => "deno-x86_64-apple-darwin.zip",
      [:linux, false] => "deno-x86_64-unknown-linux-gnu.zip", [:linux, true] => "deno-aarch64-unknown-linux-gnu.zip",
      [:windows, false] => "deno-x86_64-pc-windows-msvc.zip"
    }.each do |(os, arm), expected|
      VdlBtz::OS.stub(:windows?, os == :windows) do
        VdlBtz::OS.stub(:mac?, os == :mac) do
          VdlBtz::OS.stub(:arm?, arm) { assert_equal expected, VdlBtz::Installer.new(bin_dir: "/x").deno_asset }
        end
      end
    end
  end

  def test_install_deno_verifies_the_zip_before_installing
    Dir.mktmpdir do |dir|
      inst = DenoInstaller.new(bin_dir: dir)
      inst.good_sums = true
      path = inst.ensure_deno!
      assert_equal File.join(dir, VdlBtz::OS.exe("deno")), path
      assert_equal path, inst.deno_path
      assert File.executable?(path)
    end

    Dir.mktmpdir do |dir|
      bad = DenoInstaller.new(bin_dir: dir)
      bad.good_sums = false
      e = assert_raises(VdlBtz::Error) { bad.ensure_deno! }
      assert_includes e.message, "SHA-256"
      assert_nil bad.deno_path
      assert_nil bad.ensure_deno
    end
  end
end
