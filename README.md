# anat-processing
Pipeline to process anatomical data, including microstructure metrics from DWI and MT data

## How to run the pipeline

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

