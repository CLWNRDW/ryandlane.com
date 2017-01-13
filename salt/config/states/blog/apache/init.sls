Ensure apache2 packages are installed:
  pkg.installed:
    - names:
        - apache2
        - apache2-mpm-prefork
        - apache2-utils

Ensure php packages are installed:
  pkg.installed:
    - names:
        - libapache2-mod-php7.0
        - php7.0
        - php7.0-common
        - php7.0-cli
        - php7.0-curl
        - php7.0-mysql
        - php7.0-gmp
        - php7.0-tidy
        - php-openid
        - php-apcu
        - php-memcached

Ensure apache2 is running:
  service.running:
    - name: apache2
    - enable: true

Ensure ports is configured:
  file.managed:
    - name /etc/apache2/ports.conf
    - source: salt://blog/apache/ports.conf
    - listen_in:
        - service: apache2

Ensure default site is absent:
  file.absent:
    - name /etc/apache2/sites-enabled/000-default.conf
    - listen_in:
        - service: apache2

{% for site in ['ryandlane', 'alexborges'] %}
Ensure {{ site }} site is available:
  file.managed:
    - name: /etc/apache2/sites-available/{{ site }}
    - source: salt://blog/apache/{{ site }}
    - listen_in:
        - service: apache2

Ensure {{ site }} site is enabled:
  file.symlink:
    - name: /etc/apache2/sites-enabled/{{ site }}
    - target: /etc/apache2/sites-available/{{ site }}
    - listen_in:
        - service: apache2
{% endfor %}
