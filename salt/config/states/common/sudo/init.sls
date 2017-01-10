Ensure sudoers configuration exists:
  file.managed:
    - name: /etc/sudoers
    - source: salt://common/sudo/sudoers
    - template: jinja
    - mode: 440
