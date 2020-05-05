# Workshop for Genomics HPC workflow using Nextflow on AWS Batch

This workshop assumes that you run in the AWS **Oregon** Region (us-west-2)

## Workshop setup
* Login to the Event Engine
    * https://dashboard.eventengine.run/dashboard

* Start the Cloud9 IDE and login. It is assumed that all the commands are executed within Cloud9.
    * https://www.hpcworkshops.com/02-aws-getting-started/05-start_cloud9.html

* Download the workshop example code:

    * `git clone https://github.com/aws-samples/aws-parallelcluster-price-performance.git`
    * `cd aws-parallelcluster-price-performance/aws-batch-nextflow-genomics-ws`

* Create an S3 Bucket:
    * `BUCKET_POSTFIX=$(uuidgen --random | cut -d'-' -f1)`
    * `aws s3 mb s3://batch-workshop-${BUCKET_POSTFIX}`
    * Take note of the bucket name you have just created

## Prepare the Docker image

* Create the docker image
    * `docker build --tag nextflow:latest .`

* Create an ECR repository
    * `aws ecr create-repository --repository-name nextflow-${BUCKET_POSTFIX}`
    * `ECR_REPOSITORY_URI=$(aws ecr describe-repositories --repository-names nextflow-${BUCKET_POSTFIX} --output text --query 'repositories[0].[repositoryUri]')`

* Push the docker image to the repository:
    * Get login credentials: `aws ecr get-login --no-include-email --region us-east-2`
    * Copy and paste the result from previous command to login
    * `docker tag nextflow:latest $ECR_REPOSITORY_URI`
    * `docker push $ECR_REPOSITORY_URI`
    * Run the following command to get the image details:
    `aws ecr describe-images --repository-name nextflow-${BUCKET_POSTFIX}`
    * You will need the following information to construct and use the image URI at a later stage
    	* registryId
    	* repositoryName
    	* imageTags
    * The image URI can be constructed using the format `<registryId>.dkr.ecr.<region>.amazonaws.com/<repositoryName>:<imageTag>`


## Configure IAM Policies & Roles

To allow AWS Batch to access the EC2 resources, we need to: 

* Create 3 new Policies:
	* **bucket-access-policy** to allow Batch to access the S3 bucket
	* **ebs-autoscale-policy** to allow the EC2 instance to autoscale the EBS
	* Nextflow needs to be able to create and submit Batch Job Defintions and Batch Jobs, and read workflow logs and session information from an S3 bucket. These permissions are provided via a Job Role associated with the Job Definition. Policies for this role would look like the following:
	* **nextflow-batch-access-policy** to allow Batch jobs to submit other Batch jobs

* and add 3 new Roles:
	* AWSBatchServiceRole
	* ecsInstanceRole
	* BatchJobRole
	
## Access Policies
### Bucket Access Policy

* To configure a new policy
	* In the IAM console, choose **Policies**, **Create policy**
	* Select Service -> S3
	* Select **All Actions**
	* Under **Resources** select **accesspoint** > Any
	* Under **Resources** select **job** > Any	
	* Under **Resources** > bucket, click **Add ARN**
		* Type in the name of the bucket you previously created
		* Click **Add**
	* Under **Resources** > object, click **Add ARN**
		* For **Bucket Name** type in the name of the bucket
		* Click **Object Name**, select **Any**
	* Click Review Policy
	* In the Review Policy Page, enter **bucket-access-policy** in the name field, and click Create Policy.

### EBS Autoscale Policy

* Go to the IAM Console
* Click on **Policies**
* Click on **Create Policy**
* Switch to the **JSON** tab
* Paste the following into the editor:
```json
{
    "Version": "2012-10-17",
    "Statement": {
        "Action": [
            "ec2:*Volume",
            "ec2:modifyInstanceAttribute",
            "ec2:describeVolumes"
        ],
        "Resource": "*",
        "Effect": "Allow"
    }
}
```
* Click **Review Policy**
* Name the policy **ebs-autoscale-policy**
* Click **Create Policy**

### Nextflow Batch Job Submission Policy:

