import boto3, json, os
from botocore.exceptions import ClientError

credentials_path = os.getenv('S3_CREDENTIALS_PATH', '../seaweedfs/s3-config.json')
credentials = json.load(open(credentials_path))\
                .get('identities', [None])[0]\
                .get('credentials', [None])[0]
bucket_names = ['paimon-data', 'flink-checkpoints']
endpoint = os.getenv('S3_ENDPOINT', 'http://localhost:9095')

client = boto3.client(
    's3',
    endpoint_url=endpoint,
    aws_access_key_id=credentials.get('accessKey', ''),
    aws_secret_access_key=credentials.get('secretKey', ''),
    region_name='us-east-1',
    config=boto3.session.Config(s3={'addressing_style': 'path'}),
    verify=False
)

def bucket_exists(bucket):
    try:
        client.head_bucket(Bucket=bucket)
        return True
    except ClientError:
        return False
    
for bucket_name in bucket_names:
    if bucket_exists(bucket_name):
        print(f"Bucket '{bucket_name}' already exists")
    else:
        print(f"Creating bucket '{bucket_name}'...")
        try:
            client.create_bucket(Bucket=bucket_name)
            print(f"Bucket '{bucket_name}' created")
        except ClientError as e:
            print(f"Failed to create bucket: {e}")
            exit(1)

    if bucket_exists(bucket_name):
        print(f"Verification passed: Bucket '{bucket_name}' is ready")
    else:
        print(f"Verification failed: Bucket '{bucket_name}' not accessible")
        exit(1)