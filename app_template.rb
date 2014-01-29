# coding: utf-8
run "wget --no-check-certificate 'https://raw.github.com/paulsutcliffe/digitalocean-rails/master/public/humans.txt' -O public/humans.txt"

#Setup extra gems
gsub_file 'Gemfile', /# gem 'capistrano'/, 'gem "capistrano"'
gsub_file 'Gemfile', /# gem 'unicorn'/, 'gem "unicorn"'
gem 'bootstrap-sass', '~> 3.0.3.0'
gem "compass-rails", group: :assets
gem 'rails_layout', group: :development
gem 'rvm-capistrano'
gem 'haml'
gem 'scaffold-bootstrap3'
gem 'inherited_resources'
gem 'page_title_helper'
gem 'friendly_id', '~> 5.0.0'
gem 'devise'
gem 'mini_magick'
gem 'carrierwave'
gem 'fake', group: :test
gem 'capybara', '~> 2.2.1', group: :test
gem 'launchy', '~> 2.4.2', group: :test

gem 'rspec-rails', '~> 3.0.0.beta', group: [:test, :development]
gem 'factory_girl_rails', '~> 4.3.0', group: [:test, :development]

run "bundle install"

#Setup the database
run "rm config/database.yml"

db_user = ask("¿Cúal es tu usuario local de mysql")
db_password = ask("Ingresa la contraseña de mysql")

file "config/database.yml", <<-CODE
defaults: &defaults
  adapter: mysql2
  encoding: utf8
  reconnect: false
  pool: 5
  username: #{db_user}
  password: #{db_password}

development:
  database: #{app_name.camelize(:lower)}_development
  socket: /tmp/mysql.sock
  <<: *defaults

test: &test
  database: #{app_name.camelize(:lower)}_test
  socket: /tmp/mysql.sock
  <<: *defaults

production:
  host: localhost
  database: #{app_name.camelize(:lower)}_production
  <<: *defaults
CODE

rake "db:create"

#Install the gems
run "rm app/views/layouts/application.html.erb"
run "wget --no-check-certificate 'https://raw.github.com/paulsutcliffe/digitalocean-rails/master/application.html.haml' -O app/views/layouts/application.html.haml"
run "wget --no-check-certificate 'https://raw.github.com/paulsutcliffe/digitalocean-rails/master/_navigation.html.haml' -O app/views/layouts/_navigation.html.haml"
run "wget --no-check-certificate 'https://raw.github.com/paulsutcliffe/digitalocean-rails/master/_messages.html.haml' -O app/views/layouts/_messages.html.haml"

generate 'rspec:install'
inject_into_file 'spec/spec_helper.rb', "\nrequire 'factory_girl'", :after => "require 'rspec/rails'"
inject_into_file 'config/application.rb', :after => "config.filter_parameters += [:password]" do
  <<-eos

    # Customize generators
    config.generators do |g|
      g.stylesheets false
      g.javascripts false
      g.test_framework :rspec,
        fixtures: true,
        view_specs: false,
        helper_specs: false,
        routing_specs: false,
        controller_specs: true,
        request_specs: false
      g.fixture_replacement :factory_girl, dir: "spec/factories"
    end
  eos
end
run "echo '--format documentation' >> .rspec"

if ask("¿Quieres generar un controller para usarlo como root?(si/no)") == 'si'
  name = ask("¿Cómo quieres que se llame tu controller para el root?").underscore
  generate :controller, "#{name} index"
  route "root to: '#{name}\#index'"
end

# Setup Google Analytics
if ask("Tienes a la mano el key de Google Analytics? (si/no)") == 'si'
  ga_key = ask("¿Cual es el tracking key de Google Analytics: (ejemplo: UA-46217331-1)")
  ga_domain = ask("¿Cual es el dominio configurado en Google Analytics:")
else
  ga_key = nil
end

file "app/views/shared/_google_analytics.html.erb", <<-CODE
<script>
  (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
  (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
  m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
  })(window,document,'script','//www.google-analytics.com/analytics.js','ga');

  ga('create', '#{ga_key || "INSERT-URCHIN-CODE"}', '#{ga_domain || "INSERT-DOMAIN-HERE"}');
  ga('send', 'pageview');

</script>
CODE

if ga_key
append_file "app/views/layouts/application.html.haml", <<-CODE
    = render 'shared/google_analytics'
CODE
end

append_file "app/assets/javascripts/application.js", <<-CODE
//= require bootstrap
CODE

