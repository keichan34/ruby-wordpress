# Encoding: UTF-8

class WordPress::Schema < WordPress::Base

  # Initialize the database. Will drop your current database!
  def initialize!
    drop!
    create_db!
    load!
  end

  def load!
    @conn.query_options[:flags] = Mysql2::Client::MULTI_STATEMENTS

    schema = File.open(File.join(File.dirname(__FILE__), '..', '..', 'wordpress-3.5.1.sql')).read
    @conn.query(schema)
  end

  private

    def drop!
      # Drops the database
      db = @wp.configuration[:database]
      @conn.query "DROP DATABASE `#{db}`"
    end

    def create_db!
      db = @wp.configuration[:database]
      @conn.query "CREATE DATABASE `#{db}`"
      @conn.query "USE `#{db}`"
    end

end
