#
# EKS Cluster Resources
#  * IAM Role to allow EKS service to manage other AWS services
#  * EC2 Security Group to allow networking traffic with EKS cluster
#  * EKS Cluster
#

resource "aws_iam_role" "blimp-cluster" {
  name = "terraform-eks-blimp-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "blimp-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.blimp-cluster.name
}

resource "aws_eks_cluster" "blimp" {
  name     = var.cluster-name
  role_arn = aws_iam_role.blimp-cluster.arn
  version  = "1.16"

  # Disabled: audit, authenticator
  enabled_cluster_log_types = ["api", "controllerManager", "scheduler"]

  vpc_config {
    security_group_ids = [aws_security_group.blimp-cluster.id]
    subnet_ids         = aws_subnet.blimp[*].id
  }

  depends_on = [
    aws_iam_role_policy_attachment.blimp-cluster-AmazonEKSClusterPolicy,
  ]
}
