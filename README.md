Demo of multi-tenant Lustre with re-export to clients via NFS.

# Overview
Required pre-existing infrastructure:
- A "low-latency" RDMA-capable network (modelling the core Lustre network)
- A TCP network (modelling a storage network in a tenancy)

Deployed infrastructure on low-latency network:
- Lustre server:
    - CentOS 7.9
    - LDISKFS MGT/MDT/OST created on ephemeral devices (NB: needs Nova option `max_local_block_devices` < 0 or >= 4).
    - A single Lustre fileysystem, with the following tree:

    ```
        /tenants/
            srcp-foo/
            srcp-bar/
        /csd3/
            project/
                    baz/
                    qux/
    ```

- Lustre admin client - used for mananging the filesystem:
    - Rocky Linux 8.5
    - Nodemap configured with `trusted` and `admin` true to allow root to modify filesystem tree (e.g. add/remove/chown directories)
- Lustre CSD3 client - models a client with fairly-priviledged access to multiple projects:
    - Rocky Linux 8.5
    - Nodemap configured with `trusted` true to allow view of real UIDs/GIDs, but `admin` is false so `root` is squashed to `nobody`.
    - Mounts `/csd3`.
- Lustre/NFS exporter (would be per-tenant):
    - Rocky Linux 8.5
    - Lustre client
    - Kernel NFS server (also RDMA-capable, via configuration)
    - With a port tagged `nfs:lustre` (concept is protocol:filesystem name)
    - Mounts `/csd3/project/baz`

The idea is that a non-lustre-capable client in an isolated tenancy can mount from the NFS exporter. This is demoed in ` portal-nfs-client/` which contains terraform and ansible to create a VM with an NFS client mounting the above exporter.

Note currently the Lustre Lnet is set to `tcp` despite being on a RDMA-capable network as that provided better performance in the Arcus environment.

# Install

On Rocky Linux 8.5

Install ansible:
```
sudo yum -y install python3.9 git
python3.9 -m venv venv
. venv/bin/activate
pip install -r requirements.txt
ansible-galaxy install -p roles/ -r requirements.yml
```

Install terraform:
```
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo yum -y install terraform
cd terraform/
terraform init
```

# Create and configure infrastructure

1. Ensure the following are available on OpenStack:
- A keypair with private key on the deployment host.
- Infrastructure and images as described above.

1. Ensure Openstack credentials are available (e.g. download and source `openrc.sh` file).

1. Review the variables defined in `terraform/main.tf` and `terraform/csd3.tf` and modify as appropriate, then run terraform to create the infrastructure:

    ```
    cd terraform/
    terraform apply
    ```

    As well as creating the VMs this will also create an ansible inventory file `inventory/hosts`.

1. Review the ansible variables in `inventory/group_vars` and modify as apppropriate, then run ansible to install and configure Lustre servers/clients and NFS server:
    
    ```
    ansible-playbook site.yml
    ```

    **NB:** the first time (only) append `-e lustre_format_force=true` as the server VM is created with ext4-formatted ephermeral disks (despite asking not to). This will reformat the devices specified by the `lustre_format_{mgs,mdts,osts}` variables so use with caution!

1. Create a `grafana_password` in e.g. `inventory/group_vars/all/secrets.yml` and then run:

    ```
    ansible-playbook monitoring.yml
    ```

# Utility playbooks and scripts:

- `client-mount.yml`: Change mount state of all Lustre clients. Useful when making changes.
- `reimage.yml`: Revert nodes to their original image. Useful when debugging problems.
- `fio.yml`: Run example FIO workloads.
- `ansible-ssh`: Login to a node using ansible information (e.g. user) - pass `--host <inventory_hostname>` to select node.

To change permisions/mapping/squashing etc. it is probably safest to unmount first:

     ansible-playbook client-unmount.yml
     ansible-playbook site.yml --tags filetree

The second command will create/set directory/file permissions, mount lustre clients, export NFS and mount NFS clients.
