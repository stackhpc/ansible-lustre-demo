Demo of using https://github.com/mjrasobarnett/ansible-role-lustre.


# Install

On CentOS8

Install ansible:
```
sudo yum -y install python3 git
python3 -m venv venv
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

# Create infrastructure

1. Ensure the following are available on OpenStack:
- A keypair with private key on the deployment host.
- A network with internet access.
- A CentOS 7.9 2009 image.
- A suitable VM flavor.
- 3x volumes, for MGS, MDT and OST.

1. Ensure Openstack credentials are available (e.g. download and source `openrc.sh` file).

1. Run terraform:

    ```
    cd terraform/
    terraform apply
    ```

As well as creating the VMs this will also create an ansible inventory `inventory/hosts`. Note the volume attachments are done at VM creation time to try to to keep device paths (e.g. `/dev/sda`) consistent across boots. Device ordering is not guaranteed though, so in production the appropriate device should be located using the OpenStack volume ID which is exposed to the VM as the device serial number.

# Install and configure Lustre
```
ansible -i inventory site.yml
```
