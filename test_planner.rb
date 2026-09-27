# frozen_string_literal: true

require "minitest/autorun"
load "lib/planner.rb"

class PlannerTest < Minitest::Test
  WEEK = "2026-09-28"

  def planner(blocks = [])
    Rota::Planner.new(week_start: WEEK, busy_blocks: blocks, day_start: 8 * 60, day_end: 12 * 60)
  end

  def test_busy_lesson_and_bus_leave_only_real_gaps
    slots = planner([
      { "date" => WEEK, "start_time" => "08:00", "end_time" => "09:00" },
      { "date" => WEEK, "start_time" => "10:00", "end_time" => "11:00" }
    ]).available_slots

    assert_equal [["09:00", "10:00"], ["11:00", "12:00"]], slots.select { |slot| slot[:date].to_s == WEEK }.map { |slot| [clock(slot[:start]), clock(slot[:end])] }
  end

  def test_task_is_split_across_multiple_gaps
    result = planner([
      { "date" => WEEK, "start_time" => "09:00", "end_time" => "10:00" },
      { "date" => WEEK, "start_time" => "11:00", "end_time" => "12:00" }
    ]).plan([{ "id" => "t1", "title" => "Rapor", "duration_minutes" => 180, "due_date" => WEEK }])

    assert_equal 2, result["allocations"].count { |item| item["date"] == WEEK }
    assert_empty result["unplaced"]
  end

  def test_due_date_orders_tasks
    result = planner.plan([
      { "id" => "late", "title" => "Geç", "duration_minutes" => 30, "due_date" => "2026-10-03" },
      { "id" => "early", "title" => "Erken", "duration_minutes" => 30, "due_date" => "2026-09-29" }
    ])

    assert_equal "early", result["allocations"].first["task_id"]
  end

  def test_unplaced_task_reports_remaining_minutes
    result = planner.plan([{ "id" => "big", "title" => "Büyük iş", "duration_minutes" => 2000, "due_date" => WEEK }])

    assert_equal 320, result["unplaced"].first["remaining_minutes"]
  end

  def test_meeting_only_uses_common_free_time
    calendars = [
      { "blocks" => [{ "date" => WEEK, "start_time" => "08:00", "end_time" => "09:00" }] },
      { "blocks" => [{ "date" => WEEK, "start_time" => "10:00", "end_time" => "11:00" }] }
    ]
    slots = planner.common_slots(calendars: calendars, duration_minutes: 60)

    assert_equal "09:00", clock(slots.first[:start])
    assert_equal "10:00", clock(slots.first[:end])
  end

  private

  def clock(value)
    format("%02d:%02d", value / 60, value % 60)
  end
end
