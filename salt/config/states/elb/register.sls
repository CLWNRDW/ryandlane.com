{% for elb in grains.get('elbs', []) %}
Ensure the node is registered with {{elb}} ELB:
  module.run:
    - name: boto_elb.register_instances
    - m_name: {{ elb }}
    - instances: {{ grains['ec2_instance-id'] }}
    - region: {{ grains['ec2_region'] }}
{% endfor %}
