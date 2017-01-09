{% if salt['environ.get']('CLUSTER_NAME') %}
{# initial bootstrapping, set hostname and setup /etc/hosts #}
{% set hostname = '{0}-{1}'.format(salt['environ.get']('CLUSTER_NAME'), grains['ec2_instance-id']) %}
{% set domain = salt['environ.get']('DOMAIN') %}
{% set fqdn = '{0}.{1}'.format(hostname, domain) %}
Ensure hostname is set in /etc/hosts:
  host.present:
    - ip:
      - 127.0.1.1
    - names:
      - {{ fqdn }}
      - {{ hostname }}

Ensure /etc/hostname is set:
  file.managed:
    - name: /etc/hostname
    - contents: {{ hostname }}

Ensure hostname is set:
  cmd.run:
    - name: hostname {{ hostname }}
    - unless: hostname | grep {{ hostname }}
    - reload_grains: True
{% endif %}

Ensure basic dependencies are installed:
  pkg.installed:
    - pkgs:
      - git-core
    - reload_modules: True

# Salt and salt dependencies
Ensure python dependencies are installed:
  pkg.installed:
    - pkgs:
      - python-virtualenv
      - python-pip
      - python-apt
      - python-dev
    - reload_modules: True

Ensure salt virtualenv is managed:
  virtualenv.managed:
    - name: /srv/salt/venv
    # Switch to the existing salt venv
    - pip_exists_action: s
    - system_site_packages: True
    - requirements: /srv/ryandlane.com/requirements.txt
    - reload_modules: True

Ensure salt-call link exists:
  file.symlink:
    - name: /usr/local/bin/salt-call
    - target: /srv/salt/venv/bin/salt-call

Ensure salt-minion configuration exists:
  file.managed:
    - name: /etc/salt/minion
    - source: salt://startup/salt/minion
    - makedirs: True
