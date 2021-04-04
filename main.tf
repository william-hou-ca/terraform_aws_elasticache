provider "aws" {
  region = "ca-central-1"
}

provider "aws" {
  alias = "other_region"
  region = "us-east-1"
}

###########################################################################
#
# Create a Memcached cluster.
#
###########################################################################
resource "aws_elasticache_cluster" "mmc" {
  count = 0
  # Cluster engine
  engine               = "memcached"

  # Memcached settings
  cluster_id           = "tf-memcached-cluster"
  engine_version = "1.6.6"
  port                 = 11211
  parameter_group_name = "default.memcached1.6"
  node_type = "cache.t2.micro"
  num_cache_nodes      = 2

  # Advanced Memcached settings
  #subnet_group_name = 
  
  ## Availability zones placement - multi zone configuration
  az_mode = "cross-az" #Valid values for this parameter are single-az or cross-az, default is single-az. If you want to choose cross-az, num_cache_nodes must be greater than 1 
  preferred_availability_zones = ["ca-central-1a", "ca-central-1b"]

  ## Availability zones placement - single zone configuration
  # az_mode = "single-az"
  # availability_zone = "ca-central-1a"

  security_group_ids = data.aws_security_groups.default_sg.ids

  # Maintenance
  maintenance_window = "sun:00:00-sun:01:00"
  # notification_topic_arn = 

  # apply changes immediatly to cluster
  apply_immediately  = true
}




###########################################################################
#
# Create a Redis instance with cluster mode disabled and no replication
#
###########################################################################

resource "aws_elasticache_cluster" "redis_no_cluster_mode_no_replica" {
  count = 0

  # apply changes immediatly to cluster
  apply_immediately  = true
  engine               = "redis"
  
  # Redis settings  
  cluster_id           = "tf-single-node-redis-instance"
  engine_version       = "6.0.5"
  port                 = 6379
  parameter_group_name = "default.redis6.x"
  node_type            = "cache.t2.micro"
  num_cache_nodes      = 1 #For Redis, this value must be 1

  # Advanced Redis settings
  #subnet_group_name =
  #Availability zones placement = 

  # Security
  security_group_ids = data.aws_security_groups.default_sg.ids
  #Encryption at-rest = not supported
  #Encryption in-transit = not supported

  # Import data to cluster 
  ##Seed RDB file S3 location 
  #snapshot_arns = [] #A single-element string list containing an Amazon Resource Name (ARN) of a Redis RDB snapshot file stored in Amazon S3. 

  # Backup
  #Backup retention period 
  # snapshot_name = "backup-name"
  # snapshot_retention_limit = 5
  # snapshot_window = "05:00-09:00"

  # Maintenance
  # maintenance_window = "sun:05:00-sun:09:00"
  # notification_topic_arn =""

}

###########################################################################
#
# Create a Redis instance with cluster mode disabled and has replica instance
# 2 ways to create it:
# the first is: configuring the paramter number_cache_clusters (total number of primary and secondery nodes)
# the second is: number_cache_clusters = 1 (primary) and using aws_elasticache_cluster manually attach replication nodes
#
###########################################################################

resource "aws_elasticache_replication_group" "no_clustermode_with_replicas" {
  count = 0

  # apply changes immediatly to cluster
  apply_immediately  = true
  automatic_failover_enabled    = true
  engine = "redis"

  # Redis settings
  replication_group_id          = "tf-rep-group-1"
  replication_group_description = "redis cluster mode disabled and with replicas"
  engine_version       = "6.x"
  port                          = 6379
  parameter_group_name          = "default.redis6.x"
  node_type                     = "cache.t2.micro"
  number_cache_clusters         = 1 #  The number of cache clusters (primary and replicas) this replication group will have
  multi_az_enabled = true

  # Advanced Redis settings
  # subnet_group_name = 
  availability_zones            = ["ca-central-1a", "ca-central-1b"]

  # Security
  security_group_ids = data.aws_security_groups.default_sg.ids
  # at_rest_encryption_enabled = true
  # kms_key_id = 
  # transit_encryption_enabled = true
  # auth_token = 

  # Import data to cluster
  # snapshot_arns = ""
  # snapshot_name = ""

  # Backup
  snapshot_retention_limit = 0
  snapshot_window  = "05:00-09:00"

  # Maintenance
  maintenance_window = "sun:01:00-sun:03:00"
  # notification_topic_arn = ""



  lifecycle {
    ignore_changes = [number_cache_clusters, engine_version]
  }
}

