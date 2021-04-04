output "ec2-ip"  {
  value = aws_instance.web.public_ip
}

output "memcache-cfg-endpoint" {
  value = length(aws_elasticache_cluster.mmc) > 0 ? aws_elasticache_cluster.mmc[0].configuration_endpoint : ""
}

output "memcache-nodes-endpoint" {
  value = length(aws_elasticache_cluster.mmc) > 0 ? aws_elasticache_cluster.mmc[0].cache_nodes : ""
}

output "redis-noclustermode-noreplicas" {
  value = length(aws_elasticache_cluster.redis_no_cluster_mode_no_replica) > 0 ? aws_elasticache_cluster.redis_no_cluster_mode_no_replica[0].cache_nodes : []
}

output "redis-clustermode" {
  value = length(aws_elasticache_replication_group.cluster_mode) > 0 ? aws_elasticache_replication_group.cluster_mode[0].configuration_endpoint_address : "" 
}