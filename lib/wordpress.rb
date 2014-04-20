require "wordpress/version"

require "wordpress/error"
require "wordpress/base"
require "wordpress/options"
require "wordpress/post"
require "wordpress/post/meta"

require 'mysql2'
require 'php_serialize'
require 'cgi'

class WordPress
  def initialize(options)
    # Symbolize keys
    options = options.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}

    options[:wordpress_prefix] ||= 'wp_'
    @tbl = {
      :terms => options[:wordpress_prefix] + 'terms',
      :termtax => options[:wordpress_prefix] + 'term_taxonomy',
      :termrel => options[:wordpress_prefix] + 'term_relationships',
      :posts => options[:wordpress_prefix] + 'posts',
      :postmeta => options[:wordpress_prefix] + 'postmeta',
      :options => options[:wordpress_prefix] + 'options',
      :prefix => options[:wordpress_prefix]
    }

    @conn = Mysql2::Client.new options
    @conn.query_options.merge!(:symbolize_keys => true)

    @configuration = options

    # The WordPress options table
    @options = WordPress::Options.new self
  end

  attr_reader :options

  attr_reader :tbl
  attr_reader :conn

  attr_accessor :configuration

  def query args
    # Main query function.
    # The goal is to support as much as the original WP_Query API as possible.
    raise ArgumentError.new('Hash arguments are supported.') unless args.kind_of?(Hash)

    # Defaults
    args = {
      :post_type => 'post',
      :post_status => 'publish'
    }.merge(args)

    wheres_and = []
    inner_joins = []

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
      if args[:post_type].kind_of? Array
        postTypeInStatement = args[:post_type].map { |e| "'" + ( @conn.escape e ) + "'" }.join ', '
        wheres_and << "`#{@tbl[:posts]}`.`post_type` IN (#{ postTypeInStatement })"
      else
        wheres_and << "`#{@tbl[:posts]}`.`post_type`='#{ @conn.escape args[:post_type] }'"
      end
    end

    if args[:p]
      wheres_and << "`#{@tbl[:posts]}`.`ID`='#{ args[:p].to_i }'"
    end

    if args[:post_parent]
      wheres_and << "`#{@tbl[:posts]}`.`post_parent`='#{ args[:post_parent].to_i }'"
    end

    if args[:name]
      wheres_and << "`#{@tbl[:posts]}`.`post_name`='#{ @conn.escape args[:name] }'"
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

    # Meta finders

    if (mqs = args[:meta_query]) and mqs.kind_of?(Array)
      append = (args[:meta_query_relation] || '').upcase == 'OR' ? (meta_ors = []) : wheres_and

      mqs.each_with_index do |mq, i|
        postmeta_alias = "pm_#{i}"
        inner_joins << "`#{@tbl[:postmeta]}` AS `#{postmeta_alias}` ON `#{@tbl[:posts]}`.`ID`=`#{postmeta_alias}`.`post_id`"
        mq_params = {
          :compare => '=',
          :type => 'CHAR' # Ignored for now
        }.merge(mq)

        # Allowed compares
        mq_params[:compare] = '=' unless ['=', '!=', '>', '>=', '<', '<=', 'LIKE', 'NOT LIKE', 'IN', 'NOT IN', 'BETWEEN', 'NOT BETWEEN'].include?(mq_params[:compare].upcase)

        # Allowed types
        mq_params[:type] = 'CHAR' unless ['NUMERIC', 'BINARY', 'CHAR', 'DATE', 'DATETIME', 'DECIMAL', 'SIGNED', 'TIME', 'UNSIGNED'].include?(mq_params[:type].upcase)

        mq_params[:type] = 'SIGNED' if mq_params[:type] == 'NUMERIC'

        if mq_params[:compare] =~ /BETWEEN/
          # Meta value needs to be a 2-element array or range
          x = mq_params[:value]
          raise ArgumentError.new("#{mq_params[:compare]} requires an Array with 2 elements or a Range. You passed #{x.class.to_s}.") if !(x.kind_of?(Array) and x.count == 2) and !x.kind_of?(Range)
          mq_params[:type] = 'SIGNED' if !mq[:type] and x.first.kind_of?(Integer) and x.last.kind_of?(Integer)
          mq_params[:type] = 'DECIMAL' if !mq[:type] and x.first.kind_of?(Float) and x.last.kind_of?(Float)
          comparator = "'#{@conn.escape x.first.to_s}' AND '#{@conn.escape x.last.to_s}'"
        elsif mq_params[:compare] =~ /IN/
          x = mq_params[:value]
          raise ArgumentError.new("#{mq_params[:compare]} requires an Array or a Range.") if !x.kind_of?(Array) and !x.kind_of?(Range)
          mq_params[:type] = 'SIGNED' if !mq[:type] and x.first.kind_of?(Integer) and x.last.kind_of?(Integer)
          mq_params[:type] = 'DECIMAL' if !mq[:type] and x.first.kind_of?(Float) and x.last.kind_of?(Float)
          comparator = '(' + x.map { |e| "'#{ @conn.escape e.to_s }'" }.join(', ') + ')'
        else
          comparator = "'" + @conn.escape(mq_params[:value].to_s) + "'"
        end

        append << "(`#{postmeta_alias}`.`meta_key`='#{@conn.escape mq_params[:key].to_s}' AND CAST(`#{postmeta_alias}`.`meta_value` AS #{mq_params[:type]}) #{mq_params[:compare]} #{ comparator })"
      end

      wheres_and << meta_ors.join(' OR ') if (args[:meta_query_relation] || '').upcase == 'OR'

    end

    query = "SELECT `#{@tbl[:posts]}`.* FROM `#{@tbl[:posts]}` "
    if inner_joins.length > 0
      query += inner_joins.map { |e| "INNER JOIN #{e}" }.join(' ') + ' '
    end

    query += "WHERE #{ wheres_and.join ' AND ' }"

    @conn.query(query).map do |row|
      WordPress::Post.build self, row
    end
  end

  def new_post args
    # 'args' is a hash of attributes that WordPress::Post responds to
    # See wordpress/post.rb
    WordPress::Post.build self, args
  end

  def update_taxonomy_counts *taxes
    taxes.each do |taxonomy|
      @conn.query("SELECT `term_taxonomy_id`, `count` FROM `#{@tbl[:termtax]}` WHERE `taxonomy`='#{@conn.escape taxonomy.to_s}'").each do |term_tax|
        termtax_id = term_tax[:term_taxonomy_id]
        count = 0
        @conn.query("SELECT COUNT(*) as `c` FROM `#{@tbl[:posts]}`, `#{@tbl[:termrel]}` WHERE `#{@tbl[:posts]}`.`ID`=`#{@tbl[:termrel]}`.`object_id` AND `#{@tbl[:termrel]}`.`term_taxonomy_id`='#{ termtax_id.to_i }'").each do |x|
          count = x[:c]
        end
        if count != term_tax[:count]
          @conn.query("UPDATE `#{@tbl[:termtax]}` SET `count`='#{count.to_i}' WHERE `term_taxonomy_id`='#{ termtax_id.to_i }'")
        end
      end
    end
  end
end
