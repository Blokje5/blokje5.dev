---
title: "Validating Terraform plans with the Open Policy Agent"
date: 2019-07-20T21:37:03+02:00
draft: false
tags: ["terraform", "conftest", "open-policy-agent"]
abstract: "Validating whether a set of resources in the cloud comply with your internal company policies is hard. Of course proprietary tools exists for cloud providers that evaluate all resources in that cloud provider, but that already limits their usability. In this post I will introduce the Open Policy Agent as a generic policy evaluation engine that could solve all your compliance problem, and I will show a real world example using the Open Policy Agent to evaluate Terraform Plans."
---

# Validating Terraform plans with the Open Policy Agent

Teams in a DevOps organisation should be free to setup and manage the infrastructure for their services. Terraform is a great way to allow teams to declaratively define their infrastructure needs. However, from a compliance and security perspective, you want to place certain guardrails in place. One such guardrail is of course restricting the set of permissions the teams are given. This stops teams from deploying infrastructure your organisation does not have a need for (Most likely your teams do not need to setup [satellite connections from the cloud](https://aws.amazon.com/ground-station/)) and prevents them from editing resources not managed by them. But it does not cover all rules and regulations that you want to enforce. You also want to ensure that teams do not create public databases, or that the naming convention of your organisation is followed.

One approach you could take is to setup an auditing service like [AWS Config](https://aws.amazon.com/config/):

> AWS Config is a fully managed service that provides you with an AWS resource inventory, configuration history, and configuration change notifications to enable security and governance. With AWS Config you can discover existing AWS resources, export a complete inventory of your AWS resources with all configuration details, and determine how a resource was configured at any point in time. These capabilities enable compliance auditing, security analysis, resource change tracking, and troubleshooting.

Together with [AWS system manager automation](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-automation.html) you can even automatically remediate actions based on configuration changes. For example you could automatically remove public read/write ACLs from a S3 bucket.

There are two problems with this approach however:

1. It only works for AWS resources. If you have resources in multiple cloud providers or if you are deploying applications on top of Kubernetes you need to setup different tools for those environments. Which also means that you need to spend time to become familiar with those tools. Compliance regulations could be configured differently in the different environments, leading to inconsistency and potential violations of company policy.

2. It is applied after the resources are deployed. Of course in severe cases most likely you automatically remediate the action, meaning no manual action is required. However, there is no visibility for the team why it was changed. They might not even be aware a change happened!

## Introducing the Open Policy Agent

In order to remediate the previously described issues, we need a more flexible tool for our governance needs. Preferably we also would like to run the tool as a validation step before the resources are actually deployed.

Luckily for us, such a tool exists, the Open Policy Agent:

> Open Policy Agent (OPA) is a general-purpose policy engine with uses ranging from authorization and admission control to data filtering. OPA provides greater flexibility and expressiveness than hard-coded service logic or ad-hoc domain-specific languages. And it comes with powerful tooling to help you get started

The Open Policy Agent allows you to define policies in based on the Rego language, which is a declarative language based on [Datalog](https://en.wikipedia.org/wiki/Datalog). The Open Policy Agent can be integrated into your application landscape on three ways:

1. Running as a standalone server that can be queried for policy evaluation. This is great for runtime policy evaluation. For example, [integrating OPA as a Kubernetes admission controller](https://github.com/open-policy-agent/gatekeeper).

2. Using the OPA CLI as a command line tool. This could be used to evaluate policies as part of a CI/CD pipeline. For example using a tool like [conftest](https://github.com/instrumenta/conftest) to validate infrastructure configuration.

3. Embedding OPA as a Go library into your application. A great example of this is [Chef Automate](https://github.com/chef/automate/tree/master/components/authz-service), which build an IAM system leveraging OPA.

As you can see, OPA provides a lot of flexibility. This allows one policy to be applied in multiple ways. You no longer need to learn several proprietary tools, instead you only need to become familiar with Rego.

## Getting started with Rego policies

With OPA you query data (By default, OPA support JSON), which can be pulled in by OPA or send via its REST APIs. Along side the data, you define a set of policies which define the state of the data. For example, you could define a policy that states that all S3 buckets should have ACLs that disallow public access. These policies are written in Rego.

Rego is a declarative language, which means that a policy writer can focus more on what the policy should return, rather then on how to execute the queries. It has great support for dealing with deeply nested structures (such as JSON). It also supports many built in functions to be able to support complex policies.

The basic unit in a Rego policy is a rule. Rules allow you to make an assertion about the desired state.

```golang
sites := [{"name": "prod"}, {"name": "smoke1"}, {"name": "dev"}]

prod_exists { sites[_].name == "prod" }
```

In the above policy, you assign an array of JSON objects to the rule `sites`. In rule `prod_exists` we make an assertion: There exists a site in sites with the name "prod". When we query this rule with OPA, it will return true, because currently the `sites` object contains a site named "prod". You do not have to write a for-loop over the `sites` array and write an if-statement to check if the name is equal to "prod" and then return true. You can just state the assertion and OPA will figure out how to execute the query! 

We can improve on the above example by generalising the rule:

```golang
exists[name] {  name := sites[_].name }
```

Now the rule `exists` will return the set of all names in `sites`. We can rewrite the `prod_exists` rule as follow:

```golang
prod_exists { exists["prod"] }
```

Rego also support functions. There is a whole list of build in functions: Aggregation functions, Regex, Set operations, you name it. Rego also allows you to define your own functions:

```golang
is_proper_url(url) {
    re_match(`https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)`, url)
}
```

Here we define a function `is_proper_url` which takes in a url and evaluates whether it matches a regex pattern (using the build in `re_match` function). When evaluating the query:

```golang
is_proper_url("https://play.openpolicyagent.org")
```

This will return the value true.

Rego policies are ordered in packages:

```golang
package url

is_proper_url(url) {
    re_match(`https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)`, url)
}
```

And these packages can be imported in other policies using the import statement:

```golang
import data.url

url.is_proper_url("https://play.openpolicyagent.org")
```

Note that we import from data. OPA treats both policies and input (JSON) data as data.

These simple snippets hopefully show the power of a declarative language. Instead of focusing on the details, such as how to loop over an array of data, OPA will figure out how to execute the query. As a policy writer, you just make assertions on the expected state of the system. If you want to know more about writing policies in Rego, I suggest checking out [the documentation](https://www.openpolicyagent.org/docs/latest/how-do-i-write-policies/). There is also [the Rego playground](https://play.openpolicyagent.org/) which allows you to play around with policies.

Next lets work on a real world example! Along the way I will show some of the more advanced features of Rego.

## Using the Open Policy Agent to validate Terraform plans

Before Terraform deploys a set of resources it creates a plan of all the changes it will apply. With OPA, we can validate these plans to ensure they comply with our regulations and standards.

Now lets work on a real world situation. Lets say we have several teams working with Terraform to deploy AWS resources. We want to ensure teams apply [AWS Tagging best practices](https://aws.amazon.com/answers/account-management/aws-tagging-strategies/), as it allows us to easily search for resources and setup budget reports per team.

Terraform generates a terraform specific execution plan. However, OPA only understands JSON input. Luckily, Terraform 0.12 came with the ability to output plans in json (For Terraform pre 0.12, you can use [tfjson](https://github.com/palantir/tfjson)):

```bash
terraform plan -out=tfplan
terraform show -json ./tfplan > tfplan.json
```

Terraform outputs a deeply nested JSON structure that shows both the previous state of the resources and shows the state after executing the plan. Luckily OPA shines in dealing with complicated JSON as we will see.

We will validate our policies against this JSON plan. In order to simplify the setup of our validation pipeline, we will use [conftest](https://github.com/instrumenta/conftest), which provides a CLI around OPA. Conftest is created to simplify running OPA to validate configuration files in automation. It also provides support for formats other then JSON, such as YAML and TOML. We can use it to validate our Terraform plan against a set of policies (by default conftest looks for a policy directory in your project):

```bash
conftest test tfplan.json
```

Conftest by default looks for `deny[msg]` and `warn[msg]` rules, therefore providing a set of best practices on how to setup your Rego policies. The `msg` can contain additional description on why the rule was triggered. So lets set up some policies! First we will create a package to evaluate our tags:

```golang
package tags_validation

minimum_tags = {"ApplicationRole", "Owner", "Project"}

key_val_valid_pascal_case(key, val) {
    is_pascal_case(key)
    is_pascal_case(val)
}

is_pascal_case(string) {
    re_match(`^([A-Z][a-z0-9]+)+`, string)
}

tags_contain_proper_keys(tags) {
    keys := {key | tags[key]}
    leftover := minimum_tags - keys
    leftover == set()
}
```

We define three functions here: `key_val_valid_pascal_case` validates whether the keys and values are proper pascal case, `is_pascal_case` is a helper function that determines whether a string is pascal case. `tags_contain_proper_keys` validates whether the tags contain atleast the minumum set of tags: ApplicationRole, Owner and Project. Note that we are using a [set comprehension](https://www.openpolicyagent.org/docs/latest/how-do-i-write-policies/#set-comprehensions) to generate a set of keys after which we use set operations to check if the tags contain the minimum set.

Now that we have the functions in place to validate the tags, we can write the actual rules. Ideally our rules also contain some information on which resources where affected and which rule they broke:

```golang
package main

import data.tags_validation

module_address[i] = address {
    changeset := input.resource_changes[i]
    address := changeset.address
}

tags_pascal_case[i] = resources {
    changeset := input.resource_changes[i]
    tags  := changeset.change.after.tags
    resources := [resource | resource := module_address[i]; val := tags[key]; not tags_validation.key_val_valid_pascal_case(key, val)]
}

tags_contain_minimum_set[i] = resources {
    changeset := input.resource_changes[i]
    tags := changeset.change.after.tags
    resources := [resource | resource := module_address[i]; not tags_validation.tags_contain_proper_keys(changeset.change.after.tags)]
}

deny[msg] {
    resources := tags_contain_minimum_set[_]
    resources != []
    msg := sprintf("Invalid tags (missing minimum required tags) for the following resources: %v", [resources])
}

deny[msg] {
    resources := tags_pascal_case[_]
    resources != []
    msg := sprintf("Invalid tags (not pascal case) for the following resources: %v", [resources])
}
```

In conftest, all the data you are testing against is inserted as `input`. So in this case, our Terraform plan output is in `input`. The first rule `module_address[i]` returns the changeset address for the i<sup>th</sup> resource. We use this in the other rules to find the module addresses of the resources that triggered a rule. 

The rules `tags_pascal_case[i]` and `tags_contain_minimum_set[i]` validate the state after the plan against the functions we defined before. For the i<sup>th</sup> resource change, they check the changeset state after and grab the tags. Then we use an [array comprehension](https://www.openpolicyagent.org/docs/latest/how-do-i-write-policies/#array-comprehensions) to get the resources `module_address` of the rules that do not comply with our functions. Here you see the power of Rego: we traverse a deeply nested structure, evaluating rules along the way and return an array of non-compliant resources in a single line.

The two `deny` rules use [incremental rule definitions](https://www.openpolicyagent.org/docs/latest/how-do-i-write-policies/#incremental-definitions) two output a nice message when we have resources that do not comply with our rules. In this case `resources := tags_pascal_case[_]` returns the list of all resources that do not have properly formatted pascal case tags.

## Conclusion

Hopefully you have seen what can be achieved with the Open Policy Agent. It is a really powerful tool for policy evaluation that can be used in multiple places in your architecture to evaluate compliance policies. Although it takes some time to get used to writing Rego policies due to its declarative nature, it is a really powerful language that lets you focus on what you want to achieve, instead of focusing on how to achieve it. And once you know how to write Rego policies, you can apply them across the entire stack!

You can find the code for this blog post on [GitHub](https://github.com/Blokje5/validating-terraform-with-conftest).
