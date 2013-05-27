require "wordpress/version"

require 'mysql2'
require 'php_serialize'
require 'cgi'

class WordPress
  def initialize(options)
    # Symbolize keys
    options = options.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}

    options[:wordpress_prefix] ||= 'wp_'
    @tbl = {
      terms: options[:wordpress_prefix] + 'terms',
      termtax: options[:wordpress_prefix] + 'term_taxonomy',
      termrel: options[:wordpress_prefix] + 'term_relationships',
      posts: options[:wordpress_prefix] + 'posts',
      postmeta: options[:wordpress_prefix] + 'postmeta',
      options: options[:wordpress_prefix] + 'options',
      prefix: options[:wordpress_prefix]
    }

    @conn = Mysql2::Client.new options
    @conn.query_options.merge!(symbolize_keys: true)

    # The WordPress options table
    @options = WP::Options.new @conn, @tbl
  end

  attr_reader :options
end
