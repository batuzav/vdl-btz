# frozen_string_literal: true

require "tmpdir"
ENV["VDL_BTZ_HOME"] = Dir.mktmpdir("vdl-btz-test")
ENV["NO_COLOR"] = "1"

require "minitest/autorun"
require "vdl_btz"
