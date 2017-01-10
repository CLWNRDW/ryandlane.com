Ensure nfs-common is installed:
  pkg.installed:
    - name: nfs-common

Ensure content mount is mounted:
  mount.mounted:
    - name: /srv/content
    - device: fs-57fa201e.efs.us-east-1.amazonaws.com:/
    - fstype: nfs4
    - mkmnt: True
    - opts:
        - rsize=1048576
        - wsize=1048576
        - hard
        - timeo=600
        - retrans=2
        - nfsvers=4.1
