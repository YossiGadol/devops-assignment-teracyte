# Base image for python-backend

This directory contains the Dockerfile for the base image used in the python-backend service.  
This base image is built on top of the official Python image and includes common dependencies and configurations needed for the backend service.

### Pre-requisites:

- Docker installed on your machine.
- AWS CLI installed and configured with appropriate permissions to push images to ECR.

### Building the Base Image:

You need to rebuild the base image whenever you want to update the Python version or any of the dependencies specified in the requirements.txt file.

1. Update `requirements.txt` as needed.
2. Navigate to the directory containing the Dockerfile:
   ```bash
   cd .k8s/docker/base/docker
   ```
3. Run the build script to build the Docker image:
   ```bash
   ./build.sh
   ```
   This script will build the Docker image and push it to ECR.

In the next deployments of the app, the newly built base image will be used as the source for the python-backend service.
