{% for name, user in pillar.users.items() if 'iam_groups' in user %}
{% if not user.get("disabled", False) %}
# Temporarily disabled.
#Ensure iam user {{name}} is present:
#  boto_iam.user_present:
#    - name: {{name}}
#    - profile: primary_profile
{% endif %}
{% endfor %}

Ensure Admin iam role exists:
  boto_iam_role.present:
    - name: Admin
    - policies:
        'admin_role':
          Version: '2012-10-17'
          Statement:
            - Action: "*"
              Effect: Allow
              Resource: "*"
    - policy_document:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              AWS: 'arn:aws:iam::{{ pillar.aws_account_id }}:root'
            Action: 'sts:AssumeRole'
    - create_instance_profile: False
    - profile: primary_profile

Ensure iam group AssumeAdmin is present:
  boto_iam.group_present:
    - name: AssumeAdmin
    - users:
        {% for username, user in pillar.users.items() if 'iam_groups' in user and 'AssumeAdmin' in user['iam_groups'] %}
        - {{username}}
        {% endfor %}
    - policies:
        assume_admin_policy:
          Statement:
            - Action: "sts:AssumeRole"
              Effect: Allow
              Resource: "arn:aws:iam::{{ pillar.aws_account_id }}:role/Admin"
              Condition:
                Bool:
                  "aws:MultiFactorAuthPresent": "true"
    - profile: primary_profile

Ensure iam group HumanUsers is present:
  boto_iam.group_present:
    - name: HumanUsers
    - users:
        {% for username, user in pillar.users.items() if 'iam_groups' in user and 'HumanUsers' in user['iam_groups'] %}
        - {{username}}
        {% endfor %}
    - policies:
        HumanUserPolicy:
          Version: "2012-10-17"
          Statement:
            # Make the AWS console sort of work
            - Action:
                - "iam:ListAccountAliases"
                - "iam:GetAccountSummary"
                - "iam:ListUsers"
              Effect: Allow
              Resource: "*"
            - Action:
                - "iam:ListServerCertificates"
                - "iam:GetServerCertificate"
              Effect: Allow
              Resource: "*"
            # Account self-service
            - Action:
                - "iam:ChangePassword"
                - "iam:GetAccountPasswordPolicy"
                - "iam:List*"
                - "iam:Get*"
              Effect: Allow
              Resource: "arn:aws:iam::{{ pillar.aws_account_id }}:user/${aws:username}"
            # Access key and login profile self-service
            - Action:
                - "iam:CreateAccessKey"
                - "iam:DeleteAccessKey"
                - "iam:UpdateAccessKey"
                - "iam:CreateLoginProfile"
                - "iam:DeleteLoginProfile"
                - "iam:UpdateLoginProfile"
              Effect: Allow
              Resource: "arn:aws:iam::{{ pillar.aws_account_id }}:user/${aws:username}"
              Condition:
                Bool:
                  "aws:MultiFactorAuthPresent": "true"
            # MFA self-service
            - Action:
                - "iam:CreateVirtualMFADevice"
                - "iam:EnableMFADevice"
                - "iam:ListMFADevices"
                - "iam:ListVirtualMFADevices"
              Effect: Allow
              Resource:
                - "arn:aws:iam::{{ pillar.aws_account_id }}:mfa/${aws:username}"
                - "arn:aws:iam::{{ pillar.aws_account_id }}:user/${aws:username}"
            - Action:
                - "iam:DeactivateMFADevice"
                - "iam:DeleteVirtualMFADevice"
                - "iam:ResyncMFADevice"
              Effect: Allow
              Resource:
                - "arn:aws:iam::173840052742:mfa/${aws:username}"
                - "arn:aws:iam::173840052742:user/${aws:username}"
              Condition:
                Bool:
                  "aws:MultiFactorAuthPresent": "true"
    - profile: primary_profile

{% for name, user in pillar.users.items() %}
{% if user.get("disabled", False) or not user.get("iam_groups", []) %}
Ensure iam user {{name}} is absent:
  boto_iam.user_absent:
    - delete_keys: True
    - delete_mfa_devices: True
    - delete_profile: True
    - name: {{name}}
    - profile: primary_profile
{% endif %}
{% endfor %}
