import boto3
import os

def lambda_handler(event, context):
    eks = boto3.client('eks')
    cluster_name = os.environ['CLUSTER_NAME']

    try:
        print(f"Deleting EKS cluster: {cluster_name}")
        eks.delete_cluster(name=cluster_name)
        return {"status": "success", "message": f"Cluster {cluster_name} deleted"}
    except Exception as e:
        print(f"Error deleting cluster: {e}")
        return {"status": "error", "message": str(e)}

