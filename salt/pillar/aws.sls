key_name: ryanlanepersonal
account_id: 435973743168
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
domain: ryandlane.com
ami:
  useast1:
    hvm:
      trusty: ami-2fee0b39
      xenial: ami-9dcfdb8a
