# frozen_string_literal: true

require "uri"

module VdlBtz
  # Detecta la plataforma a partir de la URL.
  module Platform
    HOSTS = {
      "youtube" => /(?:\A|\.)(?:youtube\.com|youtu\.be|youtube-nocookie\.com)\z/i,
      "tiktok" => /(?:\A|\.)tiktok\.com\z/i,
      "instagram" => /(?:\A|\.)instagram\.com\z/i,
      "facebook" => /(?:\A|\.)(?:facebook\.com|fb\.watch|fb\.com)\z/i
    }.freeze

    NAMES = {
      "youtube" => "YouTube", "tiktok" => "TikTok", "instagram" => "Instagram",
      "facebook" => "Facebook", "otros" => "Otro sitio"
    }.freeze

    module_function

    def host(url)
      uri = URI.parse(url.to_s.strip)
      return nil unless %w[http https].include?(uri.scheme) && uri.host && !uri.host.empty?

      uri.host
    rescue URI::InvalidURIError
      nil
    end

    def valid_url?(url)
      !host(url).nil?
    end

    # Devuelve "youtube", "tiktok", "instagram", "facebook", "otros" o nil si la URL no es válida.
    def detect(url)
      h = host(url)
      return nil unless h

      HOSTS.each { |key, pattern| return key if h.match?(pattern) }
      "otros"
    end

    def display_name(key)
      NAMES.fetch(key, key.to_s)
    end
  end
end
