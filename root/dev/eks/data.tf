data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "moathsalman-tfstate-dev"
    key    = "env/dev/vpc/terraform.tfstate"
    region = "us-east-1"
  }
}