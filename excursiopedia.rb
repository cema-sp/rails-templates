source_paths << File.expand_path(File.dirname(__FILE__))

insert_into_file 'Gemfile', "ruby '2.2.3'", after: "source 'https://rubygems.org'\n"
comment_lines 'Gemfile', "gem 'sqlite3'"

gem 'slim-rails'

gem 'sass-rails', '~> 5.0'
gem 'bootstrap-sass', '~> 3.3.5'

gem 'devise'
gem 'pundit'

gem_group :development, :test do
  gem 'byebug'
  gem 'web-console', '~> 2.0'
  gem 'spring'
  gem 'rspec-rails', '~> 3.0'
  gem 'capybara'
  gem 'cucumber-rails', require: false
  gem 'database_cleaner'
  gem 'factory_girl_rails'
  gem 'faker'
  gem 'pry'
  gem 'awesome_print', require: false
  gem 'sqlite3'
end

gem_group :development do
  gem 'guard'
  gem 'guard-bundler', require: false
  gem 'guard-rspec', require: false
  gem 'guard-cucumber', '~>1.6.0', require: false # do not work
  gem 'spring-commands-rspec'
  gem 'spring-commands-cucumber'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'quiet_assets'
  gem 'rubocop', require: false
  gem 'rubocop-rspec'
  gem 'guard-rubocop'
end

gem_group :test do
  gem 'shoulda-matchers', require: false
end

gem_group :production do
  gem 'rails_12factor'
  gem 'puma'
  gem 'pg'
end

remove_file 'README.rdoc'
create_file 'README.md'

inside 'app/assets' do
  inside 'stylesheets' do
    remove_file 'application.css'
    create_file 'application.sass' do <<-SASS.gsub /^ {6}/, ''
      /*
       * require_tree .
       * require_self
       */

      @import "bootstrap-sprockets"
      /* ----------------------- Bootstrap parameters --------------------------- */
      @import "bootstrap"
      /* ------------------------- Custom parameters ---------------------------- */

      /* --------------------------- Custom Styles ------------------------------ */
    SASS
    end
  end

  inside 'javascripts' do
    remove_file 'application.js'
    create_file 'application.js.coffee' do <<-COFFEE.gsub /^ {8}/, ''
        #= require jquery
        #= require jquery_ujs
        #= require bootstrap-sprockets
        #= require turbolinks
        #= require_tree .
      COFFEE
    end
  end
end

copy_file '.pryrc'
copy_file '.rspec'
copy_file '.rubocop.yml'

append_to_file '.gitignore' do <<-IGNORE.gsub /^ {2}/, ''

  # Ignore vagrant files
  /.vagrant

  # Ignore rerun.txt
  rerun.txt

  # Ignore vim tmp files
  /*.swp

IGNORE
end

environment 'config.serve_static_files = false', env: 'development'
environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }", env: 'development'
environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }", env: 'test'
environment "config.web_console.whitelisted_ips = '192.168.33.0/16'", env: 'development'
environment "config.action_mailer.default_url_options = { host: 'excursiopedia-test.herokuapp.com' }", env: 'production'

application do <<-APP

  config.generators do |generate|
    generate.route false
    generate.helper false
    generate.assets false
    generate.view_specs false
  end
APP
end

create_file 'Procfile' do <<-PROC.gsub /^ {2}/, ''
  web: bundle exec puma -t 5:5 -p ${PORT:-3000} -e ${RACK_ENV:-development}
PROC
end

after_bundle do
  run 'spring stop'

  generate('devise:install')
  generate('pundit:install')
  generate('rspec:install', '-s')
  generate('cucumber:install')

  run 'bundle exec guard init'
  run 'bundle binstubs cucumber'
  run 'bundle binstubs guard'
  run 'bundle binstubs rails'
  run 'bundle binstubs rake'
  run 'bundle binstubs rspec'
  run 'bundle binstubs rubocop'
  run 'bundle exec spring binstub --all'

  inside 'spec' do
    gsub_file 'rails_helper.rb', /(config.use_transactional_fixtures) = true/, '\1 = false'

    insert_into_file 'rails_helper.rb', after: "require 'rspec/rails'\n" do <<-RSPEC.gsub /^ {6}/, ''
      require 'capybara/rspec'
      require 'shoulda/matchers'
      require 'pundit/rspec'
    RSPEC
    end

    insert_into_file 'rails_helper.rb', after: "config.use_transactional_fixtures = false\n" do <<-RSPEC.gsub /^ {4}/, ''

      config.before(:suite) do
        begin
          DatabaseCleaner.start
          FactoryGirl.lint
        ensure
          # DatabaseCleaner.clean
          DatabaseCleaner.clean_with(:truncation)
        end
      end

      config.before(:each) do |example|
        DatabaseCleaner.strategy =
          example.metadata[:js] ? :truncation : :transaction
        DatabaseCleaner.start
      end

      config.after(:each) do
        DatabaseCleaner.clean
      end
    RSPEC
    end

    insert_into_file 'rails_helper.rb', after: "config.infer_spec_type_from_file_location!\n" do <<-RSPEC.gsub /^ {4}/, ''

      config.include FactoryGirl::Syntax::Methods
      config.include Devise::TestHelpers, type: :controller
    RSPEC
    end

    uncomment_lines 'rails_helper.rb', /Dir\[Rails.root.join/
  end

  inside 'features/support' do
    append_to_file 'env.rb' do <<-ENV.gsub /^ {6}/, ''
      Around do |_scenario, block|
        DatabaseCleaner.cleaning(&block)
      end
      World(FactoryGirl::Syntax::Methods)
    ENV
    end
  end

  gsub_file 'Guardfile', /(guard :rspec).*/,
    "guard :rspec, cmd: 'bin/rspec -f html -o ./tmp/spec_results.html' do\n"

  gsub_file 'Guardfile', /(guard "cucumber").*/,
    "guard 'cucumber',\n\
        cli: '-f html -o ./tmp/cukes_results.html',\n\
        bundler: false,\n\
        binstubs: true,\n\
        all_after_pass: false,\n\
        keep_failed: false do\n\
      watch(%r{^app/views/(.+)/.*\.(erb|haml|slim)$}) { |_m| 'features' }\n"

  gsub_file 'Guardfile', /(guard :rubocop).*/,
    "guard :rubocop,\n\
        hide_stdout: true,\n\
        keep_failed: false,\n\
        notification: false,\n\
        cli: ['--rails', '-a', '-D', '--format',\n\
              'html', '--out', './tmp/rubocop_result.html'] do\n"

  rake 'db:migrate'

  run 'bin/rubocop --rails -a -D'

  git :init
  git add: '.'
  git commit: "-a -m 'Initial commit'"
end
