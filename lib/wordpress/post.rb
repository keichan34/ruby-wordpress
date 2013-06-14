# Encoding: UTF-8

require 'cgi'
require 'mime/types'
require 'RMagick'

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

  def to_h
    Hash[ WORDPRESS_ATTRIBUTES.keys.map { |e| [e, instance_variable_get(:"@#{e}")] }]
  end

  def inspect
    to_h.to_s
  end

  def persisted?
    @post_id != -1 and !unsaved_changes?
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
    return self if persisted?

    new_id = update_or_insert @tbl[:posts], "`#{@tbl[:posts]}`.`ID`='#{ post_id.to_i }'", Hash[ WORDPRESS_ATTRIBUTES.keys.map { |e| [e, instance_variable_get(:"@#{e}")] }].reject { |k, v| READONLY_ATTRIBUTES.include? k }

    # We'll assume everything went OK since no errors were thrown.
    @in_database = Hash[ WORDPRESS_ATTRIBUTES.keys.map { |e| [e, instance_variable_get(:"@#{e}")] }]
    if new_id and new_id > 0
      @in_database[:post_id] = @post_id = new_id
    end

    self
  end

  def save!
    save || raise(WordPress::Error.new('Save failed.'))
  end

  # Post Meta

  def post_meta
    raise 'Post must be saved before manipulating metadata' if @post_id == -1
    @post_meta ||= WordPress::Post::Meta.new @wp, self
  end

  # Taxonomies

  def get_the_terms taxonomy
    raise 'Post must be saved before manipulating taxonomies' if @post_id == -1
    super @post_id, taxonomy
  end

  def set_post_terms terms, taxonomy, append=false
    raise 'Post must be saved before manipulating taxonomies' if @post_id == -1
    terms = [terms] unless terms.kind_of?(Array)
    current_terms = get_the_terms(taxonomy)
    return current_terms if current_terms.sort == terms.sort && append == false
    super @post_id, terms, taxonomy, append
  end

  # Attachments

  def attach_featured_image image
    img_id = attach_image(image).post_id
    post_meta['_thumbnail_id'] = img_id
  end

  def attach_image image
    raise 'Post must be saved before manipulating attached images' if @post_id == -1

    # Make a new post with the "attachment" format
    if image.respond_to? :open
      handle = image.open
    else
      handle = image
    end

    title = (0...10).map{(65+rand(26)).chr}.join
    if image.respond_to? :path
      path = Pathname.new image.path
      title = path.each_filename.to_a[-1]
    end

    mimetype = nil
    ext = ''
    if image.respond_to? :meta
      mimetype = (image.meta['content-type'] || '').split(';')[0]
      type = MIME::Types[mimetype].first
      if type
        ext = '.' + type.extensions.first
      end
    else
      if type = MIME::Types.type_for(title).first
        mimetype = types.content_type
        # ext = types.extensions.first
      end
    end

    # Build the pathname where this will go.
    file_basename = File.join(@wp.configuration[:wordpress_wp_content], '/uploads')
    uri_basename = @wp.configuration[:wordpress_wp_content_url] || (@wp.options['siteurl'] + '/wp-content/uploads')

    today = Date.today
    relative_filepath = "#{'%02d' % today.year}/#{'%02d' % today.month}/#{title}"

    # Copy the file
    local_filepath = Pathname.new(File.join(file_basename, relative_filepath + ext))
    FileUtils.mkdir_p local_filepath.dirname.to_s

    buffer = handle.read.force_encoding('BINARY')
    out = File.open(local_filepath.to_s, 'wb')
    out.write buffer
    out.close

    attachment = self.class.build @wp, {
      :post_title => title,
      :post_name => CGI::escape(title.downcase),
      :post_status => 'inherit',
      :post_parent => @post_id,
      :post_type => 'attachment',
      :post_mime_type => mimetype,
      :guid => uri_basename + '/' + relative_filepath + ext
    }
    attachment.save

    attachment.post_meta['_wp_attached_file'] = relative_filepath + ext

    # Get image metadata

    begin
      img = Magick::Image::read(local_filepath.to_s).first
      size_hash = {}

      thumbnail_filename = title + '-150x150' + ext
      thumb_img = img.resize_to_fill(150, 150)
      thumb_img.write File.join(file_basename, "#{'%02d' % today.year}/#{'%02d' % today.month}/#{thumbnail_filename}")

      size_hash[:thumbnail] = {
        :file => thumbnail_filename,
        :width => 150,
        :height => 150
      }

      size_hash[:medium] = {
        :file => title + ext,
        :height => img.rows,
        :width => img.columns
      }

      size_hash[:large] = {
        :file => title + ext,
        :height => img.rows,
        :width => img.columns
      }

      attachment.post_meta['_wp_attachment_metadata'] = {
        :file => title + ext,
        :height => img.rows,
        :width => img.columns,
        :sizes => size_hash
      }
    rescue Exception => e
      # raise e
      puts "Warn: Ignoring exception #{e.to_s}"
    end

    attachment
  end

  def featured_image
    thumb_id = post_meta['_thumbnail_id']
    @wp.query(:post_type => 'attachment', :post_parent => @post_id, :post_status => 'inherit', :p => thumb_id).first if thumb_id
  end

  def attached_files *args
    attach_args = {
      :post_type => 'attachment', :post_parent => @post_id, :post_status => 'inherit'
      }.merge(args[0] || {})
    @wp.query attach_args
  end

  # Initializators

  def initialize root
    super

    WORDPRESS_ATTRIBUTES.each do |att, default|
      instance_variable_set :"@#{att}", default
    end

    @in_database = {}
  end

  def self.build root, values
    post = new root
    # Use the map
    values = Hash[values.map { |k, v| [DB_MAP[k] || k, v] }]


    from_db = false
    # Because the post ID is greater than zero, let's assume that this is a persisted record.
    from_db = true if values[:post_id] and values[:post_id] > 0

    values.select { |key, value| WORDPRESS_ATTRIBUTES.keys.include? key }.each do |key, value|
      post.instance_variable_set(:"@#{key}", value)
      post.instance_variable_get(:@in_database)[key] = value if from_db
    end
    post
  end

  # Equality

  def == other
    other.post_id == post_id ? true : false
  end

  def <=> other
    post_id <=> other.post_id
  end

end
