# frozen_string_literal: true

require_relative "vdl_btz/version"

module VdlBtz
  # Error controlado: se muestra al usuario sin backtrace.
  class Error < StandardError; end
end

require_relative "vdl_btz/os"
require_relative "vdl_btz/paths"
require_relative "vdl_btz/ui"
require_relative "vdl_btz/config"
require_relative "vdl_btz/platform"
require_relative "vdl_btz/hints"
require_relative "vdl_btz/installer"
require_relative "vdl_btz/downloader"
require_relative "vdl_btz/cli"
