

# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }
  }
}


#---------------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------------------------------------------------------------------------------------------------#
#                                                   AWS Terraform IaC Start. 
#---------------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------------------------------------------------------------------------------------------------#

provider "aws" {
  region  = "eu-central-1"
}

module "vpc" {
  source = "./aws-modules/vpc"

  cidr        = var.vpc_cidr
  environment = var.environment
}

module "private_subnet" {
  source = "./aws-modules/subnet"

  name               = "${var.environment}_private_subnet"
  environment        = var.environment
  vpc_id             = module.vpc.id
  cidrs              = var.private_subnet_cidrs
  availability_zones = var.availability_zones
}

module "public_subnet" {
  source = "./aws-modules/subnet"

  name               = "${var.environment}_public_subnet"
  environment        = var.environment
  vpc_id             = module.vpc.id
  cidrs              = var.public_subnet_cidrs_eu-central-1a
  availability_zones = var.availability_zones
}


module "nat" {
  source = "./aws-modules/nat_gateway"

  subnet_ids   = module.public_subnet.ids
  subnet_count = length(var.public_subnet_cidrs)
}

resource "aws_route" "public_igw_route" {
  count                  = length(var.public_subnet_cidrs)
  route_table_id         = element(module.public_subnet.route_table_ids, count.index)
  gateway_id             = module.vpc.igw
  destination_cidr_block = var.destination_cidr_block
}

resource "aws_route" "private_nat_route" {
  count                  = length(var.private_subnet_cidrs)
  route_table_id         = element(module.private_subnet.route_table_ids, count.index)
  nat_gateway_id         = element(module.nat.ids, count.index)
  destination_cidr_block = var.destination_cidr_block
}

/* resource "aws_route" "private_peering_route" {
  count                     = length(var.private_subnet_cidrs)
  route_table_id            = element(module.private_subnet.route_table_ids, count.index)
  destination_cidr_block    = var.destination_cidr_block_rds
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_to_rds.id
} */

# Creating a NAT Gateway takes some time. Some services need the internet (NAT Gateway) before proceeding. 
# Therefore we need a way to depend on the NAT Gateway in Terraform and wait until is finished. 
# Currently Terraform does not allow module dependency to wait on.
# Therefore we use a workaround described here: https://github.com/hashicorp/terraform/issues/1178#issuecomment-207369534

resource "null_resource" "dummy_dependency" {
  depends_on = [module.nat]
}


resource "aws_security_group" "web_sg" {
  name   = "HTTP and SSH"
  vpc_id = module.vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [module.vpc.cidr_block]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [module.vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = [module.vpc.cidr_block]
  }
}


resource "aws_instance" "web_instance" {
  ami           = "ami-0dcc0ebde7b2e00db"
  instance_type = "t2.micro"
  key_name      = "MyKeyPair"

  subnet_id                   = module.public_subnet.ids.0
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true

  tags = {
    "Name" : "Terraform POC - Web Instance"
  }
}


# Create a new load balancer
resource "aws_elb" "bar" {
  name               = "Website-terraform-elb"
  availability_zones = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]

  access_logs {
    bucket        = "foo"
    bucket_prefix = "bar"
    interval      = 60
  }

  listener {
    instance_port     = 8000
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:8000/"
    interval            = 30
  }

  instances                   = [aws_instance.web_instance.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
  subnets                     = module.public_subnet.ids

  tags = {
    Name = "Website-terraform-elb"
  }
  depends_on                =  [aws_instance.web_instance]
}


resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = module.private_subnet.ids

  tags = {
    Name = "My DB subnet group"
  }
}

resource "aws_db_instance" "mysqldb" {
  allocated_storage    = 10
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  name                 = "mydb"
  username             = "foo"
  password             = "foobarbaz"
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
  db_subnet_group_name = aws_db_subnet_group.default.id
}

#---------------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------------------------------------------------------------------------------------------------#
#                                                   AWS Terraform code End. 
#---------------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------------------------------------------------------------------------------------------------#



#---------------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------------------------------------------------------------------------------------------------#
#                                                 Azure Terraform IaC Start. 
#---------------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------------------------------------------------------------------------------------------------#

provider "azurerm" {
  skip_provider_registration = true 
  features {}
}


