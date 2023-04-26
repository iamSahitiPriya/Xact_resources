provider "aws" {
  region     = "ap-south-1"
}

resource "aws_iam_role" "start_stop_rds_lambda" {
  name = "start_stop_rds_lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "start_stop_rds_lambda" {
  name        = "start_stop_rds_lambda"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "rds:DescribeDBClusterParameters",
                "rds:StartDBCluster",
                "rds:StopDBCluster",
                "rds:DescribeDBEngineVersions",
                "rds:DescribeGlobalClusters",
                "rds:DescribePendingMaintenanceActions",
                "rds:DescribeDBLogFiles",
                "rds:StopDBInstance",
                "rds:StartDBInstance",
                "rds:DescribeReservedDBInstancesOfferings",
                "rds:DescribeReservedDBInstances",
                "rds:ListTagsForResource",
                "rds:DescribeValidDBInstanceModifications",
                "rds:DescribeDBInstances",
                "rds:DescribeSourceRegions",
                "rds:DescribeDBClusterEndpoints",
                "rds:DescribeDBClusters",
                "rds:DescribeDBClusterParameterGroups",
                "rds:DescribeOptionGroups",
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
            ]
            "Resource": ["*"]
        }]
  })
  }

resource "aws_iam_role_policy_attachment" "start_stop_rds_lambda" {
  policy_arn = aws_iam_policy.start_stop_rds_lambda.arn
  role       = aws_iam_role.start_stop_rds_lambda.name

}

  resource "aws_lambda_function" "start_rds_lambda" {
      filename      = "start-rds.zip"
      function_name = "start-rds"
      role          = aws_iam_role.start_stop_rds_lambda.arn
      handler       = "start-rds.lambda_handler"
      runtime       = "python3.8"
      environment {
          variables = {
            KEY = "non-prod"
            VALUE = "auto-start-stop"
            REGION = "ap-south-1"
          }
        }
    }

 resource "aws_lambda_function" "stop_rds_lambda" {
    filename      = "stop-rds.zip"
    function_name = "stop-rds"
    role          = aws_iam_role.start_stop_rds_lambda.arn
    handler       = "stop-rds.lambda_handler"
    runtime       = "python3.8"
    environment {
        variables = {
          KEY = "non-prod"
          VALUE = "auto-start-stop"
          REGION = "ap-south-1"
        }
      }
  }


resource "aws_cloudwatch_event_rule" "start_rds_event" {
  name        = "start-rds-event"
  description = "Trigger Lambda function every weekday at 8:00 AM IST"

  schedule_expression = "cron(30 2 ? * MON-FRI *)"
}

resource "aws_cloudwatch_event_rule" "stop_rds_event" {
  name        = "stop-rds-event"
  description = "Trigger Lambda function every weekday at 10:00 PM IST"

  schedule_expression = "cron(30 16 ? * MON-FRI *)"
}


resource "aws_cloudwatch_event_target" "start_rds_target" {
  target_id = "start-rds-target"
  rule      = aws_cloudwatch_event_rule.start_rds_event.name
  arn       = aws_lambda_function.start_rds_lambda.arn
}

resource "aws_cloudwatch_event_target" "stop_rds_target" {
  target_id = "stop-rds-target"
  rule      = aws_cloudwatch_event_rule.stop_rds_event.name
  arn       = aws_lambda_function.stop_rds_lambda.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_start_rds_lambda" {
  statement_id = "AllowExecutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_rds_lambda.arn
  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.start_rds_event.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_stop_rds_lambda" {
  statement_id = "AllowExecutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stop_rds_lambda.arn
  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.stop_rds_event.arn
}