FROM nginx:1.16-alpine

WORKDIR /var/www/black_candy

COPY ./public public/

COPY ./config/nginx/ /etc/nginx

EXPOSE 80

CMD [ "nginx", "-g", "daemon off;" ]
