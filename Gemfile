source "https://rubygems.org"

platform :ruby do
  gem 'pg',                     '~> 0.17'
  gem 'rmagick',                '~> 2.13'
  gem 'RedCloth',               '~> 4.2'
  gem 'unicorn',                '~> 5.2'
end

platform :jruby do
  gem 'activerecord-jdbcpostgresql-adapter'
  gem 'rmagick4j'
end

gem 'rails',                    '~> 4.2.4'
gem 'fast_gettext',             '~> 1.2'
gem 'acts-as-taggable-on',      '~> 4.0'
gem 'rails_autolink',           '~> 1.1.6'
gem 'ruby-feedparser',          '~> 0.7'
gem 'daemons',                  '~> 1.1'
gem 'nokogiri',                 (if RUBY_VERSION >= '2.4.0' then '~> 1.7.0' else '~> 1.6.0' end)
gem 'will_paginate',            '~> 3.1'
gem 'pothoven-attachment_fu',   '~> 3.2.16'
gem 'delayed_job'
gem 'delayed_job_active_record'
gem 'rake', :require => false
gem 'rest-client',              '~> 1.6'
gem 'exception_notification',   '~> 4.0.1'
gem 'gettext',                  '~> 3.1', :require => false
gem 'locale',                   '~> 2.1'
gem 'whenever',                 '~> 0.9.4', :require => false
gem 'eita-jrails', '~> 0.10.0', require: 'jrails'
gem 'diffy',                    '~> 3.0'
gem 'slim'
gem 'activerecord-session_store', '1.0.0'
gem 'recaptcha', require: 'recaptcha/rails'
gem 'honeypot-captcha'
gem 'font-awesome-sass'
gem 'rspec',                  '~> 3.3'
gem 'rspec-rails',            '~> 3.2'

# API dependencies
gem 'grape',                    '~> 0.12'
gem 'grape-entity',             '~> 0.6.0'
gem 'grape_logging'
gem 'rack-cors'
gem 'rack-contrib'
gem 'api-pagination',           '>= 4.1.1'
gem 'liquid',                    '>= 3.0.3'

# asset pipeline
gem 'uglifier', '>= 1.0.3'
gem 'sass-rails'
gem 'sprockets-rails', '~> 2.1'

# gems to enable rails3 behaviour
gem 'protected_attributes'
gem 'rails-observers'
gem 'actionpack-page_caching'
gem 'actionpack-action_caching'

group :production do
  gem 'dalli', '~> 2.7.0'
end

group :development, :test do
  gem 'spring'
end

group :test do
  gem 'mocha',                  '~> 1.1.0', :require => false
  gem 'test-unit' if RUBY_VERSION >= '2.2.0'
  gem 'minitest'
  gem 'minitest-reporters'
  gem 'simplecov', :require => false
end

group :cucumber, :test do
  gem 'capybara',               '~> 2.2'
  gem 'launchy'
  gem 'cucumber',               '~> 2.4'
  gem 'cucumber-rails',         '~> 1.4.3', require: false
  gem 'database_cleaner',       '~> 1.3'
  # Selenium WebDriver 3+ depends on geckodriver
  gem 'selenium-webdriver',     '>= 2.53', '< 3.0'
  gem 'chromedriver-helper' if ENV['SELENIUM_DRIVER'] == 'chrome'
end

# Requires custom dependencies
eval(File.read('config/Gemfile'), binding) rescue nil

##
# Gems inside repository, to move outside
#
vendor = Dir.glob('vendor/{,plugins/}*') - ['vendor/plugins']
vendor.each do |dir|
  plugin = File.basename dir
  version = if Dir.glob("#{dir}/*.gemspec").length > 0 then '> 0.0.0' else '0.0.0' end

  gem plugin, version, path: dir
end

# include gemfiles from enabled plugins
# plugins in baseplugins/ are not included on purpose. They should not have any
# dependencies.
Dir.glob('config/plugins/*/Gemfile').each do |gemfile|
  eval File.read(gemfile)
end

