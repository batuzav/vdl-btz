# frozen_string_literal: true

require "test_helper"
require "open3"

# El plano tiene una fuente única (blueprints/source/*/steps.yml): sus vistas no pueden desfasarse.
class BlueprintSyncTest < Minitest::Test
  SYNC = File.expand_path("../blueprints/source/sync.rb", __dir__)
  SOURCES = Dir[File.expand_path("../blueprints/source/*/steps.yml", __dir__)]

  def test_every_blueprint_view_matches_its_single_source
    skip "no hay plano en este checkout" unless File.file?(SYNC) && !SOURCES.empty?
    SOURCES.each do |src|
      slug = File.basename(File.dirname(src))
      out, status = Open3.capture2e(RbConfig.ruby, SYNC, slug, "--check")
      assert status.success?, "El plano #{slug} se desfasó de su fuente única:\n#{out}"
    end
  end
end
