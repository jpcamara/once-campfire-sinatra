# Copy a writable copy of the parity seed's SQLite database into the PostgreSQL database named by DATABASE_URL.
#
#   bin/rails runner /bench/pg/load_seed.rb /tmp/seed/production.sqlite3
#
# The schema must already be loaded (db:prepare). Rows go through Active Record's PostgreSQL types,
# so SQLite's 0/1 booleans, text timestamps and JSON text arrive as native values. Foreign keys are
# not checked during the copy; sequences are reset afterwards and every table's row count is compared.
require "sqlite3"

source = SQLite3::Database.new(ARGV.fetch(0))
connection = ActiveRecord::Base.connection
skipped = %w[schema_migrations ar_internal_metadata]
tables = source.execute("select name from sqlite_master where type = 'table' and name not like 'sqlite_%' and name not like 'message_search_index%'").flatten - skipped
search_rows = source.execute("select rowid, body from message_search_index")

connection.transaction do
  connection.execute("SET LOCAL session_replication_role = replica")
  tables.each do |table|
    model = Class.new(ActiveRecord::Base) { self.table_name = table; self.inheritance_column = nil }
    columns = source.execute("pragma table_info(#{connection.quote_table_name(table)})").map { |column| column[1] }
    json = columns.select { |column| %i[json jsonb].include?(model.columns_hash[column]&.type) }
    rows = source.execute("select #{columns.map { |column| %("#{column}") }.join(', ')} from \"#{table}\"")
    rows.each_slice(500) do |batch|
      model.insert_all(batch.map { |row|
        columns.zip(row).to_h.tap { |record| json.each { |column| record[column] = JSON.parse(record[column]) if record[column].is_a?(String) } }
      })
    end
  end

  search_rows.each_slice(500) do |batch|
    connection.execute("insert into message_search_index (rowid, body) values " +
      batch.map { |rowid, body| "(#{Integer(rowid)}, #{connection.quote(body)})" }.join(", "))
  end

  connection.execute("UPDATE push_subscriptions SET endpoint = 'https://127.0.0.1:9/push/' || id")
  connection.execute("UPDATE webhooks SET url = 'http://127.0.0.1:9/hook/' || id")
end

tables.each { |table| connection.reset_pk_sequence!(table) }

mismatches = (tables + %w[message_search_index]).filter_map do |table|
  expected = source.get_first_value("select count(*) from \"#{table}\"")
  actual = connection.select_value("select count(*) from #{connection.quote_table_name(table)}")
  "#{table}: sqlite #{expected}, postgres #{actual}" unless expected == actual
end
abort "row counts differ:\n#{mismatches.join("\n")}" unless mismatches.empty?
puts "copied #{tables.size} tables and #{search_rows.size} search rows; row counts match"
