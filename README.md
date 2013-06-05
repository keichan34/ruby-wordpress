# Ruby/WordPress

Access your WordPress database with Ruby.

## Installation

Add this line to your application's Gemfile:

    gem 'ruby-wordpress', :require => 'wordpress'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ruby-wordpress

## Usage

    require 'wordpress'
    wp = WordPress.new options

## Initialization options

A symbol hash.

See the [mysql2 connection options](https://github.com/brianmario/mysql2#connection-options).

Additional options:

* `:wordpress_prefix` (default: 'wp_')

## Changelog

### 0.0.2

* Bug fixes
* Post meta
* Taxonomy functions
* Adds post meta queries

### 0.0.1

* Initial public release
* Basic SQL functions (WordPress::Base)
* `wp_options` accessor

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
