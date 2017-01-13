Ensure varnish is installed:
  pkg.installed:
    - name: varnish

Ensure varnish is running:
  service.running:
    - name: varnish
    - enable: true

Ensure varnish default is configured:
  file.managed:
    - name: /etc/systemd/system/varnish.service.d/override.conf
    - source: salt://blog/varnish/override.conf
    - makedirs: true

Ensure systemd is reloaded on varnish change:
  module.run:
    - name: service.systemctl_reload
    - onchanges:
      - file: /etc/systemd/system/varnish.service.d/override.conf
    - listen_in:
        - service: varnish

Ensure varnish is configured:
  file.managed:
    - name: /etc/varnish/default.vcl
    - source: salt://blog/varnish/default.vcl
    - listen_in:
        - service: varnish
