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

## Centralising Rego policies

In order to make the policies accessible to all developers, we need to store the policies in a centrally accessible location. Luckily, [conftest](https://github.com/instrumenta/conftest) support storing Rego policies in a Docker registry. Under the hood, conftest is utilising [ORAS](https://github.com/deislabs/oras). ORAS, or OCI Registry As Storage is an initiative by Microsoft to support pushing artifacts to OCI Spec Compliant registries. Rego policies are stored using the [Bundle format](https://www.openpolicyagent.org/docs/latest/management/#bundles) specified by the Open Policy Agent.

Let's look at an example of how that can work. First we need access to a Docker registry. At the moment of writing, only two registries support ORAS, namely the [Docker distribution](https://github.com/docker/distribution) and the [Azure Container Registry](https://azure.microsoft.com/nl-nl/services/container-registry/). I will be using the Docker distribution.

```bash
docker run -d --rm -p 5000:5000 --name registry registry:2
```

This command starts a local Docker registry, running in detached mode. Now we can push policies to the registry using conftest:

```bash
conftest push localhost:5000/policies:latest
```

This command pushes the policies in your local directory to the Docker registry. By default conftest looks for policies in the `policy` directory, but this can be overridden by specifying the `--policy` flag. The syntax is similar to how you would push a Docker container, where you specify the registry location, the name of the image and an optional tag.

These policies can then be pulled using the pull command:

```bash
conftest pull localhost:5000/policies:latest
```

The `pull` command by default pulls policies into the `policy` directory.

With central storage in place, a single (or multiple depending on the size of your organisation) compliance platform team can maintain the policies. Developers can easily access the latest version of the policies.

## Validating the policies

Rego can be hard. We don't want to push policies that are broken. If the policies are broken, changes can be applied that need to be manually resolved later. Which is inefficient of course. Luckily, Rego policies have built in support for unit tests.

Rego tests are just regular Rego policies, but with the rules prefixed with `test_`. Let's look at an example:

```golang
package tags_validation

minimum_tags = {"ApplicationRole", "Owner", "Project"}

tags_contain_proper_keys(tags) {
    keys := {key | tags[key]}
    leftover := minimum_tags - keys
    leftover == set()
}
```

The function `tags_contain_proper_keys` validates whether a set of tags contain the minimum required tags. We can test this with the following unit test:

```golang
package aws.tags_validation

test_tags_contain_proper_keys {
    tags := { "ApplicationRole": "ArtifactRepository", "Project": "Artifacts", "Owner": "MyTeam", "Country": "Nl" }
    tags_contain_proper_keys(tags)
}

test_tags_contain_proper_keys_missing_key {
    tags := { "ApplicationRole": "ArtifactRepository", "Project": "Artifacts", "Country": "Nl" }
    not tags_contain_proper_keys(tags)
}
```

This passes a set of tags to the  function and asserts whether the function returns the expected result. Just like with regular code, it is important to validate what you write.

conftest supports the `verify` command to the test Rego policies:

```bash
conftest verify
```
