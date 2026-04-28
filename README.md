# Customer Management Application on AWS

## Core Idea
![](./images/image1.jpeg) Based on a
healthcare system scenario, this AWS architecture shows how to connect
and use the application in the cloud.

The healthcare company stores customer information in an Aurora Global
Database. A sample database named
\"[db_health.sql](https://github.com/aren-01/Customer-Management-Cloud-Application/blob/main/db/db_health.sql)"
is in the database folder. A JS admin panel application, deployed and
containerized with Docker on the local machine, retrieves data from the
database and edits it. As per the requirements of this scenario, for
availability and low latency, there are two regions, and these regions
are connected to the on-premises servers by a Site-to-Site VPN. In this
way, the company can track its customer information in the AWS Cloud.
Thanks to Aurora Global Database, the data is replicated across regions.
Credentials are stored in AWS Secrets Manager. In case of failure in one
region, the on-premises server can connect to another region via AWS
Transit Gateway.


## Actual Deployment

![](./images/image2.jpg)


In this project, I focused on the system shown above. This is a
simplified version of the first architecture, and it includes an
Internet Gateway (IGW). In practice, it is not safe to deploy a JS
admin panel without a login page; however, this simplified deployment is
only for training purposes using the AWS Free Tier. There is one
temporary EC2 instance, used only to import the SQL file into RDS.

I also deployed a GitHub [destroy.yml](.github/workflows/destroy.yml) file to destroy the system. The deploy workflow creates an S3 bucket to store the Terraform state.

[deploy.yml](.github/workflows/deploy.yml):

1. Creates a S3 Bucket to store Terraform state 
2. Creates an ECR repo
3. Containerizes the application through Docker
4. Pushes the container
5. Installs the infrastructure above through Terraform
6. Installs the DB into the RDS instance with a temporary EC2 instance

Please see the [cloudformation.yml](optional/cloudformation.yml) file if you prefer manual deployment of the VPC infrastructure.



