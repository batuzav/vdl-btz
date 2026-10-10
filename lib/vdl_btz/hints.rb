# frozen_string_literal: true

module VdlBtz
  # Traduce errores de yt-dlp a sugerencias en español.
  module Hints
    RULES = [
      [/could not copy .*cookie|failed to decrypt|cookie database/i,
       "No se pudieron leer las cookies. Cierra el navegador por completo y vuelve a intentarlo."],
      [/sign in to confirm|not a bot/i,
       "YouTube pide verificar que no eres un bot. Prueba con: vdl-btz URL --cookies chrome"],
      [/private|login required|log in|logged-in|requires authentication|use --cookies|cookies/i,
       "Este contenido requiere iniciar sesión. Abre la red social en tu navegador y usa: --cookies chrome (o firefox, edge, safari...)"],
      [/unsupported url/i,
       "Este enlace no es compatible. Verifica que sea el enlace directo al video."],
      [/429|too many requests|rate.?limit/i,
       "La plataforma limitó las descargas temporalmente. Espera unos minutos y reintenta."],
      [/404|not available|unavailable|removed|does not exist|no video/i,
       "El video no existe, fue eliminado o no está disponible en tu país."],
      [/ffmpeg|ffprobe/i,
       "Falta ffmpeg o está dañado. Ejecuta: vdl-btz setup"],
      [/unable to download|unable to extract|http error|timed out|connection/i,
       "Revisa tu conexión. Si sigue fallando, actualiza con: vdl-btz update"]
    ].freeze

    DEFAULT = "Si el problema persiste, actualiza el motor de descarga con: vdl-btz update"

    module_function

    def for(message)
      RULES.each { |pattern, hint| return hint if message.to_s.match?(pattern) }
      DEFAULT
    end
  end
end
