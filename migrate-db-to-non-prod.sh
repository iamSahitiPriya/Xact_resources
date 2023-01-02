#!/bin/bash
TEMP_PROD_USERNAME=$(aws secretsmanager get-secret-value --secret-id migration/db --output text | grep -o '"username":"[^"]*' | grep -o '[^"]*$' | sed 's/!/\\!/g')
TEMP_PROD_PASSWORD=$(aws secretsmanager get-secret-value --secret-id migration/db --output text | grep -o '"password":"[^"]*' | grep -o '[^"]*$' | sed 's/!/\\!/g')
NON_PROD_USERNAME=$(aws secretsmanager get-secret-value --secret-id non-prod/db --output text --query SecretString | grep -o '"username":"[^"]*' | grep -o '[^"]*$')
NON_PROD_PASSWORD=$(aws secretsmanager get-secret-value --secret-id non-prod/db --output text --query SecretString | grep -o '"password":"[^"]*' | grep -o '[^"]*$')
DB_CONNECT_USERNAME=$(aws secretsmanager get-secret-value --secret-id dev/dbuser --output text | grep -o '"DEV_DB_USER":"[^"]*' | grep -o '[^"]*$' | sed 's/!/\\!/g')
TEMP_PROD_INSTANCE_NAME=temp-prod-instance
TEMP_PROD_DB=xactprodtemp
PROD_DB=xactprod
NP_SNAPSHOT_ID=$1
EXISTING_NP_INSTANCE=$(aws rds describe-db-instances --query DBInstances[*].DBInstanceIdentifier | grep -o 'xact-db-np-[^"]*')
PROD_SNAPSHOT_ID=$2
TEMP_NON_PROD_INSTANCE_NAME=xact-db-np-$(date +'%m-%d-%Y-%H-%M-%S')
AVAILABLE_STATUS='"available"'
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name xact.thoughtworks.net --output json --query HostedZones[0].Id | tr -d '"')

echo $EXISTING_NP_INSTANCE

create_instance() {
  SNAPSHOT_ID=$2
  DB_INSTANCE_ID=$1
  echo "Creating Instance from snapshot - ${SNAPSHOT_ID}"
  echo "Instance Created - $1"

  aws rds restore-db-instance-from-db-snapshot --db-instance-identifier ${DB_INSTANCE_ID} --db-snapshot-identifier ${SNAPSHOT_ID} --vpc-security-group-ids sg-0c4805d53deaceac9 --no-publicly-accessible
  INSTANCE_STATUS=$(aws rds describe-db-instances --db-instance-identifier ${DB_INSTANCE_ID} --query DBInstances[0].DBInstanceStatus)
  while [ $INSTANCE_STATUS != $AVAILABLE_STATUS ]; do
    echo "Waiting on Instance to be available - ${INSTANCE_STATUS}"
    sleep 10
    INSTANCE_STATUS=$(aws rds describe-db-instances --db-instance-identifier $1 --query DBInstances[0].DBInstanceStatus)
  done
}
create_instance ${TEMP_PROD_INSTANCE_NAME} ${PROD_SNAPSHOT_ID}

create_instance ${TEMP_NON_PROD_INSTANCE_NAME} ${NP_SNAPSHOT_ID}

echo "Modifying Instance credentials"
aws rds modify-db-instance --db-instance-identifier temp-prod-instance --master-user-password ${TEMP_PROD_PASSWORD}

INSTANCE_STATUS=$(aws rds describe-db-instances --db-instance-identifier temp-prod-instance --query DBInstances[0].DBInstanceStatus)
while [ $INSTANCE_STATUS == $AVAILABLE_STATUS ]; do
  echo $INSTANCE_STATUS
  sleep 10
  INSTANCE_STATUS=$(aws rds describe-db-instances --db-instance-identifier temp-prod-instance --query DBInstances[0].DBInstanceStatus)
done

while [ $INSTANCE_STATUS != $AVAILABLE_STATUS ]; do
  echo "Waiting on Instance to be available - ${INSTANCE_STATUS}"
  sleep 10
  INSTANCE_STATUS=$(aws rds describe-db-instances --db-instance-identifier temp-prod-instance --query DBInstances[0].DBInstanceStatus)
done

NON_PROD_HOST=$(aws rds describe-db-instances --db-instance-identifier ${TEMP_NON_PROD_INSTANCE_NAME} --query DBInstances[0].Endpoint.Address | tr -d '"')
TEMP_PROD_HOST=$(aws rds describe-db-instances --db-instance-identifier ${TEMP_PROD_INSTANCE_NAME} --query DBInstances[0].Endpoint.Address | tr -d '"')

