package main

import (
	"context"
	"encoding/json"
	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/dynamodb"
	// "github.com/go-swagger/go-swagger/cmd/swagger"
	// "github.com/aws/aws-sdk-go/service/dynamodb/dynamodbattribute"
)

var tableName = aws.String("user_contacts")

func getDB() *dynamodb.DynamoDB {
	sess, err := session.NewSession()
	if err != nil {
		panic("could not create aws session")
	}

	dynamoDBClient := dynamodb.New(sess)
	return dynamoDBClient
}

type User struct {
	UserID       string `json:"userID"`
	FirstName    string `json:"firstName"`
	LastName     string `json:"lastName"`
	Address      string `json:"address"`
	MobileNumber string `json:"mobileNumber"`
	EmailAddress string `json:"emailAddress"`
}

// CreateContactHandler creates a new contact
func CreateContactHandler(request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	db := getDB()

	// Parse the request body into the Item struct
	item := User{}

	// Check if the request body is empty
	if request.Body == "" {
		return events.APIGatewayProxyResponse{
			StatusCode: 400,
			Body:       `{"error": "Request body is empty"}`,
		}, nil
	}
	// Parse the request body into the Item struct
	err := json.Unmarshal([]byte(request.Body), &item)

	if err != nil {
		return events.APIGatewayProxyResponse{
			StatusCode: 400,
			Body:       `{"error": "` + err.Error() + `"}`,
			}, nil
	}

	// Create the DynamoDB PutItem input
	input := &dynamodb.PutItemInput{
		TableName: aws.String("user_contacts"), // Replace with your actual table name
		Item: map[string]*dynamodb.AttributeValue{
			"userID": {
				S: aws.String(item.UserID),
			},
			"firstName": {
				S: aws.String(item.FirstName),
			},
			"lastName": {
				S: aws.String(item.LastName),
			},
			"address": {
				S: aws.String(item.Address),
			},
			"mobileNumber": {
				S: aws.String(item.MobileNumber),
			},
			"emailAddress": {
				S: aws.String(item.EmailAddress),
			},
		},
	}

	// Insert the item into DynamoDB
	_, err = db.PutItem(input)
	if err != nil {
		return events.APIGatewayProxyResponse{
			StatusCode: 500,
			Body:       "Failed to insert item into DynamoDB",
		}, err
	}

	return events.APIGatewayProxyResponse{
		StatusCode: 200,
		Body:       "Item inserted successfully",
	}, nil
}

// UpdateContactHandler updates contact information by ID
func UpdateContactHandler(request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error)  {
	db := getDB()
	user := User{}
	var userID string

	err := json.Unmarshal([]byte(request.Body), &user)
	if err != nil {
		return events.APIGatewayProxyResponse{
			StatusCode: 400,
			Body:       "Invalid request body",
			}, nil
	}
	if request.PathParameters !=nil {
		userID = request.PathParameters["userID"]
	}


	// Update the item in DynamoDB
	input := &dynamodb.UpdateItemInput{
		TableName: aws.String("user_contacts"),
		Key: map[string]*dynamodb.AttributeValue{
			"userID": {
				S: aws.String(userID),
			},
		},
		ExpressionAttributeValues: map[string]*dynamodb.AttributeValue{
			":firstName": {
				S: aws.String(user.FirstName),
			},
			":lastName": {
				S: aws.String(user.LastName),
			},
		},
		UpdateExpression: aws.String("SET firstName = :firstName, lastName = :lastName"),
		ReturnValues:     aws.String("ALL_NEW"),
	}

	_, err = db.UpdateItem(input)
	if err != nil {
		return events.APIGatewayProxyResponse{StatusCode: 500}, err
	}

	// Return a successful response
	return events.APIGatewayProxyResponse{
		StatusCode: 200,
		Body:       "Item updated successfully!",
	}, nil
}

// DeleteContactHandler deletes contact information by ID
func DeleteContactHandler(request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error){
	db := getDB()
	var userID string
	var firstName string
	var lastName string

	if request.PathParameters == nil && request.QueryStringParameters == nil {
		return events.APIGatewayProxyResponse{
			StatusCode: 400,
			Body:       "Bad request",
		}, nil 
	}

	if request.PathParameters !=nil {
		userID = request.PathParameters["userID"]
	}

	// Build the delete input parameters
	input := &dynamodb.DeleteItemInput{
		TableName: aws.String("user_contacts"), // DynamoDB table name
		Key: map[string]*dynamodb.AttributeValue{
			"userID": {
				S: aws.String(userID),
			},
		},
	}

	if request.QueryStringParameters !=nil {
		firstName = request.QueryStringParameters["firstName"]
		lastName = request.QueryStringParameters["lastName"]
	}

	// If firstName or lastName is provided, add a condition expression for deletion
	if firstName != "" || lastName != "" {
		// Build the condition expression
		conditionExpr := ""
		attributeValues := map[string]*dynamodb.AttributeValue{}
		if firstName != "" {
			conditionExpr += "firstName = :firstName"
			attributeValues[":firstName"] = &dynamodb.AttributeValue{
				S: aws.String(firstName),
			}
		}
		if lastName != "" {
			if firstName != "" {
				conditionExpr += " AND "
			}
			conditionExpr += "lastName = :lastName"
			attributeValues[":lastName"] = &dynamodb.AttributeValue{
				S: aws.String(lastName),
			}
		}

		// Add the condition expression and attribute values to the delete input parameters
		input.ConditionExpression = aws.String(conditionExpr)
		input.ExpressionAttributeValues = attributeValues
	}

	_, err := db.DeleteItem(input)
	if err != nil {
		return events.APIGatewayProxyResponse{
			StatusCode: 500,
			Body:       "error while deleting user",
		}, nil
	}

	// Return a success response
	return events.APIGatewayProxyResponse{
		StatusCode: 200,
		Body:       "User deleted successfully",
	}, nil

}

func Differentiate(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	if request.QueryStringParameters == nil && request.PathParameters == nil {
		responseData,err:= CreateContactHandler(request)
		return responseData,err
	}

	if request.PathParameters["userID"] != "" && request.Body != ""{
		responseData,err:= UpdateContactHandler(request)
		return responseData,err
	}

	if request.PathParameters["userID"] != "" && request.QueryStringParameters == nil || request.QueryStringParameters !=nil {
		responseData,err:= DeleteContactHandler(request)
		return responseData,err
	}

	return events.APIGatewayProxyResponse{
		StatusCode: 200,
		Body:      "Ok!",
	}, nil
}

func main() {
	lambda.Start(Differentiate)
}