* Go to the IAM Console
* Click on **Policies**
* Click on **Create Policy**
* Switch to the **JSON** tab
* Paste the following into the editor:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "batch:DeregisterJobDefinition",
                "batch:SubmitJob",
                "batch:RegisterJobDefinition"
            ],
            "Resource": [
                "arn:aws:batch:*:*:job-definition/nf-*:*",
                "arn:aws:batch:*:*:job-definition/nf-*",
                "arn:aws:batch:*:*:job-queue/*"
            ]
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "batch:DescribeJobQueues",
                "batch:TerminateJob",
                "batch:CreateJobQueue",
                "batch:DescribeJobs",
                "batch:CancelJob",
                "batch:DescribeJobDefinitions",
                "batch:DeleteJobQueue",
                "batch:ListJobs",
                "batch:UpdateJobQueue"
            ],
            "Resource": "*"
        }
    ]
}
```
* Click **Review Policy**
* Name the policy **nextflow-batch-access-policy**
* Click **Create Policy**

## IAM Roles
### Create a Batch Service Role

* In the IAM console, choose **Roles**, **Create New Role**.
* Under type of trusted entity, choose **AWS service** then **Batch**.
* Click **Next: Permissions**.
* On the Attach Policy page, the **AWSBatchServiceRole** will already be attached
* Click Next:Tags (adding tags is optional)
* Click **Next: Review**
* Set the Role Name to **AWSBatchServiceRole**, and choose Create Role.

### Create an EC2 Instance Role

This is a role that controls what AWS Resources EC2 instances launched by AWS Batch have access to. In this case, you will limit S3 access to just the bucket you created earlier.

* Go to the IAM Console
* Click on **Roles**
* Click on **Create Role**
* Select **AWS service** as the trusted entity
* Choose **EC2** from the larger services list
* Choose **EC2 - Allows EC2 instances to call AWS services on your behalf** as the use case.
* Click **Next: Permissions**
* Type **ContainerService** in the search field for policies
* Click the checkbox next to **AmazonEC2ContainerServiceforEC2Role** to attach the policy
* Type **S3** in the search field for policies
* Click the checkbox next to **AmazonS3ReadOnlyAccess** to attach the policy


**Note** :
Enabling Read-Only access to all S3 resources is required if you use publicly available datasets such as the [1000 Genomes dataset](https://registry.opendata.aws/1000-genomes/), and others, available in the [AWS Registry of Open Datasets](https://registry.opendata.aws/).


* Type **bucket-access-policy** in the search field for policies
* Click the checkbox next to **bucket-access-policy** to attach the policy
* Type **ebs-autoscale-policy** in the search field for policies
* Click the checkbox next to **ebs-autoscale-policy** to attach the policy
* Click **Next: Tags**. (adding tags is optional)
* Click **Next: Review**
* Set the Role Name to **ecsInstanceRole**
* Click **Create role**

### Create a Job Role

This is a role used by individual Batch Jobs to specify permissions to AWS resources in addition to permissions allowed by the Instance Role above.

* Go to the IAM Console
* Click on **Roles**
* Click on **Create role**
* Select **AWS service** as the trusted entity
* Choose **Elastic Container Service** from the larger services list
* Choose **Elastic Container Service Task** as the use case.
* Click **Next: Permissions**

* Attach the following policies.
	* **bucket-access-policy**
	* **AmazonS3ReadOnlyAccess**
	* **nextflow-batch-access-policy**

* Click **Next: Tags**. (adding tags is optional)
* Click **Next: Review**
* Set the Role Name to **BatchJobRole**
* Click **Create Role**

## Create an EC2 Launch Template 

Genomics is a data-heavy workload and requires some modification to the defaults used by AWS Batch for job processing. To efficiently use resources, AWS Batch places multiple jobs on an worker instance. The data requirements for individual jobs can range from a few MB to 100s of GB. Instances running workflow jobs will not know beforehand how much space is required, and need scalable storage to meet unpredictable runtime demands.

To handle this use case, we can use a process that monitors a scratch directory on an instance and expands free space as needed based on capacity thresholds. This can be done using logical volume management and attaching EBS volumes as needed to the instances. 

The ***EBS Autoscaling*** process requires a few small dependencies and a simple daemon installed on the host instance.

By default, AWS Batch uses the Amazon ECS-Optimized AMI to launch instances for running jobs. This is sufficient in most cases, but specialized needs, such as the large storage requirements noted above, require customization of the base AMI. Because the provisioning requirements for EBS autoscaling are fairly simple and light weight, one can use an EC2 Launch Template to customize instances.

We will create a launch template using the Cloudformation template provided in the repo. To execute the CloudFormation template, copy the template YAML file to your S3 bucket:

* Replace with the S3 bucket name you have created before
* `aws s3 cp genomics-launch-template.yaml s3://<bucket>/genomics-launch-template.yaml`
* Go to CloudFormation console.
* Click on **Create Stack** > **With new resources (standard)**
* In **Amazon S3 URL** text box, provide the S3 bucket url plus the name of the yaml file in the format `https://s3.<region-name>.amazonaws.com/<bucketname>/genomics-launch-template.yaml`
* Click **Next**
* Provide a stack name
* Under **Workflow Orchestrator** select nextflow
* Click **Next** & **Next**
* Click **Create Stack**

