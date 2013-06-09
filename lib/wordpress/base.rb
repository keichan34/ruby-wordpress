# Encoding: UTF-8

require 'unicode_utils/nfc' unless RUBY_VERSION =~ /1\.8\.7/

class WordPress::Base
  def initialize root
    @wp = root

    @conn = @wp.conn
    @tbl = @wp.tbl
  end

  def inspect
    nil
  end

  def insert(table, content)
    return nil if content.keys.length == 0

    fields = content.keys.map { |e| "`#{@conn.escape e.to_s}`" }
    values = content.keys.map { |e| "'#{@conn.escape content[e].to_s}'" }

    @conn.query("INSERT INTO `#{@conn.escape table}` (#{fields.join ', '}) VALUES (#{values.join ', '})")
    @conn.last_id
  end

  def update(table, where, content)
    return nil if content.keys.length == 0

    fields = content.keys.map { |e| "`#{@conn.escape e.to_s}`" }
    result = @conn.query("SELECT #{fields.join ', '} FROM `#{@conn.escape table}` WHERE #{where}")
    return false if result.count == 0

    if content.respond_to?(:diff)
      row = result.to_a[0]
      diff = content.diff row

      # Already up-to-date
      return true if diff.count == 0
    else
      diff = content
    end

    # Let's update the difference
    statements = diff.keys.map { |e| "`#{@conn.escape e.to_s}`='#{@conn.escape content[e].to_s}'" }
    @conn.query("UPDATE `#{@conn.escape table}` SET #{statements.join ', ' } WHERE #{where}")
    true
  end

  def update_or_insert(table, where, content)
    return nil if content.keys.length == 0

    unless update table, where, content
      insert table, content
    end
  end

  def get_post_meta(id, meta_key)
    (@conn.query("SELECT `meta_value` FROM `#{@tbl[:postmeta]}` WHERE `post_id`='#{id.to_i}' AND `meta_key`='#{@conn.escape meta_key.to_s}'").first || {})[:meta_value]
  end

  def set_post_meta(id, meta_key, meta_value)
    update_or_insert $tbl[:postmeta], "`post_id`='#{id.to_i}' AND `meta_key`='#{@conn.escape meta_key.to_s}'", {
      :post_id => id,
      :meta_key => meta_key.to_s,
      :meta_value => meta_value.to_s
    }
  end

  def get_the_terms(id, taxonomy)
    terms = @conn.query("SELECT `#{@tbl[:termtax]}`.`taxonomy`, `#{@tbl[:terms]}`.`name` FROM `#{@tbl[:posts]}`, `#{@tbl[:termtax]}`, `#{@tbl[:termrel]}`, `#{@tbl[:terms]}` WHERE `#{@tbl[:posts]}`.`ID` = '#{id.to_i}' AND `#{@tbl[:termrel]}`.`object_id` = `#{@tbl[:posts]}`.`ID` AND `#{@tbl[:termrel]}`.`term_taxonomy_id` = `#{@tbl[:termtax]}`.`term_taxonomy_id` AND `#{@tbl[:termtax]}`.`taxonomy` = '#{@conn.escape taxonomy}' AND `#{@tbl[:terms]}`.`term_id` = `#{@tbl[:termtax]}`.`term_id`")
    terms.map { |e| e[:name] }
  end

  def set_post_terms(post_id, terms, taxonomy, append=false)
    terms_esc = terms.map { |e| "'#{@conn.escape e.to_s}'" }
    terms_slugs = terms.map { |e| "'#{@conn.escape(CGI::escape e.to_s)}'"}
    raise ArgumentError, 'Terms must be an array with more than zero elements' unless terms_esc.count > 0
    # Cache post terms and term IDs
    termtax_rel = Hash[@conn.query("SELECT `#{@tbl[:termtax]}`.`term_taxonomy_id`, `#{@tbl[:terms]}`.`name` FROM `#{@tbl[:terms]}`, `#{@tbl[:termtax]}` WHERE (`#{@tbl[:terms]}`.`name` IN (#{ terms_esc.join ', ' }) OR `#{@tbl[:terms]}`.`slug` IN (#{ terms_slugs.join ', ' })) AND `#{@tbl[:terms]}`.`term_id` = `#{@tbl[:termtax]}`.`term_id` AND `#{@tbl[:termtax]}`.`taxonomy` = '#{@conn.escape taxonomy}' GROUP BY `#{@tbl[:terms]}`.`name`").map { |e| [e[:name], e[:term_taxonomy_id]] }]

    (terms - termtax_rel.keys).each do |x|
      # These are terms that do not exist yet
      term_id = (@conn.query("SELECT `term_id` FROM `#{@tbl[:terms]}` WHERE `name`='#{@conn.escape x}' AND `slug`='#{@conn.escape(CGI::escape x)}' LIMIT 1").first || {})[:term_id]
      unless term_id
        @conn.query("INSERT INTO `#{@tbl[:terms]}` (`name`, `slug`, `term_group`) VALUES ('#{@conn.escape x}', '#{@conn.escape(CGI::escape x)}', '0')")
        term_id = @conn.last_id
      end
      termtax_id = (@conn.query("SELECT `term_taxonomy_id` FROM `#{@tbl[:termtax]}` WHERE `term_id`='#{term_id.to_i}' AND `taxonomy`='#{@conn.escape taxonomy}' LIMIT 1").first || {})[:term_taxonomy_id]
      unless termtax_id
        @conn.query("INSERT INTO `#{@tbl[:termtax]}` (`term_id`, `taxonomy`, `parent`, `count`) VALUES ('#{term_id.to_i}', '#{@conn.escape taxonomy}', '0', '0')")
        termtax_id = @conn.last_id
      end
      termtax_rel[x] = termtax_id
    end

    termtax_to_add = terms

    if !append
      # Delete all associations first
      @conn.query("DELETE `#{@tbl[:termrel]}` FROM `#{@tbl[:termrel]}` JOIN `#{@tbl[:termtax]}` ON `#{@tbl[:termrel]}`.`term_taxonomy_id`=`#{@tbl[:termtax]}`.`term_taxonomy_id` WHERE `#{@tbl[:termtax]}`.`taxonomy`='#{@conn.escape taxonomy}' AND `#{@tbl[:termrel]}`.`object_id` = '#{post_id.to_i}'")
    else
      currently_associated = @conn.query("SELECT `#{@tbl[:termrel]}`.`term_taxonomy_id` FROM `#{@tbl[:termrel]}`, `#{@tbl[:termtax]}` WHERE `#{@tbl[:termrel]}`.`object_id` = '#{post_id.to_i}' AND `#{@tbl[:termrel]}`.`term_taxonomy_id` = `#{@tbl[:termtax]}`.`term_taxonomy_id` AND `#{@tbl[:termtax]}`.`taxonomy` = '#{@conn.escape taxonomy}'").map { |e| e[:term_taxonomy_id] }
      termtax_to_add -= currently_associated
    end

    termtax_to_add.each do |term|
      @conn.query("INSERT INTO `#{@tbl[:termrel]}` (`object_id`, `term_taxonomy_id`, `term_order`) VALUES ('#{post_id.to_i}', '#{termtax_rel[term].to_i}', '0')")
    end
  end
end

