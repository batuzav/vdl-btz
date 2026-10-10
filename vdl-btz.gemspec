# frozen_string_literal: true

require_relative "lib/vdl_btz/version"

Gem::Specification.new do |spec|
  spec.name = "vdl-btz"
  spec.version = VdlBtz::VERSION
  spec.authors = ["batuzav"]
  spec.summary = "CLI sencilla para descargar videos de TikTok, YouTube, Instagram y Facebook"
  spec.description = "vdl-btz es una herramienta de línea de comandos multiplataforma (macOS, Linux, Windows) " \
                     "que descarga videos y audio usando yt-dlp, instalando sus dependencias automáticamente."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7"

  spec.files = Dir["lib/**/*.rb", "bin/*", "README.md", "LICENSE"]
  spec.bindir = "bin"
  spec.executables = ["vdl-btz"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "minitest", ">= 5.0"
  spec.add_development_dependency "rake", ">= 13.0"
end
