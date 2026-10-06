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

    # Read results, kept until the database changes. PRAGMA data_version on the reader connection
    # changes whenever another connection commits: this process's writer, or another worker's. It's
    # read again at the start of each request, cable command and job (DB#check_for_changes), and the
    # cache is also cleared after this process's own commits. Rows are frozen, as they're shared.
    # `generation` counts the clears: pages kept by it (App#kept_response) last as long as the reads
    # they were made from.
    class ReadCache
      LIMIT = 8192

      attr_reader :generation

      def initialize(reader)
        @reader = reader
        @entries = {}
        @version = nil
        @generation = 0
      end

      def fetch(key)
        if (rows = @entries.delete(key))
          @entries[key] = rows
        else
          rows = @entries[key] = yield
          @entries.delete(@entries.first[0]) while @entries.size > LIMIT
          rows
        end
      end

      def check_for_changes
        version = @reader.value("PRAGMA data_version")
        clear unless version == @version
        @version = version
      end

      def clear
        @entries.clear
        @generation += 1
      end
    end

    def self.path
      ENV.fetch("DATABASE_PATH") { File.join(ENV.fetch("STORAGE_PATH", "storage"), "db", "production.sqlite3") }
    end

    def initialize(path = self.class.path)
      @reader = Connection.new(path, yielding_busy_handler: false)
      @writer = Connection.new(path, yielding_busy_handler: true)
      @write_lock = Mutex.new
      @cache = ReadCache.new(@reader)
    end

    def rows(sql, *binds) = @cache.fetch([ :rows, sql, *binds ]) { @reader.rows(sql, *binds).each(&:freeze).freeze }
    def row(sql, *binds) = @cache.fetch([ :row, sql, *binds ]) { @reader.row(sql, *binds)&.freeze }
    def value(sql, *binds) = row(sql, *binds)&.first

    # A value derived from reads (records built from rows), kept with them until the database changes.
    def memo(key) = @cache.fetch([ :memo, *key ]) { yield }

    def check_for_changes = @cache.check_for_changes
    def generation = @cache.generation

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
        ensure
          @cache.clear
        end
      end
    end

    # `IN (?, ?, ...)` for a list of ids; each list length is its own cached statement.
    def self.in_list(count)
      Array.new(count, "?").join(", ")
    end
  end
end
