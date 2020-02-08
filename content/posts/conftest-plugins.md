---
title: "Extending conftest with plugins"
date: 2020-02-08T20:43:30+02:00
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

Conftest plugins are stored in a local cache directory, located by default in `~/.conftest/plugins`. Conftest loads plugins located in the cache directory, and makes the plugins available as part of the conftest CLI. For example, if you load the kubectl plugin, this plugin is available in conftest as `conftest kubectl`. To add a plugin to conftest, you need to install it.


Installing plugins is easy using the `conftest plugin install` command. This command should be invoked by passing a valid URL. Conftest will then fetch the plugin from the URL and ensure it is properly installed into the cache. After that you should be able to use the plugin. Under the hood conftest uses the [go-getter](https://github.com/hashicorp/go-getter) library to download plugins. This means plugins can be downloaded from git, Amazon s3, Google cloud buckets, etc.

So how does conftest know what to do when a plugin is called? Each plugin is identified by a `plugin.yaml` file. This file contains the name of the plugin, some metadata and the command to execute when the plugin starts up. For example, the kubectl plugin is defined as follows:

```yaml
name: "kubectl"
version: "0.1.0"
usage: conftest kubectl (TYPE[.VERSION][.GROUP] [NAME] | TYPE[.VERSION][.GROUP]/NAME).
description: |-
  A Kubectl plugin for using Conftest to test objects in Kubernetes using Open Policy Agent.
  Usage: conftest kubectl (TYPE[.VERSION][.GROUP] [NAME] | TYPE[.VERSION][.GROUP]/NAME).
command: $CONFTEST_PLUGIN_DIR/kubectl-conftest.sh
```

The following fields are defined in a `plugin.yaml` file:

- name: the name of the plugin. This also determines how the plugin will be made available in the conftest CLI. E.g. if the plugin is named kubectl, you can call the plugin with `conftest kubectl`
- version: Version of the plugin.
- usage: a short usage description.
- description: A long description of the plugin. This is displayed as the help message for the plugin.
- command: The command that your plugin will execute when calling the plugin. In this case, a local bash script (`kubectl-conftest.sh`) will be invoked whenever `conftest kubectl` is called.

The `kubectl-conftest.sh` bash script calls the kubectl command and passes the output of the kubectl command to conftest. Conftest in turn tests this output against the specified set of Rego policies. The kubectl plugin expects a resource type (e.g. Pod, Deployment, Service) and optionally a resource name as input.