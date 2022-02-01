Demo of multi-tenant Lustre with re-export to clients via NFS.

# Overview
Required pre-existing infrastructure:
- A "low-latency" RDMA-capable network
- A TCP network

Deployed infrastructure on low-latency network:
- Lustre server:
    - CentOS 7.9
    - LDISKFS MGT/MDT/OST created via loop devices in /var
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
    - Kernel NFS server (also RDMA-capable)
    - With a port tagged `nfs:lustre` (concept is protocol:filesystem name)

The idea is that a non-lustre-capable client can mount from the NFS exporter. This is demoed in ` portal-nfs-client/` which contains terraform and ansible to create a VM with an NFS client mounting the above exporter.

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
    ansible inventory site.yml
    ```