echo "Dropping old databases if exists"
psql --dbname=postgresql://${NON_PROD_USERNAME}:${NON_PROD_PASSWORD}@${NON_PROD_HOST}:5432/xactdev -c "DROP DATABASE IF EXISTS xactdev1"
psql --dbname=postgresql://${NON_PROD_USERNAME}:${NON_PROD_PASSWORD}@${NON_PROD_HOST}:5432/xactdev -c "DROP DATABASE IF EXISTS xactqa1"
psql --dbname=postgresql://${NON_PROD_USERNAME}:${NON_PROD_PASSWORD}@${NON_PROD_HOST}:5432/xactdev -c "DROP DATABASE IF EXISTS xactprod"
psql --dbname=postgresql://${NON_PROD_USERNAME}:${NON_PROD_PASSWORD}@${NON_PROD_HOST}:5432/xactdev -c "DROP DATABASE IF EXISTS xactprodtemp"

echo "Creating temp-prod database"
psql --dbname=postgresql://${NON_PROD_USERNAME}:${NON_PROD_PASSWORD}@${NON_PROD_HOST}:5432/xactdev -c "CREATE DATABASE ${TEMP_PROD_DB}"

echo "Copying temp prod instance to dev"
pg_dump -C --dbname=postgresql://${TEMP_PROD_USERNAME}:${TEMP_PROD_PASSWORD}@${TEMP_PROD_HOST}:5432/${PROD_DB} | psql --dbname=postgresql://${NON_PROD_USERNAME}:${NON_PROD_PASSWORD}@${NON_PROD_HOST}:5432/${TEMP_PROD_DB}

echo "Renaming temp-prod to dev1"
psql --dbname=postgresql://${NON_PROD_USERNAME}:${NON_PROD_PASSWORD}@${NON_PROD_HOST}:5432/xactdev -c "ALTER DATABASE ${PROD_DB} RENAME TO xactdev1;"

echo "Copying prod instance to qa"
pg_dump -C --dbname=postgresql://${TEMP_PROD_USERNAME}:${TEMP_PROD_PASSWORD}@${TEMP_PROD_HOST}:5432/${PROD_DB} | psql --dbname=postgresql://${NON_PROD_USERNAME}:${NON_PROD_PASSWORD}@${NON_PROD_HOST}:5432/${TEMP_PROD_DB}

echo "Renaming prod to qa1"
psql --dbname=postgresql://"${NON_PROD_USERNAME}":"${NON_PROD_PASSWORD}"@${NON_PROD_HOST}:5432/xactdev -c "ALTER DATABASE ${PROD_DB} RENAME TO xactqa1;"

echo "Drop old database"
psql --dbname=postgresql://"${NON_PROD_USERNAME}":"${NON_PROD_PASSWORD}"@${NON_PROD_HOST}:5432/xactqa -c "DROP DATABASE xactdev;"
psql --dbname=postgresql://"${NON_PROD_USERNAME}":${NON_PROD_PASSWORD}@${NON_PROD_HOST}:5432/xactdev1 -c "DROP DATABASE xactqa;"
psql --dbname=postgresql://"${NON_PROD_USERNAME}":${NON_PROD_PASSWORD}@${NON_PROD_HOST}:5432/xactdev1 -c "DROP DATABASE xactprodtemp;"

echo "Rename dev1 and qa1"
psql --dbname=postgresql://"${NON_PROD_USERNAME}":${NON_PROD_PASSWORD}@${NON_PROD_HOST}:5432/xactqa1 -c "ALTER DATABASE xactdev1 RENAME TO xactdev;"
psql --dbname=postgresql://${NON_PROD_USERNAME}:${NON_PROD_PASSWORD}@${NON_PROD_HOST}:5432/xactdev -c "ALTER DATABASE xactqa1 RENAME TO xactqa;"


echo "Grant permissions"
psql --dbname=postgresql://${NON_PROD_USERNAME}:${NON_PROD_PASSWORD}@${NON_PROD_HOST}:5432/xactdev -c 'GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "'${DB_CONNECT_USERNAME}'";'
psql --dbname=postgresql://${NON_PROD_USERNAME}:${NON_PROD_PASSWORD}@${NON_PROD_HOST}:5432/xactqa -c 'GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "'${DB_CONNECT_USERNAME}'";'


echo "Changing hosted zone"
aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch "{\"Changes\": [{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"xact-db-np.xact.thoughtworks.net\",\"Type\":\"CNAME\",\"TTL\":30,\"ResourceRecords\":[{\"Value\":\"${NON_PROD_HOST}\"}]}}]}"

echo "Deleting existing NP instance - $EXISTING_NP_INSTANCE"
aws rds delete-db-instance --db-instance-identifier ${EXISTING_NP_INSTANCE} --delete-automated-backups --skip-final-snapshot
