terraform {
  required_version = ">= 0.13"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0, < 3.0.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0, <= 3.0.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0, <= 4.0.0"
    }
  }

  backend "local" {}
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

locals {
  app                = yamldecode(file("./kubernetes/app.yaml"))
  config_map_scripts = yamldecode(file("./kubernetes/configmaps_scripts.yaml"))
  config_map_sql     = yamldecode(file("./kubernetes/configmaps_sql.yaml"))
  hpa                = yamldecode(file("./kubernetes/hpa.yaml"))
  namespace          = yamldecode(file("./kubernetes/namespace.yaml"))
  secrets            = yamldecode(file("./kubernetes/secrets.yaml"))
  service            = yamldecode(file("./kubernetes/service.yaml"))

  volumes_secrets = flatten([
    for _, volume in local.app.spec.template.spec.volumes
    : volume if length(try(volume.secret, "")) > 0
  ])

  volumes_config_map = flatten([
    for _, volume in local.app.spec.template.spec.volumes
    : volume if length(try(volume.configMap, "")) > 0
  ])
}

resource "local_sensitive_file" "secret_string_data" {
  for_each = local.secrets.stringData
  content  = each.value
  filename = "${path.module}/.cache/${each.key}"
}

resource "kubernetes_secret" "database_secrets" {
  depends_on = [local_sensitive_file.secret_string_data]
  metadata {
    name      = local.secrets.metadata.name
    namespace = local.secrets.metadata.namespace
    labels    = local.secrets.metadata.labels
  }

  data = merge([
    {
      for k, v in local.secrets.data :
      format("%s", k) => v
    },
    {
      for k, v in local.secrets.stringData :
      format("%s", k) => (v == tostring(null)
        || v == tostring("")
      ? try(file("${path.module}/.cache/${k}"), null) : v)
    }
  ]...)

  type = local.secrets.type
}

resource "kubernetes_config_map" "config_maps_scripts" {
  metadata {
    name      = local.config_map_scripts.metadata.name
    namespace = local.config_map_scripts.metadata.namespace
    labels    = local.config_map_scripts.metadata.labels
  }

  data = merge([
    for k, v in local.config_map_scripts.data :
    { format("%s", k) = (v == tostring(null)
      || v == tostring("")
    ? try(file("${path.module}/scripts/${k}"), null) : v) }
  ]...)
}

resource "kubernetes_config_map" "config_maps_sql" {
  metadata {
    name      = local.config_map_sql.metadata.name
    namespace = local.config_map_sql.metadata.namespace
    labels    = local.config_map_sql.metadata.labels
  }

  data = merge([
    for k, v in local.config_map_sql.data :
    { format("%s", k) = (v == tostring(null)
      || v == tostring("")
    ? try(file("${path.module}/scripts/${k}"), null) : v) }
  ]...)
}

