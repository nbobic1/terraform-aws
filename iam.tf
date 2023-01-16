data "aws_caller_identity" "current" {}

data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

data "aws_iam_instance_profile" "lab_instance_profile" {
  name = "LabInstanceProfile"
}

# resource "aws_iam_role" "ecs_task_execution_role" {
#   name               = "ecs_task_execution_role"
#   assume_role_policy = data.aws_iam_policy_document.lab_instance_profile.json
# }

#     principals {
#       type        = "Service"
#       identifiers = ["ecs-tasks.amazonaws.com"]
#     }
#   }
# }

# data "aws_iam_policy" "ecs_task_execution_policy" {
#   arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
# }

# resource "aws_iam_role" "ecs_task_execution_role" {
#   name               = "ecs_task_execution_role"
#   assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role_policy.json
#   #   inline_policy {
#   #     name = "ecs_task_execution_policy"
#   #     policy = data.aws_iam_policy.ecs_task_execution_policy.policy
#   #   }
# }

# resource "aws_iam_role_policy" "ecs_task_execution_policy" {
#   name   = "ecs_task_execution_policy"
#   role   = aws_iam_role.ecs_task_execution_role.id
#   policy = data.aws_iam_policy.ecs_task_execution_policy.policy
# }

# ECS role for EC2 instance

# data "aws_iam_policy_document" "instance_assume_role_policy" {
#   statement {
#     actions = ["sts:AssumeRole"]

#     principals {
#       type        = "Service"
#       identifiers = ["ec2.amazonaws.com"]
#     }
#   }
# }

# data "aws_iam_policy" "ecs_instance_role_policy" {
#   arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
# }

# resource "aws_iam_role" "ecs_instance_role" {
#   name               = "ecs_instance_role"
#   assume_role_policy = data.aws_iam_policy_document.instance_assume_role_policy.json
# }

# resource "aws_iam_role_policy" "ecs_instance_role_policy" {
#   name   = "ecs_instance_role_policy"
#   role   = aws_iam_role.ecs_instance_role.id
#   policy = data.aws_iam_policy.ecs_instance_role_policy.policy
# }

# resource "aws_iam_instance_profile" "ecs_instance_role" {
#   name = "ecs_instance_profile_role"
#   role = aws_iam_role.ecs_instance_role.name
# }
