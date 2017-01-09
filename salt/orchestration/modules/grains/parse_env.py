'''
Set service_*, and region grains based on environment variables.
'''
import os


def parse_env():
    service_name = os.environ.get('SERVICE_NAME')
    service_instance = os.environ.get('SERVICE_INSTANCE')
    region = os.environ.get('REGION')
    service_group = '{0}-{1}'.format(service_name, service_instance, region)
    iam_role_name = '{0}-{1}'.format(service_group, region)
    workers = {}
    worker_names = os.environ.get('WORKERS', 'web').split(',')
    for worker_name in worker_names:
        workers[worker_name] = {}
        workers[worker_name]['cluster_name'] = '{0}-{1}-{2}-{3}'.format(
            service_name,
            worker_name,
            service_instance,
            region
        )
    return {
        'service_name': service_name,
        'service_instance': service_instance,
        'region': region,
        'service_group': service_group,
        'iam_role_name': iam_role_name,
        'workers': workers
    }
