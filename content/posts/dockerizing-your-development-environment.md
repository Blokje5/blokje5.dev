---
title: "Dockerizing your development environment"
date: 2020-02-23T13:43:30+02:00
draft: false
tags: ["vs code", "docker"]
abstract: "Keeping up with the latest and greatest in the software industry requires a constantly changing development environment. Keeping your local machine clean is hard if you constantly install new tools. And what if you need multiple versions of the same tool installed? With Visual Studio Code Dev Containers you can dockerize your development environment to ensure that for each project you can use a clean and reproducible environment! "
---

Most development environments are not heterogenous. Over time more languages, libraries, frameworks & tools are introduced into the organisation, while others are phased out. This means that you need to keep your development environment up to date with these changes. And of course, just when you updated your environment, a legacy application experiences an issue and now you need to ensure that your environment also supports older versions of the tools in use. There are tools such as Brew & Chocolatey which help you with the installation and management of your machine. And tools such as jenv allow you to per directory define what the local version of the JVM in use is. But after installing the tenth tool with env as a suffix it becomes a bit cumbersome. Lazyiness creeps in and we forget to properly manage the dependencies of our development environment. I once had to hotfix a presentation I created an our before I was giving the presentation as I was using reveal.js and there was a node.js version compatibility issue. 

And dependencies are not the only thing we need to worry about! We still have to maintain git configurations, IDE extensions, dotfiles, environment variables, etc. And that is just *your* development environment, what about your team members environment? Or the environment of the person working on the project 2 years down the line? Ideally you would just start with a clean and reproducible environment per project. But the amount of bash scripting required too maintain this is too high! Everybody has a neglected dotfiles repository somewhere.

Luckily, Visual Studio Code (vscode) has released a feature called Dev Containers that allows you to dockerize your entire development environment! Even vscode itself! In this post I will show you how you can get started with Dev Containers and how you can ensure a clean working environment for each project. Even better, the configuration is easily shareable. As long as your team mates also use vscode, they can reuse the same dockerized environment!

## Getting Started 

## Customizing your environment

## Docker in Docker?