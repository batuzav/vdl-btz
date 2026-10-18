# frozen_string_literal: true

module VdlBtz
  module GUI
    # Abre la pantalla: ventana de aplicación de un navegador Chromium, o el navegador por defecto, o solo la URL.
    # Todo lo que toca el sistema entra por parámetros para poder probarlo sin abrir nada.
    module Shell
      module_function

      def window_args(exe, url, profile_dir)
        [exe, "--app=#{url}", "--user-data-dir=#{profile_dir}", "--no-first-run", "--window-size=980,780"]
      end

      def candidates(os, env: ENV)
        case os
        when :mac
          ["Google Chrome", "Microsoft Edge", "Brave Browser", "Chromium"].map { |n| "/Applications/#{n}.app/Contents/MacOS/#{n}" }
        when :windows
          bases = [env["ProgramFiles"], env["ProgramFiles(x86)"], env["LOCALAPPDATA"]].compact
          bases.flat_map do |b|
            ["#{b}\\Microsoft\\Edge\\Application\\msedge.exe", "#{b}\\Google\\Chrome\\Application\\chrome.exe",
             "#{b}\\BraveSoftware\\Brave-Browser\\Application\\brave.exe"]
          end
        else
          %w[google-chrome google-chrome-stable chromium chromium-browser microsoft-edge brave-browser]
        end
      end

      def current_os
        OS.windows? ? :windows : (OS.mac? ? :mac : :linux)
      end

      # Devuelve :app_window, :browser o :manual (no se pudo abrir nada).
      def launch(url, os: current_os, spawner: Process.method(:spawn), exists: File.method(:file?),
                 which: OS.method(:which), opener: OS.method(:open_url), profile_dir: File.join(Paths.home, "gui-profile"))
        exe = candidates(os).filter_map { |c| os == :linux ? which.call(c) : (c if exists.call(c)) }.first
        if exe
          pid = spawner.call(*window_args(exe, url, profile_dir), out: File::NULL, err: File::NULL)
          Process.detach(pid) if pid.is_a?(Integer)
          :app_window
        elsif opener.call(url)
          :browser
        else
          :manual
        end
      end
    end
  end
end
