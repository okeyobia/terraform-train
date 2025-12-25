provider "aws"  {
  region = "us-east-1"
  
}

resource "aws_instance" "t2_micro" {
  ami           = "ami-01b9f1e7dc427266e" # Amazon Linux 2 AMI
  instance_type = "t4g.small"

  tags = {
    Name = "MyFirstTFEC2Instance"
  }
  
}