# frozen_string_literal: true

require_relative "../lib/planner"
require_relative "common"

Handler = proc do |request, response|
  RotaApi.with_errors(response) do
    RotaApi.current_user(request)
    payload = RotaApi.json_request(request)
    planner = Rota::Planner.new(
      week_start: payload.fetch("week_start"),
      busy_blocks: [],
      day_start: payload.fetch("day_start", 480),
      day_end: payload.fetch("day_end", 1320)
    )
    slots = planner.common_slots(
      calendars: payload.fetch("calendars"),
      duration_minutes: payload.fetch("duration_minutes")
    )
    RotaApi.respond(response, 200, { slots: slots.map { |slot| slot.merge(date: slot[:date].to_s) } })
  end
end
