{% for name, user in pillar.get('users', {}).items() %}
Ensure human user {{ name }} exist:
  user.present:
    - name: {{ name }}
    - uid: {{ user.id }}
    - gid_from_name: True
    - shell: /bin/bash
    - createhome: True
    - password: '*'
    - fullname: {{ user.full_name }}
    {% if user.get('disabled', False) %}
    - expire: 1
    {% endif %}

{% if 'ssh_key' in user and not user.get('disabled', False) %}
Ensure authorized_keys for {{ name }} is present:
  file.managed:
    - name: /home/{{ name }}/.ssh/authorized_keys
    - contents_pillar: users:{{ name }}:ssh_key
    - user: {{ name }}
    - group: {{ name }}
    - mode: 600
    - dir_mode: 700
    - makedirs: True
{% else %}
Ensure authorized_keys for {{ name }} is absent:
  file.absent:
    - name: /home/{{ name }}/.ssh/authorized_keys
{% endif %}

{% if 'ssh_private_key' in user %}
Ensure ssh private key for {{ name }} is present:
  file.managed:
    - name: /home/{{ name }}/.ssh/id_rsa
    - contents_pillar: users:{{ name }}:ssh_private_key
    - user: {{ name }}
    - group: {{ name }}
    - mode: 600
    - dir_mode: 700
    - makedirs: True
{% else %}
Ensure ssh private key for {{ name }} is absent:
  file.absent:
    - name: /home/{{ name }}/.ssh/id_rsa
{% endif %}

Ensure mail alias for {{ name }} is set:
  alias.present:
    - name: {{ name }}
    - target: {{ user.email }}
{% endfor %}

