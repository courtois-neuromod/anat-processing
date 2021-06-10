# anat-processing
Pipeline to process anatomical data, including microstructure metrics from DWI and MT data

## Download the data

### Get `s3_access_key` and `s3_secret_key` 👉 contact Basile.
Then, set them:
```bash
export AWS_ACCESS_KEY_ID=<s3_access_key>
export AWS_SECRET_ACCESS_KEY=<s3_secret_key>
```

### Get the data
```bash
datalad install -r git@github.com:courtois-neuromod/anat.git
cd anat
datalad get .
```

## Install requirements

The requirements for this pipeline include:
- Nextflow and Docker for brain data analysis
- SCT for spinal cord data analysis

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

### Install Spinal Cord Toolbox

See [SCT installation instructions](https://spinalcordtoolbox.com/en/latest/user_section/installation.html). 


## Run brain analysis pipeline

### Simplest use case

```bash
nextflow run neuromod-process-anat.nf --bids /path/to/courtois-neuromod/directory -with-report report.html
```

### What are those files appeared in the source directory? 

Upon invocation within a directory (in this case it is where you cloned `neuromod/anat-processing`), nextflow creates a 
set of project specific files/folders to cache outputs with detailed provenance recording: 

- `.nextflow` folder that contains caching information 
- `*.log` workflow execution logs 
- `work` folder that contains all the Nextflow outputs and traces. 
- `report.html` workflow execution report 

All these files are gitignored, so you are not likely to push any of these files by mistake. However, you can change the location 
where these outputs are saved to keep the source directory clean.

### Managing work directory and cleaning Nextflow files after a run

Using the following nextflow arguments, you can configure where the interim files will be stored:

```
COMMAND     VALUE
-w          /working/directory
-log        /execution/log-file.log
```

Example: 

```
nextflow -log $TMPDIR/cneuromod.log run neuromod-process-anat.nf --bids /path/to/courtois-neuromod/directory -w $TMPDIR -with-report /select/direcroty/for/report.html
```

Note that environment variable storing the temporary directory depends on your operation system:
- OSX:      `$TMPDIR`
- Ubuntu:   `$TMP`
- Windows:  `%TMP%`

Nonetheless, you can set any directory where you have write access to. 

In this case, only `.nextflow` folder will pop up in the source directory. Resultant work dorectory  be displayed in the 
terminal along with a random Mnemonic (e.g. `sad_ampere`). To clean interim workflow outputs, you can run the following 
in the terminal:

```
nextflow clean mnemonic_name -n
```

this command will show you the list of files that'll be deleted if you run

```
nextflow clean mnemonic_name -f
```

Note that if you delete these files and would like to [resume nextflow after an interrupted run](https://www.nextflow.io/blog/2019/demystifying-nextflow-resume.html) you won't be able to 
recover the processed files. 

### Datalad 

You can invoke the nextflow pipeline using `datalad` so that the process appears in dataset history:

```
datalad run -m "add some description" -d /path/to/courtois-neuromod/directory -o /path/to/courtois-neuromod/directory/derivatives "nextflow -log $TMPDIR/nf.log run neuromod-process-anat.nf --bids /path/to/courtois-neuromod/directory -w $TMPDIR/NF -with-report report.html"
```

Note that extensive provenance recording is also captured by Nextflow. You are highly encouraged to save `report.html` and inspect it after each workflow run.

### Resources 

For all the processes the current allocation (`nextflow.config`) is: 

- 1 CPU
- 1GB RAM

Except for aligning input images, for which 2CPUs are allocated. 

Nextflow infers parallelism at the `subject/session` level, so the number of maximum parallel operations depend on 
your processor specs & how many of them are requested per task. You can change `nextflow.config` to optimize resources 
according to your system's capacity. If you would like to limit maximum number of parallel operations for a process, 
you can set `maxForks` property. For example:  

```
...
   withName: alignMtsatInputs {
        cpus = 2
        memory = 2.GB
        maxForks = 4
        container = 'qmrlab/antsfsl:latest'
    }
...
```

By default `maxForks` value is equal to the number of CPU cores available minus 1. 

The local executor is used by default. It runs the pipeline processes in the computer where Nextflow is launched. The processes are 
parallelised by spawning multiple threads and by taking advantage of multi-cores architecture provided by the CPU.

Resources allocated to running containers are governed by your [Docker settings](https://docs.docker.com/config/containers/resource_constraints/). For example, if you need 500MB memory for a process, but if you set Docker memory access limit to 200MB, the process will run 
out of memory and fail to proceed. Note that this allocation affects performance as well.

You can use [any of these available executors](https://www.nextflow.io/docs/latest/executor.html).

### Notes 

- By default, this workflow is configured to work with multiple containers. However, you can edit `nextflow.config` for a select 
process to run locally. In that case, you need to make sure that all the dependencies are met for that process.
- All the processes expect certain outputs to be emitted. Exceptions will interrupt the workflow run. 
- A `subject/session` process will be omitted if any of the configured inputs are missing for that `subject/session`. For example, 
if you set `use_b1cor=true` the whole process will be skipped for a `subject/session` missing `../fmap/...B1plusmap.nii.gz`. This ensures that 
all the derivatives are processed uniformly.

## Run spinal cord analysis pipeline

```
sct_run_batch -path-data <PATH_NEUROMOD_DATA> -path-output <PATH_OUTPUT> -job <NUM_CPU_CORE> -script process_spinalcord.sh
```

To test the pipeline in one subject, run:
```
sct_run_batch -path-data <PATH_NEUROMOD_DATA> -path-output <PATH_OUTPUT> -script process_spinalcord.sh -include sub-01/ses-001
```

For more available options, run `sct_run_batch -h`