run "mv app/assets/stylesheets/application.css app/assets/stylesheets/application.css.scss"

gsub_file 'app/assets/stylesheets/application.css.scss', '*= require_tree .', '*'

append_file "app/assets/stylesheets/application.css.scss", <<-CODE
@import 'bootstrap';

@import 'mixins.css.scss';
@import 'variables.css.scss';
@import 'fonts.css.scss';
@import 'layout.css.scss';
@import 'styles.css.scss';
@import 'media_queries.css.scss';
CODE

run "touch app/assets/stylesheets/_mixins.css.scss"
run "touch app/assets/stylesheets/_variables.css.scss"
run "touch app/assets/stylesheets/_fonts.css.scss"
run "touch app/assets/stylesheets/_layout.css.scss"
run "touch app/assets/stylesheets/_styles.css.scss"
run "touch app/assets/stylesheets/_media_queries.css.scss"

#Capistrano for deploying on Digital Ocean Ubuntu Ngnix + Unicorn
run "capify ."
run "rm config/deploy.rb"
gsub_file 'Capfile', /# load/, 'load'

cap_server = ask("Ingresa el url del server")
cap_user = ask("Ingresa el username del server")
coding = '#coding: utf-8'
application = '#{application}'
command = '#{command}'
user = '#{user}'
current_path = '#{current_path}'
shared_path = '#{shared_path}'
release_path = '#{release_path}'
trysudo = '#{try_sudo}'
latest_release = '#{latest_release}'
rails_env = '#{rails_env}'
asset_env = '#{asset_env}'
rake = '#{rake}'
rootpassword = '#{root_password}'
source_local = '#{source.local.log(from)}'
dbname = '#{db_name}'
dbuser = '#{db_user}'
dbpass = '#{db_pass}'
github_user = ask("Please enter your Github's username")

file "config/deploy.rb", <<-CODE
#{coding}
require "bundler/capistrano"
require "rvm/capistrano"

set :rvm_ruby_string, '2.1.0'
set :rvm_type, :user  # Don't use system-wide RVM

server "#{cap_server}", :web, :app, :db, primary: true

set :application, "#{app_name.camelize(:lower)}"
set :user, "#{cap_user}"
set :deploy_to, "/var/www/#{application}"
set :deploy_via, :remote_cache
set :use_sudo, false

set :scm, "git"
set :repository, "git@github.com:#{github_user}/#{application}.git"
set :branch, "master"

default_run_options[:pty] = true
ssh_options[:forward_agent] = true

namespace :bundler do
  desc "|DarkRecipes| Installs bundler gem to your server"
  task :setup, :roles => :app do
    run "if ! gem list | grep --silent -e 'bundler'; then #{trysudo} gem uninstall bundler; #{trysudo} gem install --no-rdoc --no-ri bundler; fi"
  end

  desc "|DarkRecipes| Runs bundle install on the app server (internal task)"
  task :install, :roles => :app, :except => { :no_release => true } do
    run "cd #{current_path} && bundle install --deployment --without=development test"
    if File.exist? "/#{current_path}/bin/unicorn"
      run "cd #{current_path} && bundle install -—binstubs"
    end
  end
end

namespace :deploy do

  desc "creates database & database user"

  task :create_database do
    set :root_password, Capistrano::CLI.password_prompt("MySQL root password: ")
    set :db_user, Capistrano::CLI.ui.ask("Application database user: ")
    set :db_pass, Capistrano::CLI.password_prompt("Password: ")
    set :db_name, Capistrano::CLI.ui.ask("Database name: ")

    run "mysql --user=root --password=#{rootpassword} -e \\"CREATE DATABASE IF NOT EXISTS #{dbname}\\""
    run "mysql --user=root --password=#{rootpassword} -e \\"GRANT ALL PRIVILEGES ON #{dbname}.* TO '#{dbuser}'@'localhost' IDENTIFIED BY '#{dbpass}' WITH GRANT OPTION\\""
  end

  task :setup_config, roles: :app do
    if File.exist? "/etc/nginx/sites-enabled/default"
      sudo "rm /etc/nginx/sites-enabled/default"
    end
    sudo "ln -nfs #{current_path}/config/nginx.conf /etc/nginx/sites-enabled/#{application}"
    sudo "ln -nfs #{current_path}/config/unicorn_init.sh /etc/init.d/unicorn_#{application}"
    run "cd /var/www/#{application}/current/"
    run "bundle install --binstubs"
  end
  before "deploy:cold", "deploy:create_database"
  after "deploy:cold", "deploy:setup_config"

  desc "Make sure local git is in sync with remote."
  task :check_revision, roles: :web do
    unless `git rev-parse HEAD` == `git rev-parse origin/master`
      puts "WARNING: HEAD is not the same as origin/master"
      puts "Run `git push` to sync changes."
      exit
    end
  end
  before "deploy", "deploy:check_revision"
  after "deploy", "deploy:restart_unicorn"

  task :restart_unicorn, roles: :app do
    sudo "service unicorn_#{application} restart"
  end
