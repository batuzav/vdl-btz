# frozen_string_literal: true

require "test_helper"
require "timeout"

class GuiJobsTest < Minitest::Test
  Res = Struct.new(:ok, :file, :error, :canceled, keyword_init: true)
  KEYS = %i[id url platform status title percent speed eta file error hint audio quality].freeze

  def wait_until(&block)
    Timeout.timeout(5) { sleep 0.01 until block.call }
  end

  def queue(workers: 2, &runner)
    @q = VdlBtz::GUI::JobQueue.new(workers: workers, runner: runner)
  end

  def teardown
    @q&.shutdown
  end

  def status_of(id)
    @q.list.find { |j| j[:id] == id }[:status]
  end

  def test_add_valid_urls_and_ordered_list_keys
    queue { |_j, _c| Res.new(ok: true, file: "/x") }
    jobs = @q.add(%w[https://youtu.be/a https://youtu.be/b], audio: false, quality: "720")
    assert_equal 2, jobs.map(&:id).uniq.size
    assert_equal jobs.map(&:id), @q.list.map { |h| h[:id] }
    assert_equal KEYS.sort, @q.list.first.keys.sort
  end

  def test_invalid_url_enqueues_nothing
    queue { |_j, _c| Res.new(ok: true) }
    e = assert_raises(VdlBtz::Error) { @q.add(%w[https://youtu.be/a not-a-url], audio: false, quality: "best") }
    assert_includes e.message, "not-a-url"
    assert_empty @q.list
  end

  def test_at_most_workers_run_at_once
    gate = Queue.new
    lock = Mutex.new
    now = max = 0
    queue(workers: 2) do |_j, _c|
      lock.synchronize { now += 1; max = [max, now].max }
      gate.pop
      lock.synchronize { now -= 1 }
      Res.new(ok: true)
    end
    @q.add(Array.new(4) { |i| "https://youtu.be/#{i}" }, audio: false, quality: "best")
    wait_until { now == 2 }
    sleep 0.1
    assert_equal 2, max
    4.times { gate << 1 }
    wait_until { @q.list.all? { |j| j[:status] == "done" } }
    assert_equal 2, max
  end

  def test_done_and_error_with_hint
    queue { |j, _c| j.url.end_with?("bad") ? Res.new(ok: false, error: "This video is private") : Res.new(ok: true, file: "/v.mp4") }
    a, b = @q.add(%w[https://youtu.be/good https://youtu.be/bad], audio: false, quality: "best")
    wait_until { %w[done error].include?(status_of(a.id)) && %w[done error].include?(status_of(b.id)) }
    done = @q.list.find { |j| j[:id] == a.id }
    err = @q.list.find { |j| j[:id] == b.id }
    assert_equal ["done", "/v.mp4"], [done[:status], done[:file]]
    assert_equal "error", err[:status]
    assert_includes err[:hint], "cookies"
  end

  def test_cancel_queued_running_and_unknown
    gate = Queue.new
    ran = []
    queue(workers: 1) do |j, c|
      ran << j.id
      c.on_cancel { gate << :go }
      gate.pop
      Res.new(ok: false, canceled: true)
    end
    run, queued = @q.add(%w[https://youtu.be/a https://youtu.be/b], audio: false, quality: "best")
    wait_until { status_of(run.id) == "running" }
    assert @q.cancel(queued.id)
    assert_equal "canceled", status_of(queued.id)
    assert @q.cancel(run.id)
    wait_until { status_of(run.id) == "canceled" }
    refute_includes ran, queued.id
    refute @q.cancel("nope")
  end

  def test_youtube_playlist_params_are_dropped_from_the_job_url
    queue { |_j, _c| Res.new(ok: true) }
    job = @q.add(["https://www.youtube.com/watch?v=6-6aVn0wwYM&list=RD6-6aVn0wwYM&start_radio=1"], audio: false, quality: "best").first
    assert_equal "https://www.youtube.com/watch?v=6-6aVn0wwYM", job.url
  end
end
