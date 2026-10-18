# frozen_string_literal: true

require "test_helper"
require "net/http"
require "json"
require "digest"

class GuiAssetsTest < Minitest::Test
  TOKEN = "d" * 32
  IDS = %w[masthead dateline theme-toggle setup setup-label setup-progress form-add urls mode-video mode-audio quality
           btn-add msg jobs empty cfg-output cfg-quality cfg-cookies btn-save-config btn-update-engine legal].freeze
  FONT_SHA = {
    "hanken-grotesk-var.woff2" => "1f21c6eaa0000f3329cfcfac966b43d5bebf5aa610303e33294ac31bc6f4bb59",
    "space-mono-400.woff2" => "e0c8e616bda27642f4c3cebaecff6525d901e73afc8a227cbbb0f2af4810f300",
    "space-mono-700.woff2" => "af7cf6d2b897ec453acdcdacde4e9bcc8410718af5914de865b453e09f10eebc"
  }.freeze

  def setup
    @server = VdlBtz::GUI::Server.new(token: TOKEN)
    @port = @server.start
  end

  def teardown
    @server.stop
  end

  def get(path)
    Net::HTTP.start("127.0.0.1", @port) { |http| http.request(Net::HTTP::Get.new(path)) }
  end

  def test_page_needs_the_token_and_embeds_it
    res = get("/?t=#{TOKEN}")
    assert_equal "200", res.code
    assert_equal "text/html; charset=utf-8", res["Content-Type"]
    assert_includes res.body, %(<meta name="vdl-token" content="#{TOKEN}">)
    ["/", "/?t=wrong"].each do |path|
      bad = get(path)
      assert_equal "401", bad.code
      assert_equal "unauthorized", JSON.parse(bad.body).dig("error", "code")
    end
  end

  def test_html_has_every_dom_id_and_nothing_inline
    html = get("/?t=#{TOKEN}").body
    IDS.each { |id| assert_match(/\sid="#{Regexp.escape(id)}"/, html, "missing id #{id}") }
    refute_match(/<script(?![^>]*\ssrc=)[^>]*>/, html)
    refute_match(/<script[^>]*src=[^>]*>\s*[^<\s]/, html)
    refute_match(/\sstyle=/, html)
  end

  def test_css_carries_the_design_tokens
    res = get("/assets/app.css")
    assert_equal ["200", "text/css; charset=utf-8"], [res.code, res["Content-Type"]]
    ["--paper:#ece9e1", "--ink:#000000", "--paper:#0c0b09", "--ink:#ede8db", "prefers-color-scheme", "Hanken Grotesk",
     "Space Mono"].each { |lit| assert_includes res.body, lit }
  end

  def test_fonts_are_served_byte_exact
    FONT_SHA.each do |name, sha|
      res = get("/assets/fonts/#{name}")
      assert_equal ["200", "font/woff2"], [res.code, res["Content-Type"]]
      assert_equal sha, Digest::SHA256.hexdigest(res.body)
    end
  end

  def test_paths_outside_the_allowlist_are_not_found
    ["/assets/unknown.js", "/assets/../server.rb", "/assets/fonts/../../server.rb"].each do |path|
      res = get(path)
      assert_equal "404", res.code, path
      assert_equal "not_found", JSON.parse(res.body).dig("error", "code")
    end
  end

  def test_gemspec_ships_the_assets
    files = Gem::Specification.load(File.expand_path("../vdl-btz.gemspec", __dir__)).files
    %w[index.html app.css fonts/hanken-grotesk-var.woff2 fonts/space-mono-400.woff2 fonts/space-mono-700.woff2].each do |f|
      assert_includes files, "lib/vdl_btz/gui/assets/#{f}"
    end
  end

  APP_JS = File.expand_path("../lib/vdl_btz/gui/assets/app.js", __dir__)
  APP_HTML = File.expand_path("../lib/vdl_btz/gui/assets/index.html", __dir__)

  def test_app_js_has_none_of_the_forbidden_constructs
    js = File.read(APP_JS)
    %w[innerHTML outerHTML insertAdjacentHTML eval( document.write].each { |bad| refute_includes js, bad }
  end

  def test_app_js_only_uses_ids_that_exist_in_the_page
    js = File.read(APP_JS)
    html = File.read(APP_HTML)
    ids = js.scan(/getElementById\("([^"]+)"\)/).flatten
    refute_empty ids
    ids.each { |id| assert_includes html, %(id="#{id}"), "app.js uses unknown id #{id}" }
  end

  def test_app_js_talks_to_every_documented_route
    js = File.read(APP_JS)
    %w[/api/ping /api/state /api/jobs /api/setup /api/config /api/engine/update /api/open X-VDL-Token].each do |s|
      assert_includes js, s
    end
  end

  def test_app_js_is_served
    res = get("/assets/app.js")
    assert_equal ["200", "text/javascript; charset=utf-8"], [res.code, res["Content-Type"]]
  end

  def test_app_js_syntax_when_node_is_available
    skip "node no está instalado" unless system("node --version", out: File::NULL, err: File::NULL)
    assert system("node", "--check", APP_JS), "node --check failed"
  end
end
