# frozen_string_literal: true

require "tmpdir"
Encoding.default_external = Encoding::UTF_8 # README y assets son UTF-8 aunque el sistema (CI, Windows) no tenga locale UTF-8
ENV["VDL_BTZ_HOME"] = Dir.mktmpdir("vdl-btz-test")
ENV["HOME"] = ENV["VDL_BTZ_HOME"] # Dir.home y la carpeta de descargas por defecto quedan dentro del directorio temporal
ENV["NO_COLOR"] = "1"

require "minitest/autorun"
require "vdl_btz"
