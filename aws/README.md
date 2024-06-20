## How to start Appsmith with ecs_ec2
```
mkdir appsmith && cd appsmith

cat << EOF > appsmith_ecs_ec2.tf
terraform {

}

provider "aws" {
  profile = "<desired_profile>"
  region  = "<region>"
}

module "appsmith_ecs_ec2" {
  source            = "github.com/appsmithorg/appsmith-tf-modules.git//aws/ecs_ec2"
  vpc_id            = "<vpc_id>"
  region            = "<region>"
  ecs_subnet_id     = ["list", "of", "subnets"]
  appsmith_image    = "index.docker.io/appsmith/appsmith-ee:latest"
  ecs_instance_type = "t3.medium"

}
EOF
```

## Initializing the module
```
terraform init
```

## Apply the changes
```
terraform apply -auto-approve
```

## Destroy the changes
```
terraform destroy -auto-approve
```
