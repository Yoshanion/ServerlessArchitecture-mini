import json
import boto3
import logging
from boto3.dynamodb.conditions import Key # type: ignore

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource('dynamodb')


def lambda_handler(event, context):
    table = dynamodb.Table('BasicTable')
    http_method = event['httpMethod']
    try :
        if http_method == 'GET':
            # Read item
            item_id = event['queryStringParameters']['id']
            response = table.get_item(Key={'id': item_id})
            item = response.get('Item', {})
            return {
                'statusCode': 200,
                'body': json.dumps(item)
            }

        elif http_method == 'POST':
            # Create item
            data = json.loads(event['body'])
            table.put_item(Item=data)
            return {
                'statusCode': 201,
                'body': json.dumps({'message': 'Item created'})
            }

        elif http_method == 'PUT':
            # Update item
            item_id = event['queryStringParameters']['id']
            data = json.loads(event['body'])
            table.update_item(
                Key={'id': item_id},
                UpdateExpression='SET info = :val',
                ExpressionAttributeValues={':val': data['info']}
            )
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'Item updated'})
            }

        elif http_method == 'DELETE':
            # Delete item
            item_id = event['queryStringParameters']['id']
            table.delete_item(Key={'id': item_id})
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'Item deleted'})
            }

        else:
            return {
                'statusCode': 400,
                'body': json.dumps({'message': 'Unsupported HTTP method'})
            }
   
    except Exception as e:
        logger.error("Error processing request: {}".format(str(e)))
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal server error'})
        }