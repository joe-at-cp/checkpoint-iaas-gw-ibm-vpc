##############################################################################
# IBM Cloud Provider
##############################################################################

provider "ibm" {
  ibmcloud_api_key   = "${var.ibmcloud_api_key}"
  generation         = 2
  region             = "${var.region}"
  ibmcloud_timeout   = 300
  resource_group     = "${var.resource_group}"
}

##############################################################################
# Variable block - See each variable description
##############################################################################

variable "region" {
  default     = "us-east"
  description = "The VPC Region that you want your VPC, networks and the CP virtual server to be provisioned in. To list available regions, run `ibmcloud is regions`."
}

variable "resource_group" {
  default     = "cprg"
  description = "The resource group to use. If unspecified, the account's default resource group is used."
}

variable "vnf_cos_gw_image_url" {
  default     = "cos://us-east/r80.40-03252020/Check_Point_R80.40_Cloudguard_Security_Gateway_Generic_06012020_EA.qcow2"
  description = "The COS image object SQL URL for Checkpoint GW qcow2 image."
}

variable "vnf_cos_gw_image_url_test" {
  default     = ""
  description = "The COS image object url for Checkpoint GW qcow2 image in test.cloud.ibm.com."
}

variable "zone" {
  default     = "us-east-3"
  description = "The VPC Zone that you want your VPC networks and virtual servers to be provisioned in. To list available zones, run `ibmcloud is zones`."
}

variable "vpc_name" {
  default     = "cpvpc"
  description = "The name of your VPC where Checkpoint GW will be provisioned."
}

variable "frontend_subnet_id" {
  default     = "0777-06f95dd6-47e1-4a68-a2e5-24bb8aaee362"
  description = "The id of the subnet infront of the Check Point gateway."
}

variable "backend_subnet_id" {
  default     = "0777-9d1c7162-c5c8-4ea9-a502-62f2d52bab2a"
  description = "The id of the subnet behind the Check Point gateway."
}

variable "ssh_key_name" {
  default     = "development"
  description = "The name of the public SSH key to be used when provisining Checkpoint GW and Mgmt VSIs."
}

variable "vnf_vpc_gw_image_name" {
  default     = "checkpoint-gw-image"
  description = "The name of the Checkpoint GW custom image to be provisioned in your IBM Cloud account."
}

variable "vnf_security_group" {
  default     = "checkpointsg"
  description = "The security group for VNF VPC"
}

variable "vnf_gw_instance_name" {
  default     = "checkpoint-gateway"
  description = "The name of your Checkpoint GW Virtual Server to be provisioned."
}

variable "vnf_profile" {
  default     = "bx2-2x8"
  description = "The profile of compute cpu and memory resources to be used when provisioning VSI. bx2-2x8, bx2-4x16, bx2-8x32, bx2-16x64, bx2-32x128, bx2-48x192"
}

variable "vnf_license" {
  default     = ""
  description = "Optional. The BYOL license key that you want your cp virtual server in a VPC to be used by registration flow during cloud-init."
}

variable "ibmcloud_endpoint" {
  default     = "cloud.ibm.com"
  description = "The IBM Cloud environmental variable 'cloud.ibm.com' or 'test.cloud.ibm.com'"
}

variable "delete_custom_image_confirmation" {
  default     = ""
  description = "This variable is to get the confirmation from customers that they will delete the custom image manually, post successful installation of VNF instances. Customer should enter 'Yes' to proceed further with the installation."
}

variable "ibmcloud_api_key" {
  default     = ""
  description = "holds the user api key"
}

##############################################################################
# Data block 
##############################################################################

data "ibm_is_subnet" "cp_subnet1" {
  identifier = "${var.frontend_subnet_id}"
}

data "ibm_is_subnet" "cp_subnet2" {
  identifier = "${var.backend_subnet_id}"
}

data "ibm_is_image" "cp_gw_custom_image" {
  name = "${ibm_is_image.cp_gw_custom_image.name}"
}

