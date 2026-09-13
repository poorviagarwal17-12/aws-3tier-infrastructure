aws_region           = "us-east-1"
project_name         = "aws-3tier"
owner                = "DevOpsTeam"
vpc_cidr             = "10.0.0.0/16"

# Compute
instance_type        = "t3.micro"
asg_min_size         = 1
asg_max_size         = 2
asg_desired_capacity = 1

# Database
db_instance_class    = "db.t3.micro"
db_name              = "appdb"
db_username          = "dbadmin"
deletion_protection  = false

# Monitoring
enable_monitoring    = true
