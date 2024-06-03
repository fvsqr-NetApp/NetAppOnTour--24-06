# Nginx
copy retrogames.conf to /etc/nginx/sites-available/retrogames.conf
```
sudo ln -d /etc/nginx/sites-available/retrogames.conf /etc/nginx/sites-enabled/retrogames.conf
sudo rm -f /etc/nginx/sites-enabled/default
sudo service nginx stop
sudo service nginx start
```
