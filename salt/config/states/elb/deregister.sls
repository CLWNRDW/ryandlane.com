{% for elb in grains.get('elbs', []) %}
Ensure the node is deregistered with {{elb}} ELB:
  module.run:
    - name: boto_elb.deregister_instances
    - m_name: {{ elb }}
    - instances: {{ grains['ec2_instance-id'] }}
    - region: {{ grains['ec2_region'] }}
{% endfor %}
