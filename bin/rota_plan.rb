#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "fileutils"
require "json"
require "time"

# Kendi haftalık ders ve iş bloklarını tek dosyada okuyup boş zamanlara çalışma
# görevleri yerleştirir. Her çalışmada logs/rota_plan.log dosyasına sonuç yazar.
class RotaPlan
  DAY_START = 8 * 60
  DAY_END = 22 * 60

  def initialize(schedule, week_start: Date.today - ((Date.today.cwday - 1) % 7))
    @schedule = schedule
    @week_start = Date.parse(week_start.to_s)
  end

  def build
    slots = available_slots
    allocations = []
    unplaced = []

    @schedule.fetch("tasks", []).sort_by { |task| task.fetch("due_date") }.each do |task|
      remaining = task.fetch("duration_minutes").to_i
      slots.each do |slot|
        break if remaining.zero?
        next if slot[:start] >= slot[:end]

        amount = [slot[:end] - slot[:start], remaining].min
        allocations << {
          "task" => task.fetch("title"),
          "date" => slot[:date].to_s,
          "start_time" => clock(slot[:start]),
          "end_time" => clock(slot[:start] + amount),
          "minutes" => amount
        }
        slot[:start] += amount
        remaining -= amount
      end
      unplaced << task.merge("remaining_minutes" => remaining) if remaining.positive?
    end

    {
      "week_start" => @week_start.to_s,
      "allocations" => allocations,
      "unplaced" => unplaced,
      "estimated_minutes_saved" => @schedule.fetch("manual_planning_minutes", 0).to_i,
      "note" => "Tasarruf değeri, örnek takvimdeki manuel planlama süresi varsayımıdır."
    }
  end

  def self.run(input_path:, output_path:, log_path:, week_start: nil)
    schedule = JSON.parse(File.read(input_path))
    result = new(schedule, week_start: week_start || schedule.fetch("week_start")).build
    FileUtils.mkdir_p(File.dirname(output_path))
    File.write(output_path, JSON.pretty_generate(result) + "\n")
    FileUtils.mkdir_p(File.dirname(log_path))
    File.open(log_path, "a") do |file|
      file.puts("#{Time.now.iso8601} action=weekly_plan allocations=#{result['allocations'].length} unplaced=#{result['unplaced'].length} saved_minutes=#{result['estimated_minutes_saved']}")
    end
    result
  end

  private

  def available_slots
    (0..6).flat_map do |weekday|
      date = @week_start + weekday
      blocks = @schedule.fetch("weekly_blocks", []).select { |block| block.fetch("weekday").to_i == weekday }
                       .sort_by { |block| minutes(block.fetch("start_time")) }
      cursor = DAY_START
      slots = []
      blocks.each do |block|
        start_at = minutes(block.fetch("start_time"))
        end_at = minutes(block.fetch("end_time"))
        slots << { date: date, start: cursor, end: start_at } if start_at > cursor
        cursor = [cursor, end_at].max
      end
      slots << { date: date, start: cursor, end: DAY_END } if cursor < DAY_END
      slots
    end
  end

  def minutes(time)
    hour, minute = time.split(":").map(&:to_i)
    hour * 60 + minute
  end

  def clock(value)
    format("%02d:%02d", value / 60, value % 60)
  end
end

if $PROGRAM_NAME == __FILE__
  input = ARGV[0] || "data/my_week.json"
  result = RotaPlan.run(input_path: input, output_path: "data/plan_output.json", log_path: "logs/rota_plan.log")
  puts "Plan oluşturuldu: #{result['allocations'].length} blok, #{result['estimated_minutes_saved']} dk tasarruf varsayımı."
end
