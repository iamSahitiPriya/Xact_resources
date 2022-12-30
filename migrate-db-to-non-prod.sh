#!/bin/bash
TEMP_PROD_USERNAME=$(aws secretsmanager get-secret-value --secret-id migration/db --output text | grep -o '"username":"[^"]*' | grep -o '[^"]*$' | sed 's/!/\\!/g')
TEMP_PROD_PASSWORD=$(aws secretsmanager get-secret-value --secret-id migration/db --output text | grep -o '"password":"[^"]*' | grep -o '[^"]*$' | sed 's/!/\\!/g')
NON_PROD_USERNAME=$(aws secretsmanager get-secret-value --secret-id non-prod/db --output text --query SecretString | grep -o '"username":"[^"]*' | grep -o '[^"]*$')
NON_PROD_PASSWORD=$(aws secretsmanager get-secret-value --secret-id non-prod/db --output text --query SecretString | grep -o '"password":"[^"]*' | grep -o '[^"]*$')
NON_PROD_HOST=$(aws rds describe-db-instances --db-instance-identifier temp-non-prod-instance --query DBInstances[0].Endpoint.Address | tr -d '"')
TEMP_PROD_INSTANCE_NAME=temp-prod-instance
PROD_DB=xactprod
SNAPSHOT_ID=$1
TEMP_NON_PROD_INSTANCE_NAME=temp-non-prod-instance
AVAILABLE_STATUS='"available"'
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name xact.thoughtworks.net --output json --query HostedZones[0].Id | tr -d '"')

echo "Creating Instance from snapshot - ${SNAPSHOT_ID}"

create_instance() {
  echo $1
  echo $2
  echo "Instance Created - $1"

  aws rds restore-db-instance-from-db-snapshot --db-instance-identifier $1 --db-snapshot-identifier $2 --vpc-security-group-ids sg-0c4805d53deaceac9 --no-publicly-accessible
  INSTANCE_STATUS=$(aws rds describe-db-instances --db-instance-identifier $1 --query DBInstances[0].DBInstanceStatus)
  while [ $INSTANCE_STATUS != $AVAILABLE_STATUS ]; do
    echo "Waiting on Instance to be available - ${INSTANCE_STATUS}"
    sleep 10
    INSTANCE_STATUS=$(aws rds describe-db-instances --db-instance-identifier $1 --query DBInstances[0].DBInstanceStatus)
  done
}
create_instance ${TEMP_PROD_INSTANCE_NAME} rds:xact-db-prod-2022-12-29-21-35

create_instance ${TEMP_NON_PROD_INSTANCE_NAME} rds:xact-db-np-2022-12-29-20-17

echo "Modifying Instance credentials"
aws rds modify-db-instance --db-instance-identifier temp-prod-instance --master-user-password ${TEMP_PROD_PASSWORD}
sleep 30
INSTANCE_STATUS=$(aws rds describe-db-instances --db-instance-identifier temp-prod-instance --query DBInstances[0].DBInstanceStatus)
while [ $INSTANCE_STAUS != '"resetting-master-credentials"' ]; do
  sleep 10
  INSTANCE_STATUS=$(aws rds describe-db-instances --db-instance-identifier temp-prod-instance --query DBInstances[0].DBInstanceStatus)

done

echo $INSTANCE_STATUS
while [ $INSTANCE_STATUS != $AVAILABLE_STATUS ]; do
  echo "Waiting on Instance to be available - ${INSTANCE_STATUS}"
  sleep 10
  INSTANCE_STATUS=$(aws rds describe-db-instances --db-instance-identifier temp-prod-instance --query DBInstances[0].DBInstanceStatus)
done

TEMP_PROD_HOST=$(aws rds describe-db-instances --db-instance-identifier temp-prod-instance --query DBInstances[0].Endpoint.Address | tr -d '"')

echo "Copying prod instance to dev"
pg_dump -C --dbname=postgresql://${TEMP_PROD_USERNAME}:${TEMP_PROD_PASSWORD}@${TEMP_PROD_HOST}:5432/${PROD_DB} | psql --dbname=postgresql://${NON_PROD_USERNAME}:${NON_PROD_PASSWORD}@${NON_PROD_HOST}:5432/xactdev

echo "Renaming prod to dev1"
psql --dbname=postgresql://${NON_PROD_USERNAME}:${NON_PROD_PASSWORD}@${NON_PROD_HOST}:5432/xactdev -c "ALTER DATABASE xactprod RENAME TO xactdev1;"

echo "Copying prod instance to qa"
pg_dump -C --dbname=postgresql://${TEMP_PROD_USERNAME}:${TEMP_PROD_PASSWORD}@${TEMP_PROD_HOST}:5432/${PROD_DB} | psql --dbname=postgresql://${NON_PROD_USERNAME}:${NON_PROD_PASSWORD}@${NON_PROD_HOST}:5432/xactqa

echo "Renaming prod to qa1"
psql --dbname=postgresql://"${NON_PROD_USERNAME}":"${NON_PROD_PASSWORD}"@${NON_PROD_HOST}:5432/xactdev -c "ALTER DATABASE xactprod RENAME TO xactqa1;"

echo "Drop old database"
psql --dbname=postgresql://"${NON_PROD_USERNAME}":"${NON_PROD_PASSWORD}"@${NON_PROD_HOST}:5432/xactqa -c "DROP DATABASE xactdev;"
psql --dbname=postgresql://"${NON_PROD_USERNAME}":${NON_PROD_PASSWORD}@${NON_PROD_HOST}:5432/xactdev1 -c "DROP DATABASE xactqa;"

echo "Rename dev1 and qa1"
psql --dbname=postgresql://"${NON_PROD_USERNAME}":${NON_PROD_PASSWORD}@${NON_PROD_HOST}:5432/xactqa1 -c "ALTER DATABASE xactdev1 RENAME TO xactdev;"
psql --dbname=postgresql://${NON_PROD_USERNAME}:${NON_PROD_PASSWORD}@${NON_PROD_HOST}:5432/xactdev -c "ALTER DATABASE xactqa1 RENAME TO xactqa;"

echo "Changing hosted zone"
aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch "{\"Changes\": [{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"xact-db-np.xact.thoughtworks.net\",\"Type\":\"CNAME\",\"TTL\":30,\"ResourceRecords\":[{\"Value\":\"${NON_PROD_HOST}\"}]}}]}"
