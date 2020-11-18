##############################################################################
# IBM Cloud Provider 1.13.1
##############################################################################

provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  generation       = 2
  region           = var.VPC_Region
  ibmcloud_timeout = 300
  resource_group   = var.Resource_Group
}

##############################################################################
# Variable block - See each variable description
##############################################################################

variable "VPC_Region" {
  default     = ""
  description = "The region where the VPC, networks, and Check Point VSI will be provisioned."
}

variable "Resource_Group" {
  default     = ""
  description = "The resource group that will be used when provisioning the Check Point VSI. If left unspecififed, the account's default resource group will be used."
}

variable "VPC_Name" {
  default     = ""
  description = "The VPC where the Check Point VSI will be provisioned."
}

variable "Management_Subnet_ID" {
  default     = ""
  description = "The ID of the Check Point management subnet."
}

variable "External_Subnet_ID" {
  default     = ""
  description = "The ID of the subnet that exists in front of the Check Point Security Gateway that will be provisioned (the 'external' network)."
}

variable "Internal_Subnet_ID" {
  default     = ""
  description = "The ID of the subnet that exists behind  the Check Point Security Gateway that will be provisioned (the 'internal' network)."
}

variable "SSH_Key" {
  default     = ""
  description = "The pubic SSH Key that will be used when provisioning the Check Point VSI."
}

variable "VNF_CP-GW_Instance" {
  default     = "checkpoint-gw-image"
  description = "The name of the Check Point Security Gatewat that will be provisioned."
}

variable "VNF_Security_Group" {
  default     = ""
  description = "The name of the security group assigned to the Check Point VSI."
}

variable "VNF_Profile" {
  default     = "bx2-2x8"
  description = "The VNF profile that defines the CPU and memory resources. This will be used when provisioning the Check Point VSI."
}

variable "CP_Version" {
  default     = ""
  description = "(HIDDEN) The version of Check Point to deploy. R80.40, R81EA"
}

variable "vnf_license" {
  default     = ""
  description = "(HIDDEN) Optional. The BYOL license key that you want your cp virtual server in a VPC to be used by registration flow during cloud-init."
}

variable "ibmcloud_endpoint" {
  default     = "cloud.ibm.com"
  description = "(HIDDEN) The IBM Cloud environmental variable 'cloud.ibm.com' or 'test.cloud.ibm.com'"
}

variable "delete_custom_image_confirmation" {
  default     = ""
  description = "(HIDDEN) This variable is to get the confirmation from customers that they will delete the custom image manually, post successful installation of VNF instances. Customer should enter 'Yes' to proceed further with the installation."
}

variable "ibmcloud_api_key" {
  default     = ""
  description = "(HIDDEN) holds the user api key"
}

##############################################################################
# Data block 
##############################################################################

data "ibm_is_subnet" "cp_subnet0" {
  identifier = var.Management_Subnet_ID
}

data "ibm_is_subnet" "cp_subnet1" {
  identifier = var.External_Subnet_ID
}

data "ibm_is_subnet" "cp_subnet2" {
  identifier = var.Internal_Subnet_ID
}

data "ibm_is_image" "cp_gw_custom_image" {
  name = ibm_is_image.cp_gw_custom_image.name
}

data "ibm_is_ssh_key" "cp_ssh_pub_key" {
  name = var.SSH_Key
}

data "ibm_is_instance_profile" "vnf_profile" {
  name = var.VNF_Profile
}

data "ibm_is_region" "region" {
  name = var.VPC_Region
}

data "ibm_is_vpc" "cp_vpc" {
  name = var.VPC_Name
}

data "ibm_resource_group" "rg" {
  name = var.Resource_Group
}

##############################################################################
# Create Custom Image
##############################################################################

# Generating random ID
resource "random_uuid" "test" { }

locals {
  image_url = "cos://${var.VPC_Region}/checkpoint-${var.VPC_Region}/Check_Point_${var.CP_Version}_Cloudguard_Security_Gateway.qcow2"
}

resource "ibm_is_image" "cp_gw_custom_image" {
  depends_on       = [random_uuid.test]
  href             = local.image_url
  name             = "${var.VNF_CP-GW_Instance}-${substr(random_uuid.test.result,0,8)}"
  operating_system = "centos-7-amd64"
  resource_group   = data.ibm_resource_group.rg.id

  timeouts {
    create = "30m"
    delete = "10m"
  }
}

##############################################################################
# Create Security Group
##############################################################################

resource "ibm_is_security_group" "ckp_security_group" {
  name           = var.VNF_Security_Group
  vpc            = data.ibm_is_vpc.cp_vpc.id
  resource_group = data.ibm_resource_group.rg.id
}

#Egress All Ports
resource "ibm_is_security_group_rule" "allow_egress_all" {
  depends_on = [ibm_is_security_group.ckp_security_group]
  group      = ibm_is_security_group.ckp_security_group.id
  direction  = "outbound"
  remote     = "0.0.0.0/0"
}

#Ingress All Ports
resource "ibm_is_security_group_rule" "allow_ingress_all" {
  depends_on = [ibm_is_security_group.ckp_security_group]
  group      = ibm_is_security_group.ckp_security_group.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"
}


##############################################################################
# Create Check Point Gateway
##############################################################################

resource "ibm_is_instance" "cp_gw_vsi" {
  depends_on     = [ibm_is_security_group_rule.allow_ingress_all, data.ibm_is_image.cp_gw_custom_image]
  name           = var.VNF_CP-GW_Instance
  image          = ibm_is_image.cp_gw_custom_image.id
  profile        = data.ibm_is_instance_profile.vnf_profile.name
  resource_group = data.ibm_resource_group.rg.id

  #eth0 - Management Interface
  primary_network_interface {
    name            = "eth0"
    subnet          = data.ibm_is_subnet.cp_subnet0.id
    security_groups = [ibm_is_security_group.ckp_security_group.id]
  }

  #eth1 - External Interface
  network_interfaces {
    name            = "eth1"
    subnet          = data.ibm_is_subnet.cp_subnet1.id
    security_groups = [ibm_is_security_group.ckp_security_group.id]
  }

  #eth2 - Internal Interface
  network_interfaces {
    name            = "eth2"
    subnet          = data.ibm_is_subnet.cp_subnet2.id
    security_groups = [ibm_is_security_group.ckp_security_group.id]
  }

  vpc  = data.ibm_is_vpc.cp_vpc.id
  zone = data.ibm_is_subnet.cp_subnet0.zone
  keys = [data.ibm_is_ssh_key.cp_ssh_pub_key.id]

  #Custom UserData
  user_data = file("user_data")

  timeouts {
    create = "15m"
    delete = "15m"
  }
  # Hack to handle some race condition; will remove it once have root caused the issues.
  provisioner "local-exec" {
    command = "sleep 30"
  }
}

# Delete checkpoint firewall custom image from the local user after VSI creation.
data "external" "delete_custom_image1" {
  depends_on = [ibm_is_instance.cp_gw_vsi]
  program    = ["bash", "${path.module}/scripts/delete_custom_image.sh"]

  query = {
    custom_image_id = data.ibm_is_image.cp_gw_custom_image.id
    region          = var.VPC_Region
  }
}

output "delete_custom_image1" {
  value = lookup(data.external.delete_custom_image1.result, "custom_image_id")
}
