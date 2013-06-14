# Ruby/WordPress

[![Build Status](https://travis-ci.org/keichan34/ruby-wordpress.png)](https://travis-ci.org/keichan34/ruby-wordpress)

Access your WordPress database with Ruby.

Read more: [http://keita.flagship.cc/2013/06/ruby-wordpress/](http://keita.flagship.cc/2013/06/ruby-wordpress/)

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
* `:wordpress_wp_content` (used for uploading attachments)

## Changelog

### 0.0.3 (unreleased)

Bug fixes

* `WordPress::Post#set_post_terms` will now respect the `append` parameter, when true.
* `WordPress::Post#set_post_terms` now accepts an empty array as the `terms` argument.
* `WordPress#query` `:meta_query` now correctly queries for multiple meta query statements. Only `AND` is supported at this point.
* `WordPress#query` `:meta_query` `:type` is now respected correctly
* `WordPress#query` `:meta_query` `BETWEEN`, `NOT BETWEEN`, `IN`, `NOT IN` works as expected.

New features

* PHP serialization for Ruby arrays and hashes in `WordPress::Options`
* 1.8.7 syntax support
* Added `WordPress::Post#==`. Comparison is performed only with IDs now.

### 0.0.2

* Bug fixes
* Post meta
* Taxonomy functions
* Adds post meta queries

### 0.0.1

* Initial public release
* Basic SQL functions (WordPress::Base)
* `wp_options` accessor

## Hacking

Hack away! Just make sure you have your `test_configuration.yml` file set up correctly. There's an example in `test_configuration.example.yml`; you can copy this and tailor it to your environment.

Please do not use a real database for testing - it is wiped clean before the suite runs, and loads the attached WordPress default schema.

The default `rake` task will run the entire test suite.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
