# bin/rails runner push_check.rb -> the notifications Room::MessagePusher queues for a plain message and
# for one mentioning Jason, as [subscription id, title, body, badge, path].
recorded = []
WebPush::Pool.prepend(Module.new do
  define_method(:deliver_later) do |payload, subscription|
    n = payload.key?(:badge) ? subscription.notification(**payload) : subscription.notification(**payload)
    recorded << [ subscription.id, n.instance_variable_get(:@title), n.instance_variable_get(:@body), n.instance_variable_get(:@badge), n.instance_variable_get(:@path) ]
  end
end)
david = User.find(127326141)
Current.user = david
room = Room.find(201306877)
jason = User.find(149087659)
mention = ActionText::Attachment.from_attachable(jason).to_html
[ "plain push check", "<div>hi #{mention}</div>" ].each do |body|
  message = room.messages.create!(body: body, creator: david)
  recorded.clear
  Room::MessagePusher.new(room: room, message: message).push
  puts body[0, 20], recorded.sort.inspect
end
