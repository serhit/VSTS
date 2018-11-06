# VSTS
Scripts for interacting with VSTS - DevOps helpers. 

This repository contains several powershell scripts supporting automation of some minor tasks for VSTS 

## PullRequest
PullRequest contains set of libraries and sample script to implement custom PR policy.


### Required setup of Personal Access Token (PAT) creation
Script accesses VSTS under Personal Access Token (PAT). You may create it from your profile -> Security -> Personal Access Token.

PAT will require minimal permissions as:

- Build: Read
- Code: Read, Status
- Release: Read
