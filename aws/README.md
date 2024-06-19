## How to start Appsmith with ecs_ec2
```
mkdir appsmith && cd appsmith

cat << EOF > appsmith_ecs_ec2.tf
terraform {

}

provider "aws" {
  profile = "default"
  region  = "ap-northeast-3"
}

module "appsmith_ecs_ec2" {
  source            = "github.com/appsmithorg/appsmith-tf-modules.git//aws/ecs_ec2"
  vpc_id            = "vpc-0305666a"
  region            = "ap-northeast-3"
  ecs_subnet_id     = ["subnet-9d20fdd0", "subnet-ba2c3fc2", "subnet-5804f731"]
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
