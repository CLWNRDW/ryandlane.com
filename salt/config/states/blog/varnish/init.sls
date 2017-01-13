Ensure varnish is installed:
  pkg.installed:
    - name: varnish

Ensure varnish is running:
  service.running:
    - name: varnish
    - enable: true

Ensure varnish default is configured:
  file.managed:
    - name: /etc/default/varnish
    - source: salt://blog/varnish/default
    - listen_in:
        - service: varnish

Ensure varnish is configured:
  file.managed:
    - name: /etc/varnish/default.vcl
    - source: salt://blog/varnish/default.vcl
    - listen_in:
        - service: varnish
