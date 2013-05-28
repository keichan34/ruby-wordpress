# Encoding: UTF-8

class WordPress::Post::Meta < WordPress::Base

  def initialize connection, wp_tables, post
    super connection, wp_tables
    @post = post
  end

  def [](key)
    v = nil
    @conn.query("SELECT `meta_value` FROM `#{@tbl[:postmeta]}` WHERE `meta_key`='#{@conn.escape key}' AND `post_id`='#{ @post.post_id.to_i }' LIMIT 1").each do |row|
      v = row[:meta_value]
    end
    v
  end

  def []=(key, value)
    old_value = self[key]
    if !value.nil? and !old_value.nil? and value != old_value
      # Update operation.
      @conn.query("UPDATE `#{@tbl[:postmeta]}` SET `meta_value`='#{@conn.escape value}' WHERE `meta_key`='#{@conn.escape key}' AND `post_id`='#{ @post.post_id.to_i }'")
    elsif value.nil? and !old_value.nil?
      # New value nil, old value not. Delete operation.
      @conn.query("DELETE FROM `#{@tbl[:postmeta]}` WHERE `meta_key`='#{@conn.escape key}' AND `post_id`='#{ @post.post_id.to_i }'")
    elsif !value.nil? and old_value.nil?
      # New value non-nil, old value nil. Insert operation.
      @conn.query("INSERT INTO `#{@tbl[:postmeta]}` (`meta_key`, `meta_value`, `post_id`) VALUES ('#{@conn.escape key}', '#{@conn.escape value.to_s}', '#{ @post.post_id.to_i }')")
    end
    value
  end

  def keys
    all = []
    @conn.query("SELECT `meta_key` FROM `#{@tbl[:postmeta]}` WHERE `post_id`='#{ @post.post_id.to_i }'").each { |x| all << x }
    all.collect { |x| x[:meta_key] }
  end

  def to_s
    to_h.to_s
  end

  def to_h
    Hash[keys.map { |e| [e, self[e]] }]
  end
  alias_method :to_hash, :to_h

end
