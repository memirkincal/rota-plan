# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module RotaApi
  module_function

  def json_request(request)
    body = request.respond_to?(:body) ? request.body : nil
    body = body.read if body.respond_to?(:read)
    JSON.parse(body.to_s.empty? ? "{}" : body)
  rescue JSON::ParserError
    raise ArgumentError, "Geçersiz JSON gövdesi"
  end

  def respond(response, status, payload)
    response.status = status
    response["Content-Type"] = "application/json; charset=utf-8"
    response["Cache-Control"] = "no-store"
    response.body = JSON.generate(payload)
  end

  # Yerel demoda ROTA_DEMO=true kullanılır. Canlıda Supabase erişim token'ı doğrulanır.
  def current_user(request)
    return "demo-user" if ENV["ROTA_DEMO"] == "true"

    token = request["authorization"].to_s.sub(/^Bearer\s+/i, "")
    raise SecurityError, "Oturum gerekli" if token.empty?

    base_url = ENV.fetch("SUPABASE_URL")
    api_key = ENV.fetch("SUPABASE_ANON_KEY")
    uri = URI("#{base_url}/auth/v1/user")
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      request = Net::HTTP::Get.new(uri)
      request["apikey"] = api_key
      request["Authorization"] = "Bearer #{token}"
      http.request(request)
    end
    raise SecurityError, "Geçersiz oturum" unless response.code.to_i == 200

    JSON.parse(response.body).fetch("id")
  end

  def with_errors(response)
    yield
  rescue SecurityError => error
    respond(response, 401, { error: error.message })
  rescue KeyError, ArgumentError => error
    respond(response, 422, { error: error.message })
  rescue StandardError => error
    warn error.full_message
    respond(response, 500, { error: "Sunucu isteği işleyemedi" })
  end
end
