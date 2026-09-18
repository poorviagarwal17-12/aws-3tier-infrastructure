module "network" {
  source = "./modules/network"

  project_name = var.project_name
  environment  = terraform.workspace
  vpc_cidr     = var.vpc_cidr
}

module "storage" {
  source = "./modules/storage"

  project_name = var.project_name
  environment  = terraform.workspace
}

module "security" {
  source = "./modules/security"

  project_name  = var.project_name
  environment   = terraform.workspace
  vpc_id        = module.network.vpc_id
  s3_bucket_arn = module.storage.bucket_arn
  aws_region    = var.aws_region
  db_port       = 3306
}

module "database" {
  source = "./modules/database"

  project_name         = var.project_name
  environment          = terraform.workspace
  db_instance_class    = var.db_instance_class
  db_name              = var.db_name
  db_username          = var.db_username
  db_subnet_group_name = module.network.db_subnet_group_name
  db_security_group_id = module.security.db_security_group_id
  deletion_protection  = var.deletion_protection

  
}
#comment
module "compute" {
  source = "./modules/compute"

  project_name              = var.project_name
  environment               = terraform.workspace
  vpc_id                    = module.network.vpc_id
  public_subnet_ids         = module.network.public_subnet_ids
  private_subnet_ids        = module.network.private_subnet_ids
  alb_security_group_id     = module.security.alb_security_group_id
  app_security_group_id     = module.security.app_security_group_id
  iam_instance_profile_name = module.security.iam_instance_profile_name
  instance_type             = var.instance_type
  asg_min_size              = var.asg_min_size
  asg_max_size              = var.asg_max_size
  asg_desired_capacity      = var.asg_desired_capacity
}

module "monitoring" {
  count  = var.enable_monitoring ? 1 : 0
  source = "./modules/monitoring"

  project_name            = var.project_name
  environment             = terraform.workspace
  alb_arn_suffix          = module.compute.alb_arn_suffix
  target_group_arn_suffix = module.compute.target_group_arn_suffix
  asg_name                = module.compute.asg_name
}
