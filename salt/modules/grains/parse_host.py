'''
Set service_*, and region grains based on the hostname or ec2 Name tag.
'''
import re
import salt.utils.network
import os.path
import yaml
import logging

log = logging.getLogger(__name__)


def _grains_defined_in_file():
    if not os.path.isfile('/etc/salt/grains'):
        return False
    else:
        with open('/etc/salt/grains') as f:
            grain_data = f.read()
            grains = yaml.safe_load(grain_data)
            if 'no_parse_host' in grains:
                return True
    return False


def _get_match(name):
    # Example: blog-web-production-useast1-h80hj90.example.com
    name_regex = '^(\w+)-(\w+)-(\w+)-(\w+)-(\w+)($|\.{1})'
    match = re.match(name_regex, name)
    return match


def parse_host():
    # Some entrypoints set grains in the files.
    if _grains_defined_in_file():
        return {}
    # Get the grains from the hostname if it's set and matches our convention.
    name = salt.utils.network.get_fqhostname()
    match = _get_match(name)
    if not match:
        log.error("Could not parse hostname: no pattern match found.")
        return {}
    group_len = len(match.groups())
    if group_len == 6:
        service_name = match.group(1)
        sub_service_name = match.group(2)
        service_instance = match.group(3)
        region = match.group(4)
        service_node = match.group(5)
    else:
        log.error("Could not parse hostname: invalid format. Incorrect"
                  " number of parts ({0}).".format(group_len))
        return {}
    service_group = '{0}-{1}'.format(service_name, service_instance, region)
    cluster_name = '{0}-{1}-{2}-{3}'.format(
        service_name,
        sub_service_name,
        service_instance,
        region
    )
    return {
        'service_name': service_name,
        'sub_service_name': sub_service_name,
        'service_instance': service_instance,
        'region': region,
        'service_node': service_node,
        'service_group': service_group,
        'cluster_name': cluster_name
    }
