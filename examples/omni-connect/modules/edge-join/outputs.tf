output "joined" {
  description = "Ids of the join steps, one per edge - reference this to order work after the joins"
  value       = [for join in null_resource.edge_join : join.id]
}
