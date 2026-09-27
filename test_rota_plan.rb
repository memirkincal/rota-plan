# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
load "bin/rota_plan.rb"

class RotaPlanTest < Minitest::Test
  def test_allocates_work_to_a_real_gap
    schedule = {
      "weekly_blocks" => [{ "weekday" => 0, "start_time" => "09:00", "end_time" => "10:00" }],
      "tasks" => [{ "title" => "Tekrar", "duration_minutes" => 60, "due_date" => "2026-09-22" }],
      "manual_planning_minutes" => 120
    }
    result = RotaPlan.new(schedule, week_start: "2026-09-21").build

    assert_equal 1, result["allocations"].length
    assert_equal "08:00", result["allocations"].first["start_time"]
    assert_equal 120, result["estimated_minutes_saved"]
  end

  def test_run_writes_a_log_line
    Dir.mktmpdir do |dir|
      input = File.join(dir, "week.json")
      File.write(input, JSON.generate({ "week_start" => "2026-09-21", "weekly_blocks" => [], "tasks" => [] }))
      log = File.join(dir, "logs", "rota_plan.log")
      RotaPlan.run(input_path: input, output_path: File.join(dir, "out.json"), log_path: log)

      assert_includes File.read(log), "action=weekly_plan"
    end
  end
end
