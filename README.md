
# How to run your HPC workloads on AWS: a Quickstart

This repository complements the AWS white paper on how to achieve optimal price/performance for your HPC workloads. You can find it here: https://d1.awsstatic.com/HPC2019/Optimal-Price-Performance-for-HPC-Workloads-Aug2019.pdf

The white paper will guide you through the different decision points.

The goal of this repository is to help you to map the decisions you made before to a ParallelCluster configuration that you can use to run your jobs.

**AWS ParallelCluster** is an AWS-supported open source cluster management tool that helps you to deploy and manage High Performance Computing (HPC) clusters in the AWS cloud. Built on the open source CfnCluster project, AWS ParallelCluster enables you to quickly build an HPC compute environment in AWS. It automatically sets up the required compute resources and shared filesystem. You can use AWS ParallelCluster with a variety of batch schedulers, such as AWS Batch, SGE, Torque, and Slurm.

You can find more information here: https://github.com/aws/aws-parallelcluster

**Please remember** that there is no single configuration that can address all the different cases. Feel free to experiment different things until you find the best price/performance for your needs. 

## Key decision points
* What instance type do you want to use for your computing nodes?
* What type of storage?
    * do you need a Lustre file system for the scratch area? 
    * do you want to use NFS for your home directories?
* Hyperthreading on or off?


## Instructions
* Download this repository on your computer:
    * `$ git clone https://github.com/aws-samples/aws-parallelcluster-price-performance`
* Install ParallelCluster on your computer:
    * open your terminal (I recommend the [Windows Subsystem for Linux](https://docs.microsoft.com/en-us/windows/wsl/install-win10) for Microsoft users) and run the following commands to install ParallelCluster:
    * `$ sudo apt update`
    * `$ sudo apt install python-pip`
    * `$ sudo pip install awscli`
    * `$ aws configure` to configure the AWS CLI with your credentials
    * `$ sudo pip install aws-parallelcluster`
* Edit the ParallelCluster config file you have found in this repo:
    * `$ vi config.ini`
    * specify your ssh key name, VPN and subnet for your AWS account
    * uncomment the appropriate rows based on the decisions you have made before
* Now deploy your cluster with these commands:
    * `$ pcluster create -c config.ini mycluster`
* When the deployment is done:
    * connect to the head node: `$ pcluster ssh mycluster -i <your-ssh-key>`
    * install your code in the `\shared` dir (or in another path that is shared on all the computing nodes)
    * run your code using your preferred scheduler commands e.g: `$ qsub myjob.sh`

**Congratulations!** you have run your first HPC job on AWS :)




