#
# EKS Worker Nodes Resources
#  * IAM role allowing Kubernetes actions to access other AWS services
#  * EKS Node Group to launch worker nodes
#

resource "aws_iam_role" "blimp-node" {
  name = "terraform-eks-blimp-node"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

# These three IAM policies are needed by workers. See
# https://docs.aws.amazon.com/eks/latest/userguide/worker_node_IAM_role.html
resource "aws_iam_role_policy_attachment" "blimp-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.blimp-node.name
}
resource "aws_iam_role_policy_attachment" "blimp-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.blimp-node.name
}
resource "aws_iam_role_policy_attachment" "blimp-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.blimp-node.name
}

# The instance profile grants access to this role to EC2 instances.
resource "aws_iam_instance_profile" "blimp-node" {
  name = "terraform-eks-blimp-node"
  role = aws_iam_role.blimp-node.name
}

resource "aws_key_pair" "blimp-node" {
  key_name   = "blimp-node"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCZEqFYjJeQj+oBPP6HXHFkS0jr02H3lXUhaWq9zZ4z55oOrVBjTduzlleaxFKptjU7qxT6fno+a1JVZlCjnWJREpiVSKZe5bgQAMUChpfLX2luV/mDy7OeSzQIRhAmDFxvBFlKtI0hWqkGq81KQOMN6lQj8fJQXBSGAV3sQBj6fukGWhHfiPc3lZCtVZxUx6wmDklnAWogfh5AGBA4Ltm8vrY3E5SPBCCIdAbJMgNPXQ6/AQqbndG4+TnKWUZbebtp5yiechnZ5yz92fk2Zz9GQzlTGyH1jqyRfGzQsv4SAsRicD2+rfoGNENh7WMFr+sptMQaUdil4Mw/DD76J+Xn"
}

data "aws_ami" "blimp-node-image" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["amazon-eks-node-1.16-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_launch_template" "blimp-node" {
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      delete_on_termination = true
      volume_size           = 20
      volume_type           = "gp2"
    }
  }

  iam_instance_profile {
    arn = aws_iam_instance_profile.blimp-node.arn
  }

  image_id = data.aws_ami.blimp-node-image.id

  instance_type = "t3.medium"

  key_name = aws_key_pair.blimp-node.key_name

  vpc_security_group_ids = [
    aws_security_group.blimp-nodes.id
  ]

  user_data = base64encode(<<-SCRIPT
    #!/bin/bash
    set -o xtrace
    /etc/eks/bootstrap.sh ${aws_eks_cluster.blimp.name} \
        --use-max-pods false \
        --kubelet-extra-args "--serialize-image-pulls=false --max-pods=150"
    SCRIPT
  )

  metadata_options {
    http_put_response_hop_limit = 2
    # Defaults
    http_endpoint = "enabled"
    http_tokens   = "optional"
  }
}

resource "aws_autoscaling_group" "blimp-nodes" {
  name             = "eks-blimp-nodes"
  desired_capacity = 2
  min_size         = 1
  max_size         = 4

  # The worker nodes must all be in the same availability zone, since the
  # persistent volumes created by Kubernetes are availability zone specific.
  # We just use the first availability zone.
  # Note that the VPC still needs multiple availability zones or else EKS will
  # error.
  vpc_zone_identifier = [aws_subnet.blimp[0].id]

  launch_template {
    id      = aws_launch_template.blimp-node.id
    version = aws_launch_template.blimp-node.latest_version
  }

  tag {
    key                 = "Name"
    value               = "${aws_eks_cluster.blimp.name}-node"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${aws_eks_cluster.blimp.name}"
    value               = "owned"
    propagate_at_launch = true
  }
}
