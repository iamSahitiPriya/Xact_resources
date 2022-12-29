TEMP_PROD_INSTANCE_NAME=temp-prod-instance
INSTANCE_STATUS=$(aws rds describe-db-instances --db-instance-identifier ${TEMP_PROD_INSTANCE_NAME} --query DBInstances[0].DBInstanceStatus)
while [ "$INSTANCE_STATUS" != null ];
do
  sleep 10
  aws rds delete-db-instance --db-instance-identifier temp-prod-instance --delete-automated-backups --skip-final-snapshot
  echo "Waiting on Instance to be Deleted - ${INSTANCE_STATUS}"
done