TEMP_PROD_INSTANCE_NAME=temp-prod-instance
DELETE_STATUS=$(aws rds describe-db-instances --db-instance-identifier ${TEMP_PROD_INSTANCE_NAME} --query DBInstances[0].DBInstanceStatus)
aws rds delete-db-instance --db-instance-identifier temp-prod-instance --delete-automated-backups --skip-final-snapshot
STATUS='"deleting"'

while [ $DELETE_STATUS == $STATUS ]; do
  echo "Waiting on Instance to be Deleted - ${DELETE_STATUS}"
  sleep 10
  DELETE_STATUS=$(aws rds describe-db-instances --db-instance-identifier ${TEMP_PROD_INSTANCE_NAME} --query DBInstances[0].DBInstanceStatus)
done
