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

To make use of the Dev Containers feature in vscode you need to make sure that you install the Visual Studio Code Remote - Containers extension in vscode. And of course, as Docker is used to create isolated development environments, you need to have Docker installed on your machine.

To install the extension, open the extensions panel in vscode (The shortcut is `Ctrl + Shift + x` on Linux/Windows or `Cmd + Shift + x` on Mac). Once you have installed the extension we can get started!

As an example, I am going to show how to create a dockerized development environment for Python. It is quite easy while developing in python to accidentally forget to install a python package in your virtualenv and instead install it globally. An Python version can be quite hard to manage as well. Especially since some operating systems come with a really outdated version of Python. But there is nothing that prevents you to use this same feature for Java development, or React development, or C development.

So let's say we are building a new Flask microservice. Let's start by creating a new directory called app. Then we will open that app inside a new Dev Container with vscode. Go to the Command Pallete (`Ctrl + Shift + p` on Linux/Windows or `Cmd + Shift + p` on Mac) and type `Remote-Containers: Open Folder in Container...` and open the newly created directory. It will ask you to select a base image to use as a starting point for your environment. Make sure you search for the Python 3 Docker image (A full list of all the available images and their definition can be found on [Github](https://github.com/microsoft/vscode-dev-containers)):

![select container](/select-container.png)

A status bar will appear in the bottom right corner of your screen. It might take a few minutes to complete as vscode is pulling the docker image to your local system. After it completes both vscode as well as your development environment will be running inside of the Docker container. You can verify this by opening the terminal (``Ctrl + ` ``) and checking the new environment. If you are like me, the first thing you will notice is the lack of [Oh My Zsh](https://ohmyz.sh/). You can also check by verifying that the only user in `/home` is a user called `vscode`. 

vscode itself actually runs inside the container as well! You can check this by looking at the installed extensions in vscode: Only the ms-python extensions is installed (it comes default with the Python 3 image). What is great about that is that is is now really easy to share the same configuration & extensions with your team mates. And it makes sure that you can manage extensions per project!

To test what we can do in the new work environment, let's create a really simple Flask App in a file called `app.py`:

```python
from flask import Flask
app = Flask(__name__)

@app.route('/')
def hello_world():
    return 'Hello, World!'
```

Couldn't be simpler. You might have noticed some squiggly lines under the import statement when you created this file in vscode. It is a pylint error stating that flask is unavailable in this environment. We did not install flask yet. The Python 3 dev-container image comes with a lot of python utilities such as pylint & pytest. Let's create a requirements.txt file and install Flask:

```bash
pip3 install --user -r requirements.txt
```

This installs flask globally inside the image. We can now use the flask run command to run the app:

```bash
env FLASK_APP=app.py flask run
```

Your Flask app should now be running inside of the container. Using curl we can check if the app is indeed running:  `curl localhost:5000` should return a response of `Hello, World!`.

It is important to note that installing the requirements needs to be repeated on each restart of the container, as Docker removes all uncommitted changes after the container stops. This is of course rather annoying. Maybe we can edit our dev-container to automatically install the requirements?

You might have noticed that a new directory `.devcontainer` was added. This contains a `Dockerfile` that defines the Dev Container, and it contains a `devcontainer.json` file. This ensures that you can consistently rebuild your local development environment. Both these files can be used to customize your development environment.

## Customizing your environment

## Docker in Docker?