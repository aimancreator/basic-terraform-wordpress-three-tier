# WordPress on AWS: three-tier Terraform lab

Start by creating an IAM deployment user with the permissions below. Choose **Method A: AWS CLI on your computer** or **Method B: AWS Console with CloudShell**, then deploy the infrastructure with **one `terraform apply` from this folder**. Terraform finds an official Amazon Linux 2023 image and installs WordPress during startup. No personal AMI or separate image-building deployment is required.

## Choose your method

| Method | Where you work | Authentication |
| --- | --- | --- |
| **A. AWS CLI on your computer** | Your computer's terminal; install AWS CLI, Git, and Terraform locally. | Access keys stored in a local AWS CLI profile. |
| **B. AWS Console with CloudShell** | A browser terminal inside AWS Console; install Terraform in CloudShell. | Your console session supplies temporary credentials automatically. |

Choose one method for a deployment and keep using its state files. Both methods use Terraform commands; the AWS Console route runs them inside CloudShell. The AWS Console does not have a button to apply `.tf` files directly.

## 1. Create the IAM deployment user

Using an existing AWS administrator account, open **IAM → Users → Create user**:

1. Enter `terraform-lab-user` as the user name.
2. Choose sign-in access for your method:
   - **Method A:** leave AWS Management Console access disabled.
   - **Method B:** enable **Provide user access to the AWS Management Console**. If prompted, choose **I want to create an IAM user**. Set an initial console password and require a password change at next sign-in. Save the console sign-in URL and initial credentials securely.
3. Select **Attach policies directly** and attach these AWS managed policies:

   | Policy | Purpose |
   | --- | --- |
   | `AmazonEC2FullAccess` | Official AMI discovery, EC2, VPC, subnets, NAT gateway, Elastic IP, routes, security groups, VPC endpoints, and load balancing. This policy already includes `elasticloadbalancing:*`. |
   | `AmazonRDSFullAccess` | MySQL RDS, DB subnet groups, and RDS service-linked role creation. |
   | `IAMFullAccess` | Create, attach policies to, pass, and delete the EC2 role and instance profile. |
   | `SecretsManagerReadWrite` | Support RDS-managed database credentials; includes `kms:DescribeKey` for the default Secrets Manager encryption key. |

4. For **Method B only**, also attach `AWSCloudShellFullAccess`, which lets the user open and use CloudShell. Keep the four deployment policies above as well.
5. Select **Next**, review the selected policies, and create the user.

No custom policy, JSON editing, or account ID replacement is needed for the deployment user.

These policies grant broad permissions for a learning account. In particular, `IAMFullAccess` allows management of IAM users, roles, and permissions across the account. Use a dedicated lab account and remove the access when finished; production deployments should use narrower permissions.

The EC2 instance receives its own IAM role through Terraform. That role has `AmazonSSMManagedInstanceCore` and access to its specific database secret. Do not put the deployment user's access keys on the instance.

Organization service control policies and permission boundaries can still restrict these grants. This example uses AWS's standard commercial partition and the default Secrets Manager encryption key.

## 2. Prepare your chosen environment

### Method A: AWS CLI on your computer

