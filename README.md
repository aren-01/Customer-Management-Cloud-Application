# Customer Management Application on AWS

## Original Idea
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

![](./images/image2.jpeg)

## For quick installation, just fork the repo and deploy it through GitHub Actions. However, if you prefer to use CloudFormation, follow the instructions below.

In this project, I focused on the system shown above. This is a
simplified version of the first architecture, and it includes an
Internet Gateway (IGW). In practice, it is not safe to deploy a JS
admin panel without a login page; however, this simplified deployment is
only for training purposes using the AWS Free Tier. There is one
temporary EC2 instance, used only to import the SQL file into RDS.
Step-by-step guidance is below.

1.  Pull or download the "app" folder.

2.  Install Docker and deploy the image.

3.  Create an ECR repository. CloudFormation will prompt you for the
    repository URL.

> ![](./images/image3.png)

4.  Install and configure the AWS CLI on the local machine.

5.  Authenticate Docker with Amazon ECR.
```bash
aws ecr get-login-password --region us-east-1 |
docker login --username AWS --password-stdin
<ACCOUNT_ID\>.dkr.ecr.us-east-1.amazonaws.com
```
6.  Tag the Docker Image for ECR.
```bash
docker tag healthcare-app:latest
<ACCOUNT_ID\>.dkr.ecr.us-east-1.amazonaws.com/healthcare-app:latest
```
7.  Push the Image to Amazon ECR.
```bash
docker push
<ACCOUNT_ID\>.dkr.ecr.us-east-1.amazonaws.com/healthcare-app:latest
```
8.  Create a CloudFormation stack and upload the
    "[cloudformation.yml](https://github.com/aren-01/Customer-Management-Cloud-Application/blob/main/cloudformation.yml)"
    file as the template.

9.  Fill the parameters as shown in the screenshot below.

> ![](./images/image4.png)

10. Start deploying the stack and wait until it finishes. If there is no
    EC2 key pair, create one.

11. This will set up the application. Now pull the
    "[db_health.sql](https://github.com/aren-01/Customer-Management-Cloud-Application/blob/main/db/init.sql)"
    file to import it into the RDS database.

12. In the CloudFormation file, security groups are configured to allow
    the temporary EC2 instance to connect to the RDS instance in the
    private subnet.

13. Connect to the EC2 instance from the local terminal, following the
    instructions in the "Connect" tab.

14. Install MariaDB on the EC2 instance.
```bash
sudo dnf install mariadb105 -y
```
15. Connect to the RDS database
```bash
mysql -h <RDS-ENDPOINT\> -u admin -p
```
16. Create a new database named "healthcaredb"

17. Exit MySQL and the EC2 instance, then upload the "db_health.sql"
    file to the EC2 instance.
```bash
scp -i your-key.pem init.sql
ec2-user@<EC2-PUBLIC-IP\>:/home/ec2-user/
```
18. Import the SQL file into the RDS database.
```bash
mysql -h <RDS-ENDPOINT\> -u admin -p healthcaredb < init.sql
```
19. The application should now be available through the Application Load
    Balancer's HTTP listener. You can access the admin panel to modify
    or add data. To delete the system, simply delete the CloudFormation
    stack.

![](./images/image5.png)
