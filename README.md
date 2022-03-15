Demo of multi-tenant Lustre in the Arcus cloud with re-export to isolated clients via Lustre and NFS.

# Overview
Required pre-existing infrastructure:
- A "low-latency" RDMA-capable network (modelling the core Lustre network). **NB:** Currently the Lustre Lnet is set to `tcp` despite being on a RDMA-capable network as that provided better performance in the Arcus environment.
- A normal TCP network (modelling a storage network in a tenancy).

Deployed infrastructure on low-latency network:
- A patchless LDISKFS server (CentOS 7.9) using MGT, MDT and OST created on ephemeral devices (NB: requires [Nova option](https://docs.openstack.org/nova/latest/configuration/config.html#DEFAULT.max_local_block_devices) `max_local_block_devices` < 0 or >= 4). This provides a single Lustre filesystem. Note a production system would probably require additional devices.
- Lustre admin client (Rocky Linux 8.5) used for mananging the filesystem.
- Lustre "CSD3" client (Rocky Linux 8.5) modelling a client with access to multiple projects.
- Lustre "exporter" client (Rocky Linux 8.5) modelling a restricted client with access to a single project. This also runs an NFS server, serving the portion of the Lustre filesystem it has access to from a specific pre-defined private IP.

Deployed infrastructure on the normal network:
- An NFS client (Rocky Linux 8.5) mounting the filesystem from the "exporter".

The concept here is that a client in an isolated tenancy can mount a selected portion of the Lustre filesystem over NFS. While this obviously will have a performance impact, it does provide some significant benefits:
- Access is significantly easier, as it simply requires installing NFS packages and mounting from a known IP.
- Without a Lustre client, there are no restrictions on kernel/OS versions.
- It removes the need for the client to have uids/gids matching those on the server, which may be difficult to arrange for an isolated tenancy.

All the Lustre client and server setup uses the `develop` brach of [ansible-role-lustre](https://github.com/stackhpc/ansible-role-lustre/tree/develop).

Note that unlike [previous work](https://github.com/stackhpc/ansible-lustre/tree/vss) no Lnet routers are used for this configuration, although the above role does support them.

# Example directory tree

The admin client is used to create the following example directory/file tree on the Lustre filesystem:

    ```
        /tenants/
            srcp-foo/
            srcp-bar/
        /csd3/
            project/
                proj12/
                    readwrite/
                    readonly/
                        readme.txt
                proj4/
    ```

The `/csd3/project/proj12` directory and children have both owner and group set to `proj12`. No world permissions are given. The `readwrite/` and `readonly/` subdirectories have write flags set as indicated by the name.

# Users
The lustre server and all Lustre clients are assumed to be on LDAP, and therefore share uid/gids. This is simulated using the Ansible group vars file [inventory/group_vars/lustre/ldap.yml]() as follows:
- `proj12`: The owner for the `/csd3/project/proj12` directory.
- `proj12-member`: A non-owning user for that directory.
- `alex`, `andy`: Example `csd3` users, with secondary group `proj12`.
- `becky`, `ben`: Example `proj12` users for the isolated Lustre client (the "exporter"), with secondary group proj12.

# Access control

Note access control is only configured for the `/csd3/project/proj12` example directory.

Access control is implemented using Lustre's [nodemap functionality](http://doc.lustre.org/lustre_manual.xhtml#lustrenodemap), controlled using the `ansible-role-lustre:lustre_nodemaps` [variable](roles/ansible-role-lustre/defaults/main.yml). These nodemaps are defined on the Lustre server by [inventory/group_vars/lustre_server/server.yml]() which sets them as follows:

- Admin client: Configured with `trusted_nodemap` and `admin_nodemap` both `true`, which allows this client to see the real filesystem uids/gids and means this client's `root` user is not squashed. Note that when using nodemaps a client with these properties set is required in order to make changes to permissions or owners/groups.

- CSD3 Lustre client: This is again configured with `trusted_nodemap: true` so that users can see the real filesystem uids/gids. However `admin_nodemap: false` is used, which squashes the client's `root` user to the default 99 or `nobody` user/group[^1], preventing changes to ownership or permissions. The `fileset` property is set to `/csd3` so the client mountpoint of `/mnt/lustre` only[^2] shows directories under `/csd3/` in the Lustre filesystem, i.e. all CSD3 projects. As the `alex` and `andy` uses have a secondary group of `proj12` they have group permissions in the `proj12` directory.

[^1]: Although the lustre documentation states squashing is disabled by default, in fact (under 2.12 and 2.14 at least) the squashed uid and gid default to `99`. Therefore if squashing is not required the trusted property must be set. 

[^2]: The lustre documentation for the [Fileset Feature](https://doc.lustre.org/lustre_manual.xhtml#SystemConfigurationUtilities.fileset) is confusing/incorrect as it actually appears to be describing submounts. A submount similarly specifies a child directory of the filesystem to be mounted, but is voluntary by the client - the client can chose to mount the entire filesystem. In contrast, filesets are enforced by the server only exporting the defined subdirectory. Submount functionality is not exposed by the role used here.

- "Exporter" Lustre client: This is configured with:
    - `admin_nodemap: false` and `trusted_nodemap: false`. As above this means users cannot see the real filesystem uids/guids and all users (including `root`) are squashed.
    - `fileset` is set to `/csd3/project/proj12` so the client's Lustre mountpoint at `/mnt/lustre` only provides access to this project.
    - `squash_uid` is set to the id for `proj12-member`, which does *not* own the directory.
    - `squash_gid` is set to the id for `proj12`, the directory owner.
    
    As the owner and group of the `/csd3/project/proj12/` directory are both actually `proj12`, this means that any user on client can get at most group permissions on this directory[^3]. As the squashing is done on server side, on this client neither `root`, the `proj12` user (which is the actual owner) nor the `proj12-member` user (which appears to be the owner from this client) actually has owner permissions.
    
    However to get group permissions, unprivileged client users (e.g. `becky` and `ben`) must also be members of the `proj12` group. It is not clear why this is necessary, given the group squashing. It is not necessary for the `proj12-member` user they are squashed to to be a member of the `proj12` group.

    This client also acts as an NFS server configured (in the "Re-export Lustre" play in [site.yml]()) to export the `/mnt/lustre` directory (which as above is actually the `/csd3/project/proj12/` directory on this client). This NFS export uses the options:
        - `root_squash`
        - `all_squash`
        - `anonuid` set to the `proj12-member` uid
        - `anongid` set to the `proj12` gid
        (note the gid and uid squashing mirrors the nodemap for the "exporter" Lustre client on the same instance).

    The effect is that when an NFS client mounts this NFS export, all its users (including `root`) only have group permissions on this directory. Unusually the NFS squashing configuration acts to *provide* permissions in this case; without it any NFS client users would have to have a secondary group with an id matching that of the `proj12` LDAP user in order to access the mount.

[^3]: The [client 2 nodemap in previous work](https://github.com/stackhpc/ansible-lustre/tree/vss#client-2) (which this nodemap is modelled on) mapped the client's `root` user to `proj12` to give it owner permissions in the project directory. This also meant the directory's owner appeared as `root` to other users.

- NFS demo client: Simply mounts the above NFS export to `/mnt/lustre` with default options. This client is not part of the simulated LDAP, and so the `proj12` and `proj12-member` users/groups are not defined. Therefore owners and groups in the mounted filesystem are listed by id rather than by name. If this is considered undesirable, users/groups with appropriate IDs could be configured (with any arbitrary names) but this does not affect access, only presentation.

To help explain the above, here is the view of the `proj12` directory from each client with an appropriate user - note the paths to this directory change depending on the fileset for each client:

```
# admin client, root user - real view/superuser permissions:
[rocky@lustre-admin ~]$ sudo ls -ld /mnt/lustre/csd3/project/proj12/
drwxrwx--T. 4 proj12 proj12 4096 Mar 14 15:24 /mnt/lustre/csd3/project/proj12/

# csd3 client, LDAP CSD3 user "alex" in proj12 group, effective group permissions from groups:
[rocky@lustre-csd3-client ~]$ sudo su alex
[alex@lustre-csd3-client rocky]$ groups
alex proj12
[alex@lustre-csd3-client rocky]$ ls -ld /mnt/lustre/project/proj12/
drwxrwx--T. 4 proj12 proj12 4096 Mar 14 15:24 /mnt/lustre/project/proj12/

# Restricted "exporter" client, LDAP project user "becky" in `proj12` group, effective group permissions from groups and Lustre squashing:
[rocky@lustre-exporter ~]$ sudo su becky
[becky@lustre-exporter rocky]$ groups
becky proj12
[becky@lustre-exporter rocky]$ ls -ld /mnt/lustre/
drwxrwx--T. 4 proj12-member proj12 4096 Mar 14 15:24 /mnt/lustre/

# NFS client mounting "exporter" NFS re-export, local user "rocky", effective group permissions from NFS + Lustre squashing:
[rocky@demo-nfs-client ~]$ ls -ld /mnt/lustre/
drwxrwx--T. 4 1101 1100 4096 Mar 14 15:24 /mnt/lustre/
```

# Other configuration
In addition to the installation and configuration of Lustre as described above, the `site.yml` playbook also:
- Updates the kernel to latest and installs matching `kernel-` packages where required. The update to latest is done because repos may not contain `kernel-` packages matching for older kernels. These tasks only run if Lustre has not already been installed so are idempotent - no update will be done when rerunning this playbook.
- Enables RoCE on the (CentOS 7) Lustre server (see task 'Enable RoCE') in case an `o2ib` Lnet is selected. No action is required on the (Rocky 8) clients to enable RoCE.
- Reduces user/group upcall cache time to 1 second from the default 20 minutes (see task 'Check user/group upcall cache time'). This is to help experimentation with users/groups and mapping, and may not be appropriate for a production system. **NB:** Without this option changing permissions etc. may give inconsistent or erroneous behaviour 
- Asserts that various Lustre components are in the correct state on the Lustre server (see task 'Assert server components running'). This helps catch errors like changing the Lnet without reformatting the Lustre disks.

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

1. Review the ansible variables in `inventory/group_vars` and modify as apppropriate. Note that:

    - Lustre LNET configuration (variable `lustre_lnet_lnetctl_networks`) requires the interface to be specified (e.g. `eth0`). As a convenience the Terraform-templated inventory, group variables and a preliminary 'Set fact for interface information' task in `site.yml` allow for the interface to be automatically derived from a `lustre_core_network` variable containing the name of the network to use.

    - The automatic NID range generation in [inventory/group_vars/lustre_server/server.yml]() is not general-purpose and may need adapting for other client configurations.

1. Run ansible to install and configure Lustre servers/clients and NFS server:
    
    ```
    ansible-playbook site.yml
    ```

    **NB:** the first time (only) append `-e lustre_format_force=true` as the server VM is created with ext4-formatted ephermeral disks (despite asking not to). This will reformat the devices specified by the `lustre_format_{mgs,mdts,osts}` variables so use with caution!

1. Create a `grafana_password` in e.g. `inventory/group_vars/all/secrets.yml` and then run:

    ```
    ansible-playbook monitoring.yml
    ```


# Utility playbooks and scripts:

- `reimage.yml`: Revert nodes to their original image. Useful during development.
- `ansible-ssh`: Login to a node using ansible information (e.g. user) - pass `--host <inventory_hostname>` to select node.

While the manual says nodemap changes propagate in ~10 seconds, previous work found it was necessary to unmount and remount the filesystem to get changes to apply, although this was nearly instantaneous and proved robust. All the Lustre and NFS clients can be unmounted in the correct order using:

     ansible-playbook client-unmount.yml

then rerun `site.yml`. Note this does not unmount the MGT/MDT/OST which is necessary to stop Lustre to make some other changes.
