#
# VPC Resources
#  * VPC
#  * Subnets
#  * Internet Gateway
#  * Route Table
#
# Security groups and rules

resource "aws_vpc" "blimp" {
  cidr_block = "10.0.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = map(
    "Name", "terraform-eks-blimp-node",
    "kubernetes.io/cluster/${var.cluster-name}", "shared",
  )
}

resource "aws_subnet" "blimp" {
  count = 2

  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = "10.0.${count.index}.0/24"
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.blimp.id

  tags = map(
    "Name", "terraform-eks-blimp-node",
    "kubernetes.io/cluster/${var.cluster-name}", "shared",
  )
}

resource "aws_internet_gateway" "blimp" {
  vpc_id = aws_vpc.blimp.id

  tags = {
    Name = "terraform-eks-blimp"
  }
}

resource "aws_route_table" "blimp" {
  vpc_id = aws_vpc.blimp.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.blimp.id
  }
}

resource "aws_route_table_association" "blimp" {
  count = 2

  subnet_id      = aws_subnet.blimp.*.id[count.index]
  route_table_id = aws_route_table.blimp.id
}

resource "aws_security_group" "blimp-cluster" {
  name        = "terraform-eks-blimp-cluster"
  description = "Cluster communication with worker nodes"
  vpc_id      = aws_vpc.blimp.id

  tags = {
    Name = "terraform-eks-blimp"
  }
}

resource "aws_security_group" "blimp-nodes" {
  name        = "terraform-eks-blimp-nodes"
  description = "Security group for all nodes in the cluster"
  vpc_id      = aws_vpc.blimp.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = map(
    "Name", "terraform-eks-blimp",
    # This tag is needed for LB allocation/deletion to work correctly. See:
    # https://github.com/kubernetes/kubernetes/issues/17626
    "kubernetes.io/cluster/${aws_eks_cluster.blimp.name}", "owned",
  )
}

# These rules were mostly taken from the unmanaged node group CloudFormation
# template:
# https://amazon-eks.s3.us-west-2.amazonaws.com/cloudformation/2020-06-10/amazon-eks-nodegroup.yaml

resource "aws_security_group_rule" "blimp-nodes-node-ingress" {
  description       = "Allow nodes to communicate with each other"
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.blimp-nodes.id
  self              = true
  to_port           = 65535
  type              = "ingress"
}

resource "aws_security_group_rule" "blimp-cluster-control-plane-ingress" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.blimp-cluster.id
  source_security_group_id = aws_security_group.blimp-nodes.id
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_security_group_rule" "blimp-cluster-node-egress" {
  description              = "Allow the cluster control plane to communicate with worker Kubelet and pods"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = aws_security_group.blimp-cluster.id
  source_security_group_id = aws_security_group.blimp-nodes.id
  to_port                  = 65535
  type                     = "egress"
}

resource "aws_security_group_rule" "blimp-cluster-node-443-egress" {
  description              = "Allow the cluster control plane to communicate with pods running extension API servers on port 443"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.blimp-cluster.id
  source_security_group_id = aws_security_group.blimp-nodes.id
  to_port                  = 443
  type                     = "egress"
}

resource "aws_security_group_rule" "blimp-nodes-control-plane-ingress" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = aws_security_group.blimp-nodes.id
  source_security_group_id = aws_security_group.blimp-cluster.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "blimp-nodes-control-plane-443-ingress" {
  description              = "Allow pods running extension API servers on port 443 to receive communication from cluster control plane"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.blimp-nodes.id
  source_security_group_id = aws_security_group.blimp-cluster.id
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_security_group_rule" "blimp-nodes-workstation-ingress" {
  description       = "Grant SSH access"
  type              = "ingress"
  security_group_id = aws_security_group.blimp-nodes.id
  cidr_blocks = [
    # This can be updated to be more restrictive.
    "0.0.0.0/0",
  ]
  protocol  = "tcp"
  from_port = 22
  to_port   = 22
}
