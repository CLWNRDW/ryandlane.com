{% for var in ['service_name', 'service_instance', 'region', 'workers'] %}
{% if not grains.get(var, None) %}
{{ var.upper() }} environment variable check:
    test.configurable_test_state:
        - name: {{ var.upper() }} environment variable not set
        - comment: {{ var.upper() }} environment variable must be set
        - failhard: True
        - changes: False
        - result: False
{% endif %}
{% endfor %}

Ensure elb-external security group exists:
  boto_secgroup.present:
    - name: elb-external
    - description: elb-external
    - rules:
        - ip_protocol: tcp
          from_port: 80
          to_port: 80
          cidr_ip:
            - 0.0.0.0/0
        - ip_protocol: tcp
          from_port: 443
          to_port: 443
          cidr_ip:
            - 0.0.0.0/0
    - vpc_id: {{ pillar.vpc.vpc_id }}
    - profile: primary_profile

Ensure {{ grains.service_name }} security group exists:
  boto_secgroup.present:
    - name: {{ grains.service_name }}
    - description: {{ grains.service_name }}
    - rules:
        - ip_protocol: tcp
          from_port: 80
          to_port: 80
          source_group_name: elb-external
    - vpc_id: {{ pillar.vpc.vpc_id }}
    - profile: primary_profile

Ensure {{ grains.iam_role_name }} role exists:
  boto_iam_role.present:
    - name: {{ grains.iam_role_name }}
    - policies:
        'bootstrap':
          Version: '2012-10-17'
          Statement:
            # Allow nodes to register/deregister themselves from ELB
            - Action: 'elasticloadbalancing:Describe*'
              Effect: 'Allow'
              Resource:
                - '*'
            - Action:
                - 'elasticloadbalancing:DeregisterInstancesFromLoadBalancer'
                - 'elasticloadbalancing:RegisterInstancesWithLoadBalancer'
              Effect: 'Allow'
              Resource:
                - 'arn:aws:elasticloadbalancing:*:*:loadbalancer/{{ grains.workers.web.cluster_name }}*'
            # Add S3 policy for artifact-based trebuchet mode
            - Action:
                - 's3:Head*'
                - 's3:Get*'
              Effect: 'Allow'
              Resource:
                - 'arn:aws:s3:::rlane32-infra/deploy/{{ grains.service_name }}/*'
                - 'arn:aws:s3:::rlane32-infra/bootstrap/*'
            - Action:
                - 's3:List*'
                - 's3:Get*'
              Effect: 'Allow'
              Resource:
                - 'arn:aws:s3:::rlane32-infra'
              Condition:
                StringLike:
                  's3:prefix':
                    - 'deploy/{{ grains.service_name }}/*'
                    - 'bootstrap/*'
            - Action:
                - 'ec2:DescribeTags'
              Effect: 'Allow'
              Resource:
                - '*'
    - profile: primary_profile

Ensure {{ grains.workers.web.cluster_name }} elb exists:
  boto_elb.present:
    - name: {{ grains.workers.web.cluster_name }}
    - listeners:
        - elb_port: 80
          instance_port: 80
          elb_protocol: HTTP
    - health_check:
        target: 'HTTP:80/healthcheck'
    - subnets:
      {% for subnet in pillar.vpc.vpc_subnets %}
      - {{ subnet }}
      {% endfor %}
    - security_groups:
        - elb-external
    - cnames:
        - name: blog.{{ pillar.domain }}.
          zone: {{ pillar.domain }}.
    - attributes: []
    - profile: primary_profile

Ensure {{ grains.workers.web.cluster_name }} asg exists:
  boto_asg.present:
    - name: {{ grains.workers.web.cluster_name }}
    - launch_config_name: {{ grains.workers.web.cluster_name }}
    - launch_config:
      - image_id: {{ salt['pillar.get']('ami:{0}:hvm:xenial'.format('useast1')) }}
      - key_name: {{ pillar.key_name }}
      - security_groups:
        - base
        - {{ grains.service_name }}
      - instance_profile_name: {{ grains.iam_role_name }}
      - instance_type: t2.tiny
      - associate_public_ip_address: True
      - cloud_init:
          scripts:
            salt: |
              #!/bin/bash
              set -e

              handle_error() {
                  echo "ERROR: line $1, exit code $2"
                  exit 1
              }

              trap 'handle_error $LINENO $?' ERR

              # TODO: make a bootstrap artifact with salt, config and some
              # scripts to automate all of this.
              apt-get -y update
              apt-get install -y build-essential libssl-dev python-dev python-m2crypto \
              python-pip python-virtualenv python-zmq python-crypto swig virtualenvwrapper \
              git-core
              
              mkdir -p /srv/salt/venv
              virtualenv --system-site-packages /srv/salt/venv
              git clone https://github.com/ryan-lane/ryandlane.com.git /srv/ryandlane.com
              . /srv/salt/venv/bin/activate
              pip install -r /srv/ryandlane.com/requirements.txt
              deactivate
              export DOMAIN="{{ pillar.domain }}"
              /srv/salt/venv/bin/salt-call --local -c /srv/ryandlane.com/salt/config/states/startup/salt state.sls startup
              salt-call state.highstate
              salt-call grains.setval elbs "['{{ grains.workers.web.cluster_name }}']"
              salt-call state.sls elb.register
    - vpc_zone_identifier: {{ pillar.vpc.vpc_subnets }}
    - availability_zones: {{ pillar.vpc.vpc_azs }}
    - min_size: 1
    - max_size: 1
    - desired_capacity: 1
    - tags:
      # Adding a name tag makes it easier to identify the ASG nodes in the
      # instances list.
      - key: 'Name'
        value: '{{ grains.workers.web.cluster_name }}'
        propagate_at_launch: true
    - profile: primary_profile

Ensure {{ grains.iam_role_name }} RDS subnet group exists:
  boto_rds.subnet_group_present:
    - name: {{ grains.iam_role_name }}
    - subnet_ids: {{ pillar.vpc.vpc_subnets }}
    - description: {{ grains.iam_role_name }} RDS subnet group
    - profile: primary_profile

#Ensure {{ grains.iam_role_name }} RDS exists:
#  boto_rds.present:
#    - name: {{ grains.iam_role_name }}
#    - allocated_storage: 5
#    - storage_type: gp2
#    - db_instance_class: db.t2.micro
#    - engine: MySQL
#    - master_username: TODO
#    - master_user_password: TODO
#    - multi_az: True
#    - db_subnet_group_name: {{ grains.iam_role_name }}
#    - publicly_accessible: False
#    - vpc_security_group_ids: 
#      - {{ grains.iam_role_name }}
#    - backup_retention_period: 14
#    - wait_status: available
#    - profile: primary_profile