resource "kubernetes_deployment" "deployment" {
  depends_on = [kubernetes_config_map.config_maps_scripts]

  metadata {
    labels    = local.app.metadata.labels
    name      = local.app.metadata.name
    namespace = local.app.metadata.namespace
  }

  spec {
    replicas                  = local.app.spec.replicas
    progress_deadline_seconds = local.app.spec.progressDeadlineSeconds
    revision_history_limit    = local.app.spec.revisionHistoryLimit

    selector {
      match_labels = local.app.spec.selector.matchLabels
    }

    strategy {
      type = local.app.spec.strategy.type
      rolling_update {
        max_surge       = local.app.spec.strategy.rollingUpdate.maxSurge
        max_unavailable = local.app.spec.strategy.rollingUpdate.maxUnavailable
      }
    }

    template {
      metadata {
        labels    = try(local.app.spec.template.metadata.labels, tomap({}))
        name      = try(local.app.spec.template.metadata.name, null)
        namespace = try(local.app.spec.template.metadata.namespace, null)
      }

      spec {
        termination_grace_period_seconds = try(local.app.spec.template.spec.terminationGracePeriodSeconds, 30)

        dynamic "init_container" {
          for_each = local.app.spec.template.spec.initContainers
          content {
            name              = init_container.value.name
            image             = init_container.value.image
            image_pull_policy = try(init_container.value.imagePullPolicy, null)
            command           = try(init_container.value.command, tolist([]))

            dynamic "env_from" {
              for_each = try(init_container.value.envFrom, tolist([]))
              content {
                dynamic "secret_ref" {
                  for_each = try(env_from.value, tolist([]))
                  content {
                    name = try(secret_ref.value.name, null)
                  }
                }
              }
            }

            dynamic "port" {
              for_each = try(init_container.value.ports, tolist([]))
              content {
                container_port = try(port.value.containerPort, 80)
                host_ip        = try(port.value.hostIP, null)
                host_port      = try(port.value.hostPort, null)
                name           = try(port.value.name, null)
                protocol       = try(port.value.protocol, "TCP")
              }
            }

            dynamic "volume_mount" {
              for_each = try(init_container.value.volumeMounts, tolist([]))
              content {
                name       = try(volume_mount.value.name, null)
                mount_path = try(volume_mount.value.mountPath, null)
                sub_path   = try(volume_mount.value.subPath, null)
                read_only  = try(volume_mount.value.readOnly, null)
              }
            }
          }
        }

        dynamic "container" {
          for_each = local.app.spec.template.spec["containers"]
          content {
            name              = container.value["name"]
            image             = container.value["image"]
            image_pull_policy = try(container.value["imagePullPolicy"], null)
            command           = try(container.value["command"], tolist([]))

            dynamic "env_from" {
              for_each = try(container.value["envFrom"], tolist([]))
              content {
                dynamic "secret_ref" {
                  for_each = try(env_from.value, tolist([]))
                  content {
                    name = secret_ref.value.name
                  }
                }
              }
            }

            dynamic "port" {
              for_each = container.value.ports
              content {
                container_port = try(port.value.containerPort, 80)
                host_ip        = try(port.value.hostIP, null)
                host_port      = try(port.value.hostPort, null)
                name           = try(port.value.name, null)
                protocol       = try(port.value.protocol, "TCP")
              }
            }

            dynamic "lifecycle" {
              for_each = try(container.value.lifecycle, tomap({}))
              content {
                dynamic "pre_stop" {
                  for_each = try(container.value.lifecycle.preStop, tomap({}))
                  content {
                    dynamic "exec" {
                      for_each = try(container.value.lifecycle.preStop.exec, tomap({}))
                      content {
                        command = try(container.value.lifecycle.preStop.exec.command, tolist([]))
                      }
                    }
                  }
                }
              }
            }

            liveness_probe {
              http_get {
                path = try(container.value.livenessProbe.httpGet.path, null)
                port = try(container.value.livenessProbe.httpGet.port, null)
              }
              initial_delay_seconds = try(container.value.livenessProbe.initialDelaySeconds, null)
              period_seconds        = try(container.value.livenessProbe.periodSeconds, 10)
              timeout_seconds       = try(container.value.livenessProbe.timeoutSeconds, 1)
              success_threshold     = try(container.value.livenessProbe.successThreshold, 1)
              failure_threshold     = try(container.value.livenessProbe.failureThreshold, 3)
            }

            readiness_probe {
              http_get {
                path = try(container.value.readinessProbe.httpGet.path, null)
                port = try(container.value.readinessProbe.httpGet.port, null)
              }
              initial_delay_seconds = try(container.value.readinessProbe.initialDelaySeconds, null)
              period_seconds        = try(container.value.readinessProbe.periodSeconds, 10)
              timeout_seconds       = try(container.value.readinessProbe.timeoutSeconds, 1)
              success_threshold     = try(container.value.readinessProbe.successThreshold, 1)
              failure_threshold     = try(container.value.readinessProbe.failureThreshold, 3)
            }

            resources {
              limits = {
                cpu    = try(container.value.resources.limits.cpu, null)
                memory = try(container.value.resources.limits.memory, null)
              }
              requests = {
                cpu    = try(container.value.resources.requests.cpu, null)
                memory = try(container.value.resources.requests.memory, null)
              }
            }

            dynamic "volume_mount" {
              for_each = try(container.value.volumeMounts, tolist([]))
              content {
                mount_path = try(volume_mount.value.mountPath, null)
                name       = try(volume_mount.value.name, null)
                read_only  = try(volume_mount.value.readOnly, null)
                sub_path   = try(volume_mount.value.subPath, null)
              }
            }
          }
        }

        dynamic "volume" {
          for_each = local.volumes_secrets
          content {
            name = volume.value.name
            secret {
              secret_name = volume.value.secret.secretName
              dynamic "items" {
                for_each = try(volume.value.secret.items, tolist([]))
                content {
                  key  = items.value.key
                  path = items.value.path
                }
              }
              default_mode = try(format("04s", volume.value.secret.defaultMode), "0644")
            }
          }
        }

        dynamic "volume" {
          for_each = local.volumes_config_map
          content {
            name = volume.value.name
            config_map {
              name = volume.value.configMap.name
              dynamic "items" {
                for_each = try(volume.value.configMap.items, tolist([]))
                content {
                  key  = items.value.key
                  path = items.value.path
                }
              }
              default_mode = try(format("04s", volume.value.configMap.defaultMode), "0755")
            }
          }
        }

        dns_policy = try(local.app.spec.template.spec.ClusterFirst, "ClusterFirst")
      }
    }
  }
}

