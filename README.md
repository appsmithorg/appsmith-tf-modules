# appsmith-tf-modules
Terraform modules for Appsmith

## Install Terraform

```
git clone --depth=1 https://github.com/tfutils/tfenv.git ~/.tfenv
```

**Set Path**

```
echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> ~/.bash_profile
source ~/.bash_profile
```

**Use Terraform Version 1.3.1**
```
tfenv use 1.3.1
```

### Check terraform installation
please run `terraform --version`

Eg:
```
$ terraform --version
Terraform v1.3.1
on darwin_arm64

Your version of Terraform is out of date! The latest version
is 1.8.5. You can update by downloading from https://www.terraform.io/downloads.html
```

### Refer following docs to deploy appsmith
* [Appsmith on ecs](https://github.com/appsmithorg/appsmith-tf-modules/tree/main/aws#how-to-start-appsmith-with-ecs_ec2)
