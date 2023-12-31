resource "aws_db_subnet_group" "rds_db_default_subnet_group" {
  subnet_ids = [aws_subnet.private_subnet_az_a.id, aws_subnet.private_subnet_az_b.id]
}

# Password is stored in TF_VAR_RDS_PASSWORD environment variable
variable "RDS_PASSWORD" {
  type = string
}

variable "rds_database" {
  type    = string
  default = "aws_ccp_laravel"
}

resource "aws_db_instance" "mariadb" {
  allocated_storage      = 20
  db_name                = var.rds_database
  engine                 = "mariadb"
  engine_version         = "10.6.14"
  instance_class         = "db.t3.micro"
  username               = "admin"
  password               = var.RDS_PASSWORD
  db_subnet_group_name   = aws_db_subnet_group.rds_db_default_subnet_group.name
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
}

resource "aws_security_group" "rds_sg" {
  vpc_id = aws_vpc.default_vpc.id
}

resource "aws_security_group_rule" "rds_allow_inbound" {
  security_group_id        = aws_security_group.rds_sg.id
  type                     = "ingress"
  from_port                = 0
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_sg.id
}

resource "aws_security_group_rule" "rds_allow_outbound" {
  description       = "All outbound"
  security_group_id = aws_security_group.rds_sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "all"
  cidr_blocks       = [aws_subnet.public_subnet_az_a.cidr_block, aws_subnet.public_subnet_az_b.cidr_block]
}
