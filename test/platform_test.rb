# frozen_string_literal: true

require "test_helper"

class PlatformTest < Minitest::Test
  def test_detects_supported_platforms
    assert_equal "youtube", VdlBtz::Platform.detect("https://www.youtube.com/watch?v=abc")
    assert_equal "youtube", VdlBtz::Platform.detect("https://youtu.be/abc")
    assert_equal "youtube", VdlBtz::Platform.detect("https://m.youtube.com/shorts/abc")
    assert_equal "tiktok", VdlBtz::Platform.detect("https://vm.tiktok.com/ZM123/")
    assert_equal "instagram", VdlBtz::Platform.detect("https://www.instagram.com/reel/xyz/")
    assert_equal "facebook", VdlBtz::Platform.detect("https://www.facebook.com/watch?v=1")
    assert_equal "facebook", VdlBtz::Platform.detect("https://fb.watch/abc/")
  end

  def test_other_sites_and_lookalikes
    assert_equal "otros", VdlBtz::Platform.detect("https://vimeo.com/123")
    assert_equal "otros", VdlBtz::Platform.detect("https://notyoutube.com/watch")
  end

  def test_invalid_urls
    assert_nil VdlBtz::Platform.detect("hola")
    assert_nil VdlBtz::Platform.detect("ftp://youtube.com/x")
    refute VdlBtz::Platform.valid_url?("youtube.com/watch?v=1")
  end

  def test_clean_url_drops_playlist_params_from_youtube_videos
    clean = "https://www.youtube.com/watch?v=6-6aVn0wwYM"
    assert_equal clean, VdlBtz::Platform.clean_url("#{clean}&list=RD6-6aVn0wwYM&start_radio=1")
    assert_equal "#{clean}&t=30s", VdlBtz::Platform.clean_url("#{clean}&list=PL123&index=2&t=30s")
    assert_equal "https://youtu.be/abc123", VdlBtz::Platform.clean_url("https://youtu.be/abc123?list=PL123")
  end

  def test_clean_url_leaves_everything_else_alone
    [ "https://www.youtube.com/watch?v=abc", "https://www.youtube.com/playlist?list=PL123", "https://vimeo.com/1?list=2",
      "https://www.tiktok.com/@u/video/1", "not-a-url" ].each { |u| assert_equal u, VdlBtz::Platform.clean_url(u) }
  end
end
