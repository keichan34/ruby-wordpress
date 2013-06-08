require 'rubygems'
require 'bundler/setup'

require 'wordpress'

require 'wordpress/schema'

require 'yaml'

require 'pry'

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'

  # Set up the WordPress schema

  config.before(:suite) do
    $wp_conf = YAML.load(File.open(File.join(File.dirname(__FILE__), '..', 'test_configuration.yml')))
    multistatement_conf = $wp_conf.merge({ :flags => Mysql2::Client::MULTI_STATEMENTS })
    schema = WordPress::Schema.new(WordPress.new multistatement_conf)
    schema.initialize!
    # Give MySQL time, folks...
    sleep 2

    $wp = WordPress.new $wp_conf
  end

  config.after(:suite) do
    # We probably should be wiping the database clean at this point, but we'll restrain from doing that for now.
  end

  config.before(:each) do
    $wp.conn.query("START TRANSACTION")
  end

  config.after(:each) do
    $wp.conn.query("ROLLBACK")
  end
end