end
CODE

#Nginx Configuration files
file "config/nginx.conf", <<-CODE
upstream #{app_name.camelize(:lower)}_app_server {
  server unix:/tmp/unicorn.#{app_name.camelize(:lower)}.sock fail_timeout=0;
}

server {
  listen 80;
  server_name #{cap_server};
  root /var/www/#{app_name.camelize(:lower)}/current/public;

  location ^~ /assets/ {
    gzip_static on;
    expires max;
    add_header Cache-Control public;
  }

  try_files $uri/index.html $uri @#{app_name.camelize(:lower)}_app_server;
  location @#{app_name.camelize(:lower)}_app_server {
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_redirect off;
    proxy_pass http://#{app_name.camelize(:lower)}_app_server;
  }

  error_page 500 502 503 504 /500.html;
  client_max_body_size 4G;
  keepalive_timeout 10;
}
CODE

#Unicorn configuration files
root = '#{root}'
file "config/unicorn.rb", <<-CODE
root = "/var/www/#{app_name.camelize(:lower)}/current"
working_directory root
pid "#{root}/tmp/pids/unicorn.pid"
stderr_path "#{root}/log/unicorn.log"
stdout_path "#{root}/log/unicorn.log"

listen "/tmp/unicorn.#{app_name.camelize(:lower)}.sock"
worker_processes 2
timeout 30
CODE

file "config/unicorn_init.sh", <<-CODE
#!/bin/sh
set -e

# Feel free to change any of the following variables for your app:
TIMEOUT=${TIMEOUT-60}
APP_ROOT=/var/www/#{app_name.camelize(:lower)}/current
PID=$APP_ROOT/tmp/pids/unicorn.pid
CMD="cd $APP_ROOT; bundle exec unicorn -D -c $APP_ROOT/config/unicorn.rb -E production"
AS_USER=#{cap_user}
set -u

OLD_PIN="$PID.oldbin"

sig () {
  test -s "$PID" && kill -$1 `cat $PID`
}

oldsig () {
  test -s $OLD_PIN && kill -$1 `cat $OLD_PIN`
}

run () {
  if [ "$(id -un)" = "$AS_USER" ]; then
    eval $1
  else
    su -c "$1" - $AS_USER
  fi
}

case "$1" in
start)
  sig 0 && echo >&2 "Already running" && exit 0
  run "$CMD"
  ;;
stop)
  sig QUIT && exit 0
  echo >&2 "Not running"
  ;;
force-stop)
  sig TERM && exit 0
  echo >&2 "Not running"
  ;;
restart|reload)
  sig HUP && echo reloaded OK && exit 0
  echo >&2 "Couldn't reload, starting '$CMD' instead"
  run "$CMD"
  ;;
upgrade)
  if sig USR2 && sleep 2 && sig 0 && oldsig QUIT
  then
    n=$TIMEOUT
    while test -s $OLD_PIN && test $n -ge 0
    do
      printf '.' && sleep 1 && n=$(( $n - 1 ))
    done
    echo

    if test $n -lt 0 && test -s $OLD_PIN
    then
      echo >&2 "$OLD_PIN still exists after $TIMEOUT seconds"
      exit 1
    fi
    exit 0
  fi
  echo >&2 "Couldn't upgrade, starting '$CMD' instead"
  run "$CMD"
  ;;
reopen-logs)
  sig USR1
  ;;
*)
  echo >&2 "Usage: $0 <start|stop|restart|upgrade|force-stop|reopen-logs>"
  exit 1
  ;;
esac
CODE

run "chmod +x config/unicorn_init.sh"

run "wget --no-check-certificate 'https://raw.github.com/svenfuchs/rails-i18n/master/rails/locale/es-PE.yml' -O config/locale/es.yml"
run "wget --no-check-certificate 'https://gist.github.com/Theby/8278002/raw/81666c5519aa2adaf0957ac90dff58d1522968e4/devise.es.yml' -O config/locale/devise.es.yml"

