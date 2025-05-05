import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql.functions import *

# Initialize Glue context
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)

# Get job parameters
args = getResolvedOptions(sys.argv, [
    'JOB_NAME',
    'RAW_BUCKET',
    'CURATED_BUCKET',
    'REDSHIFT_DATABASE',
    'REDSHIFT_TABLE'
])

job.init(args['JOB_NAME'], args)

# Read raw data from S3
raw_data = glueContext.create_dynamic_frame.from_options(
    connection_type="s3",
    connection_options={
        "paths": [f"s3://{args['RAW_BUCKET']}/raw/"],
        "recurse": True
    },
    format="json"
)

# Convert to Spark DataFrame for transformations
df = raw_data.toDF()

# Perform transformations
transformed_df = df.select(
    # Add your specific transformations here
    # Example:
    col("timestamp"),
    col("user_id"),
    col("event_type"),
    col("data")
)

# Write to curated S3 zone
curated_dynamic_frame = DynamicFrame.fromDF(transformed_df, glueContext, "curated")
glueContext.write_dynamic_frame.from_options(
    frame=curated_dynamic_frame,
    connection_type="s3",
    connection_options={
        "path": f"s3://{args['CURATED_BUCKET']}/curated/",
        "partitionKeys": ["year", "month", "day"]
    },
    format="parquet"
)

# Write to Redshift
glueContext.write_dynamic_frame.from_options(
    frame=curated_dynamic_frame,
    connection_type="redshift",
    connection_options={
        "url": f"jdbc:redshift://{args['REDSHIFT_DATABASE']}.redshift.amazonaws.com:5439/{args['REDSHIFT_DATABASE']}",
        "dbtable": args['REDSHIFT_TABLE'],
        "user": "admin",
        "password": "{{resolve:secretsmanager:redshift-password:SecretString:password}}",
        "redshiftTmpDir": f"s3://{args['CURATED_BUCKET']}/temp/"
    }
)

job.commit() 