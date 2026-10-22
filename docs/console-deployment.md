# Method B: deploy WordPress through AWS Console clicks

This guide builds the three-tier lab manually through AWS Console pages. You do not run Terraform, use a local terminal, or create access keys. The installation script is pasted into an EC2 form and runs automatically on the instance.

Use the console-enabled `terraform-lab-user` from [README step 1](../README.md#1-create-the-iam-deployment-user), with its four deployment policies. Sign in using the IAM user's console URL, complete the initial password change, and enable MFA. Select **US West (N. California) / `us-west-1`** in the top-right region selector and keep it selected throughout this guide.

Use a fresh environment for this method. The resource names below overlap with the Terraform lab. Resources created here must be managed and deleted manually; `terraform destroy` will not clean them up.

This lab creates billable resources, including RDS, EC2, ALB, NAT, public IPv4 addresses, and VPC endpoints. It uses HTTP, one application instance, and a single-AZ database. Check [AWS pricing](https://aws.amazon.com/pricing/) before starting. Console labels can vary as AWS updates its interface; match the settings described below.

```text
Browser → public ALB → private WordPress EC2 → private RDS MySQL
                              ↓
                         NAT → internet downloads
                              ↓
                  VPC endpoints → AWS services
```

## 1. Create the VPC

1. Search for **VPC** in the AWS Console search bar and open it.
2. Click **Your VPCs → Create VPC**.
3. Select **VPC only** and enter:

   | Field | Value |
   | --- | --- |
   | Name tag | `wordpress-lab-vpc` |
   | IPv4 CIDR | `10.0.0.0/16` |
   | IPv6 CIDR | No IPv6 CIDR block |
   | Tenancy | Default |

4. Click **Create VPC** and record its VPC ID.
5. Select the VPC, then click **Actions → Edit VPC settings**. Enable both **DNS resolution** and **DNS hostnames**, then save.

[AWS VPC creation reference](https://docs.aws.amazon.com/vpc/latest/userguide/create-vpc.html)

## 2. Create five subnets

Open **VPC → Subnets → Create subnet** and select `wordpress-lab-vpc`. Choose two different standard Availability Zones available in your account. Call the first **Zone A** and the second **Zone B** below; these are labels for this tutorial, not literal AWS zone names.

Add these subnets using **Add new subnet**, or repeat the creation form:

| Subnet name | Availability Zone | IPv4 CIDR |
| --- | --- | --- |
| `wordpress-public-1` | Zone A | `10.0.1.0/24` |
| `wordpress-public-2` | Zone B | `10.0.0.0/24` |
| `wordpress-private-app-1` | Zone A | `10.0.2.0/24` |
| `wordpress-private-db-1` | Zone A | `10.0.3.0/24` |
| `wordpress-private-db-2` | Zone B | `10.0.4.0/24` |

Click **Create subnet**. Keep automatic public IPv4 assignment disabled. The ALB and NAT gateway obtain their own public addresses; the application and database stay private. Leave the default network ACL unchanged.

[AWS subnet creation reference](https://docs.aws.amazon.com/vpc/latest/userguide/create-subnets.html)

## 3. Connect the public subnets to the internet

1. Open **VPC → Internet gateways → Create internet gateway**.
2. Enter `wordpress-igw`, then click **Create internet gateway**.
3. Select it and click **Actions → Attach to VPC**. Select `wordpress-lab-vpc` and attach it.
4. Open **Route tables → Create route table**. Name it `wordpress-public-rt`, select the VPC, and create it.
5. Select the new route table → **Routes → Edit routes → Add route**:
   - Destination: `0.0.0.0/0`.
   - Target type: **Internet Gateway**; choose `wordpress-igw`.
6. Save changes. Under **Subnet associations → Edit subnet associations**, select only `wordpress-public-1` and `wordpress-public-2`, then save.

Keep the automatically created `10.0.0.0/16 → local` route. Each subnet in this guide must have the intended route table association.

[AWS routing reference](https://docs.aws.amazon.com/vpc/latest/userguide/WorkWithRouteTables.html)

## 4. Add outbound internet access for the private application

1. Open **VPC → NAT gateways → Create NAT gateway**.
2. Name it `wordpress-nat`. If an availability mode is offered, choose **Zonal** for this lab.
3. Select subnet `wordpress-public-1` and connectivity type **Public**.
4. Click **Allocate Elastic IP**, then **Create NAT gateway**. Record the Elastic IP allocation ID and wait for the NAT status to become **Available**.
5. Open **Route tables → Create route table**. Name it `wordpress-private-app-rt` and choose your VPC.
6. Under **Routes → Edit routes**, add `0.0.0.0/0` with target type **NAT Gateway**, selecting `wordpress-nat`. Save.
7. Under **Subnet associations → Edit subnet associations**, select only `wordpress-private-app-1` and save.

The two database subnets should remain associated with the VPC's original main route table, containing only the local route. Check this under **Subnets → select a database subnet → Route table**. Do not associate them with either internet route table.

[AWS NAT creation reference](https://docs.aws.amazon.com/vpc/latest/userguide/nat-gateway-working-with.html), [subnet routing behavior](https://docs.aws.amazon.com/vpc/latest/userguide/subnet-route-tables.html)

## 5. Create the security groups

Open **VPC → Security groups → Create security group**. Create the following four groups in `wordpress-lab-vpc`, with a short description for each:

- `wordpress-alb-sg`
- `wordpress-ec2-sg`
- `wordpress-rds-sg`
- `wordpress-endpoint-sg`

Create all four before adding references between them. For each group, select it → **Inbound rules → Edit inbound rules → Add rule** and use this table:

| Security group | Type / port | Source |
| --- | --- | --- |
| `wordpress-alb-sg` | HTTP / TCP 80 | Anywhere-IPv4: `0.0.0.0/0` |
| `wordpress-ec2-sg` | HTTP / TCP 80 | Custom: select `wordpress-alb-sg` |
| `wordpress-rds-sg` | MySQL/Aurora / TCP 3306 | Custom: select `wordpress-ec2-sg` |
| `wordpress-endpoint-sg` | HTTPS / TCP 443 | Custom: select `wordpress-ec2-sg` |

For a security group source, select its `sg-...` ID from the dropdown. Do not enter the VPC CIDR instead. Save each group's changes. Add no SSH rule.

Next, open **Outbound rules → Edit outbound rules** for each group. Remove the default all-traffic rule and enter these rules:

| Security group | Type / port | Destination |
| --- | --- | --- |
| `wordpress-alb-sg` | HTTP / TCP 80 | `wordpress-ec2-sg` |
| `wordpress-ec2-sg` | HTTP / TCP 80 | `0.0.0.0/0` |
| `wordpress-ec2-sg` | HTTPS / TCP 443 | `0.0.0.0/0` |
| `wordpress-ec2-sg` | MySQL/Aurora / TCP 3306 | `wordpress-rds-sg` |
| `wordpress-rds-sg` | No outbound rules | — |
| `wordpress-endpoint-sg` | No outbound rules | — |

Save changes. Response traffic is allowed automatically by stateful security groups; the database and endpoints do not need outbound rules for replies.

[AWS security group reference](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html)

## 6. Create the database subnet group

1. Search for **RDS** and open **Subnet groups → Create DB subnet group**.
2. Name it `wordpress-db-subnet-group`, add a description, and select `wordpress-lab-vpc`.
3. Select Zone A and Zone B. Under subnets, select only `wordpress-private-db-1` and `wordpress-private-db-2`; verify their CIDRs are `10.0.3.0/24` and `10.0.4.0/24`.
4. Click **Create**.

Even a single-AZ RDS database needs a subnet group spanning two Availability Zones for this setup. [AWS RDS networking reference](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_VPC.WorkingWithRDSInstanceinaVPC.html)

## 7. Create MySQL RDS and record its connection details

Open **RDS → Databases → Create database**. Choose **Standard create**, then configure:

| Setting | Value |
| --- | --- |
| Engine | MySQL, a currently supported version compatible with `db.t3.micro` |
| Template | Dev/Test; review its defaults |
| Availability | Single DB instance / Single-AZ |
| DB instance identifier | `wordpress-mysql-db` |
| Master username | `admin` |
| Credentials management | Managed in AWS Secrets Manager |
| Secret encryption key | Default `aws/secretsmanager` key |
| Instance class | Burstable classes → `db.t3.micro` |
| Storage | General Purpose SSD (`gp3`), 20 GiB |
| Storage autoscaling | Disabled for this lab |

Under **Connectivity**, choose your VPC and DB subnet group, **Public access: No**, and existing security group `wordpress-rds-sg` only. Choose **Don't connect to an EC2 compute resource** if offered; you configure that connection yourself.

Expand **Additional configuration** and set **Initial database name** to `wordpress`. Disable automated backups and deletion protection for this disposable lab. Keep monitoring at Standard and enhanced monitoring disabled. Review the cost estimate, then click **Create database**.

Wait for **Available**. Open the database:

- **Connectivity & security:** copy the endpoint hostname and port `3306`.
- **Configuration:** follow the master credentials link into Secrets Manager, then copy the **Secret ARN** from its details page. Record the ARN, not the password.

[AWS RDS creation reference](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_CreateDBInstance.html), [managed credential settings](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-secrets-manager.html)

## 8. Create the EC2 service role using managed policies

1. Open **IAM → Roles → Create role**.
2. Choose **AWS service**, service/use case **EC2**, then **Next**.
3. Select these existing AWS managed policies:
   - `AmazonSSMManagedInstanceCore`
   - `AWSSecretsManagerClientReadOnlyAccess`
4. Click **Next**, name the role `wordpress-ec2-ssm-role`, and click **Create role**.

The IAM Console automatically creates the matching EC2 instance profile. You will select this role when launching EC2. These are the instance's permissions, separate from the four policies attached to your deployment user.

For easier console setup, the Secrets Manager policy allows reading secrets across the account, subject to other access controls. Use a dedicated learning account. The Terraform method creates a narrower policy for its specific database secret.

[AWS role creation reference](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-service.html), [instance profiles](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2_instance-profiles.html), [Secrets Manager client policy](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AWSSecretsManagerClientReadOnlyAccess.html)

## 9. Create three private service endpoints

Open **VPC → Endpoints → Create endpoint**. Repeat for each service:

| Endpoint name tag | Service name |
| --- | --- |
| `wordpress-ssm-endpoint` | `com.amazonaws.us-west-1.ssm` |
| `wordpress-ssmmessages-endpoint` | `com.amazonaws.us-west-1.ssmmessages` |
| `wordpress-secretsmanager-endpoint` | `com.amazonaws.us-west-1.secretsmanager` |

For each form:

1. Select type **AWS services**, search the exact service name, and choose the **Interface** result.
2. Select `wordpress-lab-vpc` and subnet `wordpress-private-app-1` in Zone A.
3. Use IPv4 and enable **Private DNS names** under the endpoint settings.
4. Select only `wordpress-endpoint-sg`. Leave the endpoint policy at **Full access**; the instance IAM role still controls which API operations it may perform.
5. Click **Create endpoint** and wait for **Available**.

Create all three before launching the application instance. [AWS interface endpoint reference](https://docs.aws.amazon.com/vpc/latest/privatelink/create-interface-endpoint.html)

## 10. Launch the private WordPress EC2 instance

Open **EC2 → Instances → Launch instances**. Enter:

| Setting | Value |
| --- | --- |
| Name | `wordpress-private-ec2` |
| Application and OS Images | Quick Start → Amazon Linux → standard Amazon Linux 2023, Amazon-published, 64-bit x86 |
| Instance type | `t3.micro` |
| Key pair | Proceed without a key pair |
| Network settings → Edit → VPC | `wordpress-lab-vpc` |
| Subnet | `wordpress-private-app-1` |
| Auto-assign public IP | Disable |
| Firewall | Select existing security group → `wordpress-ec2-sg` only |
| Storage | 20 GiB, `gp3` |
| Advanced details → IAM instance profile | `wordpress-ec2-ssm-role` |

Open the repository's [console installation script](console-user-data.sh) in another browser tab. On GitHub, click **Raw** to view the entire file. Copy its contents, including the first `#!/bin/bash` line, into **Advanced details → User data**. Leave any **already base64 encoded** option unchecked.

In the pasted text, replace:

- `PASTE_SECRET_ARN_HERE` with the Secret ARN recorded in step 7.
- `PASTE_RDS_ENDPOINT_HERE` with the RDS hostname; keep the trailing `:3306` already in the script. Do not add `http://` or paste the port twice.
- `us-west-1` only if you deliberately selected another region throughout the guide.

Click **Launch instance**. Record the instance ID. Wait for the instance checks and software installation; instance status checks alone do not confirm WordPress installation has finished.

The script installs the software, retrieves the password through the instance role, writes WordPress configuration, and starts Apache/PHP. It uses the AWS CLI internally on the server; you do not install or run it on your computer.

[AWS EC2 launch settings reference](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-launch-parameters.html)

## 11. Register the instance in a target group

1. Open **EC2 → Load Balancing → Target Groups → Create target group**.
2. Choose **Instances**, name `wordpress-target-group`, protocol **HTTP**, port **80**, and your VPC.
3. Set the health check to HTTP path `/`. Expand its advanced settings and use success codes `200-399`, interval 30 seconds, timeout 5 seconds, healthy threshold 2, and unhealthy threshold 2.
4. Click **Next**, select `wordpress-private-ec2` on port 80, and click **Include as pending below**.
5. Click **Create target group**. An unused target group is not healthy until attached to a load balancer in the next step.

[AWS target group reference](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-target-group.html)

## 12. Create the public Application Load Balancer

1. Open **EC2 → Load Balancers → Create load balancer**.
2. Under **Application Load Balancer**, click **Create**.
3. Name it `wordpress-alb`, select **Internet-facing**, and choose IPv4.
4. Under **Network mapping**, select your VPC and both public subnets: `wordpress-public-1` in Zone A and `wordpress-public-2` in Zone B.
5. Select only `wordpress-alb-sg` under security groups.
6. For the **HTTP:80** listener's default action, choose **Forward to target groups** and select `wordpress-target-group`.
7. Review the settings and click **Create load balancer**. Wait for **Active**.

The ALB accepts browser traffic and forwards it to the private instance. The instance needs no public address. [AWS ALB creation reference](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-application-load-balancer.html)

## 13. Verify the website through the console

1. Open **EC2 → Target Groups → wordpress-target-group → Targets**. Wait for the target to become **Healthy**.
2. Open **EC2 → Load Balancers → wordpress-alb → Details** and copy its **DNS name**.
3. Open `http://<ALB-DNS-name>` in your browser and complete the WordPress site title, administrator account, password, and email fields. The WordPress account is separate from the RDS `admin` account.

If you see a temporary `503`, wait for installation and health checks. If it persists, inspect these settings using their console pages:

| Symptom | What to check |
| --- | --- |
| No browser response | ALB Active; public subnet route to the attached internet gateway; ALB inbound TCP 80. |
| Unhealthy target / persistent `503` | Correct instance registered on port 80; ALB outbound rule; EC2 inbound rule; NAT Available; app subnet default route to NAT. |
| Database connection error | RDS Available; initial database `wordpress`; DB inbound TCP 3306 from the EC2 group; correct endpoint/port and secret ARN in user data. |
| Secret retrieval/install failure | EC2 instance role; three endpoints Available; private DNS; endpoint inbound TCP 443; EC2 outbound HTTP/HTTPS. |

To change the pasted configuration, stop the instance, then select **Actions → Instance settings → Edit user data**. User data normally runs only at first boot; editing it and restarting does not automatically repeat installation. For a fresh lab with incorrect user data, launch a corrected replacement and update target registration, then remove the old instance after checking any local files you need. [AWS user data behavior](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html)

This guide does not require an interactive instance terminal. `AmazonSSMManagedInstanceCore` enables the instance agent; it does not grant your console user permission to start Session Manager sessions.

## 14. Delete the manual lab through the console

Export any database data and save any WordPress files you need before deleting resources. Work only on resources created for this lab.

1. **EC2 → Load Balancers:** select `wordpress-alb` → **Actions → Delete load balancer**. Wait for deletion.
2. **EC2 → Target Groups:** select `wordpress-target-group` → **Actions → Delete**.
3. **EC2 → Instances:** select the lab instance → **Instance state → Terminate (delete) instance**. Check **Volumes** afterward for any remaining lab disks.
4. **RDS → Databases:** select `wordpress-mysql-db` → **Actions → Delete**. Choose whether to keep a final snapshot and retained backups; keeping them can incur storage charges. Confirm deletion. Check **Snapshots** for anything retained.
5. **VPC → Endpoints:** select the three lab endpoints → **Actions → Delete VPC endpoints**.
6. **VPC → NAT gateways:** select `wordpress-nat` → **Actions → Delete NAT gateway** and wait for deletion. Then open **Elastic IPs**, select its recorded allocation ID, and click **Actions → Release Elastic IP addresses**.
7. **RDS → Subnet groups:** delete `wordpress-db-subnet-group` after database deletion finishes. Check the RDS-managed secret in **Secrets Manager** for its deletion status.
8. **VPC → Security groups:** remove the cross-group references from the four lab groups before deleting them. Wait for database, endpoint, and ALB network interfaces to disappear if AWS reports a dependency.
9. **VPC → Your VPCs:** select `wordpress-lab-vpc` → **Actions → Delete VPC**. Review the related subnets, route tables, and internet gateway listed for removal; resolve any remaining dependencies and confirm.
10. **IAM → Roles:** delete `wordpress-ec2-ssm-role`. Remove the deployment user's access/policies and user if you no longer need them. Do not delete a user or role used by another project.

There is no Terraform state for these manual resources and no `terraform destroy` step. Recheck the relevant service consoles for leftovers such as snapshots, disks, and allocated Elastic IPs.

[Back to the Terraform method](../README.md)
