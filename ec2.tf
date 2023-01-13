data "aws_ami" "ecs_optimized_amazon_linux_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  owners = ["591542846629"]
}

resource "aws_launch_template" "arm_launch_template" {
  name_prefix            = "arm_launch_template"
  image_id               = data.aws_ami.ecs_optimized_amazon_linux_ami.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.arm_ec2_access_key.key_name
  vpc_security_group_ids = [aws_security_group.arm_security_group.id]
  user_data = base64encode(templatefile("./templates/user_data.tpl", {
    cluster_name = aws_ecs_cluster.arm_ecs_cluster.name
  }))
  update_default_version = true

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      delete_on_termination = true
      encrypted             = true
      kms_key_id            = aws_kms_key.ebs_encryption_key.arn
      volume_size           = 30
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_role.name
  }

  depends_on = [
    aws_kms_key.ebs_encryption_key
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "arm_autoscaling_group" {
  name_prefix               = "arm_autoscaling_group"
  max_size                  = 2
  min_size                  = 2
  vpc_zone_identifier       = [aws_subnet.arm_subnet_public.id, aws_subnet.arm_subnet_private.id]
  wait_for_capacity_timeout = "2m"

  launch_template {
    id      = aws_launch_template.arm_launch_template.id
    version = "$Latest"
  }

  depends_on = [
    aws_launch_template.arm_launch_template
  ]
}
