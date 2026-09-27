# frozen_string_literal: true

require "date"

# Haftalık blokları kullanarak iş ve toplantı önerileri üretir.
module Rota
  class Planner
    SLOT_MINUTES = 30

    def initialize(week_start:, busy_blocks:, day_start: 8 * 60, day_end: 22 * 60)
      @week_start = Date.parse(week_start.to_s)
      @busy_blocks = busy_blocks.map { |block| normalize_block(block) }
      @day_start = day_start.to_i
      @day_end = day_end.to_i
    end

    def plan(tasks)
      slots = available_slots
      allocations = []
      unplaced = []

      tasks.sort_by { |task| [task.fetch("due_date", "9999-12-31"), task.fetch("title", "")] }.each do |task|
        remaining = task.fetch("duration_minutes").to_i
        task_allocations = []

        slots.each do |slot|
          break if remaining.zero?
          minutes = [slot[:end] - slot[:start], remaining].min
          task_allocations << allocation(task, slot[:date], slot[:start], slot[:start] + minutes)
          slot[:start] += minutes
          remaining -= minutes
        end

        allocations.concat(task_allocations)
        unplaced << task.merge("remaining_minutes" => remaining) if remaining.positive?
      end

      { "allocations" => allocations, "unplaced" => unplaced, "available_minutes" => slots.sum { |slot| slot[:end] - slot[:start] } }
    end

    def common_slots(calendars:, duration_minutes:)
      per_person = calendars.map do |calendar|
        self.class.new(
          week_start: @week_start,
          busy_blocks: calendar.fetch("blocks", []),
          day_start: @day_start,
          day_end: @day_end
        ).available_slots
      end

      intersections = per_person.reduce { |left, right| intersect(left, right) } || []
      intersections.select { |slot| slot[:end] - slot[:start] >= duration_minutes.to_i }
                   .map { |slot| slot.merge(end: slot[:start] + duration_minutes.to_i) }
    end

    def available_slots
      (0..6).flat_map do |offset|
        date = @week_start + offset
        occupied = @busy_blocks.select { |block| block[:date] == date }.sort_by { |block| block[:start] }
        cursor = @day_start
        day_slots = []

        occupied.each do |block|
          start_at = [[block[:start], @day_start].max, @day_end].min
          end_at = [[block[:end], @day_start].max, @day_end].min
          day_slots << { date: date, start: cursor, end: start_at } if start_at > cursor
          cursor = [cursor, end_at].max
        end
        day_slots << { date: date, start: cursor, end: @day_end } if cursor < @day_end
        day_slots
      end
    end

    private

    def normalize_block(block)
      { date: Date.parse(block.fetch("date").to_s), start: minutes(block.fetch("start_time")), end: minutes(block.fetch("end_time")) }
    end

    def allocation(task, date, start_at, end_at)
      {
        "task_id" => task["id"], "title" => task.fetch("title"), "date" => date.to_s,
        "start_time" => clock(start_at), "end_time" => clock(end_at), "minutes" => end_at - start_at,
        "status" => "suggested"
      }
    end

    def intersect(left, right)
      left.flat_map do |first|
        right.filter_map do |second|
          next unless first[:date] == second[:date]
          start_at = [first[:start], second[:start]].max
          end_at = [first[:end], second[:end]].min
          { date: first[:date], start: start_at, end: end_at } if start_at < end_at
        end
      end
    end

    def minutes(value)
      hours, minutes = value.to_s.split(":").map(&:to_i)
      (hours * 60) + minutes
    end

    def clock(value)
      format("%02d:%02d", value / 60, value % 60)
    end
  end
end
