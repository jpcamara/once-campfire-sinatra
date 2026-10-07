require "time"

module Campfire
  # The Date header Thruster's Go HTTP server puts on every response; Falcon sends none. Thruster is
  # a static Go binary on the real clock, so under the parity harness's libfaketime (FAKETIME) the
  # date is the real time at boot plus the monotonic time since, which libfaketime leaves real.
  class DateHeader
    def initialize(app)
      @app = app
      if ENV["FAKETIME"].to_s.empty?
        @booted_at = nil
      else
        @booted_at = Float(IO.popen([ "env", "-u", "LD_PRELOAD", "date", "+%s.%N" ], &:read))
        @booted_at_monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end

    def call(env)
      status, headers, body = @app.call(env)
      headers["date"] ||= now.httpdate unless status == 101
      [ status, headers, body ]
    end

    private
      def now
        return Time.now unless @booted_at
        Time.at(@booted_at + Process.clock_gettime(Process::CLOCK_MONOTONIC) - @booted_at_monotonic)
      end
  end
end
