job "hw" {
  datacenters = ["dc1"]
  type = "service"
  group "hw" {
    count = 1
    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }
    volume "hw" {
      type      = "host"
      read_only = false
      source    = "hw"
    }
    task "nginx" {
      driver = "docker"
      volume_mount {
        volume      = "hw"
        destination = "/usr/share/nginx/html"
      }
      config {
        image = "nginx:latest"
        port_map {
          app = 80
        }
        volumes = [
          "nginx-conf:/etc/nginx/conf.d/",
        ]
      }
      template {
        data = <<EOH
        server {
          server_name _;
          listen 80;
          root /usr/share/nginx/html;

          error_log  /var/log/nginx/error.log;
          access_log /var/log/nginx/access.log;
          index index.php index.html index.htm;

          location ~ /\.ht { deny  all; }
          location ~ /\. { deny all; access_log off; log_not_found off; }

          location / {
            try_files $uri $uri/ /index.php?$query_string;
          }

          #    location ~* ^.+\.(jpg|jpeg|gif|png|ico|svg|css|zip|tgz|gz|rar|bz2|exe|pdf|doc|xls|ppt|txt|odt|ods|odp|odf|tar|bmp|rtf|js|mp3|avi|mpeg|flv|html|htm)$ {
          #        root           /code/public;
          #        expires        max;
          #        try_files      $uri $uri/ /index.php?$query_string;
          #    }

          location ~ \.php$ {
            try_files $uri =404;
            fastcgi_split_path_info ^(.+\.php)(/.+)$;
            fastcgi_pass {{range service "php-fpm"}} {{.Address}}:{{.Port}}{{end}};
            fastcgi_index index.php;
            include fastcgi_params;
            #fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            fastcgi_param SCRIPT_FILENAME /var/www/html$fastcgi_script_name;
            fastcgi_param PATH_INFO $fastcgi_path_info;
          }
        }
 
        EOH

        destination = "nginx-conf/default.conf"
      }
      resources {
        cpu = 500 
        memory = 128
        network {
          mbits = 10
          port "app" {}
        }
      }
      service {
        name = "${TASKGROUP}-nginx"
        tags = ["global", "dc1", "nginx"]
        port = "app"
        tags = [
          "traefik.tags=service",
          "traefik.frontend.entryPoints=http,https",
          "traefik.frontend.rule=Host:hello.2327.ru"
        ]
        check {
          name = "alive"
          type = "tcp"
          interval = "10s"
          timeout = "2s"
        }
      }
    }
    task "php-fpm" {
      driver = "docker"
      volume_mount {
        volume      = "hw"
        destination = "/var/www/html"
      }

      config {
        image = "php:7.4-fpm"
        port_map {
          php = 9000
        }
        volumes = [
	  "msmtp-conf:/etc/",
        ]

      }
      template {
        data = <<EOH
          account mail_account
          tls on
          tls_starttls off
          tls_certcheck off
          auth on
          host smtp.example.ltd
          port 465
          user mail@example.ltd
          from mail@example.ltd
          password pAs$wR0d
          EOH

        destination = "msmtp-conf:msmtp.conf"
      }
      resources {
        cpu    = 500
        memory = 128
        network {
          port "php" {}
        }
      }
      service {
        name = "php-fpm"
        tags = ["global", "dc1", "php-fpm"]
        port = "php"
        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }

    task "mysql-server" {
      driver = "docker"
      env = {
          "MYSQL_ROOT_PASSWORD" = "secret"
      }
      config {
        image = "mysql/mysql-server:8.0"
        port_map {
          db = 3306
        }
        volumes = [
          "docker-entrypoint-initdb.d/:/docker-entrypoint-initdb.d/",
          "name=mysql,size=10,repl=3/:/var/lib/mysql"
        ]
      }
      template {
        data = <<EOH
        CREATE DATABASE db;
        CREATE USER 'db'@'%' IDENTIFIED BY 'db';
        GRANT ALL PRIVILEGES ON db.* TO 'db'@'%';
        EOH

        destination = "docker-entrypoint-initdb.d/db.sql"
      }
#      volume_mount {
#        volume      = "mysql"
#        destination = "/var/lib/mysql"
#        read_only   = false
#      }
      resources {
        cpu    = 500
        memory = 512
        network {
          port "db" {}
        }
      }
      service {
        name = "${TASKGROUP}-mysql-server"
        tags = ["global", "dc1", "mysql-server"]
        port = "db"
        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}

