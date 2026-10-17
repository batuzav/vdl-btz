# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "timeout"

class DownloaderTest < Minitest::Test
  URL = "https://youtu.be/abc"

  def args_for(ffmpeg: "/bin/ffmpeg", **opts)
    VdlBtz::Downloader.new(ytdlp: "yt-dlp", ffmpeg: ffmpeg, output: "/tmp/out", **opts).build_args(URL)
  end

  def value_after(args, flag)
    args[args.index(flag) + 1]
  end

  def test_best_quality_merges_with_ffmpeg
    args = args_for
    assert_equal "bv*+ba/b", value_after(args, "-f")
    assert_equal "res,ext:mp4:m4a", value_after(args, "-S")
    assert_equal "mp4", value_after(args, "--merge-output-format")
    assert_equal "/bin/ffmpeg", value_after(args, "--ffmpeg-location")
    assert_equal ["--", URL], args.last(2)
  end

  def test_limited_quality
    assert_equal "res:720,ext:mp4:m4a", value_after(args_for(quality: "720"), "-S")
  end

  def test_without_ffmpeg_uses_single_file
    args = args_for(ffmpeg: nil)
    assert_equal "b", value_after(args, "-f")
    refute_includes args, "--merge-output-format"
    refute_includes args, "--ffmpeg-location"
  end

  def test_audio_mp3
    args = args_for(audio: true)
    assert_includes args, "-x"
    assert_equal "mp3", value_after(args, "--audio-format")
  end

  def test_output_folder_by_platform
    expected = File.join(File.expand_path("/tmp/out"), "youtube", "%(title).80B [%(id)s].%(ext)s")
    assert_equal expected, value_after(args_for, "-o")
  end

  def test_cookies_and_playlist
    args = args_for(cookies: "chrome", playlist: true)
    assert_equal "chrome", value_after(args, "--cookies-from-browser")
    assert_includes args, "--yes-playlist"
    assert_includes args_for, "--no-playlist"
  end

  def test_cancel_terminates_the_child_process
    skip "POSIX only" if VdlBtz::OS.windows?
    Dir.mktmpdir do |dir|
      fake = File.join(dir, "fake-ytdlp")
      File.write(fake, "#!/bin/sh\nexec sleep 30\n")
      File.chmod(0o755, fake)
      d = VdlBtz::Downloader.new(ytdlp: fake, output: dir)
      result = nil
      th = Thread.new { result = d.download(URL) }
      Timeout.timeout(5) { sleep 0.05 until d.pid }
      pid = d.pid
      d.cancel!
      assert th.join(5), "download did not return after cancel!"
      refute result.ok
      assert result.canceled
      assert_equal "Cancelado", result.error
      assert_raises(Errno::ESRCH) { Process.kill(0, pid) }
    end
  end

  def test_cancel_without_download_and_default_canceled
    d = VdlBtz::Downloader.new(ytdlp: "yt-dlp", output: "/tmp/out")
    assert_nil d.cancel!
    assert_nil VdlBtz::Downloader::Result.new(url: "u", ok: true).canceled
  end
end
