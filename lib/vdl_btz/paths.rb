# frozen_string_literal: true

module VdlBtz
  # Rutas donde vdl-btz guarda sus binarios y configuración.
  # Se puede cambiar la carpeta base con la variable de entorno VDL_BTZ_HOME.
  module Paths
    module_function

    def home
      ENV["VDL_BTZ_HOME"] || File.join(Dir.home, ".vdl-btz")
    end

    def bin_dir
      File.join(home, "bin")
    end

    def config_file
      File.join(home, "config.yml")
    end

    # Marca que indica que la instalación automática de ffmpeg ya falló una vez,
    # para no reintentarla en cada descarga (se reintenta con `vdl-btz setup`).
    def ffmpeg_skip_file
      File.join(home, ".ffmpeg_skipped")
    end

    def default_output
      File.join(Dir.home, "Downloads", "vdl-btz")
    end
  end
end
