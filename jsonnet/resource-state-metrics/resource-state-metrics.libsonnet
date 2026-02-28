// Copyright 2026 The Kubernetes resource-state-metrics Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

{
  local rsm = self,
  name:: error 'must set name',
  namespace:: error 'must set namespace',
  version:: error 'must set version',
  image:: error 'must set image',

  commonLabels:: {
    'app.kubernetes.io/name': 'resource-state-metrics',
    'app.kubernetes.io/version': rsm.version,
  },

  extraRecommendedLabels:: {
    'app.kubernetes.io/component': 'exporter',
  },

  podLabels:: {
    [labelName]: rsm.commonLabels[labelName]
    for labelName in std.objectFields(rsm.commonLabels)
    if !std.setMember(labelName, ['app.kubernetes.io/version'])
  },

  clusterRoleBinding:
    {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRoleBinding',
      metadata: {
        name: rsm.name,
        labels: rsm.commonLabels + rsm.extraRecommendedLabels,
      },
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'ClusterRole',
        name: rsm.name,
      },
      subjects: [{
        kind: 'ServiceAccount',
        name: rsm.name,
        namespace: rsm.namespace,
      }],
    },

  // ClusterRole rules ordered alphabetically by apiGroup to match controller-gen output.
  clusterRole:
    local rules = [
      {
        apiGroups: ['apiextensions.k8s.io'],
        resources: [
          'customresourcedefinitions',
        ],
        verbs: ['get', 'list', 'watch'],
      },
      {
        apiGroups: ['authentication.k8s.io'],
        resources: [
          'tokenreviews',
        ],
        verbs: ['create'],
      },
      {
        apiGroups: ['authorization.k8s.io'],
        resources: [
          'subjectaccessreviews',
        ],
        verbs: ['create'],
      },
      {
        apiGroups: ['resource-state-metrics.instrumentation.k8s-sigs.io'],
        resources: [
          'resourcemetricsmonitors',
          'resourcemetricsmonitors/status',
        ],
        verbs: ['*'],
      },
    ];

    {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRole',
      metadata: {
        name: rsm.name,
        labels: rsm.commonLabels + rsm.extraRecommendedLabels,
      },
      rules: rules,
    },

  deployment:
    local c = {
      name: 'resource-state-metrics',
      image: rsm.image,
      args: [
        '--main-host=0.0.0.0',
        '--main-port=9999',
        '--self-host=0.0.0.0',
        '--self-port=9998',
      ],
      ports: [
        { name: 'http-metrics', containerPort: 9999 },
        { name: 'telemetry', containerPort: 9998 },
      ],
      securityContext: {
        runAsUser: 65534,
        runAsNonRoot: true,
        allowPrivilegeEscalation: false,
        readOnlyRootFilesystem: true,
        capabilities: { drop: ['ALL'] },
        seccompProfile: { type: 'RuntimeDefault' },
      },
      livenessProbe: { timeoutSeconds: 5, initialDelaySeconds: 5, httpGet: {
        port: 'http-metrics',
        path: '/livez',
      } },
      readinessProbe: { timeoutSeconds: 5, initialDelaySeconds: 5, httpGet: {
        port: 'telemetry',
        path: '/readyz',
      } },
    };

    {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: {
        name: rsm.name,
        namespace: rsm.namespace,
        labels: rsm.commonLabels + rsm.extraRecommendedLabels,
      },
      spec: {
        replicas: 1,
        selector: { matchLabels: rsm.podLabels },
        template: {
          metadata: {
            labels: rsm.commonLabels + rsm.extraRecommendedLabels,
          },
          spec: {
            containers: [c],
            serviceAccountName: rsm.serviceAccount.metadata.name,
            automountServiceAccountToken: true,
            nodeSelector: { 'kubernetes.io/os': 'linux' },
          },
        },
      },
    },

  serviceAccount:
    {
      apiVersion: 'v1',
      kind: 'ServiceAccount',
      metadata: {
        name: rsm.name,
        namespace: rsm.namespace,
        labels: rsm.commonLabels + rsm.extraRecommendedLabels,
      },
      automountServiceAccountToken: false,
    },

  service:
    {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: rsm.name,
        namespace: rsm.namespace,
        labels: rsm.commonLabels + rsm.extraRecommendedLabels,
      },
      spec: {
        clusterIP: 'None',
        selector: rsm.podLabels,
        ports: [
          { name: 'http-metrics', port: 9999, targetPort: 'http-metrics' },
          { name: 'telemetry', port: 9998, targetPort: 'telemetry' },
        ],
      },
    },

  // CRD spec must match controller-gen output in manifests/custom-resource-definition.yaml
  customResourceDefinition:
    {
      apiVersion: 'apiextensions.k8s.io/v1',
      kind: 'CustomResourceDefinition',
      metadata: {
        name: 'resourcemetricsmonitors.resource-state-metrics.instrumentation.k8s-sigs.io',
      },
      spec: {
        group: 'resource-state-metrics.instrumentation.k8s-sigs.io',
        names: {
          kind: 'ResourceMetricsMonitor',
          listKind: 'ResourceMetricsMonitorList',
          plural: 'resourcemetricsmonitors',
          shortNames: ['rmm'],
          singular: 'resourcemetricsmonitor',
        },
        scope: 'Namespaced',
        versions: [
          {
            name: 'v1alpha1',
            served: true,
            storage: true,
            subresources: {
              status: {},
            },
            schema: {
              openAPIV3Schema: {
                type: 'object',
                description: 'ResourceMetricsMonitor is a specification for a ResourceMetricsMonitor resource.',
                properties: {
                  apiVersion: {
                    type: 'string',
                    description: 'APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources',
                  },
                  kind: {
                    type: 'string',
                    description: 'Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds',
                  },
                  metadata: {
                    type: 'object',
                  },
                  spec: {
                    type: 'object',
                    description: 'ResourceMetricsMonitorSpec is the spec for a ResourceMetricsMonitor resource.',
                    required: ['configuration'],
                    properties: {
                      configuration: {
                        type: 'string',
                        description: 'Configuration is the RSM configuration that generates metrics.',
                      },
                    },
                  },
                  status: {
                    type: 'object',
                    description: 'ResourceMetricsMonitorStatus is the status for a ResourceMetricsMonitor resource.',
                    properties: {
                      conditions: {
                        type: 'array',
                        description: 'Conditions is an array of conditions associated with the resource.',
                        'x-kubernetes-list-map-keys': ['type'],
                        'x-kubernetes-list-type': 'map',
                        items: {
                          type: 'object',
                          description: 'Condition contains details for one aspect of the current state of this API Resource.',
                          required: ['lastTransitionTime', 'message', 'reason', 'status', 'type'],
                          properties: {
                            lastTransitionTime: {
                              type: 'string',
                              format: 'date-time',
                              description: 'lastTransitionTime is the last time the condition transitioned from one status to another.\nThis should be when the underlying condition changed.  If that is not known, then using the time when the API field changed is acceptable.',
                            },
                            message: {
                              type: 'string',
                              maxLength: 32768,
                              description: 'message is a human readable message indicating details about the transition.\nThis may be an empty string.',
                            },
                            observedGeneration: {
                              type: 'integer',
                              format: 'int64',
                              minimum: 0,
                              description: 'observedGeneration represents the .metadata.generation that the condition was set based upon.\nFor instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date\nwith respect to the current state of the instance.',
                            },
                            reason: {
                              type: 'string',
                              maxLength: 1024,
                              minLength: 1,
                              pattern: '^[A-Za-z]([A-Za-z0-9_,:]*[A-Za-z0-9_])?$',
                              description: "reason contains a programmatic identifier indicating the reason for the condition's last transition.\nProducers of specific condition types may define expected values and meanings for this field,\nand whether the values are considered a guaranteed API.\nThe value should be a CamelCase string.\nThis field may not be empty.",
                            },
                            status: {
                              type: 'string',
                              enum: ['True', 'False', 'Unknown'],
                              description: 'status of the condition, one of True, False, Unknown.',
                            },
                            type: {
                              type: 'string',
                              maxLength: 316,
                              pattern: '^([a-z0-9]([-a-z0-9]*[a-z0-9])?(\\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*/)?(([A-Za-z0-9][-A-Za-z0-9_.]*)?[A-Za-z0-9])$',
                              description: 'type of condition in CamelCase or in foo.example.com/CamelCase.',
                            },
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        ],
      },
    },
}
