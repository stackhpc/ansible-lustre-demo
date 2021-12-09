Demo of using https://github.com/mjrasobarnett/ansible-role-lustre.


# Install

On CentOS8

```
sudo yum -y install python3 git
python3 -m venv venv
. venv/bin/activate
pip install -r requirements.txt
ansible-galaxy install -p roles/ -r requirements.yml
```


# Run
```
ansible -i inventory site.yml
```
