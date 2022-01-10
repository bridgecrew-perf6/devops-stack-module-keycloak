resource "argocd_project" "this" {
  metadata {
    name      = "keycloak"
    namespace = var.argocd.namespace
    annotations = {
      "devops-stack.io/argocd_namespace" = var.argocd.namespace
    }
  }
 
  spec {
    description  = "keycloak application project"
    source_repos = [
      "https://github.com/camptocamp/devops-stack-module-keycloak.git",
      "https://github.com/keycloak/keycloak-operator.git"
    ]
 
    destination {
      server    = "https://kubernetes.default.svc"
      namespace = var.namespace
    }
 
    orphaned_resources {
      warn = true
    }

    cluster_resource_whitelist {
      group = "*"
      kind  = "*"
    }
  }
}

data "utils_deep_merge_yaml" "values" {
  input = [ for i in var.profiles : templatefile("${path.module}/profiles/${i}.yaml", {
      oidc           = var.oidc,
      base_domain    = var.base_domain,
      cluster_issuer = var.cluster_issuer,
      argocd         = var.argocd,
      keycloak       = local.keycloak,
  }) ]
}

resource "argocd_application" "operator" {
  metadata {
    name      = "keycloak-operator"
    namespace = var.argocd.namespace
  }

  spec {
    project = argocd_project.this.metadata.0.name

    source {
      repo_url        = "https://github.com/keycloak/keycloak-operator.git"
      path            = "deploy"
      target_revision = "15.0.1"
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = var.namespace
    }

    sync_policy {
      automated = {
        prune     = true
        self_heal = true
      }

      sync_options = [
        "CreateNamespace=true"
      ]
    }
  }
}

resource "argocd_application" "this" {
  metadata {
    name      = "keycloak"
    namespace = var.argocd.namespace
  }

  spec {
    project = argocd_project.this.metadata.0.name

    source {
      repo_url        = "https://github.com/camptocamp/devops-stack-module-keycloak.git"
      path            = "charts/keycloak"
      target_revision = "main"
      helm {
        values = data.utils_deep_merge_yaml.values.output
      }
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = var.namespace
    }

    sync_policy {
      automated = {
        prune     = true
        self_heal = true
      }

      sync_options = [
        "CreateNamespace=true"
      ]
    }
  }

  depends_on = [ argocd_application.operator ]
}