Install [Terraform](https://developer.hashicorp.com/terraform/install), [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html), and Git on your computer. The examples below use Bash or Zsh; on Windows, use Git Bash or WSL.

Open **IAM → Users → terraform-lab-user → Security credentials → Create access key**. Choose **Command Line Interface (CLI)** and save the key ID and secret securely. The secret is only shown when the key is created.

In your computer's terminal, run:

```bash
aws configure --profile terraform-lab
```

Enter the access key ID and secret belonging to `terraform-lab-user`, region `us-west-1`, and output format `json`.

These names mean different things:

| Name | Meaning |
| --- | --- |
| `terraform-lab-user` | The IAM user in your AWS account. |
| `terraform-lab` | A local CLI profile containing that user's credentials. You choose this profile name; it does not need to match the IAM user name. |

Select the profile and verify your identity:

```bash
export AWS_PROFILE=terraform-lab
aws sts get-caller-identity
```

Check that the account is correct and the ARN identifies `terraform-lab-user`. Download the project:

```bash
git clone https://github.com/aimancreator/basic-terraform-wordpress-three-tier.git
cd basic-terraform-wordpress-three-tier
```

Continue to step 3. `provider.tf` uses the standard AWS credential chain, so configured temporary role credentials also work. Never put access keys in Terraform files.

### Method B: AWS Console with CloudShell

Use this method to work entirely in your browser, without installing tools on your computer or creating access keys.

1. Sign in using the IAM user's console sign-in URL, user name `terraform-lab-user`, and initial password from step 1. Complete the required password change. Enable MFA for the user.
2. Select **US West (N. California) / `us-west-1`** in the console's region selector.
3. Open **CloudShell** from the console toolbar or search for **CloudShell**. Use its standard environment, which has internet access, and select **Bash**.
4. Confirm the signed-in identity:

```bash
aws sts get-caller-identity
```

The ARN should identify `terraform-lab-user`. CloudShell already includes AWS CLI and Git and automatically uses your console credentials. Continue with those credentials; no `aws configure`, local profile, or access keys are needed here.

Install Terraform in CloudShell using HashiCorp's official Amazon Linux repository:

```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo dnf install -y terraform
terraform version
```

Download the project into CloudShell's persistent home directory:

```bash
cd ~
git clone https://github.com/aimancreator/basic-terraform-wordpress-three-tier.git
cd basic-terraform-wordpress-three-tier
```

Continue to step 3 in the same CloudShell terminal. The default deployment region is still `us-west-1`; changing the console region alone does not override Terraform's region variable.

After deployment, keep a private backup of `terraform.tfstate` using **CloudShell → Actions → Download file**. Run `pwd` in the project directory to find the full path, then append `/terraform.tfstate` in the download dialog. Keep it out of GitHub. Return to the same console identity, CloudShell region, and project directory to manage or destroy this deployment. CloudShell home storage is region-specific and can be removed after prolonged inactivity, so it should not be the only copy of your state.

## 3. Choose the deployment region

The default region is `us-west-1`. Terraform automatically selects two available standard Availability Zones and an official Amazon-owned Amazon Linux 2023 x86_64 AMI in that region. Each user launches their own instance in their own account; access to a personal AMI is unnecessary.

To use another region, set this before running Terraform:

```bash
export TF_VAR_aws_region=us-east-1
```

Use the selected region in any AWS CLI troubleshooting commands as well. The region must offer at least two standard Availability Zones, the selected instance classes, MySQL RDS, and the configured VPC endpoint services.

On startup, the private EC2 instance downloads Apache, PHP, and WordPress through a public NAT gateway. It then retrieves the RDS-generated database credentials through Secrets Manager, creates unique WordPress authentication keys, and starts the web server. The database subnets have no NAT route, and the EC2 instance has no public IP or inbound SSH rule.

`modules/ami-builder/` contains older optional image-building tools. The main deployment does not use them, and no image-building step is required.

## 4. Deploy from this folder

In your chosen terminal (your computer for Method A, or CloudShell for Method B), use the cloned project folder containing `main.tf` and `provider.tf`:

```bash
pwd
ls main.tf provider.tf
```

Deploy:

```bash
terraform init
terraform validate
terraform apply
```

Review the plan and enter `yes` to approve it. Only `terraform apply` provisions resources; initialization and validation prepare and check the configuration. RDS creation and the first software installation can take several minutes. Terraform can finish before cloud-init finishes installing WordPress; a temporary ALB `503` during installation is expected.

Run these commands in the root folder only. The deployment user already has the permissions configured in step 1; no separate IAM bootstrap apply is required.

Use a clean account/region or resolve any existing resources with the same names first. If resources already exist but are absent from your state, import them before applying. Keep the state created by this deployment so Terraform can manage and destroy those resources later.

### What Terraform creates

```text
Internet → public Application Load Balancer :80
                       ↓
             private WordPress EC2 :80
                       ↓
               private MySQL RDS :3306

WordPress EC2 → private VPC endpoints :443
               (SSM, SSM Messages, Secrets Manager)

WordPress EC2 → public NAT gateway → internet software downloads
```

The deployment includes a VPC, two public subnets, one private application subnet, two private database subnets, an internet gateway, one public NAT gateway and Elastic IP, public and private application routes, security groups, an EC2 role/profile, an ALB, one EC2 instance, RDS, and three interface endpoints. RDS generates and stores its master credentials in Secrets Manager.

This is a learning configuration: HTTP only, one application instance, a single-AZ database, and no automated database backups. EC2, RDS, ALB, NAT gateway hours/data processing, public IPv4 addresses, interface endpoints, storage, and Secrets Manager can incur charges while deployed. Check [AWS pricing](https://aws.amazon.com/pricing/) for your region.

## 5. Open WordPress

Terraform displays a `wordpress_url` output. You can print it again with:

```bash
terraform output -raw wordpress_url
```

Open the returned `http://...` URL and complete the WordPress installation screen. Set the site title, WordPress administrator name, password, and email. The WordPress administrator account is separate from the MySQL `admin` user.

If you see `503`, allow time for startup and check **EC2 → Target Groups → wordpress-target-group → Targets**. If the target stays unhealthy, inspect `/var/log/cloud-init-output.log` on the instance using an administrator with Session Manager access. Check NAT routing, outbound HTTP/HTTPS access, package downloads, Apache/PHP-FPM services, endpoint connectivity, and secret permissions. `/var/log/wordpress-install.log` contains startup diagnostics and `/var/log/wordpress-install-complete` marks successful installation. The deployment policies above, including optional CloudShell access, do not grant interactive Session Manager access.

## 6. Destroy the lab

From the same root folder and deployment environment, using the same AWS identity, region, and state (Method A: select `AWS_PROFILE=terraform-lab` again if needed; Method B: return to the original CloudShell region and project folder):

```bash
terraform destroy
```

Review the destruction plan and enter `yes`. **The database is deleted without a final snapshot** (`skip_final_snapshot = true`). Export anything you need first.

Terraform destroys the NAT gateway and Elastic IP along with the rest of the managed lab. The official Amazon Linux image is maintained by AWS; this deployment creates no custom AMI or image snapshots. After cleanup, deactivate/delete the deployment user's access keys and remove the user/policies if no longer needed.

### Reapplying and existing deployments

Review every plan: switching an existing instance from a custom AMI to the official image replaces that EC2 instance. Future applies can also select a newer official AMI and replace EC2; startup script changes are configured to replace it too. Back up WordPress uploads/plugins/themes stored on the instance before replacing it. RDS data is separate from the EC2 disk, but `terraform destroy` deletes the database as described above.

For an existing deployment, the automatic Availability Zone selection may differ from the old hardcoded zones. Review any subnet replacement in the plan before approving; changing regions also requires a separate deployment/state strategy.

## GitHub checklist

Commit the Terraform source, shell scripts, this README, `.gitignore`, and `.terraform.lock.hcl`. Keep `.terraform/`, state, saved plans, access keys, and local variable files out of GitHub. The supplied `.gitignore` excludes Terraform's generated and local files. Store your active Terraform state securely outside public GitHub.

## References

- [IAM user credentials for the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-authentication-user.html)
- [AmazonEC2FullAccess policy](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonEC2FullAccess.html)
- [AmazonRDSFullAccess policy](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonRDSFullAccess.html)
- [IAMFullAccess policy](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/IAMFullAccess.html)
- [SecretsManagerReadWrite policy](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/SecretsManagerReadWrite.html)
- [RDS-managed password permissions](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-secrets-manager.html)
- [Official Amazon Linux AMI lookup with Terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami)
- [NAT gateways](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html)
- [WordPress on Amazon Linux 2023](https://docs.aws.amazon.com/linux/al2023/ug/hosting-wordpress-aml-2023.html)
- [Getting started with AWS CloudShell](https://docs.aws.amazon.com/cloudshell/latest/userguide/getting-started.html)
- [CloudShell credentials and permissions](https://docs.aws.amazon.com/cloudshell/latest/userguide/sec-auth-with-identities.html)
- [CloudShell storage and session limits](https://docs.aws.amazon.com/cloudshell/latest/userguide/limits.html)
- [Install Terraform on Amazon Linux](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
