#
# Variables Configuration
#

variable "cluster-name" {
  default = "terraform-eks-blimp"
  type    = string
}

variable "public-key-path" {
  default = "~/.ssh/id_rsa.pub"
  description = "Path to public SSH key for EC2 instances"
  type = string
}

variable "aws-region" {
  default = "us-west-2"
  description = "Target AWS region"
  type = string
}
