local k = import "ksonnet/ksonnet.beta.3/k.libsonnet";

{
    alertmanager+: {
        secret:
            local secret = k.core.v1.secret;

            secret.new("alertmanager-main", {"alertmanager.yaml": std.base64($._config.alertmanagerConfig)}) +
              secret.mixin.metadata.withNamespace($._config.namespace),

        serviceAccount:
            local serviceAccount = k.core.v1.serviceAccount;

            serviceAccount.new("alertmanager-main") +
              serviceAccount.mixin.metadata.withNamespace($._config.namespace),

        service:
            local service = k.core.v1.service;
            local servicePort = k.core.v1.service.mixin.spec.portsType;

            local alertmanagerPort = servicePort.newNamed("web", 9093, "web");

            service.new("alertmanager-main", {app: "alertmanager", alertmanager: "main"}, alertmanagerPort) +
              service.mixin.metadata.withNamespace($._config.namespace) +
              service.mixin.metadata.withLabels({alertmanager: "main"}),

        serviceMonitor:
            {
                "apiVersion": "monitoring.coreos.com/v1",
                "kind": "ServiceMonitor",
                "metadata": {
                    "name": "alertmanager",
                    "namespace": $._config.namespace,
                    "labels": {
                        "k8s-app": "alertmanager"
                    }
                },
                "spec": {
                    "selector": {
                        "matchLabels": {
                            "alertmanager": "main"
                        }
                    },
                    "namespaceSelector": {
                        "matchNames": [
                            "monitoring"
                        ]
                    },
                    "endpoints": [
                        {
                            "port": "web",
                            "interval": "30s"
                        }
                    ]
                }
            },

        alertmanager:
            {
              apiVersion: "monitoring.coreos.com/v1",
              kind: "Alertmanager",
              metadata: {
                name: "main",
                namespace: $._config.namespace,
                labels: {
                  alertmanager: "main",
                },
              },
              spec: {
                replicas: 3,
                version: "v0.14.0",
                serviceAccountName: "alertmanager-main",
              },
            },
    }
}
