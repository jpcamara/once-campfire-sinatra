require "sqlite3"

module Campfire
  # Two SQLite connections per process: one for reads, one for writes. Statements are prepared once
  # per connection and reused. A read runs to completion without yielding to the fiber scheduler,
  # so fibers never see each other's half-finished statements. Writes take a fiber-aware lock and
  # BEGIN IMMEDIATE; the writer waits for other processes with a busy handler that sleeps (and so
  # lets other fibers run, on the reader connection).
  class DB
    BUSY_TIMEOUT_MS = 5_000

    class Connection
      def initialize(path, yielding_busy_handler:)
        @db = SQLite3::Database.new(path)
        if yielding_busy_handler
          @db.busy_handler_timeout = BUSY_TIMEOUT_MS
        else
          @db.busy_timeout = BUSY_TIMEOUT_MS
        end
        @db.execute("PRAGMA journal_mode = WAL")
        @db.execute("PRAGMA synchronous = NORMAL")
        @db.execute("PRAGMA foreign_keys = ON")
        @db.execute("PRAGMA mmap_size = 0")
        @statements = {}
      end

      def rows(sql, *binds)
        statement(sql).execute(*binds).to_a
      end

      def row(sql, *binds)
        stmt = statement(sql)
        result = stmt.execute(*binds).next
        stmt.reset!
        result
      end

      def value(sql, *binds)
        row(sql, *binds)&.first
      end

      def run(sql, *binds)
        statement(sql).execute(*binds).to_a
        @db.changes
      end

      def execute(sql)
        @db.execute(sql)
      end

      def last_insert_row_id
        @db.last_insert_row_id
      end

      private
        def statement(sql)
          @statements[sql] ||= @db.prepare(sql)
        end
    end

    def self.path
      ENV.fetch("DATABASE_PATH") { File.join(ENV.fetch("STORAGE_PATH", "storage"), "db", "production.sqlite3") }
    end

    def initialize(path = self.class.path)
      @reader = Connection.new(path, yielding_busy_handler: false)
      @writer = Connection.new(path, yielding_busy_handler: true)
      @write_lock = Mutex.new
    end

    def rows(...) = @reader.rows(...)
    def row(...) = @reader.row(...)
    def value(...) = @reader.value(...)

    def transaction
      @write_lock.synchronize do
        @writer.execute("BEGIN IMMEDIATE")
        begin
          result = yield @writer
          @writer.execute("COMMIT")
          result
        rescue Exception
          @writer.execute("ROLLBACK") rescue nil
          raise
        end
      end
    end

    # `IN (?, ?, ...)` for a list of ids; each list length is its own cached statement.
    def self.in_list(count)
      Array.new(count, "?").join(", ")
    end
  end
end
