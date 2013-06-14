# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'wordpress/version'

Gem::Specification.new do |spec|
  spec.name          = "ruby-wordpress"
  spec.version       = WordPress::Version::VERSION
  spec.authors       = ["Keitaroh Kobayashi"]
  spec.email         = ["keita@kkob.us"]
  spec.description   = %q{A gem to interface with the WordPress database}
  spec.summary       = %q{A gem to interface with the WordPress database}
  spec.homepage      = "https://github.com/keichan34/ruby-wordpress"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "mysql2", "~> 0.3.11"

  spec.add_dependency "unicode_utils", "~> 1.4.0" unless RUBY_VERSION =~ /1\.8\.7/

  spec.add_dependency "k-php-serialize", "~> 1.2.0"
  spec.add_dependency "mime-types", "~> 1.23"
  spec.add_dependency 'rmagick', '= 2.13.2'

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "pry"
end
