FROM ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends apache2 libapache2-mod-php php-mysql openssl ca-certificates && rm -rf /var/lib/apt/lists/* && a2enmod ssl rewrite

RUN mkdir -p /etc/apache2/ssl /var/www/http /var/www/https \
    && openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
       -keyout /etc/apache2/ssl/site-https.key \
       -out /etc/apache2/ssl/site-https.crt \
       -subj "/CN=site-https.local"

COPY apache/http.conf /etc/apache2/sites-available/http.conf
COPY apache/https.conf /etc/apache2/sites-available/https.conf
COPY sites/http/ /var/www/http/
COPY sites/https/ /var/www/https/
RUN a2dissite 000-default && a2ensite http https && chown -R www-data:www-data /var/www/http /var/www/https

EXPOSE 80 443
CMD ["apachectl", "-D", "FOREGROUND"]
