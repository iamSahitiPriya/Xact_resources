#!/bin/bash
TEMP_PROD_USERNAME=$(aws secretsmanager get-secret-value --secret-id migration/db --output text | grep -o '"username":"[^"]*' |  grep -o '[^"]*$' | sed 's/!/\\!/g')
TEMP_PROD_PASSWORD=$(aws secretsmanager get-secret-value --secret-id migration/db --output text | grep -o '"password":"[^"]*' |  grep -o '[^"]*$' | sed 's/!/\\!/g')
NON_PROD_USERNAME=$(aws secretsmanager get-secret-value --secret-id non-prod/db --output text --query SecretString | grep -o '"username":"[^"]*' |  grep -o '[^"]*$')
NON_PROD_PASSWORD=$(aws secretsmanager get-secret-value --secret-id non-prod/db --output text --query SecretString | grep -o '"password":"[^"]*' |  grep -o '[^"]*$' | sed 's/!/\\!/g')
NON_PROD_HOST=$(aws rds describe-db-instances --db-instance-identifier xact-db-np --query DBInstances[0].Endpoint.Address)
TEMP_PROD_INSTANCE_NAME=temp-prod-instance
PROD_DB=xactprod
SNAPSHOT_ID=$1
AVAILABLE_STATUS='"available"'

echo "Creating Instance from snapshot - ${SNAPSHOT_ID}"
aws rds restore-db-instance-from-db-snapshot --db-instance-identifier ${TEMP_PROD_INSTANCE_NAME} --db-snapshot-identifier ${SNAPSHOT_ID}  --vpc-security-group-ids sg-0c4805d53deaceac9 --no-publicly-accessible
echo "Instance Created"
INSTANCE_STATUS=$(aws rds describe-db-instances --db-instance-identifier $TEMP_PROD_INSTANCE_NAME --query DBInstances[0].DBInstanceStatus)
while [ $INSTANCE_STATUS != $AVAILABLE_STATUS ];
do
  echo "Waiting on Instance to be available - ${INSTANCE_STATUS}"
  sleep 10
  INSTANCE_STATUS=$(aws rds describe-db-instances --db-instance-identifier $TEMP_PROD_INSTANCE_NAME --query DBInstances[0].DBInstanceStatus)
done
echo "Modifying Instance credentials"
aws rds modify-db-instance --db-instance-identifier temp-prod-instance --master-user-password $TEMP_PROD_PASSWORD

INSTANCE_STATUS=$(aws rds describe-db-instances --db-instance-identifier temp-prod-instance --query DBInstances[0].DBInstanceStatus)
while [ $INSTANCE_STATUS != $AVAILABLE_STATUS ];
do
  echo "Waiting on Instance to be available - ${INSTANCE_STATUS}"
  sleep 10
  INSTANCE_STATUS=$(aws rds describe-db-instances --db-instance-identifier temp-prod-instance  --query DBInstances[0].DBInstanceStatus)
done

TEMP_PROD_HOST=$(aws rds describe-db-instances --db-instance-identifier temp-prod-instance --query DBInstances[0].Endpoint.Address)

echo "Copying prod instance to dev"
pg_dump -C --dbname=postgresql://$TEMP_PROD_USERNAME:$TEMP_PROD_PASSWORD@$TEMP_PROD_HOST:5432/$PROD_DB | psql --dbname=postgresql://$NON_PROD_USERNAME:$NON_PROD_PASSWORD@$NON_PROD_HOST:5432/xactdev

echo "Renaming prod to dev1"
psql --dbname=postgresql://$NON_PROD_USERNAME:$NON_PROD_PASSWORD@$NON_PROD_HOST:5432/xactdev -c "ALTER DATABASE xactprod RENAME TO xactdev1;"

echo "Copying prod instance to qa"
pg_dump -C --dbname=postgresql://$PROD_USERNAME:$PROD_PASSWORD@$TEMP_PROD_HOST:5432/$PROD_DB | psql --dbname=postgresql://$NON_PROD_USERNAME:$NON_PROD_PASSWORD@$NON_PROD_HOST:5432/xactqa

echo "Renaming prod to qa1"
psql --dbname=postgresql://"$NON_PROD_USERNAME":"$NON_PROD_PASSWORD"@$NON_PROD_HOST:5432/xactdev -c "ALTER DATABASE xactprod RENAME TO xactqa1;"

echo "Drop old database"
psql --dbname=postgresql://"$NON_PROD_USERNAME":"$NON_PROD_PASSWORD"@$NON_PROD_HOST:5432/xactqa -c "DROP DATABASE xactdev;"
psql --dbname=postgresql://"$NON_PROD_USERNAME":$NON_PROD_PASSWORD@$NON_PROD_HOST:5432/xactdev -c "DROP DATABASE xactqa;"

echo "Rename dev1 and qa1"
psql --dbname=postgresql://"$NON_PROD_USERNAME":$NON_PROD_PASSWORD@$NON_PROD_HOST:5432/xactqa -c "ALTER DATABASE xactdev1 RENAME TO xactdev;"
psql --dbname=postgresql://$NON_PROD_USERNAME:$NON_PROD_PASSWORD@$NON_PROD_HOST:5432/xactdev -c "ALTER DATABASE xactqa1 RENAME TO xactqa;"