resource "kubernetes_service" "service" {
  depends_on = [kubernetes_deployment.deployment]
  metadata {
    name      = local.service.metadata.name
    namespace = local.service.metadata.namespace
    labels    = local.service.metadata.labels
  }
  spec {
    selector = local.service.spec.selector
    type     = local.service.spec.type
    dynamic "port" {
      for_each = local.service.spec.ports
      content {
        port        = port.value.port
        target_port = port.value.targetPort
        name        = port.value.name
        protocol    = port.value.protocol
      }
    }
    publish_not_ready_addresses = false
  }
  wait_for_load_balancer = false
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "hpa" {
  depends_on = [kubernetes_deployment.deployment]
  metadata {
    name      = local.hpa.metadata.name
    namespace = local.hpa.metadata.namespace
    labels    = local.hpa.metadata.labels
  }

  spec {
    min_replicas = local.hpa.spec.minReplicas
    max_replicas = local.hpa.spec.maxReplicas

    scale_target_ref {
      kind        = local.hpa.spec.scaleTargetRef.kind
      name        = local.hpa.spec.scaleTargetRef.name
      api_version = local.hpa.spec.scaleTargetRef.apiVersion
    }

    dynamic "metric" {
      for_each = try(local.hpa.spec.metrics, tolist([]))
      content {
        type = metric.value.type

        resource {
          name = metric.value.resource.name
          target {
            type                = metric.value.resource.target.type
            average_utilization = metric.value.resource.target.averageUtilization
          }
        }
      }
    }

    behavior {
      scale_down {
        stabilization_window_seconds = 300
        select_policy                = "Min"
        policy {
          period_seconds = 120
          type           = "Pods"
          value          = 1
        }

        policy {
          period_seconds = 310
          type           = "Percent"
          value          = 100
        }
      }
      scale_up {
        stabilization_window_seconds = 600
        select_policy                = "Max"
        policy {
          period_seconds = 180
          type           = "Percent"
          value          = 100
        }
        policy {
          period_seconds = 600
          type           = "Pods"
          value          = 5
        }
      }
    }
  }
}

resource "local_file" "deployment_yaml" {
  depends_on = [kubernetes_deployment.deployment]
  content    = yamlencode(kubernetes_deployment.deployment)
  filename   = "${path.module}/main.yaml"
}

output "deployment" {
  description = "Kubernetes Dockerize Deployment"
  value       = kubernetes_deployment.deployment
}

output "service" {
  description = "Kubernetes Dockerize Service"
  value       = kubernetes_service.service
}

output "hpa" {
  description = "Kubernetes Dockerize Horizontal Pod Autoscaler"
  value       = kubernetes_horizontal_pod_autoscaler_v2.hpa
}

output "deployment_yaml" {
  description = "Kubernetes Dockerize Deployment Yaml Generated By Terraform"
  value       = yamlencode(kubernetes_deployment.deployment)
}
