remove_file "README.rdoc"
create_file "README.md", "TODO"

#Replace the layout for a Haml layout
run "rm app/views/layouts/application.html.erb"
#get "https://raw.github.com/paulsutcliffe/digitalocean-rails/master/app/views/layouts/application.html.haml", "app/views/layouts/application.html.haml"

#get "https://raw.github.com/paulsutcliffe/digitalocean-rails/master/public/humans.txt", "public/humans.txt"

#Setup extra gems
gsub_file 'Gemfile', /# gem 'capistrano'/, 'gem "capistrano"'
gsub_file 'Gemfile', /# gem 'unicorn'/, 'gem "unicorn"'
gem 'haml'
gem 'haml-rails'
gem 'will_paginate'
gem 'inherited_resources'
gem "rspec-rails", group: [:test, :development]

#Setup the database
run "rm config/database.yml"

db_user = ask("Please enter your local mysql user")
db_password = ask("Please enter your local mysql password")

file "config/database.yml", <<-CODE
defaults: &defaults
  adapter: mysql2
  encoding: utf8
  reconnect: false
  pool: 5
  username: #{db_user}
  password: #{db_password}
  socket: /tmp/mysql.sock

development:
  database: #{app_name.camelize(:lower)}_development
  <<: *defaults

test: &test
  database: #{app_name.camelize(:lower)}_test
  <<: *defaults

production:
  host: localhost
  database: #{app_name.camelize(:lower)}_production
  <<: *defaults
CODE

rake "db:create"

#Install the gems
if yes? "Do you want to install devise?(yes/no)"
  gem 'devise'
  run "bundle install"
  generate 'devise:install'
else
  run "bundle install"
end
generate "rspec:install"

if yes? "Do you want to generate a root controller?(yes/no)"
  name = ask("What should it be called?").underscore
  generate :controller, "#{name} index"
  route "root to: '#{name}\#index'"
  remove_file "public/index.html"
end

# Setup Google Analytics
if ask("Do you have Google Analytics key? (N/y)").upcase == 'Y'
  ga_key = ask("Please provide your Google Analytics tracking key: (e.g UA-XXXXXX-XX)")
else
  ga_key = nil
end

file "app/views/shared/_google_analytics.html.erb", <<-CODE
<script type="text/javascript" charset="utf-8">
  var _gaq = _gaq || [];
  _gaq.push(['_setAccount', '#{ga_key || "INSERT-URCHIN-CODE"}']);
  _gaq.push(['_trackPageview']);

  (function() {
    var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
    ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
    var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
  })();
</script>
CODE

if ga_key
append_file "app/views/layouts/application.html.haml", <<-CODE
    = render 'shared/google_analytics'
CODE
end

#Capistrano for deploying on Digital Ocean Ubuntu Ngnix + Unicorn
run "capify ."
run "rm config/deploy.rb"

cap_server = ask("Please enter your server url")
cap_user = ask("Please enter your server's username")
application = '#{application}'
command = '#{command}'
user = '#{user}'
current_path = '#{current_path}'
shared_path = '#{shared_path}'
release_path = '#{release_path}'
github_user = ask ("Please enter your Github's username")

file "config/deploy.rb", <<-CODE
require "bundler/capistrano"

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

after "deploy", "deploy:cleanup" # keep only the last 5 releases

namespace :deploy do
  %w[start stop restart].each do |command|
    desc "#{command} unicorn server"
    task command, roles: :app, except: {no_release: true} do
      run "/etc/init.d/unicorn_#{application} #{command}"
    end
  end

  task :setup_config, roles: :app do
    sudo "ln -nfs #{current_path}/config/nginx.conf /etc/nginx/sites-enabled/#{application}"
    sudo "ln -nfs #{current_path}/config/unicorn_init.sh /etc/init.d/unicorn_#{application}"
    run "mkdir -p #{shared_path}/config"
    put File.read("config/database.example.yml"), "#{shared_path}/config/database.yml"
    puts "Now edit the config files in #{shared_path}."
  end
  after "deploy:setup", "deploy:setup_config"

  task :symlink_config, roles: :app do
    run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
  end
  after "deploy:finalize_update", "deploy:symlink_config"

  desc "Make sure local git is in sync with remote."
  task :check_revision, roles: :web do
    unless `git rev-parse HEAD` == `git rev-parse origin/master`
      puts "WARNING: HEAD is not the same as origin/master"
      puts "Run `git push` to sync changes."
      exit
    end
  end
  before "deploy", "deploy:check_revision"
end
CODE

#Nginx Configuration files
file "config/nginx.conf", <<-CODE
upstream unicorn {
  server unix:/tmp/unicorn.#{app_name.camelize(:lower)}.sock fail_timeout=0;
}

server {
  listen 80 default deferred;
  server_name #{cap_server};
  root /var/www/app_name.camelize(:lower)/current/public;

  location ^~ /assets/ {
    gzip_static on;
    expires max;
    add_header Cache-Control public;
  }

  try_files $uri/index.html $uri @unicorn;
  location @unicorn {
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_redirect off;
    proxy_pass http://unicorn;
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

listen "/tmp/unicorn.blog.sock"
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

git :init
append_file ".gitignore", "config/database.yml"
run "cp config/database.yml config/database.example.yml"
git add: ".", commit: "-m 'initial commit'"
git push origin master
if yes? "Do you want to deploy:setup?(yes/no)"
  cap deploy:setup
end
