# frozen_string_literal: true

require_relative "common"

Handler = proc do |request, response|
  RotaApi.with_errors(response) do
    RotaApi.current_user(request)
    payload = RotaApi.json_request(request)
    query = payload.fetch("query").to_s.strip
    raise ArgumentError, "Araştırma sorusu gerekli" if query.empty?
    raise ArgumentError, "GEMINI_API_KEY sunucu ayarında tanımlı değil" unless ENV["GEMINI_API_KEY"]

    uri = URI("https://generativelanguage.googleapis.com/v1beta/interactions")
    request_body = {
      model: ENV.fetch("GEMINI_MODEL", "gemini-2.5-flash"),
      input: "Türkçe, kısa ve uygulanabilir bir araştırma notu üret. İddiaları kaynaklarıyla ilişkilendir. Soru: #{query}",
      tools: [{ type: "google_search" }]
    }
    gemini_response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      api_request = Net::HTTP::Post.new(uri)
      api_request["x-goog-api-key"] = ENV.fetch("GEMINI_API_KEY")
      api_request["Content-Type"] = "application/json"
      api_request.body = JSON.generate(request_body)
      http.request(api_request)
    end
    raise ArgumentError, "Gemini isteği başarısız: #{gemini_response.code}" unless gemini_response.code.to_i.between?(200, 299)

    result = JSON.parse(gemini_response.body)
    text_block = result.fetch("steps", []).filter_map do |step|
      next unless step["type"] == "model_output"
      step.fetch("content", []).find { |content| content["type"] == "text" }
    end.first || {}
    citations = Array(text_block["annotations"]).filter_map do |annotation|
      next unless annotation["type"] == "url_citation"
      annotation.slice("title", "url", "start_index", "end_index")
    end
    RotaApi.respond(response, 200, { summary: text_block.fetch("text", ""), citations: citations })
  end
end
