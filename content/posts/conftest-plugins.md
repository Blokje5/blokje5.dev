---
title: "Extending conftest with plugins"
date: 2020-02-23T13:43:30+02:00
draft: false
tags: ["conftest"]
abstract: "Conftest now supports a plugin mechanism. These plugins allow you to extend conftest without needing to edit the codebase. In this blog post I will show you how to use conftest plugins and how to create your own."
---
> If you are unfamiliar with [conftest](https://github.com/instrumenta/conftest), I wrote a previous blog post on [utilising conftest to build compliance into CI/CD pipelines]({{< ref "compliance-in-cicd.md" >}}).

Conftest plugins allow users to extend the conftest CLI without needing to add to the codebase. This means anybody can add new features to conftest. For example, you could easily build a kubectl plugin that passes information from a live kubernetes cluster into conftest. This allows conftest to test Rego policies against live applications! This can be a good first step for achieving compliance in a continuos manner. First existing applications can be audited, and the teams maintaining that application can be notified before new compliance rules will be enabled. This gives teams the opportunities to prepare instead of forcing them to change their application as soon as new rules are enabled.

Or you could write a plugin that monitors resources of your cloud provider. No need anymore to rely on proprietary cloud monitoring services. Instead you can reuse the same policies you used with conftest in your CI/CD pipelines to monitor live cloud resources!

Of course this could be achieved with some scripting in the past. The main benefit of plugins however is that they can be shared and reused by the community! Instead of having to copy over some bash scripts from another blog, you can download a plugin created by another community member!

In this blog post I will explain how you can use plugins to extend conftest. I will show how to install and utilise plugins. After that I will show how you can create your own plugins.

## Using conftest plugins

Conftest plugins are stored in a local cache directory, located by default in `~/.conftest/plugins`. Conftest loads plugins located in the cache directory, and makes the plugins available as part of the conftest CLI. For example, if you load the kubectl plugin, this plugin is available in conftest as `conftest kubectl`.

Installing plugins is easy using the `conftest plugin install` command. This command should be invoked by passing a valid URL. Conftest will then fetch the plugin from the URL and ensure it is properly installed into the cache. After that you should be able to use the plugin. Under the hood conftest uses the [go-getter](https://github.com/hashicorp/go-getter) library to download plugins. This means plugins can be downloaded from git, Amazon s3, Google cloud buckets, etc. To add a plugin to conftest, you need to install it. To install the kubectl plugin from the conftest github repository we can run the following command:

```console
conftest plugin install git::https://github.com/instrumenta/conftest.git//examples/plugins/kubectl
```

Note the double slash, that is actually necessary to download relative paths in Git. Once the plugin is installed, it can be used directly by calling the contest CLI. We can try this with the kubectl plugin. With the kubectl plugin we can test Rego policies against a live cluster. For example, we can use a simple policy to check if there are any containers in our cluster that run as root:

```rego
package main

deny[msg] {
  input.kind = "Deployment"
  not input.spec.template.spec.securityContext.runAsNonRoot

  msg = sprintf("Containers must not run as root in Deployment %s", [name])
}
```

Preventing a container to run as a non-root user is a security best practice. It prevents a potential attacker to gain access to the host from the container if they somehow manage to gain access to your container. For example, an attacker could have exploited a code execution vulnerability in your application. Now let's use the kubectl plugin to verify if this is the case for some running deployments.

First we need a Kubernetes cluster. The quickest way to do this locally is by using [kind](https://github.com/kubernetes-sigs/kind), which builds a local Kubernetes cluster running in docker containers. We can build a cluster with the following command:

```console
kind create cluster --name conftest-demo --wait 200s
export KUBECONFIG=$(kind get kubeconfig-path --name conftest-demo)
```

This will create a simple kubernetes cluster on your local computer. We also make sure we setup our kubeconfig to point to the newly created cluster. Now let's deploy a simple application:

```yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.7.9
        ports:
        - containerPort: 80
```

As you can see, we did not configure a [SecurityContext](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/) on this deployment. That means any container we run can run as root. We can now validate this against our Rego policy using the kubectl plugin:

```console
conftest kubectl deployment nginx-deployment
FAIL - Containers must not run as root in Deployment nginx-deployment
```

Great! now we can validate live applications in a Kubernetes cluster against our policies!

## Plugins behind the scenes

So how does conftest know what to do when a plugin is called? Each plugin is identified by a `plugin.yaml` file. This file contains the name of the plugin, some metadata and the command to execute when the plugin starts up. For example, the kubectl plugin is defined as follows:

```yaml
name: "kubectl"
version: "0.1.0"
usage: conftest kubectl (TYPE[.VERSION][.GROUP] [NAME] | TYPE[.VERSION][.GROUP]/NAME).
description: |-
  A Conftest plugin for using kubectl to test objects in Kubernetes using Open Policy Agent.
  Usage: conftest kubectl (TYPE[.VERSION][.GROUP] [NAME] | TYPE[.VERSION][.GROUP]/NAME).
command: $CONFTEST_PLUGIN_DIR/kubectl-conftest.sh
```

The following fields are defined in a `plugin.yaml` file:

- name: the name of the plugin. This also determines how the plugin will be made available in the conftest CLI. E.g. if the plugin is named kubectl, you can call the plugin with `conftest kubectl`
- version: Version of the plugin.
- usage: a short usage description.
- description: A long description of the plugin. This is displayed as the help message for the plugin.
- command: The command that your plugin will execute when calling the plugin. In this case, a local bash script (`kubectl-conftest.sh`) will be invoked whenever `conftest kubectl` is called. Let's look at the source code:

```bash
#!/bin/bash

# kubectl-conftest allows for testing resources in your cluster using Open Policy Agent
# It uses the conftest utility and expects to find associated policy files in
# a directory called policy


# Check if a specified command exists on the path and is executable
function check_command () {
    if ! [[ -x $(command -v $1) ]] ; then
        echo "$1 not installed"
        exit 1
    fi
}

function usage () {
    echo "A Kubectl plugin for using Conftest to test objects in Kubernetes using Open Policy Agent"
    echo
    echo "See https://github.com/instrumenta/conftest for more information"
    echo
    echo "Usage:"
    echo "   conftest kubectl (TYPE[.VERSION][.GROUP] [NAME] | TYPE[.VERSION][.GROUP]/NAME)"
}

CONFTEST_BIN="conftest"

# Check the required commands are available on the PATH
check_command "kubectl"


if [[ ($# -eq 0) || ($1 == "--help") || ($1 == "-h") ]]; then
    # No commands or the --help flag passed and we'll show the usage instructions
    usage
elif [[ ($# -eq 1) && $1 =~ ^[a-z\.]+$ ]]; then
    # If we have one argument we get the list of objects from kubectl
    # parse our the individual items and then pass those one by one into conftest
    check_command "jq"
    if output=$(kubectl get $1 $2 -o json); then
        echo $output | jq -cj '.items[] | tostring+"\u0000"' | xargs -n1 -0 -I@ bash -c "echo '@' | ${CONFTEST_BIN} test -"
    fi
elif [[ ($# -eq 1 ) ]]; then
    # Support the / variant for getting an individual resource
    if output=$(kubectl get $1 -o json); then
        echo $output | ${CONFTEST_BIN} test -
    fi
elif [[ ($# -eq 2 ) && $1 =~ ^[a-z]+$ ]]; then
    # if we have two arguments then we assume the first is the type and the second the resource name
    if output=$(kubectl get $1 $2 -o json); then
        echo $output | ${CONFTEST_BIN} test -
    fi
elif [[ ($# -gt 2 ) ]]; then
    echo "${@:3}"
    if output=$(kubectl get $1 $2 -o json); then
        echo $output | ${CONFTEST_BIN} test ${@:3} -
    fi
else
    echo "Please check the arguments to kubectl conftest"
    echo
    usage
    exit 1
fi
```

The `kubectl-conftest.sh` bash script calls the kubectl command and passes the output of the kubectl command to conftest. Conftest in turn tests this output against the specified set of Rego policies. The kubectl plugin expects a resource type (e.g. Pod, Deployment, Service) and optionally a resource name as input.

As you can see, writing a plugin really is not that hard. Now let's create a plugin from scratch!

## Creating a plugin

> The code for the plugin is available on [GitHub](https://github.com/Blokje5/aws-conftest-plugin).

I work a lot with AWS infrastructure. Ideally I want to reuse the same policies in Rego I use to validate [Terraform deployments]({{< ref "validating-terraform-plans.md" >}}). So let's create a (simple) plugin that allows us to monitor AWS resources.

In order to create a plugin, we need two components: an executable and a `plugin.yaml` file. Our executable should be able to interact with AWS resources. We can leverage the python library [boto3](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html) to interact with the AWS API. The AWS CLI itself is also written using boto3.

To make our executable a bit more user friendly, we can use [click](https://click.palletsprojects.com/en/7.x/). Click is a python library to make beautiful CLI tools. So let's get started:

```python
import datetime
import json
import subprocess

import boto3
import click


def default(o):
    if isinstance(o, (datetime.date, datetime.datetime)):
        return o.isoformat()


class CLIContext:
    def __init__(self):
        if not self.check_conftest_program():
            raise RuntimeError("Could not find the conftest program")
        self.ctx = {}

    def check_conftest_program(self):
        from shutil import which

        if which("conftest"):
            return True

        return False


@click.group()
@click.pass_context
def cli(ctx):
    ctx.obj = CLIContext()


@cli.command()
@click.argument("instance_id")
@click.option(
    "--output",
    default=False,
    help="Print the ec2 instance output instead of running a test against it",
)
@click.option("--policy", default="policy", help="path to the policy dir")
@click.pass_context
def ec2(ctx, instance_id, output, policy):
    client = boto3.client("ec2")
    response = client.describe_instances(
        Filters=[{"Name": "instance-id", "Values": [instance_id]}]
    )
    instance = response["Reservations"][0]["Instances"][0]
    if output:
        click.echo(json.dumps(instance, indent=4, default=default))
    else:
        call_conftest(json.dumps(instance, default=default), policy)


def call_conftest(input, policy):
    p = subprocess.Popen(
        ["conftest", "test", "--input", "json", "--policy", policy, "-"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        stdin=subprocess.PIPE,
    )
    output = p.communicate(str.encode(input))[0]
    print(output.decode())


if __name__ == "__main__":
    cli(obj={})
```

This python code creates a subcommand called `ec2`. The `ec2` subcommand takes an AWS EC2 identifier as input and calls the `describe_instances` method to fetch some information about the EC2 instance. Depending on whether the `--output` flag is passed it will either pretty-print the information, or it will call `conftest` using the `subprocess` library in python. In the `call_conftest` method, we pipe the output of the `describe_instances` to `conftest` and print out the results. Conftest of course will use the [Open Policy Agent](https://www.openpolicyagent.org/) to validate the passed input against a Rego policy.

In order to use this python snippet as a conftest plugin, we need to define a `plugin.yaml` for this plugin:

```yml
name: "aws"
version: "0.1.0"
usage: conftest aws [TYPE] [NAME] [FLAGS]
description: |-
  A Conftest plugin for validating AWS resources with Open Policy Agent.
  Usage: conftest aws [TYPE] [NAME] [FLAGS]
command: python $CONFTEST_PLUGIN_DIR/main.py
```

The command calls the python interpreter to execute the python script we created. The plugin is now ready for action. First we need to install it:

```console
conftest plugin install https://github.com/Blokje5/aws-conftest-plugin.git
```

We leverage the fact that the plugin is already available in a git repository. As mentioned previously, `conftest` supports installing plugins from Git. Now we can call start using the plugin. Let's define a simple Rego policy:


```golang
package main

deny[msg] {
    input.InstanceType == "t3.xlarge"
    msg := "Instance type not supported within the organisation"
}
```

This creates a rule that validates whether an EC2 instance is of type `t3.xlarge`. If that is the case, the policy should fail. It is not the most useful policy, but it is enough to demonstrate what we can do with conftest plugins. Let's use our plugin to validate an instance:

```console
conftest aws ec2 <some-t3.xlarge-instance-identifier>
FAIL - Instance type not supported within the organisation
```

Great! We can now validate EC2 instances in the cloud using Rego policies. Of course a lot more interesting checks can be performed. We could validate the security groups attached to an EC2 instance, or check if the AMI is using an operating system deemed secure enough for production use cases. But the main point of this article is to showcase the flexibility of conftest plugins. Now instead of relying on custom built tools, we can leverage the Open Policy Agent to validate resources in a Kubernetes cluster. Or to validate ec2 instances in the AWS cloud.
