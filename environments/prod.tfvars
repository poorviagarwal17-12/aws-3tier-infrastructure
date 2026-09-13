aws_region           = "us-east-1"
project_name         = "aws-3tier"
owner                = "DevOpsTeam"
vpc_cidr             = "10.1.0.0/16"

# Compute
instance_type        = "t3.micro"
asg_min_size         = 2
asg_max_size         = 4
asg_desired_capacity = 2

# Database
db_instance_class    = "db.t3.micro"
db_name              = "appdb"
db_username          = "dbadmin"
deletion_protection  = true

# Monitoring
enable_monitoring    = true
