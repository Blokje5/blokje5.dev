---
title: "Extending conftest with plugins"
date: 2020-02-08T20:43:30+02:00
draft: false
tags: ["conftest"]
abstract: "Conftest now supports a plugin mechanism. These plugins allow you to extend conftest without needing to edit the codebase. In this blog post I will show you how to use conftest plugins and how to create your own."
---
> If you are unfamiliar with [conftest](https://github.com/instrumenta/conftest), I wrote a previous blog post of [utilising conftest to build compliance into CI/CD pipelines]({{< ref "compliance-in-cicd.md" >}}).

Conftest plugins allow users to extend the conftest CLI without needing to add to the codebase. This means anybody can add new features to conftest. For example, you could easily build a kubectl plugin that passes information from a live kubernetes cluster into conftest. This allows conftest to test Rego policies against live applications! This can be a good first step for achieving compliance in a continuos manner. First existing applications can be audited, and the teams maintaining that application can be notified before new compliance rules will be enabled. This gives teams the opportunities to prepare instead of forcing them to change their application as soon as new rules are enabled.

Or you could write a plugin that monitors resources of your cloud provider. No need anymore to rely on proprietary cloud monitoring services. Instead you can reuse the same policies you used with conftest in your CI/CD pipelines to monitor live cloud resources!

Of course this could be achieved with some scripting in the past. The main benefit of plugins however is that they can be shared and reused by the community! Instead of having to copy over some bash scripts from another blog, you can download a plugin created by another community member!

In this blog post I will explain how you can use plugins to extend conftest. I will show how to install and utilise plugins. After that I will show how you can create your own plugins.
