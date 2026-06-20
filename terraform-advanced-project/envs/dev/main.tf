module "network" {
  source      = "../../modules/network"
  name_prefix = local.name_prefix
}

module "security" {
  source          = "../../modules/security"
  name_prefix     = local.name_prefix
  vpc_id          = module.network.vpc_id
  app_port        = var.app_port
  app_secret_arn  = var.app_secret_arn
}

module "alb" {
  source            = "../../modules/alb"
  name_prefix       = local.name_prefix
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  alb_sg_id         = module.security.alb_sg_id
  app_port          = var.app_port
}

module "compute" {
  source                 = "../../modules/compute"
  name_prefix            = local.name_prefix
  environment            = "dev"
  instance_type          = "t3.micro"
  instance_profile_name  = module.security.instance_profile_name
  app_sg_id              = module.security.app_sg_id
  private_subnet_ids     = module.network.private_subnet_ids
  target_group_arn       = module.alb.target_group_arn
  desired_capacity       = 2
  min_size               = 1
  max_size               = 4
}

locals {
  name_prefix = "myapp-dev"
}
