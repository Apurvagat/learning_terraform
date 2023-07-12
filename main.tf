provider "aws" {
  region = "eu-north-1"
  shared_credentials_files = ["/home/apurva/.aws/credentials"]
}

resource "aws_dynamodb_table" "user_contacts" {
  name           = "user_contacts"
  hash_key       = "userID"
  billing_mode   = "PAY_PER_REQUEST"

  attribute {
    name = "userID"
    type = "S"
  }

  attribute {
    name = "firstName"
    type = "S"
  }

  attribute {
    name = "lasttName"
    type = "S"
  }

  attribute {
    name = "address"
    type = "S"
  }

  attribute {
    name = "mobileNumber"
    type = "S"
  }

  attribute {
    name = "emailAddress"
    type = "S"
  }

  global_secondary_index {
    name               = "firstNameIndex"
    hash_key           = "firstName"
    projection_type    = "ALL"
    read_capacity      = 5
    write_capacity     = 5
  }

   global_secondary_index {
    name               = "lasttNameIndex"
    hash_key           = "lasttName"
    projection_type    = "ALL"
    read_capacity      = 5
    write_capacity     = 5
  }

   global_secondary_index {
    name               = "addressIndex"
    hash_key           = "address"
    projection_type    = "ALL"
    read_capacity      = 5
    write_capacity     = 5
  }

   global_secondary_index {
    name               = "mobileNumberIndex"
    hash_key           = "mobileNumber"
    projection_type    = "ALL"
    read_capacity      = 5
    write_capacity     = 5
  }

   global_secondary_index {
    name               = "emailIndex"
    hash_key           = "emailAddress"
    projection_type    = "ALL"
    read_capacity      = 5
    write_capacity     = 5
  }
}


resource "aws_iam_role" "user_operations_role" {
  name = "user_operations_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "aws_iam_policy" {
  name        = "aws_iam_policy"
  path        = "/"
  description = "IAM policy for a lambda"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "dynamodb:*",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "user_operations_role_attachement1" {
  role       = aws_iam_role.user_operations_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "user_operations_role_attachement2" {
  role       = aws_iam_role.user_operations_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_api_gateway_rest_api" "user_info_api" {
  name        = "user_info_api"
  description = "user info api"
}

data "archive_file" "users" {
  type        = "zip"
  source_dir = "${path.module}/users"
  output_path = "${path.module}/users/users.zip"
 depends_on = [ "null_resource.build_zip1" ]
}

resource "null_resource" "build_zip1" {
  provisioner "local-exec" {
    command = "bash build.sh"
    working_dir = "${path.module}/users"
  }
}

resource "aws_s3_bucket_object" "users_zip" {
  bucket = "user-get-operations-bucket"
  key    = "users.zip"
  source = "${path.module}/users/users.zip"
  etag   = filemd5("${path.module}/users/users.zip")
}

resource "aws_lambda_function" "user_get_operations" {
  filename      = "${path.module}/users/main.zip"
  function_name = "user_get_operations"
  role          = aws_iam_role.user_operations_role.arn
  runtime       = "go1.x"
  handler       = "main"
  timeout       = 1
  memory_size   = 512
  depends_on    = [aws_iam_role_policy_attachment.user_operations_role_attachement1,aws_iam_role_policy_attachment.user_operations_role_attachement2]
  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.user_contacts.name
    }
  }
}


resource "aws_api_gateway_resource" "users" {
  rest_api_id = aws_api_gateway_rest_api.user_info_api.id
  parent_id   = aws_api_gateway_rest_api.user_info_api.root_resource_id
  path_part   = "users"
}

resource "aws_api_gateway_method" "GET" {
  rest_api_id   = aws_api_gateway_rest_api.user_info_api.id
  resource_id   = aws_api_gateway_resource.users.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_resource" "users_userID" {
  rest_api_id = aws_api_gateway_rest_api.user_info_api.id
  parent_id   = aws_api_gateway_resource.users.id
  path_part   = "{userID}"
}

resource "aws_api_gateway_method" "getAllUsers" {
  rest_api_id   = aws_api_gateway_rest_api.user_info_api.id
  resource_id   = aws_api_gateway_resource.users_userID.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "user_get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.user_info_api.id
  resource_id             = aws_api_gateway_resource.users.id
  http_method             = aws_api_gateway_method.GET.http_method
  integration_http_method = "GET"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.user_get_operations.invoke_arn
}

