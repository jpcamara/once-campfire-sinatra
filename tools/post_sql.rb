# bin/rails runner post_sql.rb -> the SQL statements one message post runs (after a warm-up post).
Rails.application.env_config["action_dispatch.show_exceptions"] = :none
s = ActionDispatch::Integration::Session.new(Rails.application)
s.host! "127.0.0.1"
s.post "/session", params: { email_address: "david@37signals.com", password: "secret123456" }, headers: { "Sec-Fetch-Site" => "same-origin" }
post = -> { s.post "/rooms/201306877/messages", params: { message: { body: "<div>sql check</div>", client_message_id: SecureRandom.uuid } },
  headers: { "Sec-Fetch-Site" => "same-origin", "Accept" => "text/vnd.turbo-stream.html" } }
post.call
statements = []
subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
  statements << "#{payload[:cached] ? "CACHED " : ""}#{payload[:sql][0, 150]}" unless payload[:name] == "SCHEMA"
end
post.call
ActiveSupport::Notifications.unsubscribe(subscriber)
puts "status #{s.response.status}, #{statements.size} statements (#{statements.count { |q| q.start_with?("CACHED") }} cached)"
puts statements
