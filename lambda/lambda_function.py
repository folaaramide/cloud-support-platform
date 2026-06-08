import json
import boto3
import uuid

s3 = boto3.client("s3")
sns = boto3.client("sns")

BUCKET_NAME = "afolabi-cloud-support-incidents-2026"

def lambda_handler(event, context):

    body = json.loads(event["body"])

    incident_id = str(uuid.uuid4())

    s3.put_object(
        Bucket=BUCKET_NAME,
        Key=f"incidents/{incident_id}.json",
        Body=json.dumps(body)
    )

    response = sns.publish(
        TopicArn="arn:aws:sns:eu-west-2:920572019844:incident-alerts",
        Subject="New Incident Submitted",
        Message=f"""
    Service: {body['service']}
    Severity: {body['severity']}
    Description: {body['description']}
    """
    )

    print(response)

    print(f"Incident stored: {incident_id}")

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Incident Received",
            "incident_id": incident_id
        })
    }