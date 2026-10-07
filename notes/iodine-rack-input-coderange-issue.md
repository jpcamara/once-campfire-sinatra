# Draft upstream issue (not filed): rage-iodine `rack.input#read(len, buffer)` leaves a stale coderange

Target: rage-rb/iodine (the `rage-iodine` gem, 5.7.0). Found Oct 6 2026 while debugging Campfire-on-Rage
parity. Not filed; JP decides.

---

**Title:** `rack.input#read(length, buffer)` doesn't clear the buffer's cached coderange, so Rack's
multipart parser raises on binary uploads

**Summary**

`IodineRackIO#read(length, buffer)` copies the body bytes into `buffer` with `memcpy` and
`rb_str_set_len`, after `rb_enc_associate(buffer, binary)`. It never clears the string's cached
coderange. When the buffer was empty, or held only ASCII, Ruby has cached it as 7-bit, and it still
reports `ascii_only? == true` after binary bytes land in it.

Rack 3.2's multipart parser reads with an output buffer (`io.read(@bufsize, outbuf)`). It then
appends that buffer to its UTF-8 `StringScanner` buffer. Because the chunk claims to be ASCII, the
scan buffer stays UTF-8. `String#sub` on a file part then raises:

```
ArgumentError: invalid byte sequence in UTF-8
  rack-3.2.7/lib/rack/multipart/parser.rb:503:in 'String#sub'
  rack-3.2.7/lib/rack/multipart/parser.rb:503:in 'Rack::Multipart::Parser#handle_mime_body'
```

So any app or middleware that parses a multipart body through `Rack::Request#POST` on Iodine fails
on binary file parts. In our case that was a `_method` override reading the form. Iodine's own C
multipart parser is unaffected.

**Repro** (Ruby 3.4.10, rage-iodine 5.7.0, rack 3.2.7):

```ruby
require "iodine"
app = lambda do |env|
  io = env["rack.input"]
  b = String.new
  b.ascii_only?          # caches the empty buffer's 7-bit coderange
  io.read(65536, b)
  actual = b.dup.force_encoding("BINARY").bytes.all? { _1 < 128 }
  io.rewind
  [200, {}, ["ascii_only?=#{b.ascii_only?} actually_ascii=#{actual} plain_read_ascii_only?=#{io.read.ascii_only?}\n"]]
end
Iodine.listen service: :http, handler: app, port: "9395", address: "127.0.0.1"
Iodine.threads = 1; Iodine.workers = 1; Iodine.start
```

```
$ curl -s --data-binary @moon.jpg -H "content-type: application/octet-stream" http://127.0.0.1:9395/
ascii_only?=true actually_ascii=false plain_read_ascii_only?=false
```

With a multipart body and `Rack::Request.new(env).POST`, it fails as above. The same parse over a
`StringIO` of the same bytes succeeds.

**Fix:** in `rio_read` (ext/iodine/iodine_rack_io.c), call `rb_str_modify(buffer)` before
writing into the buffer (or `ENC_CODERANGE_CLEAR(buffer)` after). `rb_str_resize` plus `memcpy` into
`RSTRING_PTR` bypasses the coderange bookkeeping that `rb_str_cat` and friends do. Separately, at EOF
with a buffer given, Ruby's `IO#read` empties the buffer; `rio_read` leaves its old contents in place.
