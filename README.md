# AWS Terraform Demo 

This repo contains example terraform code and github actions workflow needed to deploy modular and scalable AWS infra with Terraform Cloud API

## To Do
- [x] Add integration with TF cloud
- [x] Add integration with Github Actions
- [x] Add deployement for VPC
- [x] Add deployement for EKS
- [x] Seperate AWS accounts support for dev/stgn/prod
- [x] Multi Region support?
- [ ] Explore TF json format for automation and templating purpose
- [ ] Add deployment for Kubernetes (namespace, ingress, IAM....). Find a workaround for the providers alias not able to use variables
- [ ] Add component and deployement for DB
- [ ] Integration with terragrunt? (It seems complicated to get it work with both github actions and TF cloud)
- [ ] Refactor the github actions so we don't need a seperate yml for each component. Find workaround for github actions limitations
- [ ] Use git tags (#ref...) on the modules used in data_source


## Setup
* Create a Terraform Cloud account
* Setup dynamic credentials with AWS provider (https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/aws-configuration)
* Enable Github Actions
* Add the following repository env vars
    * TF_CLOUD_ORGANIZATION
* Add the following repository secret
    * TF_API_TOKEN

#### Create a new workspace in TF cloud
Create a worksapce in Terraform Cloud for each type of resources you wish to deploy (VPC,EKS...). The naming convention should be similar to ```aws-terraform-demo-vpc-ENV-AWS_REGION```. You'll need a sperate workspace for each ENV as well as each AWS_REGION. So for 2 regions you'll need 6 workspaces

#### Add a new component 

Create a new subfolder under ./components. There needs to be 4 files. 
```
main.tf
outputs.tf
providers.tf
variables.tf
```
In providers.tf the default provider for aws should be 

```
provider "aws" {
  region = "$TF_REGION" # set by envsubst in the template file
  allowed_account_ids  = [var.aws_allowed_account_id]
}
```

Create a new subfolder called deploy-XX under the root. Create a subfolder deploy-XX for each deployment region (ie. deploy-XX/ca-central-1). Add the terraform.tfvars file.


#### Add a new pipeline

Clone the values of VPC.yml to a new yml file. Modify the 3 inputs variables to fit your new component and deployment
```
tf_vars_directory: "deploy-xx"
tf_directory: "components/xx"
tf_workspace_prefix: "aws-terraform-demo-xx"
```

#### Seperate AWS accounts for DEV/STGN/PROD

You can have a seperate AWS accounts associated to dev/stgn/prod. Add the following to the github repository variables. The value is the account number

```
TF_VARS_AWS_ALLOWED_ACCOUNTS_IDS_DEV
TF_VARS_AWS_ALLOWED_ACCOUNTS_IDS_STGN
TF_VARS_AWS_ALLOWED_ACCOUNTS_IDS_PROD
```

### To execute the terraform cloud runs locally 
https://developer.hashicorp.com/terraform/cloud-docs/run/cli

## Design choices

![Alt text here](diagrams/folder_structure.svg)


* The repository is structured to facilitate the deployment of various resource types, organized into folders named `deploy-xx` where `xx` corresponds to different types of resources. These folders contain subfolders for each deployment region which themselves contain `.tfvars` files that are used to configure the resources, and the resource configurations are neatly arranged in a map for better organization and readability.

* In the `components` folder, you'll find the Terraform modules necessary for deployment. These modules reference external Git repositories through data sources to pull in the base resource configurations. It's important to note that the `providers.tf` file within the `components` folder specifies the required version of the AWS provider. To ensure smooth deployments, the external Git repositories that the modules reference should use tags that match the AWS provider version specified.

* This setup is designed to provide a clear separation between resource configuration and module definition, which helps in keeping the repository orderly and the deployment process straightforward.

    ### Pros
     * Decoupled components and modules allows for easy upgrade without conflict. Child modules should be tagged and referenced in data source.
     * Seperate pipelines and tfstate for each type or resource, this limits the risk of unwanted changes and make the tfstate smaller ideally.
     * Decouple AWS provider version in for each pipeline. This is sometimes an issue when Terraform is going through major version upgrade, causing some resouces types to have breaking change. By decoupling the providers for each type of resource we isolate the breaking change to a single pipeline. Other resouces can sill proceed with the upgrade.
     * If the organization is not mono-repo, multiple Infra teams within the organization can re-use the same child modules this way.

    ### Cons
    * Adds complexity if you intend to organized multiple types of cloud resources in a "solution" (multiple type of resources managed at the same time as a part of a solution). It's more diffucult to make a tag on a specific release version of the infra for a specfic solution.
    * Upgrade and maintenance of child modules can become a problem in the long run with multiple versions. In a centralized repo all components must be up to date with modules with one single source of truth.
    * Each TFC workspace holds one tfstate for each env, so there could be lots of tfstate.
    * Dependencies between different components must be manually managed. 




## Deployment flow
![Alt text here](diagrams/deployment_flow.svg)

* Deployment uses pull request to tigger build pipelines using Terraform Cloud. Terraform change output will be added to the comments of the pull request
