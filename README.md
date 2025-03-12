# MAGeTbrain Pipeline

A Nextflow implementation of the [Multiple Automatically Generated Templates (MAGeT) brain](https://github.com/CobraLab/MAGeTbrain) segmentation pipeline.

> Pipitone J, Park MT, Winterburn J, et al. Multi-atlas segmentation of the whole hippocampus
> and subfields using multiple automatically generated templates. Neuroimage. 2014;

> M Mallar Chakravarty, Patrick Steadman, Matthijs C van Eede, Rebecca D Calcott, Victoria Gu, Philip Shaw, Armin Raznahan, D Louis Collins, and Jason P Lerch.
> Performing label-fusion-based segmentation using multiple automatically generated templates. Hum Brain Mapp, 34(10):2635–54, October 2013. (doi:10.1002/hbm.22092)

## Prerequisites

- [Nextflow](https://www.nextflow.io/) (version 20.07.1 or later)
- [Docker](https://www.docker.com/) or [Singularity](https://sylabs.io/singularity/)
- MINC Toolkit (provided in the Docker container) _optional_

## Quick Start

> [!IMPORTANT]  
> All images should be in NIfTI format (`.nii.gz`)  
> `.mnc` can be converted to NIfTI using `mnc2nii` from minc-toolkit-v2  
> see below in section [Converting MINC to NIFTI](#converting-minc-to-nifti)  
> [link to docs](https://bic-mni.github.io/man-pages/man/mnc2nii)

1. Clone the repository:

```bash
git clone https://github.com/CoBrALab/MAGeTBrain-nextflow.git
cd MAGeTBrain-nextflow
```

2. Input structure
   Atlases and images should be structure in an input directory as follows:

```bash
inputs/
├── atlases/
│   ├── atlas1_T1w.nii.gz
│   ├── atlas1_label_*.nii.gz
│   ├── atlas2_T1w.nii.gz
│   ├── atlas2_label_*.nii.gz
│   └── ...
└── subjects/
    ├── subject1_T1w.nii.gz
    ├── subject2_T1w.nii.gz
    └── ...
```

## Converting MINC to NIFTI

A docker image can be pulled with the minc-toolkit-v2

```bash
docker pull nistmni/minc-toolkit:1.9.16
# next mount your volumne in the container
docker run -it -v /path/to/dir:/home/nistmni/input
# now you should be in the docker shell
# add the toolkit bin to the path
export PATH=$PATH:/opt/minc/1.9.16/bin
# next perform the conversion
mnc2nii input.mnc output.nii
```

The `.nii` files will now be in the directory where the original `.mnc` files were.
