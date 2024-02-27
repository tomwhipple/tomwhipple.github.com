---
layout: post
title: Docker Compose + nginx + uWSGI
---
I've been working on a personal project that serves static video files alongside a Python API and AI backend (more on that in the future). Each component is it's own [Docker](https://www.docker.com) container, managed by [Docker Compose](https://docs.docker.com/compose/).

Philosophically, personal projects should teach modern tools and techniques without causing excessive time to be spent on details that would be important for high traffic applications.

So, to that end, I chose [nginx](https://nginx.org) as a modern option with widespread support and [pyuwsgi](https://uwsgi-docs.readthedocs.io/). (Previously this project had used Lighttpd and FastCGI, but those configurations proved to be troublesome.) I would expect this combination to not be that unusual, but I found few examples, so I will share what's worked for me.

## Component Overview

This application has two basic things to serve: A Flask API, and static MP4 video clips, both served on the same host. Nginx will serve the static files directly, and then proxy the API via the uWSGI protocol to the uWSGI app running in it's own Docker container.

### uWSGI config

Configuration for the uWSGI service is stored in a [`uwsgi.ini`](https://github.com/tomwhipple/camera-watcher/blob/b0fac5f8b2586cda4e0bb3e37f7c978ddd6feaea/etc/uwsgi.ini) file, mostly to separate the concern from the Docker `compose.yaml`, and is pretty simple:

```
uwsgi-socket = :8000
master = true:w
processes = 4
module = api:app
```

The `module` line refers to the `app` variable inside `api.py`.

The main point is that we use `uwsgi-socket` to match the corresponding `uwsgi_pass` directive in the nginx config (below). If we wanted to use an http socket, we'd set `http-socket` here and use `proxy_pass` in the nginx config. Some articles suggest sharing a Docker volume to access a shared unix socket, but that seems brittle as it would require the two docker containers to run on the same host, which seems too strict.

### nginx config

As mentioned above, we want to use the uWSGI protocol between the webserver and application. We then want that application to be mapped to our application directory, in this case `watcher`. The caveat is that we need to rewrite the URL path to remove the `watcher` path, since the application code does not know about that mapping, so we need a URL rewrite. (Without the rewrite rule, the entire URL will be passed to uWSGI just as the client calls it.)

The [relevant `http` section of `ngnix.conf`](https://github.com/tomwhipple/camera-watcher/blob/b0fac5f8b2586cda4e0bb3e37f7c978ddd6feaea/etc/nginx/nginx.conf#L8) is then: 

```
http {

    # ... other boilerplate ...

    upstream api {
        server api:8000;
    }

    server {
    listen 80;

    location /watcher {
        include    uwsgi_params;
        uwsgi_pass api;
        rewrite ^/watcher(/.*)$ $1 break;
    }

    location / {
        root /data/video;
    }

    }
}
```

Here, `server api` refers to the `api` service in the Docker `compose.yaml`. 

### Docker Compose

Now that the above is complete, all that's left is to [configure docker compose](https://github.com/tomwhipple/camera-watcher/blob/b0fac5f8b2586cda4e0bb3e37f7c978ddd6feaea/compose.yaml#L68):

```  
  api:
    build: 
      context: .
      dockerfile: Dockerfile-io
    profiles: ["web"]
    command: uwsgi --ini /usr/local/etc/uwsgi.ini
    volumes:
      - ./data:/data
      - ./log:/var/log
      - ./etc:/usr/local/etc:ro
    environment:
      - WATCHER_CONFIG=/usr/local/etc/watcher.cfg
    
  web:
    image: nginx
    profiles: ["web"]
    volumes:
     - ./data/video:/data/video:ro
     - ./etc/nginx:/etc/nginx:ro
    ports:
     - "80:80"
    environment:
     - NGINX_HOST=example.com
     - NGINX_PORT=80

```

Note that the api container has no `ports` section, since nothing in that container is directly exposed to the world. Rather, the `api` name is mapped on the internal Docker network, which is what we reference in the `nginx.conf` above.

Furthermore, this compose file mounts the `etc` directory from the host, rather than copying it into the container. That's worked for my R&D project, but for environment reproducibility it should be copied in a production environment.

### Run

That's it. All that's left is `docker compose --profile web up -d`. Oh, and write the rest of the app. ;)

