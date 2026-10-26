data "aws_partition" "current" {}

locals {
  partition = data.aws_partition.current.partition
}
