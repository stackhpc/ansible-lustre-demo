
from ansible import errors

def add_device_ids(d, devices):
    if 'device' in d:
        return d
    if 'id' not in d:
        raise errors.AnsibleFilterError("Neither key 'device' or 'id' found in dictionary %s" % d)
    # todo: handle key error
    path = devices[d['id']]
    d['device'] = path
    return d
    
class FilterModule(object):

    def filters(self):
        return {
            'add_device_ids': add_device_ids
        }
