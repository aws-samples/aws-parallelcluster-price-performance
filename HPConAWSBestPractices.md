# Best practices for HPC on AWS


**Abstract:** The goal of this document is to describe the best practices to run HPC workloads efficiently on AWS. This document provides prescriptive instructions that will help in the vast majority of real use-cases; customers can improve application performance in different ways for different use cases. The document focuses on workflows that run on the Linux operating system. Customers can apply some of these recommendations also to Windows workflows. Cost considerations are also explained.



# Plan your journey

The goal of an HPC infrastructure is to enable its users to complete more jobs faster.

If you are migrating from an on-premises HPC cluster, it&#39;s critical to collect the applications requirements with their utilization data. If you are using a job scheduler (e.g. SLURM or PBS), you can easily extract these information from the job scheduler&#39;s logs. If you don&#39;t know how to do it, please contact us: AWS Professional Service and AWS Partner Network can help you to accelerate your migration.

For every queue that you have defined on your scheduler, you may want to collect the following information:

| **Queue/Application Name** | **Avg Runtime** | **Avg Pending Time** | **Avg number of Cores per job** | **Memory Requirements (GB/core)** | **Frequency (number of jobs per month/year)** |
| ---      | --- | --- | --- | --- | --- |
| Openfoam |  27 | 1   | 64  | 5   | 127 |
| GROMACS  |  720 | 200   | 264  | 24   | 48 |
| etc...      | --- | --- | --- | --- | --- |


These data are useful to prioritize the different workloads, you can start migrating from the applications that are used most often or with the longest pending time.

## Choose the right Instance Type and AMI for your workload

Most HPC customers will find that the C instance type works best for their workloads. The **C family** is designed for CPU or compute intensive workloads. **C5** instances are powered by 3.0 GHz Intel Xeon Cascadelake processors and allow a single core to run up to 3.6 GHz using Intel Turbo Boost Technology. The C4 instance types are based on the Intel Xeon E5-2666 v3 processor, also known as Haswell. This processor, which is unique to AWS, has 36 vCPUs, which are Intel Hyperthreads (which equates to 18 physical Intel Xeon cores).

**C5n** instances can utilize up to 100 Gbps of network bandwidth. In addition, C5n instances also feature 33% higher memory footprint compared to C5 instances. C5n instances are ideal for applications that can take advantage of improved network throughput and packet rate performance.

The **M** family instances are the General Purpose Instances. This family provides a balance of compute, memory, and network resources, and it is a good choice for applications requiring more memory per compute core than available on the C instance type. The M5 instance type has up to 48 physical Xeon cores (96 vCPUs) and 384Gib of memory (a ratio of 8Gib of memory per physical core). Tightly coupled workloads that cannot cross the network (such as shared memory applications) may take advantage of the large number of cores on the M5 instance type.

The **R** family is designed for particularly memory intensive applications. R5 instances have a 1:8 vCPU to memory ratio, with the largest size offering up to 768 GiB of memory per instance, allowing applications to scale up on fewer instances. R5 instances feature the Intel Xeon Platinum 8000 series (Skylake-SP) processor with a sustained all core Turbo CPU clock speed of up to 3.1 GHz. The R4 type instances features high frequency Intel Zeon E5-2670 v2 (Ivy Bridge) Processors, SSD storage, and support for enhanced networking   and optimized for memory-intensive applications.

