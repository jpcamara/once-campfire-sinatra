require "benchmark"
MARKER = /\u0001(\d+)\u0002/
def split_chars(html)
  parts = []; last = 0
  html.scan(MARKER) { m = Regexp.last_match; parts << html[last...m.begin(0)] if m.begin(0) > last; parts << m[1].to_i; last = m.end(0) }
  parts << html[last..] if last < html.size
  parts
end
def split_bytes(html)
  parts = []; last = 0
  html.scan(MARKER) { m = Regexp.last_match; b = m.byteoffset(0); parts << html.byteslice(last, b[0] - last) if b[0] > last; parts << m[1].to_i; last = b[1] }
  parts << html.byteslice(last, html.bytesize - last) if last < html.bytesize
  parts
end
seg = ("<div class=\"x\">héllo wörld … </div>\n" * 25)
ascii = ("<div class=\"x\">hello world ... </div>\n" * 25)
[["utf8", seg], ["ascii", ascii]].each do |name, s|
  html = (["<html>" + s * 20] + (0...50).map { |i| "\u0001#{i}\u0002" + "\n  " }).join + s * 10
  n = 2000
  t1 = Benchmark.realtime { n.times { split_chars(html) } }
  t2 = Benchmark.realtime { n.times { split_bytes(html) } }
  raise "mismatch" unless split_chars(html) == split_bytes(html)
  printf("%s %d bytes: chars %.1f us, bytes %.1f us\n", name, html.bytesize, t1/n*1e6, t2/n*1e6)
end
