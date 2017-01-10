Ensure awscli is installed:
  virtualenv.managed:
    - name: /srv/awscli/venv
    - use_wheel: True
    - pip_pkgs:
        - 'awscli==1.11.36'
