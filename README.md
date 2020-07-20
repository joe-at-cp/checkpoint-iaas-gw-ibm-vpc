<p align="center">
  <img width="460" src="http://blog.checkpoint.com/wp-content/uploads/2018/02/CloudGuard_IaaS.jpg">
</p>

# Check Point CloudGuard Security Gateway

## Deployment Parameters
| Deploymenmt Parameter | Description |
|-----------------------|-------------|
| region    | Geographical IBM Cloud VPC location to deploy CloudGuard. CloudGuard is supported for deployment in all VPC Gen2 regions. See below for a list of regions and zones|
| zone      | Availability zone inside selected region|
| vpc_name  | Name of VPC to deploy into|
| resource_group | Name of VPC resource group to deploy into |
| frontend_subnet_id | ID (not the name) of the untrusted subnet of eth0)
| backend_subnet_id  | ID (not the name) of the trusted subnet of eth1)
| ssh_key_name       | Name of the ssh key to apply to the CloudGuard instance |
| vnf_security_group | Name of the security group to apply to the CloudGuard instance |




## IBM Cloud Regions and Zones
| Region | Zones |
|--------|-------|
| us-south | us-south-1, us-south-2, us-south-1 |
| us-east  | us-east-1, us-east-2, us-east-1 |
| eu-gb    | eu-gb-1, eu-gb-2, eu-gb-3 |
| eu-de    | eu-de-1, eu-de-2, eu-de-3 |
| jp-tok   | jp-tok-1, jp-tok-2, jp-tok-3 |
 



## Check Point Knowledgebase
Click [HERE](https://checkpoint.com/) to view the knowledgebase article for IBM Cloud VPC deployments on the Check Point Usercenter.


## About Check Point Software Technologies Ltd.
Check Point Software Technologies Ltd. (www.checkpoint.com) is a leading provider of cyber security solutions to governments and corporate <br> 
enterprises globally. Its solutions protect customers from cyber-attacks with an industry leading catch rate of malware, ransomware and other <br>
types of attacks. Check Point offers a multilevel security architecture that defends enterprises’ cloud, network and mobile device held information, <br>
plus the most comprehensive and intuitive one point of control security management system. Check Point protects over 100,000 organizations of all sizes. <br>