resource "aws_api_gateway_integration" "user_get_integration2" {
  rest_api_id             = aws_api_gateway_rest_api.user_info_api.id
  resource_id             = aws_api_gateway_resource.users_userID.id
  http_method             = aws_api_gateway_method.getAllUsers.http_method
  integration_http_method = "GET"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.user_get_operations.invoke_arn
}

data "archive_file" "user_zip" {
  type        = "zip"
  source_dir  = "${path.module}/user"
  output_path = "${path.module}/user/user.zip"
  depends_on = [ "null_resource.build_zip2" ]
}

resource "null_resource" "build_zip2" {
  provisioner "local-exec" {
    command = "bash build.sh"
    working_dir = "${path.module}/user"
  }
}

resource "aws_s3_bucket_object" "user_zip" {
  bucket = "user-crud-operations-bucket"
  key    = "user.zip"
  source = "${path.module}/user/user.zip"
  etag   = filemd5("${path.module}/user/user.zip")
}

resource "aws_lambda_function" "user_crud_operations" {
  function_name = "user_crud_operations"
  role          = aws_iam_role.user_operations_role.arn
  runtime       = "go1.x"
  handler       = "main"
  timeout       = 1
  memory_size   = 512
  source_code_hash = data.archive_file.user_zip.output_base64sha256

  # Specify the S3 bucket and object key
  s3_bucket = "user-crud-operations-bucket"
  s3_key    = "user.zip"

  depends_on    = [aws_iam_role_policy_attachment.user_operations_role_attachement1,aws_iam_role_policy_attachment.user_operations_role_attachement2]
  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.user_contacts.name
    }
  }
}


resource "aws_api_gateway_resource" "user" {
  rest_api_id = aws_api_gateway_rest_api.user_info_api.id
  parent_id   = aws_api_gateway_rest_api.user_info_api.root_resource_id
  path_part   = "user"
}

resource "aws_api_gateway_method" "POST" {
  rest_api_id   = aws_api_gateway_rest_api.user_info_api.id
  resource_id   = aws_api_gateway_resource.user.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_resource" "user_userID" {
  rest_api_id = aws_api_gateway_rest_api.user_info_api.id
  parent_id   = aws_api_gateway_resource.user.id
  path_part   = "{userID}"
}

resource "aws_api_gateway_method" "PATCH" {
  rest_api_id   = aws_api_gateway_rest_api.user_info_api.id
  resource_id   = aws_api_gateway_resource.user_userID.id
  http_method   = "PATCH"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "DELETE" {
  rest_api_id   = aws_api_gateway_rest_api.user_info_api.id
  resource_id   = aws_api_gateway_resource.user_userID.id
  http_method   = "DELETE"
  authorization = "NONE"
}

resource "aws_lambda_permission" "user_crud_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.user_crud_operations.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.user_info_api.execution_arn}/*/*"
}

resource "aws_api_gateway_integration" "user_crud_integration1" {
  rest_api_id             = aws_api_gateway_rest_api.user_info_api.id
  resource_id             = aws_api_gateway_resource.user.id
  http_method             = aws_api_gateway_method.POST.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.user_crud_operations.invoke_arn
}

resource "aws_api_gateway_integration" "user_crud_integration2" {
  rest_api_id             = aws_api_gateway_rest_api.user_info_api.id
  resource_id             = aws_api_gateway_resource.user_userID.id
  http_method             = aws_api_gateway_method.PATCH.http_method
  integration_http_method = "PATCH"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.user_crud_operations.invoke_arn
}

resource "aws_api_gateway_integration" "user_crud_integration3" {
  rest_api_id             = aws_api_gateway_rest_api.user_info_api.id
  resource_id             = aws_api_gateway_resource.user_userID.id
  http_method             = aws_api_gateway_method.DELETE.http_method
  integration_http_method = "DELETE"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.user_crud_operations.invoke_arn
}

resource "aws_api_gateway_deployment" "user_get_ops_deployment" {
  depends_on      = [aws_api_gateway_integration.user_get_integration]
  rest_api_id     = aws_api_gateway_rest_api.user_info_api.id
  stage_name      = "dev"
}

resource "aws_api_gateway_stage" "dev" {
  rest_api_id = aws_api_gateway_rest_api.user_info_api.id
  stage_name  = "dev"
  deployment_id   = aws_api_gateway_deployment.user_get_ops_deployment.id
}

output "api_gateway_url" {
  value = aws_api_gateway_deployment.user_get_ops_deployment.invoke_url
}