/* 
#------------------------------------------------------------#
#  Terrafrom code for load balancer.
#------------------------------------------------------------#

resource "azurerm_virtual_network" "agw" {
  name                = "${var.prefix}-agw"
  address_space       = ["10.0.0.0/24"]
  location            = var.azurerm_location
  resource_group_name = var.azurerm_resource_group
}

resource "azurerm_subnet" "agw" {
  name                 = "agw"
  resource_group_name  = var.azurerm_resource_group
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_public_ip" "example" {
  name                = "example-pip"
  resource_group_name = var.azurerm_resource_group
  location            = var.azurerm_location
  allocation_method   = "Dynamic"
}

#&nbsp;since these variables are re-used - a locals block makes this more maintainable
locals {
  backend_address_pool_name      = "${azurerm_virtual_network.agw.name}-beap"
  frontend_port_name             = "${azurerm_virtual_network.agw.name}-feport"
  frontend_ip_configuration_name = "${azurerm_virtual_network.agw.name}-feip"
  http_setting_name              = "${azurerm_virtual_network.agw.name}-be-htst"
  listener_name                  = "${azurerm_virtual_network.agw.name}-httplstn"
  request_routing_rule_name      = "${azurerm_virtual_network.agw.name}-rqrt"
  redirect_configuration_name    = "${azurerm_virtual_network.agw.name}-rdrcfg"
}

resource "azurerm_application_gateway" "network" {
  name                = "example-appgateway"
  resource_group_name = var.azurerm_resource_group
  location            = var.azurerm_location

  sku {
    name     = "Standard_Small"
    tier     = "Standard"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = azurerm_subnet.agw.id
  }

  probe {
    name                = "probe"
    protocol            = "http"
    path                = "/"
    host                = "${azurerm_app_service.example.name}.azurewebsites.net"
    interval            = "30"
    timeout             = "30"
    unhealthy_threshold = "3"
  }

  frontend_port {
    name = "http"
    port = 80
  }

   frontend_ip_configuration {
    name                 = "frontend"
    public_ip_address_id = "${azurerm_public_ip.example.id}"
  }

 backend_address_pool {

      name  = "appservice-primary"
      fqdns = ["${azurerm_app_service.example.name}.azurewebsites.net"]
  
  }
 

  backend_http_settings {
    name                  = "http"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 1
    probe_name            = "probe"
    pick_host_name_from_backend_address = true
  }

  http_listener {
    name                           = "http"
    frontend_ip_configuration_name = "frontend"
    frontend_port_name             = "http"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "http"
    rule_type                  = "Basic"
    http_listener_name         = "http"
    backend_address_pool_name  = "appservice-primary"
    backend_http_settings_name = "http"
  }

depends_on                = [azurerm_subnet.agw,azurerm_public_ip.example,azurerm_app_service.example]

}
 */

#------------------------------------------------------------------------------------------------------------------------------#
#                                        Terrafrom code for Primary region (West Europe).                                      #
#------------------------------------------------------------------------------------------------------------------------------#


resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = var.azurerm_location
  resource_group_name = var.azurerm_resource_group
}

#------------------------------------------------------------#
#  Terrafrom code for public Subnet and App service.
#------------------------------------------------------------#

resource "azurerm_subnet" "public" {
  name                 = "public"
  resource_group_name  = var.azurerm_resource_group
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
  service_endpoints    = ["Microsoft.Sql"]
  delegation {
    name = "delegation"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action", "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action"]
    }
  }
}


