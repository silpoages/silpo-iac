"""Generates architecture.png from the actual resources provisioned in
terraform/modules + terragrunt/live/shared. Kept in sync by hand — update this
alongside any change to what's actually deployed.
"""

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import ECR, ECS
from diagrams.aws.database import RDSPostgresqlInstance
from diagrams.aws.general import Users
from diagrams.aws.network import ELB, CloudFront
from diagrams.aws.security import SecretsManager
from diagrams.aws.storage import S3

graph_attr = {
    "fontsize": "14",
    "bgcolor": "white",
    "pad": "0.3",
}

with Diagram(
    "Silpo - AWS Deployment (us-east-1)",
    filename="architecture",
    outformat="png",
    show=False,
    direction="LR",
    graph_attr=graph_attr,
):
    users = Users("Users")

    with Cluster("VPC (silpo-shared)"):
        with Cluster("Public Subnet"):
            alb = ELB("ALB")
            api = ECS("silpo-backend\n(Fargate)")
            alb >> api

        with Cluster("Private Subnet"):
            db = RDSPostgresqlInstance("RDS Postgres")

        api >> Edge(label="5432") >> db

    with Cluster("Supporting services"):
        ecr = ECR("ECR\nsilpo-backend")
        secrets = SecretsManager("Secrets Manager\n(JWT, DB, Resend)")

    ecr >> Edge(style="dashed", label="image") >> api
    secrets >> Edge(style="dashed", label="env vars") >> api

    with Cluster("silpo-web"):
        cdn = CloudFront("CloudFront")
        web = S3("S3 bucket")
        cdn >> web

    users >> Edge(label="HTTPS") >> alb
    users >> Edge(label="HTTPS") >> cdn
