---
draft: true
date: 2019-10-06T13:40:20+02:00
title: "Building in compliance in your CI/CD pipeline with conftest"
tags: ["conftest", "open-policy-agent", "tekton"]
abstract: "In the previous post I introduced the Open Policy Agent as a method to validate configuration changes against policies to maintain compliance in your environment. In this post I will show how you can utilise the Open Policy Agent with conftest to build in compliance checks in your CI/CD pipeline and how conftest can be used to centrally manage the Rego policies."
---

In the [previous post]({{< ref "validating-terraform-plans.md" >}}) I introduced the Open Policy Agent as a method to validate configuration changes against policies to maintain compliance in your environment. In this post I will show how you can utilise the Open Policy Agent with conftest to build in compliance checks in your CI/CD pipeline and how conftest can be used to centrally manage the Rego policies.

In order to ensure all teams can build in compliance in their development life cycle, we need to ensure every change is validated. In other words: we need to incorporate it as part of the continues integration process. There are several requirements that need to be met before we can achieve this:

- The latest version of the policies needs to be easily accessible by developers
- Updates to policies can quickly be applied accross the organisation
- Policies need to be validated on correctness
- Configuration changes can not be applied without validation

These requirements ensure that every change applied by developers in the organisation keeps the system in a compliant state. 

 