require "http/server"

channel = Channel(Int32).new
stop = false
ws_instances = [] of HTTP::WebSocket
x = false

ws_handler = HTTP::WebSocketHandler.new do |ws, ctx|
  ws_instances << ws
end

server = HTTP::Server.new do |context|
  if context.request.path == "/event"
    context.response.headers.merge!({
      "Content-Type"  => "text/event-stream",
      "Connection"    => "keep-alive",
      "Cache-Control" => "no-cache",
    })
    context.response.status_code = 200

    puts "Connected!"

    context.response.print "retry: 500\n\n"

    45.times do |n|
      sleep 1
      if stop
        context.response.print "id:23\ndata: STOP\n\n"
        stop = false
        break
      end
      if x
        context.response.print "id:55\nevent: stop\ndata: STOPPING\n\n"
        context.response.flush
        x = false
      end
    end

    puts "Closed!"
  elsif context.request.path == "/send"
    stop = true

    ws_instances.each do |ws|
      ws.send "STOP"
      ws.close
    end
    ws_instances.clear

    x = true

    context.response.content_type = "text/plain"
    context.response.print "Sent"
  elsif context.request.path == "/ws"
    ws_handler.call(context)
  else
    context.response.content_type = "text/html"
    context.response.print <<-HTML
    <!DOCTYPE html>
    <html>
      <head>
        <title>Our Funky HTML Page</title>
        <meta name="description" content="Our first page">
        <meta name="keywords" content="html tutorial template">
        <script type="module">
          const ws = new WebSocket("ws://127.0.0.1:8080/ws");
          ws.onmessage = function(e) {
            console.log(e.data);
          }

          const ul = document.querySelector('#list');
          const btn = document.querySelector('#btn');
          const fullStopBtn = document.querySelector('#full-stop-btn');

          const stream = new EventSource('http://127.0.0.1:8080/event');
          stream.addEventListener('stop', function(e) {
            console.log('stop event fired', e);
          })
          stream.onmessage = function(evt) {
            if (evt.data === "STOP") {
              stream.close();
              console.log('closed');
            }
          }
          //stream.onmessage = function(evt) {
          //  const newEl = document.createElement('li');
          //  newEl.textContent = "message: " + evt.data;
          //  ul.appendChild(newEl)
          //}
          btn.onclick = function(e) {
            e.preventDefault();
            stream.close();
            ws.close();
            console.log('streams closed');
          }
          fullStopBtn.onclick = function(e) {
            e.preventDefault();
            fetch('http://127.0.0.1:8080/send')
              .catch(function() {})
              .finally(function() {
                console.log('fully closed');
              });
          }
          window.stream = stream;
        </script>
      </head>
      <body>
        <h1>My First Heading</h1>
        <p>My first paragraph.</p>
        <button id="btn">Stop</button>
        <button id="full-stop-btn">Full Stop</button>
        <br>
        <ul id="list"></ul>
      </body>
    </html>
    HTML
  end
end

puts "Listening on http://127.0.0.1:8080"
server.listen(8080)
