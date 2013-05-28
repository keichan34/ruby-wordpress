require "wordpress/version"

require "wordpress/error"
require "wordpress/base"
require "wordpress/options"
require "wordpress/post"

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
    @options = WordPress::Options.new @conn, @tbl
  end

  attr_reader :options

  def query args
    # Main query function.
    # The goal is to support as much as the original WP_Query API as possible.
    raise ArgumentError.new('Hash arguments are supported.') unless args.kind_of?(Hash)

    # Defaults
    args = {
      post_type: 'post',
      post_status: 'publish'
    }.merge(args)

    wheres_and = []

    # Page finders

    if args[:page_id]
      args[:p] = args[:page_id]
      args[:post_type] = 'page'
    end

    if args[:pagename]
      args[:name] = args[:pagename]
      args[:post_type] = 'page'
    end

    # Post finders

    if args[:post_type]
      wheres_and << "`#{@tbl[:posts]}`.`post_type`='#{ @conn.escape args[:post_type] }'"
    end

    if args[:p]
      wheres_and << "`#{@tbl[:posts]}`.`ID`='#{ args[:p].to_i }'"
    end

    if args[:name]
      wheres_and << "`#{@tbl[:posts]}`.`post_title`='#{ @conn.escape args[:name] }'"
    end

    if args[:post_status]
      wheres_and << "`#{@tbl[:posts]}`.`post_status`='#{ @conn.escape args[:post_status] }'"
    end

    if args[:post__in]
      raise ArgumentError.new(':post__in should be an array.') unless args[:post__in].kind_of?(Array)
      wheres_and << "`#{@tbl[:posts]}`.`ID` IN (#{ args[:post__in].map { |e| "'#{ e.to_i }'" }.join ', ' })"
    end

    if args[:post__not_in]
      raise ArgumentError.new(':post__not_in should be an array.') unless args[:post__not_in].kind_of?(Array)
      wheres_and << "`#{@tbl[:posts]}`.`ID` NOT IN (#{ args[:post__not_in].map { |e| "'#{ e.to_i }'" }.join ', ' })"
    end

    @conn.query("SELECT * FROM `#{@tbl[:posts]}` WHERE #{ wheres_and.join ' AND ' }").map do |row|
      WordPress::Post.build @conn, @tbl, row
    end
  end

  def new_post args
    # 'args' is a hash of attributes that WordPress::Post responds to
    # See wordpress/post.rb
    WordPress::Post.build @conn, @tbl, args
  end
end
