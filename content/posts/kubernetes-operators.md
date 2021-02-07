+++ 
draft = true
date = 2021-01-10T21:16:04+01:00
title = "A guide to Kubernetes Operators"
abstract = ""
tags = ["kubernetes", "kubebuilder", "kubernetes-operators"]
+++

Kubernetes operators provide 

## What is an operator

An operator is an application that extends Kubernetes with new custom resources. They allow you to add new resource types (also referred to as kind) to your Kubernetes cluster. The operator is then responsible for watching changes to these custom resources and change the state of your infrastructure accordingly.

 For example, the [etcd-operator](https://github.com/coreos/etcd-operator) extends your Kubernetes cluster with the ETCD resource kind, allowing users of your cluster to spin up ETCD databases without having to worry about all the details, such as provisioning volumes for the ETCD cluster.

And it doesn't stop at just the creation of the ETCD database! The ETCD operator provides advanced features such as failover, backups and rolling upgrades! Normally, a cluster admin would get involved in order to handle a rolling upgrade of an ETCD cluster. Now we can automate these complicated manual tasks! That really shows the power of the operator pattern: it goes far beyond just resource provisioning.

Red Hat defines several operator capability levels on the [OperatorHub](https://operatorhub.io/):

- Basic Install: These operators are capable of automated application provisioning and provide the ability for managing the configuration of the application
- Seamless Upgrades: Upgrades of patch and minor versions should be supported by the operator
- Full Lifecycle: The operator should handle both the storage lifecycle of an application (which includes backups and automated failure recovery) as well as the application lifecycle.
- Deep Insights: Metrics, logs, alerts and workload analysis should all be handled by the operator.
- Auto Pilot: The operator is fully responsible for your application. It should automatically scale your application, tune the configuration and detect abnormal behaviour.

Human operators often understand everything about the applications they maintain. They know how to perform upgrades of the application, what to do when the CPU is overloaded and how to failover to another instance. But these steps often also require manual intervention of the human operator. Operators really aim to capture the know-how of human operators in code. Operators provide you with a means to scale your applications without having to worry your overloading the ops team.

## How does an operator work

Operators utilise the control loop pattern. They watch the Kubernetes API for changes in the desired state, often expressed as custom resources although operators can also extend existing resources such as the Service or Job kind. The operator is then responsible for reconciling the desired state with the current state. The diagram below explains this relation schematically.

![Kubernetes Operator Diagram](/kubernetes-operator-diagram.png)

Control loops originate from industrial control systems. You can imagine a chemical engineering plant, where a control loop is responsible for maintaining the desired state of a reactor. The control loop will watch the reactor for changes in temperature and pressure, and will make adjustments to the reactor to ensure the current state matches the desired state. Both unexpected changes in the environment (e.g. a reactor overheating) as well as changes by the chemical engineers maintaining the reactor (e.g. increasing the heat in the reactor for the second phase of a chemical reaction) trigger the control loop to reconcile current state with desired state.

Often when developing operators you will want to add a new resource to your Kubernetes cluster, such as the kind ETCD. This kind services as an abstraction between the underlying infrastructure and the end user. Kubernetes allows you to easily and dynamically add new custom resources using custom resource definitions (CRDs). These custom resources extends Kubernetes with a new resource definition and adds a new endpoint to the Kubernetes API. Kubernetes will implement the common restful operation for this new resource, such as GET, POST, PUT, DELETE. `kubectl` leverages the Kubernetes API, meaning `kubectl get my-custom-resource` will fetch a list of the `my-custom-resource` kind. Kubernetes will store this new information in the ETCD database backing the Kubernetes cluster.

On their own, these custom resources are simple a way of storing data in Kubernetes. However, combined with a custom operator, custom resources provide a powerful [declarative API](https://en.wikipedia.org/wiki/Declarative_programming) for managing your infrastructure. Custom resources express the desired state and the operator will continuously update your infrastructure to reflect this desired state.

An interesting side note is the fact that a lot of build-in Kubernetes resources are now implemented via custom resources. This provides a lot of modularity to Kubernetes, as a cluster administrator can decide to remove certain build-in kinds by removing the CRD and associated operator. Kubernetes will dynamically deregister the resource from it's API.

# CRDs

CRDs (or CustomResourceDefinitions) are a method of extending the Kubernetes API with new custom resources. A CRD is defined by a name, group, schema and scope. See the code snippet below for an example:

```yml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: cronjobs.blokje5.dev
spec:
  group: blokje5.dev
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                schedule:
                  type: string
                image:
                  type: string
  scope: Namespaced
  names:
    plural: cronjobs
    singular: cronjob
    kind: CronJob
    shortNames:
    - cj
```

The name of a resource is defined by the plural of the kind (e.g. cronjobs) and the group name. The group name is just a mechanism to prevent name conflicts within a cluster. The group is ideally a domain owned by you, to ensure your new kind is globally unique.

The schema is defined for one or more versions of your kind. This allows you to evolve your schema over time. Initially you might start out with a v1alpha1 version to indicate that your API is still unstable, but over time you might release an actual v1 version. The schema is defined as an [OpenAPI 3.0](https://www.openapis.org/) spec. This allows you to define what fields are defined for your custom resource and of what type these fields are. It is also possible to define (basic) validations on your API here, such as regex pattern checks.

The scope defines whether your custom resource is Namespace or Cluster scoped. A Namespace scoped operator operates within the boundaries of a namespace. An example of a namespace scoped operator is the [Strimzi Kafka Operator](https://strimzi.io/), which will only create Kafka clusters in a namespace defined on installation of the operator. A Cluster scoped resource watches all namespaces. [Cert-manager](https://cert-manager.io/docs/) is an example of a Cluster scoped operator as it will provision certificates in all namespaces.

Once a CRD is submitted to the CRD API in Kubernetes, Kubernetes will add the new resource to it's own API server. This automatically ensures that users can use `kubectl` to work with your new custom resource. It will ensure that your resource is stored in the ETCD database backing Kubernetes. No additional API servers are needed at all!
