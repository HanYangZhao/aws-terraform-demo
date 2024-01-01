The terraform tfvars sets the variables declared in components/eks


## To Do

- [ ] vpc_cni_irsa doesn't work with for_each. Move it to the eks child module
- [ ] aws_auth_roles doesn't work without the kubernetes provider. Create new kubenetes pipeline to manage everything kubernetes

## Diagram 

![Alt text here](../diagrams/EKS.svg)