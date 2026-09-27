# frozen_string_literal: true

require "json"

Handler = proc do |_request, response|
  response.status = 200
  response["Content-Type"] = "application/javascript; charset=utf-8"
  response["Cache-Control"] = "no-store"
  response.body = "window.ROTA_CONFIG = #{JSON.generate({ supabaseUrl: ENV.fetch('SUPABASE_URL', ''), supabaseAnonKey: ENV.fetch('SUPABASE_ANON_KEY', ''), localEnvLogin: false, localEnvAutoLogin: false })};"
end
