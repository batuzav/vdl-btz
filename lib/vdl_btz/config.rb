# frozen_string_literal: true

require "yaml"
require "fileutils"

module VdlBtz
  # Configuración persistente en ~/.vdl-btz/config.yml
  class Config
    QUALITIES = %w[best 2160 1440 1080 720 480 360].freeze
    BROWSERS = %w[chrome firefox edge safari brave opera chromium vivaldi].freeze
    KEYS = %w[output quality cookies].freeze

    attr_reader :path

    def self.load(path = Paths.config_file)
      new(path)
    end

    # Acepta "720", "720p", "4k", "BEST"... y devuelve el valor normalizado o nil si no es válido.
    def self.normalize_quality(value)
      v = value.to_s.strip.downcase
      v = "2160" if v == "4k"
      v = "1440" if v == "2k"
      v = v.delete_suffix("p")
      QUALITIES.include?(v) ? v : nil
    end

    def self.normalize_browser(value)
      v = value.to_s.strip.downcase
      BROWSERS.include?(v) ? v : nil
    end

    def initialize(path)
      @path = path
      @data = defaults.merge(read_file)
    end

    def defaults
      { "output" => Paths.default_output, "quality" => "best", "cookies" => nil }
    end

    def [](key)
      @data[key.to_s]
    end

    def to_h
      @data.dup
    end

    def set(key, value)
      key = key.to_s
      raise Error, "Clave desconocida '#{key}'. Claves válidas: #{KEYS.join(', ')}" unless KEYS.include?(key)

      @data[key] = validate(key, value)
      save
    end

    def reset
      @data = defaults
      FileUtils.rm_f(path)
    end

    private

    def validate(key, value)
      case key
      when "quality"
        Config.normalize_quality(value) ||
          raise(Error, "Calidad inválida '#{value}'. Opciones: #{QUALITIES.join(', ')}")
      when "cookies"
        return nil if %w[none ninguno no off].include?(value.to_s.downcase)

        Config.normalize_browser(value) ||
          raise(Error, "Navegador inválido '#{value}'. Opciones: #{BROWSERS.join(', ')} (o 'none')")
      when "output"
        File.expand_path(value.to_s)
      end
    end

    def read_file
      return {} unless File.exist?(path)

      data = YAML.safe_load(File.read(path)) || {}
      data.is_a?(Hash) ? data.slice(*KEYS) : {}
    rescue Psych::Exception
      {}
    end

    def save
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, YAML.dump(@data))
    end
  end
end
