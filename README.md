# AWS Terraform Demo 

This repo contains example terraform code and github actions workflow needed to deploy modular and scalable AWS infra with Terraform Cloud API

## Setup

* Enable Github Actions
* Add the following repository env vars
    * TF_CLOUD_ORGANIZATION
* Add the following repository secret
    * TF_API_TOKEN
* Create a worksapce in Terraform Cloud for each type of resources you wish to deploy (VPC,EKS...)

## Design choices

![Alt text here](diagrams/folder_structure.svg)


* The repository is structured to facilitate the deployment of various resource types, organized into folders named `deploy-xx` where `xx` corresponds to different types of resources. These folders contain `.tfvars` files that are used to configure the resources, and the resource configurations are neatly arranged in a map for better organization and readability.

* In the `components` folder, you'll find the Terraform modules necessary for deployment. These modules reference external Git repositories through data sources to pull in the base resource configurations. It's important to note that the `providers.tf` file within the `components` folder specifies the required version of the AWS provider. To ensure smooth deployments, the external Git repositories that the modules reference should use tags that match the AWS provider version specified.

* This setup is designed to provide a clear separation between resource configuration and module definition, which helps in keeping the repository orderly and the deployment process straightforward.

    ### Pros
     * Decoupled components and modules allows for easy upgrade 
     * Seperate pipelines for each type or resource
     * Decouple AWS provider version in for each resource type

    ### Cons
    * Not good if you intend to organized multiple cloud resources in a "solution" (multiple type of resources deployed at the same time)

## Deployment flow