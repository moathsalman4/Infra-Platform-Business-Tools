terraform {
  backend "s3" {
    bucket       = "moathsalman-tfstate-dev"
    key          = "env/dev/eks/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # Enables native S3 locking
  }
}
