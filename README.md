# Docker PHP-FPM 7.4 & Nginx 1.18.0 on Ubuntu 20.04 LTS

Build on [Ubuntu](https://ubuntu.com/).

You can put your code in src folder.

Usage
-----
Start the Docker containers:

Docker Compose:

```
version: "2"
networks:
  default:
    external:
      name: default-network
services:
  eraste:
    image: ramadhan/docker-php7.4-nginx-ubuntu:latest
    container_name: "yourcontainer-name"
    ports:
      - "80:80"
    privileged: true
    volumes:
      - "..:/home/projects/yourpath:cached"
      - ".:/etc/nginx/conf.d:cached"
    environment:
      - "DOMAIN_1=yourdomain.test|/home/projects/yourdomain|notssl"
```