**P** and **G** family: these instances are equipped with Nvidia GPUs and must be used for graphic intensive or [CUDA](https://it.wikipedia.org/wiki/CUDA) applications.

**Z** instances deliver high single thread performance due to a custom Intel® Xeon® Scalable processor with a sustained all core frequency of up to 4.0 GHz, the fastest of any cloud instance. Z1d provides both high compute performance and high memory, which is ideal for electronic design automation (EDA) and all workloads with high per-core licensing costs. The Intel Turbo capability enables the processor to achieve a higher clock rate based on available power and thermal headroom.

With over 200 instances to choose from, finding the right instance type can be challenging. To make it easier to discover and compare EC2 Instance Types, you can use the “Instance Types” section of the EC2 Console. With this service, you have access to instance type specifications, supported features, Regional presence, pricing, and more.

You can find more information [here](https://aws.amazon.com/blogs/compute/it-just-got-easier-to-discover-and-compare-ec2-instance-types/).

Please note that, except for T instances, each vCPU is a hyperthread of an Intel Xeon CPU core. So, if you want to run your application without the hyperthreading, you can calculate the number of physical cores by dividing the number of vCPUs by two. For better performance, always select Hardware Virtualized Machine (HVM), not para-virtualized. It&#39;s important to pick a modern operating system (Linux kernel 3.10+) and update it. The latest version of **Amazon Linux** is optimized for maximum performance on AWS.

## Use Enhanced Networking/ENA

Enhanced Networking, also known as single Root I/O Virtualization (SR-IOV), provides higher I/O performance and lower CPU utilization when supporting network traffic.

Depending on your instance type, enhanced networking can be enabled using one of the following mechanisms:

- C3, C4, M4 (excluding m4.16xlarge), and R3 can use Intel 82599 Virtual Function ( **VF** ) interface. The VF interface supports network speeds of **up to 10 Gbps.**
- C5, F1, G3, m4.16xlarge, M5, P2, P3, R4, and X1 instances use the Elastic Network Adapter ( **ENA** ). ENA supports network speeds of **up to 25 Gbps.**

**Elastic Network Adapter** (ENA) is a custom network interface optimized to deliver high throughput and packet per second (PPS) performance.

To find out the full list of instance types that support 10 or 25 Gbps network speeds, see Amazon EC2 Instance Types ([https://aws.amazon.com/ec2/instance-types](https://aws.amazon.com/ec2/instance-types)).

The latest Amazon Linux HVM AMIs have the module required for enhanced networking with ENA or VF interface installed and have the required attributes set. Therefore, if you launch an instance with the latest Amazon Linux HVM AMI on a supported instance type, enhanced networking is already enabled for your instance.

If you are not using the standard Amazon Linux AMI, please follow this guide to configure your environment:

[http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/enhanced-networking.html](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/enhanced-networking.html)

If you want to test if Enhanced Networking is enabled on your instances, you can follow these guides:

- VF interface: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/sriov-networking.html#test-enhanced-networking
- ENA: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/enhanced-networking-ena.html#test-enhanced-networking-ena

## Use Elastic Fabric Adapter (EFA)

Elastic Fabric Adapter (EFA) is a network interface for Amazon EC2 instances that enables customers to run HPC applications requiring high levels of inter-instance communications, like computational fluid dynamics, weather modeling, and reservoir simulation, at scale on AWS. It uses a custom-built operating system bypass technique to enhance the performance of inter-instance communications, which is critical to scaling HPC applications. With EFA, HPC applications using popular HPC technologies like Message Passing Interface (MPI) can scale to thousands of CPU cores. EFA supports industry-standard libfabric APIs, so applications that use a supported MPI library can be migrated to AWS with little or no modification.

EFA is available as an optional EC2 networking feature that you can enable on all the instances powered by our 100 Gbps network (e.g: C5n.9xl, C5n.18xl, and P3dn.24xl).  You can learn how to configure EFA here:

[https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa.html](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa.html)

## Use Cluster Placement Groups

Tightly-coupled HPC applications often require a low-latency network connection between compute nodes for best performance. On AWS, this is achieved by launching compute nodes directly into a placement group. Placement groups cluster the compute nodes close to each other to achieve consistent latency. For maximum effect, launch all compute nodes into a placement group, all at once.

All instance types that support enhanced networking can be launched within a Cluster Placement Group.

Placement Groups allow for reliably low latency between instances and will help your tightly-coupled application to be elastically scalable as desired.

If you want to use EFA, it&#39;s mandatory to deploy all your computing nodes in the same Cluster Placement Group.

You can find more information here: [https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/placement-groups.html](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/placement-groups.html)

## Use the Intel Hardware Features

When compiling your applications code, don&#39;t forget to use the Intel Advanced Vector Extensions (AVX/AVX2).

C5, M5 and R5 instance types provide support for the new Intel Advanced Vector Extensions 512 (AVX-512) instruction set. An example compiler flag for accessing AVX-512 is &quot;-xCOMMON-AVX512&quot; but flags vary depending on the both the compiler and the version of the compiler.

## Disable Hyper-Threading

Amazon EC2 instances support Intel Hyper-Threading Technology, which enables multiple threads to run concurrently on a single Intel Xeon CPU core. Each thread is represented as a virtual CPU (vCPU) on the instance. An instance has a default number of CPU cores, which varies according to instance type. Except for T2 instances, each vCPU in AWS is a hyperthread of an Intel Xeon CPU core.

Most HPC platforms have Intel hyperthreading disabled by default. Unless an application has been thoroughly tested in the hyper-threaded (HT) environment, it&#39;s recommend to disable [hyper-threading](https://en.wikipedia.org/wiki/Hyper-threading).

You can disable Intel Hyper-Threading Technology by specifying a single thread per CPU core. Use the _run-instances_ AWS CLI command and specify a value of 1 for ThreadsPerCore for the _--cpu-options_ parameter. For CoreCount, specify the default CPU core count for the instance type (in this example, 8 for an r4.4xlarge instance):

* aws ec2 run-instances --image-id ami-1a2b3c4d --instance-type r4.4xlarge --cpu-options &quot;CoreCount=8,ThreadsPerCore= **1**&quot; --key-name MyKeyPair

Please refer to these web pages for additional info:

- Optimizing CPU Options: [https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-optimize-cpu.html](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-optimize-cpu.html)
- Blog post: How to disable HT on Linux: [https://aws.amazon.com/blogs/compute/disabling-intel-hyper-threading-technology-on-amazon-linux/](https://aws.amazon.com/blogs/compute/disabling-intel-hyper-threading-technology-on-amazon-linux/)
- Blog post: How to disable HT on Windows: [https://aws.amazon.com/blogs/compute/disabling-intel-hyper-threading-technology-on-amazon-ec2-windows-instances/](https://aws.amazon.com/blogs/compute/disabling-intel-hyper-threading-technology-on-amazon-ec2-windows-instances/)

## Use EBS Optimized Volumes

Amazon Elastic Block Store (EBS) provides persistent block storage for use with Amazon EC2 instances in the AWS Cloud. EBS optimized instances provide an additional network path to an instance that is entirely devoted to the network traffic between the EC2 instance and the EBS volume. Enabling EBS optimization minimizes contention for the network allowing better and more consistent application performance. It&#39;s enabled by default on C5, M5 and other instances.

More info: [http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EBSOptimized.html](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EBSOptimized.html)

## Choose the right storage

Amazon EBS provides a range of options that allow you to optimize storage performance and cost for your workload. These options are divided into two major categories:

- **SSD-backed storage** for transactional workloads, such as databases and boot volumes (performance depends primarily on IOPS), and
- **HDD-backed storage** for throughput intensive workloads, such as MapReduce and log processing (performance depends primarily on MB/s).

The EBS General Purpose SSD (gp2) volume is suitable for a variety of HPC workloads, particularly those that do not have a continuous I/O demand. I/O intensive applications may prefer to use Provisioned IOPS SSD (io1).

HHD (magnetic) volumes provide the lowest cost per gigabyte and are ideal for workloads where data is accessed infrequently. Throughput Optimized HDD (st1) provides low cost HDD volume designed for frequently accessed, throughput intensive workloads: if your application does only a few large reads and writes, st1 is a good candidate.

## Use real world data for your tests

AWS on-demand computing allows for low risk, low cost testing of applications. A real-world proof-of-concept always provides the best insight into application performance. However, while system-specific benchmarks offer an understanding of the underlying performance of a computing infrastructure, they frequently don&#39;t reflect how an application will perform in the aggregate. The foremost method to check an application&#39;s performance on AWS is to run a meaningful demonstration of the application itself using the same input file you use on your environment.

An inadvertently small or large demonstration case, one that does not match expected compute, memory, I/O data transfer or network traffic loads, will not provide a meaningful example of how an application runs on AWS.

# Cost Optimization

## Use Spot Instances

Spot Instances offer spare compute capacity available in the AWS cloud at a very low price. Spot instance prices are set by Amazon and adjust gradually based on long-term trends in demand for Spot instance capacity.

Spot instances are available at a discount of up to 90% off compared to On-Demand pricing.

When AWS needs the capacity back, Spot Instances can be interrupted with two minutes of notification.

So you should use Spot Instances **only for applications that can be interrupted and resumed**.

You can also use **Spot Block** for a predefined duration – in hourly increments up to six hours in length – at a discount of up to 30-50% compared to On-Demand pricing.

Spot provides a great option to run HPC workloads on AWS, but not all HPC workloads are suitable for Spot.  Spot instances are a good addition should you have low priority turnaround time requirements. For example, some customers use Spot Fleet for molecular dynamics/quantum simulations over the weekend when capacity is available for analysis of experiment data.

There are lot of best practices to keep your Spot interruption low while leveraging low cost Spot instances.

You can refer to: [https://docs.aws.amazon.com/aws-technical-content/latest/cost-optimization-leveraging-ec2-spot-instances/introduction.html](https://docs.aws.amazon.com/aws-technical-content/latest/cost-optimization-leveraging-ec2-spot-instances/introduction.html)

## Use the Monthly Calculator to plan your budget

You can use the AWS Simple Monthly Calculator to configure your cluster and estimate your costs: [https://calculator.s3.amazonaws.com/index.html](https://calculator.s3.amazonaws.com/index.html)

## Setup Budgets and billing alarm to avoid unexpected costs

Create a billing alarm to receive notification if you exceed your budget. Billing alarms can help to protect you against unknowingly accruing charges if your workload exceeds your expectations.

If you set the billing alarm, you&#39;ll receive an email as soon as your account&#39;s usage exceeds the limits. At that point, you can decide whether to terminate the AWS resources that have exceeded the budget, or keep them running and be billed at the standard AWS rates.

You can define your Budgets from the AWS Console: [https://console.aws.amazon.com/billing/home#/budgets](https://console.aws.amazon.com/billing/home#/budgets)

## Maximize throughput vs total cost

Cost optimization must take into account the throughput (number of completed jobs per month), not only the performance of a single job.

In an on-premises environment, the number of computing nodes defines the maximum number of concurrent jobs that you can run in your cluster. Therefore, in order to maximize the number of completed jobs in a month, it&#39;s mandatory to optimize the performance of every single job.

However, the AWS infrastructure can scale-up without limits: there is no need to keep the jobs waiting in the queue because users can start automatically additional computing nodes.

To achieve the operational excellence, you have to find the configuration that maximize the number of completed jobs per month, while minimizing the cost.

When running a variety of applications on AWS, find the cloud architecture that meets the demands of the application and mix-and-match instance types to support the different applications. AWS offers the opportunity to create &quot;grids of clusters&quot;. Each cluster is unique and runs a different job concurrently.

# Further reading

- HPC well architected lens:[https://d1.awsstatic.com/whitepapers/architecture/AWS-HPC-Lens.pdf](https://d1.awsstatic.com/whitepapers/architecture/AWS-HPC-Lens.pdf)
- HPC white paper: [https://d0.awsstatic.com/whitepapers/Intro\_to\_HPC\_on\_AWS.pdf](https://d0.awsstatic.com/whitepapers/Intro_to_HPC_on_AWS.pdf)
- Achieving optimal price/performance for your HPC workload: [https://d1.awsstatic.com/HPC2019/Optimal-Price-Performance-for-HPC-Workloads-Aug2019.pdf](https://d1.awsstatic.com/HPC2019/Optimal-Price-Performance-for-HPC-Workloads-Aug2019.pdf)
- AWS HPC web site: [aws.amazon.com/hpc](http://www.aws.amazon.com/hpc)

# Acknowledgements

Most of the information on this document are based on the previous works from Linda Hedges, Dougal Ballentyne, Dave Pellerin and Arthur Petitpierre.