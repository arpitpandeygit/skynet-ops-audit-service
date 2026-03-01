const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand, QueryCommand, ScanCommand } = require("@aws-sdk/lib-dynamodb");

const config = require("../config");

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const TABLE = process.env.DYNAMODB_TABLE;

async function insert(event) {
  await docClient.send(
    new PutCommand({
      TableName: TABLE,
      Item: event
    })
  );
}

async function query({ tenantId, severity, type, limit, offset }) {
  if (tenantId) {
    const result = await docClient.send(
      new QueryCommand({
        TableName: TABLE,
        IndexName: "tenantId-index",
        KeyConditionExpression: "tenantId = :t",
        ExpressionAttributeValues: {
          ":t": tenantId
        },
        ScanIndexForward: false,
        Limit: limit
      })
    );

    return {
      items: result.Items,
      total: result.Count
    };
  }

  const result = await docClient.send(
    new ScanCommand({
      TableName: TABLE,
      Limit: limit
    })
  );

  return {
    items: result.Items,
    total: result.Count
  };
}

module.exports = { insert, query };