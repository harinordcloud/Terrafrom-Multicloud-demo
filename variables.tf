
#---------------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------------------------------------------------------------------------------------------------#
#                                                   AWS Terrafrom variables. 
#---------------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------------------------------------------------------------------------------------------------#

variable "vpc_cidr" {
  default   = "10.0.0.0/16"
  description = "VPC cidr block. Example: 10.0.0.0/16"
}

variable "environment" {
  default   = "Test-POC"
  description = "The name of the environment"
}

variable "destination_cidr_block" {
  default     = "0.0.0.0/0"
  description = "Specify all traffic to be routed either trough Internet Gateway or NAT to access the internet"
}

variable "destination_cidr_block_rds" {
  default     = "172.16.0.0/24"
  description = "Specify all traffic to be routed either trough Internet Gateway or NAT to access the internet"
}

variable "private_subnet_cidrs" {
  type        = list(any)
  default   = ["10.0.1.0/24"]
  description = "List of private cidrs, for every availability zone you want you need one. Example: 10.0.0.0/24 and 10.0.1.0/24"
}

variable "public_subnet_cidrs_eu-central-1a" {
  type        = list(any)
  default   = ["10.0.2.0/24", "10.0.3.0/24"]
  description = "List of public cidrs, for every availability zone you want you need one. Example: 10.0.0.0/24 and 10.0.1.0/24"
}

variable "public_subnet_cidrs_eu-central-1b" {
  type        = list(any)
  default   = ["10.0.3.0/24"]
  description = "List of public cidrs, for every availability zone you want you need one. Example: 10.0.0.0/24 and 10.0.1.0/24"
}

variable "availability_zones" {
  type        = list(any)
  default   = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  description = "List of availability zones you want. Example: eu-central-1a and eu-central-1b"
}

#variable "depends_id" {}


#---------------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------------------------------------------------------------------------------------------------#
#                                                   Azure Terrafrom varaiables. 
#---------------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------------------------------------------------------------------------------------------------#

variable "prefix" {
  default = "tfvmex"
}

variable "azurerm_resource_group" {
  default = "rg-hariharan-natarajan-weu"
}

variable "azurerm_location" {
  default = "West Europe"
}

variable "azurerm_location_secondary" {
  default = "Sweden Central"
}

variable "azurerm_sqlserver_administrator_user" {
description = "Azure SQL server Administrator User name"
}

variable "azurerm_sqlserver_administrator_password" {
description = "Azure SQL server Administrator User Password"
}


