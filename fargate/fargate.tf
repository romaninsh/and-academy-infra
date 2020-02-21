variable "name" {

}

variable "prod" {
  type = bool
  default = false
}

variable "public_subnets" {

}
variable "subnets" {
  type = list(string)
}
variable "vpc" {

}

resource "aws_security_group" "main" {
  name        = var.name
  vpc_id      = var.vpc

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_alb" "main" {
  name            = var.name
  subnets         = var.public_subnets
  security_groups = [aws_security_group.main.id]
}

resource "aws_alb_target_group" "main" {
  name = var.name
  port = 80
  protocol = "HTTP"
  vpc_id = var.vpc
  target_type = "ip"

}

resource "aws_alb_listener" "main" {
  load_balancer_arn = aws_alb.main.arn
  port = 80
  protocol = "HTTP"
  default_action {
    target_group_arn = aws_alb_target_group.main.arn
    type = "forward"
  }
  depends_on = [aws_alb_target_group.main]
}



resource "aws_ecs_service" "main" {
  name            = var.name
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  #iam_role        = aws_iam_role.main.arn

  network_configuration {
    assign_public_ip = true
    security_groups = [aws_security_group.main.id]
    subnets         = var.subnets
  }


  load_balancer {
    target_group_arn = aws_alb_target_group.main.arn
    container_name   = var.name
    container_port   = 80
  }



  depends_on = [
    aws_alb_listener.main
  ]
}










resource "aws_ecs_cluster" "cluster" {
  name = var.name
}


module "app_container_definition" {
  source                       = "git::https://github.com/cloudposse/terraform-aws-ecs-container-definition.git?ref=tags/0.21.0"
  container_name               = var.name
  container_image              = "tutum/hello-world" #aws_ecr_repository.main.repository_url
  container_cpu                = 512
  container_memory             = 1024
  essential                    = true
  readonly_root_filesystem     = false
  //entrypoint                   = ["/onboarding-profile-automator/run.sh"]

  environment                  = [
    /*
    {name: "ConnectionString__ElapseitProfileAutomatorDB", value: "SERVER=${module.db.this_db_instance_address};DATABASE=ElapseitProfileAutomatorDB;User Id=${var.user};PASSWORD=${random_password.db.result};"},
    {name: "ConnectionString__HangfireConnection", value: "Server=${module.db.this_db_instance_address};Database=ElapseitProfileAutomatorDB;Integrated Security=SSPI;"},
    */
  ]
  port_mappings                = [
    {
      containerPort            = 80
      hostPort                 = 80
      protocol                 = "tcp"
    }
  ]
  log_configuration            = {
    logDriver = "awslogs"
    options   = {
      "awslogs-group" = aws_cloudwatch_log_group.log.name
      "awslogs-region" = "eu-west-2"
      "awslogs-stream-prefix" = "ecs"
    }
    secretOptions = null
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = var.name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn =  aws_iam_role.main.arn

  container_definitions = "[${module.app_container_definition.json_map}]"
}

resource "aws_iam_role" "main" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "main" {
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "main" {
  policy_arn = aws_iam_policy.main.arn
  role = aws_iam_role.main.name
}


resource "aws_cloudwatch_log_group" "log" {
  name = "/ecs/${var.name}"
}
