# frozen_string_literal: true

require "securerandom"

module VdlBtz
  module GUI
    # Cola de descargas en memoria; no sabe nada de HTTP ni de yt-dlp.
    class JobQueue
      Job = Struct.new(:id, :url, :platform, :status, :title, :percent, :speed, :eta, :file, :error, :hint,
                       :audio, :quality, keyword_init: true)

      # Lo que recibe el runner para informar progreso y registrar cómo cancelarse.
      class Control
        attr_reader :cancel_block
        attr_accessor :cancel_requested

        def initialize(job, lock)
          @job = job
          @lock = lock
        end

        def update(attrs)
          @lock.synchronize { attrs.each { |k, v| @job[k] = v } }
        end

        def canceled?
          @cancel_requested
        end

        def on_cancel(&block)
          @cancel_block = block
        end
      end

      def initialize(workers: 2, runner:)
        @runner = runner
        @jobs = []
        @controls = {}
        @lock = Mutex.new
        @ids = Queue.new
        @threads = Array.new(workers) { Thread.new { work } }
      end

      def self.downloader_runner(installer:, config:)
        lambda do |job, control|
          dl = Downloader.new(ytdlp: installer.ytdlp_path, ffmpeg: installer.ffmpeg_path, output: config["output"],
                              quality: job.quality, audio: job.audio, cookies: config["cookies"],
                              js_runtime: installer.deno_path)
          control.on_cancel { dl.cancel! }
          dl.download(job.url) do |event, data|
            case event
            when :title then control.update(title: data)
            when :progress then control.update(percent: data[0], speed: data[1], eta: data[2])
            end
          end
        end
      end

      def add(urls, audio:, quality:)
        bad = urls.find { |u| !Platform.valid_url?(u) }
        raise Error, "URL inválida: #{bad}" if bad

        jobs = urls.map do |u|
          Job.new(id: SecureRandom.hex(4), url: Platform.clean_url(u), platform: Platform.detect(u), status: "queued", percent: 0,
                  audio: audio, quality: quality)
        end
        @lock.synchronize { @jobs.concat(jobs) }
        jobs.each { |j| @ids << j.id }
        jobs
      end

      def list
        @lock.synchronize { @jobs.map(&:to_h) }
      end

      def cancel(id)
        block = nil
        @lock.synchronize do
          job = @jobs.find { |j| j.id == id } or return false
          if job.status == "queued"
            job.status = "canceled"
          elsif job.status == "running"
            ctl = @controls[id]
            ctl.cancel_requested = true
            block = ctl.cancel_block
          end
        end
        block&.call
        true
      end

      def shutdown
        @lock.synchronize { @jobs.map(&:id) }.each { |id| cancel(id) }
        @threads.size.times { @ids << nil }
        @threads.each(&:join)
      end

      private

      def work
        while (id = @ids.pop)
          job = @lock.synchronize { @jobs.find { |j| j.id == id } }
          run(job)
        end
      end

      def run(job)
        ctl = Control.new(job, @lock)
        @lock.synchronize do
          return if job.status == "canceled"

          job.status = "running"
          @controls[job.id] = ctl
        end
        finish(job, ctl, @runner.call(job, ctl))
      rescue StandardError => e
        @lock.synchronize { fail_job(job, e.message) }
      end

      def finish(job, ctl, result)
        @lock.synchronize do
          if result.canceled || ctl.cancel_requested
            job.status = "canceled"
          elsif result.ok
            job.status = "done"
            job.file = result.file
          else
            fail_job(job, result.error)
          end
        end
      end

      def fail_job(job, message)
        job.status = "error"
        job.error = message
        job.hint = Hints.for(message)
      end
    end
  end
end
