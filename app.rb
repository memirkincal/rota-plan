#!/usr/bin/env ruby
# frozen_string_literal: true

# Rota'nın yerel, statik önizlemesi. Planlama API'leri Vercel'de /api altında çalışır;
# arayüz API yokken güvenli demo verisiyle çalışmaya devam eder.
require "json"
require "net/http"
require "uri"
require "webrick"
require "thread"

def load_local_environment
  path = File.join(Dir.pwd, ".env.local")
  return unless File.file?(path)

  File.foreach(path) do |line|
    next if line.lstrip.start_with?("#") || !line.include?("=")
    key, value = line.strip.split("=", 2)
    ENV[key] = value if key && value && !key.empty?
  end
end

load_local_environment
api_handler_mutex = Mutex.new

server = WEBrick::HTTPServer.new(
  Port: ENV.fetch("PORT", "4567").to_i,
  BindAddress: "127.0.0.1",
  DocumentRoot: "."
)

server.mount_proc "/" do |request, response|
  pages = { "/" => "index.html", "/plan" => "pages/plan.html", "/tasks" => "pages/tasks.html", "/program" => "pages/program.html", "/team" => "pages/team.html", "/settings" => "pages/settings.html" }
  if pages.key?(request.path)
    response.status = 200
    response["Content-Type"] = "text/html; charset=utf-8"
    response["Cache-Control"] = "no-store"
    response.body = File.binread(File.join(Dir.pwd, pages.fetch(request.path)))
    next
  end

  if request.path == "/api/config.rb"
    response.status = 200
    response["Content-Type"] = "application/javascript; charset=utf-8"
    response["Cache-Control"] = "no-store"
    response.body = "window.ROTA_CONFIG = #{JSON.generate({ supabaseUrl: ENV.fetch('SUPABASE_URL', ''), supabaseAnonKey: ENV.fetch('SUPABASE_ANON_KEY', ''), localEnvLogin: false, localEnvAutoLogin: false })};"
    next
  end

  if request.path == "/api/local-login.rb"
    response.status = 404
    response["Content-Type"] = "application/json"
    response.body = JSON.generate(error: "Yerel env ile giriş kullanılmıyor.")
    next
  end

  api_file = { "/api/plan.rb" => "plan.rb", "/api/meeting.rb" => "meeting.rb", "/api/research.rb" => "research.rb" }[request.path]
  if api_file
    handler = api_handler_mutex.synchronize do
      Object.send(:remove_const, :Handler) if Object.const_defined?(:Handler, false)
      load File.join(Dir.pwd, "api", api_file)
      Handler
    end
    handler.call(request, response)
    next
  end

  path = request.path.delete_prefix("/")
  if path.split("/").include?("..")
    response.status = 400
    response.body = "Bad request"
    next
  end
  file = File.expand_path(path, Dir.pwd)
  unless file.start_with?(File.expand_path(Dir.pwd) + File::SEPARATOR) && File.file?(file)
    response.status = 404
    response.body = "Not found"
    next
  end
  response.status = 200
  response["Content-Type"] = WEBrick::HTTPUtils.mime_type(File.extname(file), WEBrick::HTTPUtils::DefaultMimeTypes)
  response["Cache-Control"] = "no-store"
  response.body = File.binread(file)
end

trap("INT") { server.shutdown }
puts "Rota hazır: http://127.0.0.1:#{ENV.fetch('PORT', '4567')}"
server.start
