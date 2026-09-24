locals {
  tags = merge(var.tags, {
    Module = "rds-postgres"
  })
}

resource "random_password" "master" {
  length  = 32
  special = true
  # Restricted to characters that are both valid in an RDS password (not /, ", @ or space) and
  # URL-safe unreserved characters, since the password is embedded directly in database_url
  # below without percent-encoding.
  override_special = "-_.~"
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(local.tags, {
    Name = "${var.name}-subnet-group"
  })
}

resource "aws_security_group" "this" {
  name        = "${var.name}-rds-sg"
  description = "Allows Postgres access from application security groups"
  vpc_id      = var.vpc_id

  tags = merge(local.tags, {
    Name = "${var.name}-rds-sg"
  })
}

resource "aws_security_group_rule" "ingress_sg" {
  count                    = length(var.allowed_security_group_ids)
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.this.id
  source_security_group_id = var.allowed_security_group_ids[count.index]
  description              = "Postgres access from application security group"
}

resource "aws_security_group_rule" "ingress_cidr" {
  count             = length(var.allowed_cidr_blocks) > 0 ? 1 : 0
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  security_group_id = aws_security_group.this.id
  cidr_blocks       = var.allowed_cidr_blocks
  description       = "Postgres access from allowed CIDR blocks"
}

resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.this.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_db_instance" "this" {
  identifier     = var.name
  engine         = "postgres"
  engine_version = var.engine_version

  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.master_username
  password = random_password.master.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  publicly_accessible    = false

  multi_az                  = var.multi_az
  backup_retention_period   = var.backup_retention_period
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name}-final-${formatdate("YYYYMMDDhhmmss", timestamp())}"

  auto_minor_version_upgrade = true
  apply_immediately          = false

  tags = local.tags

  lifecycle {
    ignore_changes = [final_snapshot_identifier]
  }
}

resource "aws_secretsmanager_secret" "this" {
  name = "${var.name}/database"
  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id = aws_secretsmanager_secret.this.id
  secret_string = jsonencode({
    engine = "postgres"
    host   = aws_db_instance.this.address
    # ECS's Secrets Manager JSON-key injection only supports string values, so every field
    # here must be a string even where the underlying attribute (e.g. port) is a number.
    port         = tostring(aws_db_instance.this.port)
    dbname       = aws_db_instance.this.db_name
    username     = var.master_username
    password     = random_password.master.result
    database_url = "postgresql+asyncpg://${var.master_username}:${random_password.master.result}@${aws_db_instance.this.address}:${aws_db_instance.this.port}/${aws_db_instance.this.db_name}"
  })
}