data "ibm_is_ssh_key" "cp_ssh_pub_key" {
  name = "${var.ssh_key_name}"
}

data "ibm_is_instance_profile" "vnf_profile" {
  name = "${var.vnf_profile}"
}

data "ibm_is_region" "region" {
  name = "${var.region}"
}

data "ibm_is_vpc" "cp_vpc" {
  name = "${var.vpc_name}"
}

data "ibm_is_zone" "zone" {
  name   = "${var.zone}"
  region = "${data.ibm_is_region.region.name}"
}

data "ibm_resource_group" "rg" {
  name = "${var.resource_group}"
}

##############################################################################
# Create Custom Image
##############################################################################

locals {
  image_url_gw    = "${var.ibmcloud_endpoint == "cloud.ibm.com" ? var.vnf_cos_gw_image_url : var.vnf_cos_gw_image_url_test}"
}

resource "ibm_is_image" "cp_gw_custom_image" {
  href             = "${local.image_url_gw}"
  name             = "${var.vnf_vpc_gw_image_name}"
  operating_system = "centos-7-amd64"
  resource_group   = "${data.ibm_resource_group.rg.id}"

  timeouts {
    create = "30m"
    delete = "10m"
  }
}

##############################################################################
# Create Security Group
##############################################################################

resource "ibm_is_security_group" "ckp_security_group" {
    name = "${var.vnf_security_group}"
    vpc = "${data.ibm_is_vpc.cp_vpc.id}"
    resource_group = "${data.ibm_resource_group.rg.id}"
}

#Egress All Ports
resource "ibm_is_security_group_rule" "allow_egress_all" {
  depends_on = ["ibm_is_security_group.ckp_security_group"]
  group      = "${ibm_is_security_group.ckp_security_group.id}"
  direction  = "outbound"
  remote     = "0.0.0.0/0"
}

#Ingress All Ports
resource "ibm_is_security_group_rule" "allow_ingress_all" {
  depends_on = ["ibm_is_security_group.ckp_security_group"]
  group      = "${ibm_is_security_group.ckp_security_group.id}"
  direction  = "inbound"
  remote     = "0.0.0.0/0"
}


##############################################################################
# Create Check Point Gateway
##############################################################################

resource "ibm_is_instance" "cp_gw_vsi" {
  depends_on = ["ibm_is_security_group_rule.allow_ingress_all", "data.ibm_is_image.cp_gw_custom_image"]
  name    = "${var.vnf_gw_instance_name}"
  image   = "${data.ibm_is_image.cp_gw_custom_image.id}"
  profile = "${data.ibm_is_instance_profile.vnf_profile.name}"
  resource_group = "${data.ibm_resource_group.rg.id}"

  primary_network_interface {
    name   = "eth0"
    subnet = "${data.ibm_is_subnet.cp_subnet1.id}"
    security_groups = ["${ibm_is_security_group.ckp_security_group.id}"]
  }

  network_interfaces {
    name   = "eth1"
    subnet = "${data.ibm_is_subnet.cp_subnet2.id}"
    security_groups = ["${ibm_is_security_group.ckp_security_group.id}"]
  }

  vpc  = "${data.ibm_is_vpc.cp_vpc.id}"
  zone = "${data.ibm_is_zone.zone.name}"
  keys = ["${data.ibm_is_ssh_key.cp_ssh_pub_key.id}"]

  # user_data = "$(replace(file("cp-userdata.sh"), "cp-LICENSE-REPLACEMENT", var.vnf_license)"

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
  depends_on = ["ibm_is_instance.cp_gw_vsi"]
  program    = ["bash", "${path.module}/scripts/delete_custom_image.sh"]

  query = {
    custom_image_id   = "${data.ibm_is_image.cp_gw_custom_image.id}"
    region            = "${var.region}"
  }
}

output "delete_custom_image1" {
  value = "${lookup(data.external.delete_custom_image1.result, "custom_image_id")}"
}
