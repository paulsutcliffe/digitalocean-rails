digitalocean-rails
==================

Template for Ruby on Rails apps on Digital Ocean

1. Install Nginx
sudo apt-get install nginx
sudo service nginx start
ifconfig eth0 | grep inet | awk '{ print $2 }'
update-rc.d nginx defaults
System start/stop links for /etc/init.d/nginx already exist.

2. Install Mysql
sudo apt-get update
sudo apt-get install mysql-server
sudo mysql_install_db
sudo /usr/bin/mysql_secure_installation
sudo apt-get install libmysqlclient-dev

3.Install Node.js
sudo apt-get install nodejs

4.
