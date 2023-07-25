# output "module_outputs" {
#   value = flatten(module.pre03[*])
# }

output "user_password" {
  value     = random_password.pre03.result
  sensitive = true
}

locals {
  all_locations = [
    for deploy in var.deployment_locations : deploy.location
  ]

  all_users = flatten([
    for loc in local.all_locations : 
      flatten([
        for deploy in module.pre03.* : deploy[loc].users
      ])
  ])

  all_resource_groups = flatten([
    for loc in local.all_locations : 
      flatten([
        for deploy in module.pre03.* : deploy[loc].resource_groups
      ])
  ])

  all_aks_clusters = flatten([
    for loc in local.all_locations : 
      flatten([
        for deploy in module.pre03.* : deploy[loc].aks_clusters
      ])
  ])
}

output "users" {
  value = local.all_users
}

output "resource_groups" {
  value = local.all_resource_groups
}

output "aks_clusters" {
  value = local.all_aks_clusters
}