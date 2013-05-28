# Encoding: UTF-8

class WordPress::Post < WordPress::Base
  # Left: DB, right: our symbol
  DB_MAP = {
    :ID => :post_id
  }

  READONLY_ATTRIBUTES = [
    :post_id
  ]

  WORDPRESS_ATTRIBUTES = {
    :post_id => -1,
    :post_author => 1,
    :post_date => Time.new,
    :post_date_gmt => Time.new.utc,
    :post_content => '',
    :post_title => '',
    :post_excerpt => '',
    :post_status => 'draft',
    :comment_status => 'open',
    :ping_status => 'open',
    :post_password => '',
    :post_name => '',
    :to_ping => '',
    :pinged => '',
    :post_modified => Time.new,
    :post_modified_gmt => Time.new.utc,
    :post_content_filtered => '',
    :post_parent => 0,
    :guid => '0',
    :menu_order => 0,
    :post_type => 'post',
    :post_mime_type => '',
    :comment_count => 0
  }

  def persisted?
    @post_id == -1 or !unsaved_changes?
  end

  def unsaved_changes
    WORDPRESS_ATTRIBUTES.keys.select do |k|
      false
      true if instance_variable_get(:"@#{k}") != @in_database[k]
    end
  end

  def unsaved_changes?
    # Not an empty array of changes means there are unsaved changes.
    unsaved_changes != []
  end

  WORDPRESS_ATTRIBUTES.keys.each do |att|
    if READONLY_ATTRIBUTES.include? att
      attr_reader att
    else
      attr_accessor att
    end
  end

  def save
    # We don't need to save because nothing has changed
    return true if persisted?
    update_or_insert @tbl[:posts], "`#{@tbl[:posts]}`.`ID`='#{ post_id.to_i }'", Hash[ WORDPRESS_ATTRIBUTES.keys.map { |e| [e, instance_variable_get(:"@#{e}")] }].reject { |k, v| READONLY_ATTRIBUTES.include? k }
  end

  def save!
    save || raise(WordPress::Error.new('Save failed.'))
  end

  # Post Meta

  def post_meta
    raise 'Post must be saved before manipulating metadata' if @post_id == -1
    @post_meta ||= WordPress::Post::Meta.new @conn, @tbl, self
  end

  # Initializators

  def initialize connection, wp_tables
    super

    WORDPRESS_ATTRIBUTES.each do |att, default|
      instance_variable_set :"@#{att}", default
    end

    @in_database = {}
  end

  def self.build connection, wp_tables, values
    post = new connection, wp_tables
    # Use the map
    values = Hash[values.map { |k, v| [DB_MAP[k] || k, v] }]


    from_db = false
    # Because the post ID is greater than zero, let's assume that this is a persisted record.
    from_db = true if values[:post_id] > 0

    values.select { |key, value| WORDPRESS_ATTRIBUTES.keys.include? key }.each do |key, value|
      post.send :"#{key}=", value
      post.instance_variable_get(:@in_database)[key] = value if from_db
    end
    post
  end

end
