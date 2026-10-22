
#!/bin/bash
set -euo pipefail

INSTANCE_ID="${1:?Usage: create-ami.sh INSTANCE_ID}"
REGION="us-west-1"
PROFILE="terraform-lab"
AMI_NAME="wordpress-custom-$(date +%Y%m%d-%H%M%S)"

echo "Waiting for EC2 to become an SSM managed instance..."

for attempt in {1..60}; do
  STATUS=$(aws ssm describe-instance-information \
    --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query 'InstanceInformationList[0].PingStatus' \
    --output text)

  if [[ "$STATUS" == "Online" ]]; then
    echo "EC2 is online in Systems Manager!"
    break
  fi

  if [[ "$attempt" -eq 60 ]]; then
    echo "ERROR: EC2 did not become available in SSM."
    exit 1
  fi

  sleep 10
done

echo "Waiting for WordPress installation..."

READY=false

for attempt in {1..60}; do
  COMMAND_ID=$(aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=["test -f /var/log/wordpress-install-complete","/usr/local/bin/verify-wordpress.sh"]' \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query 'Command.CommandId' \
    --output text)

  if aws ssm wait command-executed \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --region "$REGION" \
    --profile "$PROFILE"; then

    READY=true
    echo "WordPress verification successful!"
    break
  fi

  echo "Installation not ready. Retrying..."
  sleep 10
done

if [[ "$READY" != true ]]; then
  echo "ERROR: WordPress installation did not complete."
  exit 1
fi

COMMAND_ID=$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["test -f /var/log/wordpress-install-complete","/usr/local/bin/verify-wordpress.sh"]' \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query 'Command.CommandId' \
  --output text)

aws ssm wait command-executed \
  --command-id "$COMMAND_ID" \
  --instance-id "$INSTANCE_ID" \
  --region "$REGION" \
  --profile "$PROFILE"

echo "Verification completed. Creating AMI..."

AMI_ID=$(aws ec2 create-image \
  --instance-id "$INSTANCE_ID" \
  --name "$AMI_NAME" \
  --description "WordPress with Apache and PHP" \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query 'ImageId' \
  --output text)

echo "Waiting for AMI to become available..."

aws ec2 wait image-available \
  --image-ids "$AMI_ID" \
  --region "$REGION" \
  --profile "$PROFILE"

echo "Custom WordPress AMI created: $AMI_ID"
