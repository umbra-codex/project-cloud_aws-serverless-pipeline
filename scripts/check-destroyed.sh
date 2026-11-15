#!/usr/bin/env bash
# Ask AWS, not the state file, whether anything with the prefix is left.
set -euo pipefail

PREFIX=${1:-serverless-pipeline}
REGION=${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}
LEFT=0

if ! aws --region "$REGION" sts get-caller-identity >/dev/null 2>&1; then
  echo "Nothing was checked: the AWS credentials did not work. Run aws login and try again."
  exit 2
fi

report() {
  local label=$1 found=$2
  if [ -z "$found" ] || [ "$found" = "None" ]; then
    echo "✅ $label: none left"
  else
    echo "❌ $label: still there"
    echo "$found"
    LEFT=1
  fi
}

if ! fns=$(aws --region "$REGION" lambda list-functions \
  --query "Functions[?starts_with(FunctionName,'$PREFIX')].FunctionName" --output text); then
  echo "Nothing was checked: the Lambda call failed."
  exit 2
fi
report "Lambda functions" "$fns"

if ! queues=$(aws --region "$REGION" sqs list-queues --queue-name-prefix "$PREFIX" --query "QueueUrls" --output text); then
  echo "Nothing was checked: the SQS call failed."
  exit 2
fi
report "SQS queues" "$queues"

if ! tables=$(aws --region "$REGION" dynamodb list-tables \
  --query "TableNames[?starts_with(@,'$PREFIX')]" --output text); then
  echo "Nothing was checked: the DynamoDB call failed."
  exit 2
fi
report "DynamoDB tables" "$tables"

if ! buckets=$(aws --region "$REGION" s3api list-buckets \
  --query "Buckets[?starts_with(Name,'$PREFIX')].Name" --output text); then
  echo "Nothing was checked: the S3 call failed."
  exit 2
fi
report "S3 buckets" "$buckets"

if [ "$LEFT" -ne 0 ]; then
  echo "Delete what is listed by hand, note why in DECISIONS.md, and run this script again."
  exit 1
fi
echo "👍 Nothing with the prefix $PREFIX is left in this account."
