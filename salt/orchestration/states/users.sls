{% for name, user in pillar.users.items() if 'iam_groups' in user %}
{% if not user.get("disabled", False) %}
# Temporarily disabled.
#Ensure iam user {{name}} is present:
#  boto_iam.user_present:
#    - name: {{name}}
{% endif %}
{% endfor %}

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
            # Account self-service
            - Action:
                - "iam:*LoginProfile"
                - "iam:*AccessKey*"
                - "iam:ChangePassword"
                - "iam:GetAccountPasswordPolicy"
                - "iam:*MFADevice"
                - "iam:List*"
                - "iam:Get*"
              Effect: Allow
              Resource: "arn:aws:iam::{{ pillar.account_id }}:user/${aws:username}"
            # MFA self-service
            - Action:
                - "iam:*MFADevice"
              Effect: Allow
              Resource: "arn:aws:iam::{{ pillar.account_id }}:mfa/${aws:username}"
            - Action:
                - "iam:ListVirtualMFADevices"
                - "iam:ListMFADevices"
              Effect: Allow
              Resource: "arn:aws:iam::{{ pillar.account_id }}:mfa/*"
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
              Resource: "arn:aws:iam::{{ pillar.account_id }}:role/admin"
              Condition:
                Bool:
                  "aws:MultiFactorAuthPresent": "true"

Ensure admin iam role exists:
  boto_iam_role.present:
    - name: admin
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
              AWS: 'arn:aws:iam::{{ pillar.account_id }}:root'
            Action: 'sts:AssumeRole'
    - create_instance_profile: False

{% for name, user in pillar.users.items() %}
{% if user.get("disabled", False) or not user.get("iam_groups", []) %}
Ensure iam user {{name}} is absent:
  boto_iam.user_absent:
    - delete_keys: True
    - delete_mfa_devices: True
    - delete_profile: True
    - name: {{name}}
{% endif %}
{% endfor %}
