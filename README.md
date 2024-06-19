# appsmith-tf-modules
Terraform modules for Appsmith

### How to start Appsmith with ecs_ec2
terraform {

}

provider "aws" {
  profile = "default"
  region  = "<region>"
}

module "appsmith_ecs_ec2" {
  source            = ".//ecs_ec2"
  vpc_id            = "<vpc_id>"
  region            = "<region>"
  ecs_subnet_id     = ["list", "of", "subnets"]
  appsmith_image    = "index.docker.io/appsmith/appsmith-ee:latest"
  ecs_instance_type = "t3.medium"

}
