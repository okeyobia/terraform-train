provider "aws"  {
  region = "us-east-1"
  
}

# variable "object_example" {
#     description = "An example of structured type in Terraform"
#     type = object({
#         name = string
#         age = number
#         tags = list(string)
#         enabled = bool
#     })
#     default = {
#         name = "John Doe"
#         age = 30
#         tags = ["developer", "terraform", "aws"]
#         enabled = "true"
#     }
  
# }

variable "server_port" {
  description = "Port on which the server will listen"
  type        = number
  default     = 8080
  
}

# output "public_ip" {
#   description = "The public IP address of the EC2 instance"
#   value       = aws_autoscaling_group.example_asg.instances[*].public_ip
  
# }

# resource "aws_instance" "t2_micro" {
#   ami           = "ami-01b9f1e7dc427266e" # Amazon Linux 2 AMI
#   instance_type = "t4g.small"
#   vpc_security_group_ids = [aws_security_group.instance_sg.id]

#   user_data = <<-EOF
#     #!/bin/bash
#         echo "Hello, World" > index.html
#         nohup busybox httpd -f -p ${var.server_port} &
#     EOF

#   tags = {
#     Name = "MyFirstTFEC2Instance"
#   }
  
# }

output "alb_dns_name" {
    description = "The DNS name of the ALB Load Balancer"
    value       = aws_alb.alb_example.dns_name
  
}


resource "aws_security_group" "instance_sg" {
  name = "instance_sg"
  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_vpc" "default" {
  default = true
  
}

data "aws_subnets" "default" {
    filter {
        name   = "vpc-id"
        values = [data.aws_vpc.default.id]
    }
  
}

# resource "aws_launch_configuration" "t2_micro" {
#   image_id           = "ami-01b9f1e7dc427266e" # Amazon Linux 2 AMI
#   instance_type = "t4g.small"
#   security_groups = [aws_security_group.instance_sg.id]

#   user_data = <<-EOF
#     #!/bin/bash
#         echo "Hello, World" > index.html
#         nohup busybox httpd -f -p ${var.server_port} &
#     EOF

#     # Required when using a launch configuration with an auto scaling group.
#         # https://www.terraform.io/docs/providers/aws/r/launch_configuration.html
#     lifecycle {
#     create_before_destroy = true
#     }
  
# }

resource "aws_alb" "alb_example" {
  name               = "terraform-asg-example-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.default.ids

  tags = {
    Name = "example-alb"
  }
  
}

resource "aws_alb_listener" "http" {
    load_balancer_arn = aws_alb.alb_example.arn
    port              = "80"
    protocol          = "HTTP"
    
    default_action {
        type             = "fixed-response"
        fixed_response {
        content_type = "text/plain"
        message_body = "Hello from ALB"
        status_code  = "200"
        }
    }
  
}

resource "aws_security_group" "alb_sg" {
  name = "alb_sg"

  # Allow inbound HTTP requests
  ingress {     
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Allow all outbound requests
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
  
}

resource "aws_lb_target_group" "asg_tg" {
    name     = "terraform-asg-tg"
    port     = var.server_port
    protocol = "HTTP"
    vpc_id   = data.aws_vpc.default.id

    health_check {
        path                = "/"
        protocol            = "HTTP"
        matcher             = "200"
        interval            = 30
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 2
    }

    tags = {
        Name = "example-asg-tg"
    }   
  
}

resource "aws_alb_listener_rule" "asg_rule" {
    listener_arn = aws_alb_listener.http.arn
    priority     = 100

    action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.asg_tg.arn
    }

    condition {
        path_pattern {
            values = ["*"]
        }
    }
  
}

resource "aws_launch_template" "t2_micro" {
    name          = "t2_micro_launch_template"
    image_id      = "ami-068c0051b15cdb816" # Amazon Linux 2 AMI
    instance_type = "t3.micro"

    network_interfaces {
        security_groups = [aws_security_group.instance_sg.id]
    }

    user_data = base64encode(<<-EOF
        #!/bin/bash
                echo "Hello, World" > index.html
                nohup busybox httpd -f -p ${var.server_port} &
        EOF
    )

    tag_specifications {
        resource_type = "instance"
        tags = {
            Name = "MyFirstTFEC2Instance"
        }
    }
}
resource "aws_autoscaling_group" "example_asg" {
#   launch_configuration = aws_launch_configuration.t2_micro.name
  launch_template {
    id      = aws_launch_template.t2_micro.id
    version = "$Latest"
  }
  vpc_zone_identifier = data.aws_subnets.default.ids
  target_group_arns = [aws_lb_target_group.asg_tg.arn]
  health_check_type = "ELB"

  min_size             = 2
  max_size             = 8
#   desired_capacity     = 4
#   vpc_zone_identifier  = ["subnet-0bb1c79de3EXAMPLE"] # Replace with your subnet ID

  

  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}


