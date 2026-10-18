# frozen_string_literal: true

require "tmpdir"
ENV["VDL_BTZ_HOME"] = Dir.mktmpdir("vdl-btz-test")
ENV["HOME"] = ENV["VDL_BTZ_HOME"] # Dir.home y la carpeta de descargas por defecto quedan dentro del directorio temporal
ENV["NO_COLOR"] = "1"

require "minitest/autorun"
require "vdl_btz"
