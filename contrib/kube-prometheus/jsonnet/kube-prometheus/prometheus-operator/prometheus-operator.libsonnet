local k = import "ksonnet/ksonnet.beta.3/k.libsonnet";

{
    prometheusOperator+: {
        clusterRoleBinding:
            local clusterRoleBinding = k.rbac.v1.clusterRoleBinding;

            clusterRoleBinding.new() +
              clusterRoleBinding.mixin.metadata.withName("prometheus-operator") +
              clusterRoleBinding.mixin.roleRef.withApiGroup("rbac.authorization.k8s.io") +
              clusterRoleBinding.mixin.roleRef.withName("prometheus-operator") +
              clusterRoleBinding.mixin.roleRef.mixinInstance({kind: "ClusterRole"}) +
              clusterRoleBinding.withSubjects([{kind: "ServiceAccount", name: "prometheus-operator", namespace: $._config.namespace}]),

        clusterRole:
            local clusterRole = k.rbac.v1.clusterRole;
            local policyRule = clusterRole.rulesType;

            local extensionsRule = policyRule.new() +
              policyRule.withApiGroups(["extensions"]) +
              policyRule.withResources([
                "thirdpartyresources",
              ]) +
              policyRule.withVerbs(["*"]);

            local apiExtensionsRule = policyRule.new() +
              policyRule.withApiGroups(["apiextensions.k8s.io"]) +
              policyRule.withResources([
                "customresourcedefinitions",
              ]) +
              policyRule.withVerbs(["*"]);

            local monitoringRule = policyRule.new() +
              policyRule.withApiGroups(["monitoring.coreos.com"]) +
              policyRule.withResources([
                "alertmanagers",
                "prometheuses",
                "prometheuses/finalizers",
                "alertmanagers/finalizers",
                "servicemonitors",
              ]) +
              policyRule.withVerbs(["*"]);

            local appsRule = policyRule.new() +
              policyRule.withApiGroups(["apps"]) +
              policyRule.withResources([
                "statefulsets",
              ]) +
              policyRule.withVerbs(["*"]);

            local coreRule = policyRule.new() +
              policyRule.withApiGroups([""]) +
              policyRule.withResources([
                "configmaps",
                "secrets",
              ]) +
              policyRule.withVerbs(["*"]);

            local podRule = policyRule.new() +
              policyRule.withApiGroups([""]) +
              policyRule.withResources([
                "pods",
              ]) +
              policyRule.withVerbs(["list", "delete"]);

            local routingRule = policyRule.new() +
              policyRule.withApiGroups([""]) +
              policyRule.withResources([
                "services",
                "endpoints",
              ]) +
              policyRule.withVerbs(["get", "create", "update"]);

            local nodeRule = policyRule.new() +
              policyRule.withApiGroups([""]) +
              policyRule.withResources([
                "nodes",
              ]) +
              policyRule.withVerbs(["list", "watch"]);

            local namespaceRule = policyRule.new() +
              policyRule.withApiGroups([""]) +
              policyRule.withResources([
                "namespaces",
              ]) +
              policyRule.withVerbs(["list"]);

            local rules = [extensionsRule, apiExtensionsRule, monitoringRule, appsRule, coreRule, podRule, routingRule, nodeRule, namespaceRule];

            clusterRole.new() +
              clusterRole.mixin.metadata.withName("prometheus-operator") +
              clusterRole.withRules(rules),

        deployment:
            local deployment = k.apps.v1beta2.deployment;
            local container = k.apps.v1beta2.deployment.mixin.spec.template.spec.containersType;
            local containerPort = container.portsType;

            local version = "v0.18.1";
            local targetPort = 8080;
            local podLabels = {"k8s-app": "prometheus-operator"};

            local operatorContainer =
              container.new("prometheus-operator", "quay.io/coreos/prometheus-operator:" + version) +
              container.withPorts(containerPort.newNamed("http", targetPort)) +
              container.withArgs(["--kubelet-service=kube-system/kubelet", "--config-reloader-image=quay.io/coreos/configmap-reload:v0.0.1"]) +
              container.mixin.resources.withRequests({cpu: "100m", memory: "50Mi"}) +
              container.mixin.resources.withLimits({cpu: "200m", memory: "100Mi"});

            deployment.new("prometheus-operator", 1, operatorContainer, podLabels) +
              deployment.mixin.metadata.withNamespace($._config.namespace) +
              deployment.mixin.metadata.withLabels(podLabels) +
              deployment.mixin.spec.selector.withMatchLabels(podLabels) +
              deployment.mixin.spec.template.spec.securityContext.withRunAsNonRoot(true) +
              deployment.mixin.spec.template.spec.securityContext.withRunAsUser(65534) +
              deployment.mixin.spec.template.spec.withServiceAccountName("prometheus-operator"),

        serviceAccount:
            local serviceAccount = k.core.v1.serviceAccount;

            serviceAccount.new("prometheus-operator") +
              serviceAccount.mixin.metadata.withNamespace($._config.namespace),

        service:
            local service = k.core.v1.service;
            local servicePort = k.core.v1.service.mixin.spec.portsType;

            local poServicePort = servicePort.newNamed("http", 8080, "http");

            service.new("prometheus-operator", $.prometheusOperator.deployment.spec.selector.matchLabels, [poServicePort]) +
            service.mixin.metadata.withNamespace($._config.namespace),

        serviceMonitor:
            {
                "apiVersion": "monitoring.coreos.com/v1",
                "kind": "ServiceMonitor",
                "metadata": {
                    "name": "prometheus-operator",
                    "namespace": $._config.namespace,
                    "labels": {
                        "k8s-app": "prometheus-operator"
                    }
                },
                "spec": {
                    "endpoints": [
                        {
                            "port": "http"
                        }
                    ],
                    "selector": {
                        "matchLabels": {
                            "k8s-app": "prometheus-operator"
                        }
                    }
                }
            },
    }
}
