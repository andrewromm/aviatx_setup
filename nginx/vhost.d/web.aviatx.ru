location /static/ {
  alias /home/app/web/static/;
  add_header Access-Control-Allow-Origin *;
}

location /media/ {
  alias /home/app/web/media/;
  add_header Access-Control-Allow-Origin *;
}