# anat-processing
Pipeline to process anatomical data, including microstructure metrics from DWI and MT data

## How to run the pipeline

Get `s3_access_key` and `s3_secret_key` 👉 contact Basile.
Then, set them:
```bash
export AWS_ACCESS_KEY_ID=<s3_access_key>
export AWS_SECRET_ACCESS_KEY=<s3_secret_key>
```

Get the data:
```bash
datalad install -r git@github.com:courtois-neuromod/anat.git
cd anat
datalad get .
```

Docker installation (for now)
```bash
docker pull qmrlab/minimal:v2.3.1
docker pull qmrlab/antsfsl:latest
```

Install Nextflow
```bash
TODO
```

Run pipeline
```bash
nextflow run neuromod-process-anat.nf [OPTIONAL_ARGUMENTS] (--root)
```