resource "azurerm_network_security_group" "NSG-public" {
  name                = "NSG-public"
  location            = var.azurerm_location
  resource_group_name = var.azurerm_resource_group

  # NSG inbound Rules 

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "80"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Health-Monitoring"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureLoadBalancer"
  }

  security_rule {
    name                       = "Disallow-everything-else"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # NSG Outbound rules 

  security_rule {
    name                       = "Allow-to-VNet"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Deny-All-Traffic"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}

resource "azurerm_subnet_network_security_group_association" "public" {
  subnet_id                 = azurerm_subnet.public.id
  network_security_group_id = azurerm_network_security_group.NSG-public.id
  depends_on                = [azurerm_subnet.public, azurerm_network_security_group.NSG-public]
}

# resource "azurerm_network_interface" "public" {
#   name                = "${var.prefix}-nic"
#   location            = var.azurerm_location
#   resource_group_name = var.azurerm_resource_group

#   ip_configuration {
#     name                          = "public-configuration"
#     subnet_id                     = azurerm_subnet.public.id
#     private_ip_address_allocation = "Dynamic"
#   }
#   depends_on = [azurerm_subnet.public, azurerm_subnet_network_security_group_association.public, azurerm_network_security_group.NSG-public]
# }

resource "azurerm_app_service_plan" "example" {
  name                = "aspdemopocwebappNC"
  location            = var.azurerm_location
  resource_group_name = var.azurerm_resource_group

  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_app_service" "example" {
  name                = "asdemowebappNC"
  location            = var.azurerm_location
  resource_group_name = var.azurerm_resource_group
  app_service_plan_id = azurerm_app_service_plan.example.id

  depends_on = [
    azurerm_sql_server.example,
    azurerm_sql_database.example,
    azurerm_subnet.public,
    azurerm_app_service_plan.example
  ]

  site_config {
    dotnet_framework_version = "v4.0"
    scm_type                 = "LocalGit"
  }

  connection_string {
    name  = azurerm_sql_server.example.name
    type  = "SQLServer"
    value = "Server=tcp:${azurerm_sql_server.example.name};Database=${azurerm_sql_database.example.name};User ID=4dm1n157r470r;Password=4-v3ry-53cr37-p455w0rd;Trusted_Connection=False;Encrypt=True;"
  }
}

resource "azurerm_app_service_virtual_network_swift_connection" "example" {
  app_service_id = azurerm_app_service.example.id
  subnet_id      = azurerm_subnet.public.id
  depends_on = [
    azurerm_app_service.example,
    azurerm_app_service_plan.example,
    azurerm_subnet.public,
  ]
}

# Virtual Machine Procurement
# resource "azurerm_virtual_machine" "main" {
#   name                  = "${var.prefix}-vm"
#   location              = var.azurerm_location
#   resource_group_name   = var.azurerm_resource_group
#   network_interface_ids = [azurerm_network_interface.public.id]
#   vm_size               = "Standard_DS1_v2"

#   # Uncomment this line to delete the OS disk automatically when deleting the VM
#   # delete_os_disk_on_termination = true

#   # Uncomment this line to delete the data disks automatically when deleting the VM
#   # delete_data_disks_on_termination = true

#   storage_image_reference {
#     publisher = "Canonical"
#     offer     = "UbuntuServer"
#     sku       = "16.04-LTS"
#     version   = "latest"
#   }
#   storage_os_disk {
#     name              = "myosdisk1"
#     caching           = "ReadWrite"
#     create_option     = "FromImage"
#     managed_disk_type = "Standard_LRS"
#   }
#   os_profile {
#     computer_name  = "hostname"
#     admin_username = "testadmin"
#     admin_password = "Password1234!"
#   }
#   os_profile_linux_config {
#     disable_password_authentication = false
#   }
#   tags = {
#     environment = "production"
#   }
# }

#------------------------------------------------------------#
#  Terrafrom code for Private Subnet and SQL Data Base server.
#------------------------------------------------------------#

resource "azurerm_subnet" "private" {
  name                 = "private"
  resource_group_name  = var.azurerm_resource_group
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints    = ["Microsoft.Sql"]
}


resource "azurerm_network_security_group" "NSG-private" {
  name                = "NSG-private"
  location            = var.azurerm_location
  resource_group_name = var.azurerm_resource_group

  # NSG inbound Rules 

  security_rule {
    name                       = "Allow-Front"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "80"
    destination_port_range     = "*"
    source_address_prefix      = azurerm_subnet.public.address_prefixes.0
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Health-Monitoring"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureLoadBalancer"
  }

  security_rule {
    name                       = "Disallow-everything-else"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # NSG Outbound rules 

  security_rule {
    name                       = "Deny-All-Traffic"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}


resource "azurerm_subnet_network_security_group_association" "private" {
  subnet_id                 = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.NSG-private.id
  depends_on                = [azurerm_subnet.private, azurerm_network_security_group.NSG-private]
}

resource "azurerm_network_interface" "private" {
  name                = "${var.prefix}-nic-db"
  location            = var.azurerm_location
  resource_group_name = var.azurerm_resource_group

  ip_configuration {
    name                          = "Private-configuration"
    subnet_id                     = azurerm_subnet.private.id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [azurerm_subnet.private, azurerm_subnet_network_security_group_association.private, azurerm_network_security_group.NSG-private]
}



resource "azurerm_storage_account" "example" {
  name                     = "sademopoc"
  resource_group_name      = var.azurerm_resource_group
  location                 = var.azurerm_location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_sql_server" "example" {
  name                         = "ssdemopoc"
  resource_group_name          = var.azurerm_resource_group
  location                     = var.azurerm_location
  version                      = "12.0"
  administrator_login          = var.azurerm_sqlserver_administrator_user  #"4dm1n157r470r"
  administrator_login_password = var.azurerm_sqlserver_administrator_password #"4-v3ry-53cr37-p455w0rd"

  tags = {
    environment = "production"
  }
  depends_on = [azurerm_storage_account.example]
}


resource "azurerm_sql_virtual_network_rule" "sqlvnetrule" {
  name                = "sql-vnet-rule"
  resource_group_name = var.azurerm_resource_group
  server_name         = azurerm_sql_server.example.name
  subnet_id           = azurerm_subnet.public.id
  depends_on          = [azurerm_sql_server.example]
}

resource "azurerm_sql_database" "example" {
  name                = "dbdemopoc"
  resource_group_name = var.azurerm_resource_group
  location            = var.azurerm_location
  server_name         = azurerm_sql_server.example.name

  extended_auditing_policy {
    storage_endpoint                        = azurerm_storage_account.example.primary_blob_endpoint
    storage_account_access_key              = azurerm_storage_account.example.primary_access_key
    storage_account_access_key_is_secondary = true
    retention_in_days                       = 6
  }

  tags = {
    environment = "production"
  }
}



#------------------------------------------------------------------------------------------------------------------------------#
#                                  Terrafrom code for secondary region (sweden central).                                       #
#------------------------------------------------------------------------------------------------------------------------------#




#---------------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------------------------------------------------------------------------------------------------#
#                                                  Azure  Terraform code end. 
#---------------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------------------------------------------------------------------------------------------------#


