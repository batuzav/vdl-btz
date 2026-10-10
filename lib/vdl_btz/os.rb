# frozen_string_literal: true

require "rbconfig"

module VdlBtz
  # Detección del sistema operativo y utilidades multiplataforma.
  module OS
    module_function

    def host_os
      RbConfig::CONFIG["host_os"]
    end

    def windows?
      host_os.match?(/mswin|mingw|cygwin/i)
    end

    def mac?
      host_os.match?(/darwin/i)
    end

    def linux?
      host_os.match?(/linux/i)
    end

    def arm?
      RbConfig::CONFIG["host_cpu"].match?(/arm|aarch64/i)
    end

    def name
      return "Windows" if windows?
      return "macOS" if mac?
      return "Linux" if linux?

      host_os
    end

    def arch
      RbConfig::CONFIG["host_cpu"]
    end

    # Nombre del ejecutable según el sistema ("ffmpeg" -> "ffmpeg.exe" en Windows).
    def exe(name)
      windows? ? "#{name}.exe" : name
    end

    # Busca un comando en el PATH. Devuelve la ruta completa o nil.
    def which(cmd)
      exts = windows? ? ENV.fetch("PATHEXT", ".EXE;.BAT;.CMD").split(";") : [""]
      ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).each do |dir|
        exts.each do |ext|
          path = File.join(dir, "#{cmd}#{ext}")
          return path if File.file?(path) && File.executable?(path)
        end
      end
      nil
    end
  end
end