# cluster atteched to replication group
resource "aws_elasticache_cluster" "replica" {
  count = length(aws_elasticache_replication_group.no_clustermode_with_replicas) > 0 ?  1 : 0

  cluster_id           = "tf-rep-group-1-${count.index}"
  replication_group_id = aws_elasticache_replication_group.no_clustermode_with_replicas[0].id
}

###########################################################################
#
# Create a Redis instance with cluster mode enabled
#
###########################################################################

resource "aws_elasticache_replication_group" "cluster_mode" {
  count = 0
  engine = "redis"
  automatic_failover_enabled    = true
  # apply changes immediatly to cluster
  apply_immediately  = true


  # Redis settings
  replication_group_id          = "tf-redis-cluster-mode"
  replication_group_description = "redis cluster mode enabled"
  engine_version       = "6.x"
  port                          = 6379
  parameter_group_name          = "default.redis6.x.cluster.on"
  node_type                     = "cache.t2.micro"

  cluster_mode {
    num_node_groups         = 2 # Number of Shards
    replicas_per_node_group = 2 # Replicas per Shard
    # total number of nodes = num_node_groups * (replicas_per_node_group + 1)
  }

  multi_az_enabled = true
  # subnet_group_name = 

  # Advanced Redis settings
  # Slots and keyspaces = not supported
  # Availability zones placement = not supported

  # Security
  security_group_ids = data.aws_security_groups.default_sg.ids
  # at_rest_encryption_enabled = true
  # kms_key_id = 
  # transit_encryption_enabled = true
  # auth_token = 

  # Import data to cluster
  # snapshot_arns = ""
  # snapshot_name = ""

  # Backup
  snapshot_retention_limit = 0
  snapshot_window  = "05:00-09:00"

  # Maintenance
  maintenance_window = "sun:01:00-sun:03:00"
  # notification_topic_arn = ""



  lifecycle {
    ignore_changes = [number_cache_clusters, engine_version]
  }

}

###########################################################################
#
# Creating a global replication group
#
###########################################################################
locals {
  redis_global_cluster = 0
}

resource "aws_elasticache_global_replication_group" "redis_global" {
  count = local.redis_global_cluster

  provider = aws.other_region

  global_replication_group_id_suffix = "example"
  primary_replication_group_id       = aws_elasticache_replication_group.redis_global_primary[0].id
}

resource "aws_elasticache_replication_group" "redis_global_primary" {
  count = local.redis_global_cluster

  provider = aws.other_region

  replication_group_id          = "example-primary"
  replication_group_description = "primary replication group"

  engine         = "redis"
  engine_version = "6.x"
  node_type      = "cache.t2.micro"

  number_cache_clusters = 1
}

resource "aws_elasticache_replication_group" "redis_global_secondary" {
  count = local.redis_global_cluster

  replication_group_id          = "example-secondary"
  replication_group_description = "secondary replication group"
  global_replication_group_id   = aws_elasticache_global_replication_group.redis_global[0].global_replication_group_id

  number_cache_clusters = 1
}


###########################################################################
#
# ec2 instance in the default vpc
#
###########################################################################

resource "aws_instance" "web" {
  #count = 0 #if count = 0, this instance will not be created.

  #required parametres
  ami           = "ami-09934b230a2c41883"
  instance_type = "t2.micro"

  #optional parametres
  associate_public_ip_address = true
  key_name = "key-hr123000" #key paire name exists in aws.

  vpc_security_group_ids = data.aws_security_groups.default_sg.ids

  tags = {
    Name = "intance-to-connect-elasticache"
  }

  user_data = <<EOF
          #! /bin/sh
          sudo yum update -y
          sudo amazon-linux-extras install epel -y 
          sudo yum install telnet -y
          EOF

}