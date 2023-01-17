## Prerequisits

* AWS Account
* [Installed aws-cli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
* [Configured AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html) - Configuration file for academy account can be found in `AWS Details` section of your Learner Lab
* [Installed Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)

## Task

* Create `arm_vpc` VPC:
    * Use `192.168.1.0/24` CIDR
    * Enable DNS hostnames in VPC
    * Split VPC into two equal sized subnets, `arm_subnet_private` and `arm_subnet_public`
    * Allow all incoming HTTP and HTTPS connections
    * Allow SSH connection from your device only
    * Allow all outgoing HTTP and HTTPS connections
    * All incoming and outgoing traffic in the security group should be allowed
* Create ECS cluster `arm_ecs_cluster` where frontend and backend apps will be deployed as tasks:
    * Cluster should use `t3.micro` EC2 instances
    * Autoscaling group should be configured to require 1 instance and allow max 2 instances
    * EC2 instance autoscaling group should place nodes in `public` subnet
    * Database EC2 instance should be in `private` subnet
    * Root block devices should be encrypted
    * EC2 instances should be accessible using SSH protocol
    * ECS cluster should have task definitions for Frontend and Database services
    * Frontend service needs to be placed in Public subnet
    * Database service needs to be placed in Private subnet

### SSH

Create SSH keypair which will be used for access to EC2 insance

https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent#generating-a-new-ssh-key

### Terraform

Use [standard module structure](https://developer.hashicorp.com/terraform/language/modules/develop/structure). Consider splitting resources in multiple configuration files (e.g `network.tf` for network configuration, `iam.tf` for IAM config etc.).

Free plan allows t2.micro and t3.micro EC2 instances. Some regions do not have t2.micro instances available. t3.micro is recommended. Since Free tier allows 750 h/month, any AWS region is acceptable.

Create Terraform workspace `arm` (Administracija Racunarskih Mreza)

Terraform configuration should include:

#### Network configuration

1. Resource `arm_vpc` which creates [VPC](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html) used for EC2 instance:
    * Set 192.168.1.0/26 CIDR 
    * Enable DNS hostnamces in VPC
1. Resources `arm_subnet_private` and `arm_subnet_public` with subnets for new VPC:
    * Split 192.168.1.0/26 CIDR in two equal subnets, `arm_subnet_private` and `arm_subnet_public`
1. Resource `arm_igw` which creates [internet gateway](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html) for `arm_vpc`
1. Resource `arm_public_rt` which routes all traffic to `arm_igw`
1. Associate `arm_public_rt` with `arm_subnet_public`
1. Resource `arm_eip` which creates Elastic IP address
1. Resource `arm_nat_gateway` which creates NAT gateway:
    * Use elastic ip `arm_eip`
    * NAT needs to be placed in public subnet
1. Resource `arm_private_rt` which routes all traffic to NAT gateway
1. Associate `arm_private_rt` with `arm_private_subnet`
1. Resource `arm_security_group` which creates [Security group](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html) for EC2 instance:
    * Attach it to `arm_vpc` created in previous step
    * Allow SSH incomming traffic from your source IP
    * Allow HTTP and HTTPS outgoing traffic to all destinations
    * Allow all incoming and outgoing traffic in the security group

#### IAM configuration

**Note:** Due to AWS Academy restrictions, You can't create IAM roles, users or groups. There are predefined `LabRole` role and `LabInstanceProfile` profile which can be used. Normally, ECS requires Task Execution role for tasks, Instance Role and Instance profile for EC2 instances. ECS tasks and EC2 instances should be able to assume their respective roles.

Check [AWS task execution role](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html#create-task-execution-role) and [instance profile](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html#ec2-instance-profile) documentation for more info

1. Data source `current` which contains information about current user
1. Data source `lab_role` which contains information about role `LabRole`
1. Data source `lab_instance_profile` which contains information about `LabInstanceProfile`

#### Keys configuration

1. Resource `arm_ec2_access_key` which will create [EC2 key pair](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html)
1. Resource `ebs_encryption_key` which will create `kms_key`. This key will be used to encrypt EC2 instances' EBS volume:
    * [Amazon EC2 Auto Scaling uses service-linked roles to delegate permissions to other AWS services](https://docs.aws.amazon.com/autoscaling/ec2/userguide/key-policy-requirements-EBS-encryption.html). KMS Key policy needs to allow this user to use this key
    * Configure kms_key policy to allow all kms actions to `current user` and `AWSServiceRoleForAutoScaling` role
    * Use `aws_iam_policy_document` resource for key policy definition and refer it's json value in kms_key resource definition

#### EC2 configuration

1. Data source `ecs_optimized_amazon_linux_ami` which will contain information about AWS AMI which will be used for ECS EC2 instance:
    * Use latest Amazon [ECS Optimized AMI](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html)
    * Root device type should be EBS
1. Resource `arm_launch_template` which creates Launch template for Autoscaling group ([AWS Launch configurations are deprecated](https://docs.aws.amazon.com/autoscaling/ec2/userguide/launch-configurations.html?icmpid=docs_ec2as_help_panel)):
    * Use `ecs_optimized_amazon_linux_ami` image
    * use `t3.micro` instance type
    * Use `arm_ec2_access_key` key pair for SSH access
    * Instance should be deployed in VPC with `arm_security_group` security group
    * ECS agent starts with `default` cluster configured. It needs to be changed to `arm_ecs_cluster` name. [user_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#user_data) can be used to provide init script. Consider using [base64encode](https://developer.hashicorp.com/terraform/language/functions/base64encode) and [templatefile](https://developer.hashicorp.com/terraform/language/functions/templatefile) functions
    * Encrypt EBS volume using `ebs_encryption_key` key
    * Attach `lab_instance_profile` IAM instance profile
    * Add tag `Name=PublicServer`
1. Resource `arm_autoscaling_group` which handles number of available EC2 instances:
    * set minimum size 1 and maximum size 2
    * instances should be placed in `arm_subnet_public`
    * Latest `arm_launch_template` should be used
    * Add tag `Name=PublicServer`
1. Resource `arm_server_private` which creates EC2 instance for Database:
    * Use `ecs_optimized_amazon_linux_ami` image
    * use `t3.micro` instance type
    * Instance should be deployed in VPC with `arm_security_group` security group
    * ECS agent starts with `default` cluster configured. It needs to be changed to `arm_ecs_cluster` name. [user_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#user_data) can be used to provide init script. Consider using [base64encode](https://developer.hashicorp.com/terraform/language/functions/base64encode) and [templatefile](https://developer.hashicorp.com/terraform/language/functions/templatefile) functions
    * Encrypt EBS volume using `ebs_encryption_key` key
    * Attach `lab_instance_profile` IAM instance profile
    * Instance should be deployed in `arm_subnet_private`
    * Add tag `Name=PrivateServer`


#### ECS configuration

1. Resource `arm_ecs_cluster` which creates ECS cluster
1. Resources `frontend_task_definition` and `database_task_definition` to define container configuration for apps:
    * AWS documentation for [task definition](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definitions.html)
    * `frontend_task` should run on instance in Public subnet
    * `database_task` should run on instance in Private subnet
1. Resources `frontend_service` and `database_service` which will run and maintain task definitions:
    * Task should use `lab_role` for both task role and execution role
    * AWS documentation for [ECS services](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs_services.html)
    * Dummy services can be used


### Tips:
* Install and configure Terraform https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli
* When you provision a NAT gateway, you are charged for each hour that your NAT gateway is available and each Gigabyte of data that it processes.
* Add [`.gitignore`](https://github.com/github/gitignore/blob/main/Terraform.gitignore) file to prevent sensitive data being uploaded to GitLab
* Use `terraform destroy` to save resources
* Consider using Terraform variables https://developer.hashicorp.com/terraform/language/values/variables
* Use aws terraform provider https://registry.terraform.io/providers/hashicorp/aws/latest/docs
    * Image AMI, along with it's properties, can be found at EC2 AMIs section (note, default filter is `Owned by Me`. Change it to `Public Images`)
    * `aws_ami` resource combined with key:value filter can provide more flexible AMI selection
    * IANA protocol numbers list https://www.iana.org/assignments/protocol-numbers/protocol-numbers.xhtml
    * VPC with private and public subnets https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Scenario2.html
    * Check [AWS Managed Policies for ECS](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/security-iam-awsmanpol.html)
    * Using [aws_iam_policy_document data source](https://developer.hashicorp.com/terraform/tutorials/aws/aws-iam-policy#refactor-your-policy) is preffered over inline definition


Use `terrafrom plan` to create execution plan and save it to file `terraform.tfplan`. Note:
> Terraform will allow any filename for the plan file, but a typical convention is to name it tfplan. Do not name the file with a suffix that Terraform recognizes as another file format; if you use a .tf suffix then Terraform will try to interpret the file as a configuration source file, which will then cause syntax errors for subsequent commands.

Convert `terraform.tfplan` to user readable JSON file `terraform.tfplan.json` using `terraform show` command.

## Teacher Guide

1. Terraform intro:
    * IaC (idea, concepts, use case, tools, CloudFormation AWS specific, Terraform cloud agnostic)
    * What are resources, data sources, providers (basic information, syntax)
    * What are modules, benefits (reuse configuration), types (root, child, local, published), using modules (local, published), module sources
    * Variables (input variables, secrets, `.tfvars` file), expressions and functions (basic info, students should know it exists and can be used)
    * What is state and it's purpose, remote vs local state (e.g working in a team), remote state and workspaces (basic info, use case)
    * Which files contains sensitive data, what to include in `.gitignore`
    * Show [standard module structure](https://developer.hashicorp.com/terraform/language/modules/develop/structure). Consider splitting resources in multiple configuration files (e.g `network.tf` for network configuration, `iam.tf` for IAM config etc.).
    * Explain commands `plan`, `apply`, `destroy`, `state` subcommands  
1. ECS intro:
    * Basic info, compare with `docker compose` and `kubernetes`
    * Explain cluster, task definition and service
    * Go through task description (detailed part) and explain what and why is each resource created
    * For IAM section explain difference between student account and normal use case
1. Practical part with assistance [minimum]:
    * Students should create VPC, Private and Public subnets, Internet gateway, public route table, associate public route table with public subnet
    * During this process, students should learn how to use `init`, `plan`, `apply` and `destroy`
1. Rest of task should be a homework and is required for [gitlab-task](https://gitlab.com/kibrovic/gitlab-task/-/tree/main)
