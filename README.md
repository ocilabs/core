## Requirements

No requirements.

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_configuration"></a> [configuration](#module\_configuration) | ./default/ | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_tenancy_ocid"></a> [tenancy\_ocid](#input\_tenancy\_ocid) | A unique identifier for the root tenancy, provided by the cloud controller | `string` | `"ocid_tenancy.xxx"` | no |
| <a name="input_class"></a> [class](#input\_class) | The tenancy classification sets boundaries for resource deployments | `string` | `"PAYG"` | no |
| <a name="input_parent"></a> [parent](#input\_parent) | The Oracle Cloud Identifier (OCID) for a parent compartment, an encapsulating child compartment will be created to define the service resident. Usually this is the root compartment, hence the tenancy OCID. | `string` | `"ocid_tenancy.xxx"` | no |
| <a name="input_organization"></a> [organization](#input\_organization) | The organization represents an unique identifier for a service owner and triggers the definition of groups on root compartment level | `string` | `"Organization"` | no |
| <a name="input_solution"></a> [solution](#input\_solution) | The solution represents an unique identifier for a service defined on root compartment level | `string` | `"Service"` | no |
| <a name="input_repository"></a> [repository](#input\_repository) | The service configuration is stored using infrastructure code in a repository | `string` | `"https://github.com/torstenboettjer/ocloud-default-configuration"` | no |
| <a name="input_owner"></a> [owner](#input\_owner) | The service owner is identified by his or her eMail address | `string` | `"RobotNotExist@oracle.com"` | no |
| <a name="input_stage"></a> [stage](#input\_stage) | The stage variable triggers lifecycle related resources to be provisioned | `string` | `"DEV"` | no |
| <a name="input_region"></a> [region](#input\_region) | The region defines the target region for service deployments | `string` | `"us-ashburn-1"` | no |
| <a name="input_host"></a> [host](#input\_host) | Provisioning a host topology prepares a service resident to deploy a traditional enterprise application with presentation, application and database tier. | `bool` | `true` | no |
| <a name="input_nodes"></a> [nodes](#input\_nodes) | Provisioning a nodes topology prepares a service resident to deploy automatically scaling services separated front- and backend tier for services like like big data or mobile backend. | `bool` | `true` | no |
| <a name="input_container"></a> [container](#input\_container) | Provisioning a container topology prepares a service resident to deploy cloud native services on Oracle's Kubernetes Engine (OKE). | `bool` | `true` | no |
| <a name="input_amend"></a> [amend](#input\_amend) | A flage that allows to delete compartments with terraform destroy. This setting should only be changed by experienced users. | `bool` | `true` | no |
| <a name="input_internet"></a> [internet](#input\_internet) | Allows or disallows to provision resources with public IP addresses. | `string` | `"ENABLE"` | no |
| <a name="input_nat"></a> [nat](#input\_nat) | Enables or disables routes through a NAT Gateway. | `string` | `"ENABLE"` | no |
| <a name="input_ipv6"></a> [ipv6](#input\_ipv6) | Triggers the release of IPv6 addresses inside the VCN. | `bool` | `false` | no |
| <a name="input_osn"></a> [osn](#input\_osn) | Configures the scope for the service gateway | `string` | `"ALL"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_tenancy"></a> [tenancy](#output\_tenancy) | n/a |
| <a name="output_resident"></a> [resident](#output\_resident) | n/a |
| <a name="output_network"></a> [network](#output\_network) | n/a |
