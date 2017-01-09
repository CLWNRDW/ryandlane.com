# Currently one vpc per region
{% if grains.region == 'useast1' %}
{% set aws_region = 'us-east-1' %}
vpc:
  vpc_id: vpc-ea50fc8f
  # Keep the ordering of these subnets and azs in sync; they match.
  vpc_subnets:
    - 'subnet-62c40815'
    - 'subnet-8ef917d7'
    - 'subnet-d43f31fc'
  vpc_azs:
    - us-east-1a
    - us-east-1d
    - us-east-1e
{% endif %}

primary_profile:
  region: {{ aws_region }}

key_name: ryanlanepersonal
aws_account_id: 435973743168
domain: ryandlane.com
ami:
  useast1:
    hvm:
      trusty: ami-2fee0b39
      xenial: ami-9dcfdb8a
