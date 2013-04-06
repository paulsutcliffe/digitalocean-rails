remove_file "README.rdoc"
create_file "README.md", "TODO"

get "https://raw.github.com/paulsutcliffe/digitalocean-rails/master/public/humans.txt", "public/humans.txt"

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

gem "rspec-rails", group: [:test, :development]
run "bundle install"
generate "rspec:install"

if yes? "Do you want to generate a root controller?(yes/no)"
  name = ask("What should it be called?").underscore
  generate :controller, "#{name} index"
  route "root to: '#{name}\#index'"
  remove_file "public/index.html"
end

if yes? "Do you want to install devise?(yes/no)"
  gem 'devise'
  run "bundle install"
  generate 'devise:install'
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
else
append_file "app/views/layouts/application.html.haml", <<-CODE
    = #render 'shared/google_analytics'
CODE
end

#Setup extra gems
gsub_file 'Gemfile', /# gem 'capistrano'/, 'gem "capistrano"'
gsub_file 'Gemfile', /# gem 'unicorn'/, 'gem "unicorn"'

run "capify ."

#git :init
#append_file ".gitignore", "config/database.yml"
#run "cp config/database.yml config/example_database.yml"
#git add: ".", commit: "-m 'initial commit'"