## Create an AWS Batch Environment
[AWS Batch](https://aws.amazon.com/batch/) is a managed service that helps you efficiently run batch computing workloads on the AWS Cloud. Users submit jobs to job queues, specifying the application to be run and the compute resources (CPU and memory) required by the job. AWS Batch is responsible for launching the appropriate quantity and types of instances needed to run your jobs.

AWS Batch manages the following resources:

* Job Definitions
* Job Queues
* Compute Environments

At the end of this exercise, you will have an AWS Batch environment consisting of the following:

* A Compute Environment that utilizes EC2 Spot instances for cost-effective computing
* A Compute Environment that utilizes EC2 on-demand (e.g. public pricing) instances for high-priority work that can't risk job interruptions or delays due to insufficient Spot capacity.
* A default Job Queue that utilizes the Spot compute environment first, but falls back to the on-demand compute environment if there is spare capacity available.
* A high-priority Job Queue that leverages the on-demand and Spot CE's (in that order) and has higher priority than the default queue.

### Setting up the Compute Environment
[Compute environments](http://docs.aws.amazon.com/batch/latest/userguide/compute_environments.html) are effectively autoscaling clusters of EC2 instances that are launched to run your jobs. Unlike traditional HPC clusters, compute environments can be configured to use a variety of instance types and sizes. The AWS Batch job scheduler will do the heavy lifting of placing jobs on the most appropriate instance type based on the jobs resource requirements. Compute environments can also use either On-demand instances, or Spot instances for maximum cost savings. Job queues are mapped to one or more compute environments and a given environment can also be mapped to one or more job queues. This many-to-many relationship is defined by the compute environment order and job queue priority properties.

As mentioned earlier, we'll create the following compute environments:

* An "optimal" compute environment using on-demand instances
* An "optimal" compute environment using spot instances

To create a compute environment we will follow these steps:

#### Create an "optimal" on-demand compute environment

* Go to the AWS Batch Console
* Click on **Compute environments**
* Click on **Create environment**
* Select **Managed** as the **Compute environment type**
* For **Compute environment name** type: **ondemand**
* In the **Service role** drop down, select the **AWSBatchServiceRole** you created previously
* In the **Instance role** drop down, select the **ecsInstanceRole** you created previously
* For **Provisioning model** select **On-Demand**
* **Allowed instance types** will be already populated with **optimal** - which is a mixture of M4, C4, and R4 instances.
* In the **Launch template** drop down, select the genomics-workflow-template you created previously
* Set Minimum and Desired vCPUs to 0.
* Optional: (Recommended) Add EC2 tags. These will help identify which EC2 instances were launched by AWS Batch. At minimum:
	* Key: **Name**
    * Value: **batch-ondemand-worker**
* Click on "Create"

#### Create an "optimal" spot compute environment

* Go to the AWS Batch Console
* Click on **Compute environments**
* Click on **Create environment**
* Select **Managed** as the **Compute environment type**
* For **Compute environment name** type: **spot**
* In the **Service role** drop down, select the **AWSBatchServiceRole** you created previously
* In the **Instance role** drop down, select the **ecsInstanceRole** you created previously
* For **Provisioning model** select **Spot**
* In **Maximum Price** text box, type 100
* **Allowed instance types** will be already populated with **optimal** - which is a mixture of M4, C4, and R4 instances.
* In the **Launch template** drop down, select the genomics-workflow-template you created previously
* Set Minimum and Desired vCPUs to 0.

* Optional: (Recommended) Add EC2 tags. These will help identify which EC2 instances were launched by AWS Batch. At minimum:
	* Key: **Name**
	* Value: **batch-spot-worker**

Click on "Create"

### Setup Job Queues

AWS Batch job queues, are where you submit and monitor the status of jobs.

Job queues can be associated with one or more compute environments in a preferred order. Multiple job queues can be associated with the same compute environment. Thus to handle scheduling, job queues also have a priority weight as well.

Below we'll create two job queues:

* A **Default** job queue
* A **High Priority** job queue

#### Create a Default Job Queue

This queue is intended for jobs that do not require urgent completion, and can handle potential interruption. This queue will schedule jobs to:

* The **spot** compute environment
* The **ondemand** compute environment in that order.

Because it primarily leverages Spot instances, it will also be the most cost effective job queue.

* Go to the AWS Batch Console
* Click on **Job queues**
* Click on **Create queue**
* For **Queue name** use **default**
* Set **Priority** to 1
* Under **Connected compute environments for this queue**, using the drop down menu:
	* Select the **spot** compute environment you created previously, then
    * Select the **ondemand** compute environment you created previously
* Click on **Create Job Queue**

#### Create a "High_Priority" Job Queue

This queue is intended for jobs that are urgent and cannot handle potential interruption. This queue will schedule jobs to:

* The **ondemand** compute environment
* The **spot** compute environment in that order.

* Go to the AWS Batch Console
* Click on **Job queues**
* Click on **Create queue**
* For **Queue name** use **highpriority**
* Set **Priority** to 100 (higher values mean higher priority)
* Under **Connected compute environments for this queue**, using the drop down menu:
* Select the **ondemand** compute environment you created previously, then
* Select the **spot** compute environment you created previously
* Click on **Create Job Queue**

### Setup a Job Definition

* Go to the AWS Batch Console
* Click on **Job definitions**
* Click on **Create**
* In **Job definition name** enter **nextflow**
* In **Job attempts** enter 5
* In Environment -> Job Role, select **BatchJobRole**
* In Container Image text box, enter the URI of the image you created earlier. If you don't have the ARN, you can obtain it by following these steps:
    * Run the following command to get the image details:
    `aws ecr describe-images --repository-name nextflow`
    * You will need the following information to construct and use the image URI at a later stage
    	* registryId
    	* repositoryName
    	* imageTags
    * The image URI can be constructed using the format `<registryId>.dkr.ecr.<region>.amazonaws.com/<repositoryName>:<imageTag>`
* Enter 2 vCPU
* Enter 1024 MB
* In Environment variables, enter the following:
	* Key: NF_LOGSDIR, Value: `s3://<bucket>/_nextflow/logs`
	* Key: NF_JOB_QUEUE, Value: `<Default job Queue ARN>`
	* Key: NF_WORKDIR, Value: `s3://<bucket>/_nextflow/runs`
* Click on **Create Job Definition**

## Describe Your Environment

Now that you have configured your batch environment, run the following commands to take a look at what we have created so far:

* `aws batch describe-compute-environments`
* `aws batch describe-job-queues`
* `aws batch describe-job-definitions`

## Run your jobs

To run a workflow you submit a nextflow Batch job to the appropriate Batch Job Queue via:

* the AWS Batch Console
* or the command line with the AWS CLI

This is what starting a workflow via the AWS CLI would look like using Nextflow's built-in **hello-world** workflow:

`aws batch submit-job --job-name nf-hello --job-queue <queue-name> --job-definition nextflow --container-overrides command=hello`

After submitting a workflow, you can monitor the progress of tasks via the AWS Batch console. For the **Hello World** workflow above you will see five jobs run in Batch - one for the head node, and one for each Channel text as it goes through the hello process.

For a more complex example, you can try the following, which will run the RNASeq workflow developed by the [NF-Core project](https://nf-co.re/) against data in the [1000 Genomes AWS Public Dataset](https://registry.opendata.aws/1000-genomes/):

`aws batch submit-job --job-name nf-core-rnaseq --job-queue <queue-name> --job-definition nextflow --container-overrides command=nf-core/rnaseq,"--reads","'s3://1000genomes/phase3/data/HG00243/sequence_read/SRR*_{1,2}.filt.fastq.gz'","--genome","GRCh37","--skip_qc"`

For the nf-core example "rnaseq" workflow you will see 11 jobs run in Batch over the course of a couple hours - the head node will last the whole duration of the pipeline while the others will stop once their step is complete. You can look at the CloudWatch logs for the head node job to monitor workflow progress. Note the additional single quotes wrapping the 1000genomes path.
