# anat-processing
Pipeline to process anatomical data, including microstructure metrics from DWI and MT data

## How to run the pipeline

### Get `s3_access_key` and `s3_secret_key` 👉 contact Basile.
Then, set them:
```bash
export AWS_ACCESS_KEY_ID=<s3_access_key>
export AWS_SECRET_ACCESS_KEY=<s3_secret_key>
```

### Get the data:
```bash
datalad install -r git@github.com:courtois-neuromod/anat.git
cd anat
datalad get .
```

### Install Nextflow
1. Make sure that java `8` or later is installed
```bash
java -version
```
> Note: version numbers `1.8.y_z` and `8` identify the Java release.

2. Enter this command in your terminal to install Nextflow:
```bash
curl -s https://get.nextflow.io | bash
```
> After the installation an executable named `nextflow` will be created in the directory where you called the command. You can simply copy this to a directory in your system `$PATH` to be able to call `nextflow` from any directory. 

3. Run a simple demo 
```
nextflow run hello
```

### Pull Docker images
These Docker images will be orchestrated by the workflow to deal with dependencies:

```bash
docker pull qmrlab/minimal:v2.3.1
docker pull qmrlab/antsfsl:latest
```

> If you are an OSX user and manually configured Docker to run in a virtual machine, please make sure that your `/Users` folder is mounted into the Docker VM. If you installed Docker using the [Desktop Installer](https://docs.docker.com/docker-for-mac/install/), this is automatically configured. 

### Run pipeline

```bash
nextflow run neuromod-process-anat.nf --bids /path/to/courtois-neuromod/directory
```

