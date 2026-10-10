# frozen_string_literal: true

require "test_helper"
require "stringio"

class CLITest < Minitest::Test
  def setup
    @config = VdlBtz::Config.new(File.join(ENV["VDL_BTZ_HOME"], "cli_config.yml"))
    @cli = VdlBtz::CLI.new(installer: VdlBtz::Installer.new, config: @config)
  end

  def capture
    old = $stdout
    $stdout = StringIO.new
    code = yield
    [code, $stdout.string]
  ensure
    $stdout = old
  end

  def test_parses_options
    opts = @cli.parse_download_options(%w[https://youtu.be/a -q 720p -a -c Chrome -o /tmp/x -p])
    assert_equal ["https://youtu.be/a"], opts[:urls]
    assert_equal "720", opts[:quality]
    assert opts[:audio]
    assert opts[:playlist]
    assert_equal "chrome", opts[:cookies]
    assert_equal "/tmp/x", opts[:output]
  end

  def test_reads_urls_from_file
    path = File.join(ENV["VDL_BTZ_HOME"], "lista.txt")
    File.write(path, "# comentario\nhttps://youtu.be/a\n\nhttps://youtu.be/b\nhttps://youtu.be/a\n")
    assert_equal %w[https://youtu.be/a https://youtu.be/b], @cli.parse_download_options(["-f", path])[:urls]
  end

  def test_invalid_quality_returns_error
    code, out = capture { @cli.run(%w[https://youtu.be/a -q 999]) }
    assert_equal 1, code
    assert_match(/Calidad inválida/, out)
  end

  def test_no_urls_returns_error
    code, out = capture { @cli.run(%w[-a]) }
    assert_equal 1, code
    assert_match(/No indicaste ninguna URL/, out)
  end

  def test_help_and_version
    assert_equal 0, capture { @cli.run([]) }.first
    assert_match(/vdl-btz #{VdlBtz::VERSION}/, capture { @cli.run(["--version"]) }.last)
  end

  def test_config_set_and_reset
    capture { @cli.run(%w[config set quality 4k]) }
    assert_equal "2160", VdlBtz::Config.new(@config.path)["quality"]
    code, = capture { @cli.run(%w[config set color azul]) }
    assert_equal 1, code
    capture { @cli.run(%w[config reset]) }
    assert_equal "best", VdlBtz::Config.new(@config.path)["quality"]
  end

  def test_hints
    assert_match(/cookies/, VdlBtz::Hints.for("This video is private"))
    assert_match(/no es compatible/, VdlBtz::Hints.for("Unsupported URL: https://x"))
  end
end
