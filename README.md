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
> [link to docs](https://bic-mni.github.io/man-pages/man/mnc2nii)

1. Clone the repository:

```bash
git clone https://github.com/CoBrALab/MAGeTBrain-nextflow.git
cd MAGeTBrain-nextflow
```

2. Input structure
   Atlases, templates and subjects need to be in a specific structure in the `inputs` directory.
   Optionally labels for each `<atlasname>_label_<labelname1.nii.gz` should be included in a `labels` directory.
   These optional labels are for collecting the volumes of the majority votes.
   Atlases, templates, subjects and Optionally labels should be structure in an input directory as follows:

```bash
inputs
├── atlases
│   ├── atlas1_label_<labelname1>.nii.gz
│   ├── atlas1_label_<labelname2>.nii.gz
│   ├── atlas1_T1w.nii.gz
│   └── ...
├── subjects
│   ├── subject1_T1w.nii.gz
│   ├── subject2_T1w.nii.gz
│   ├── subject3_T1w.nii.gz
│   ├── subject4_T1w.nii.gz
│   ├── subject5_T1w.nii.gz
│   └── ...
├── templates
│   ├── subject2_T1w.nii.gz
│   ├── subject5_T1w.nii.gz
│   └── ...
└── labels
    ├── <labelname1>_volume_labels.csv
    ├── <labelname2>_volume_labels.csv
    └── ...
```

3. When the `inputs` directory has been set-up as above the workflow can be run with the following command `nextflow magetbrain.nf`
