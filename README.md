# MAGeTbrain Pipeline

A Nextflow implementation of the [Multiple Automatically Generated Templates (MAGeT) brain](https://github.com/CobraLab/MAGeTbrain) segmentation pipeline.

> Pipitone J, Park MT, Winterburn J, et al. Multi-atlas segmentation of the whole hippocampus
> and subfields using multiple automatically generated templates. Neuroimage. 2014;

> M Mallar Chakravarty, Patrick Steadman, Matthijs C van Eede, Rebecca D Calcott, Victoria Gu, Philip Shaw, Armin Raznahan, D Louis Collins, and Jason P Lerch.
> Performing label-fusion-based segmentation using multiple automatically generated templates. Hum Brain Mapp, 34(10):2635–54, October 2013. (doi:10.1002/hbm.22092)

## Theory of Operation

Given a set of labelled MR images (atlases) and
unlabelled images (subjects), MAGeT produces a segmentation for each subject
using a multi-atlas voting procedure based on a template library made up of images from the subject set.

Here is a schematic comparing 'traditional' multi-atlas segmentation, and MAGeT brain segmentation:

![Multi-atlas and MAGeT brain operation schematic](assets/MA-MAGeTBrain-Schematic.png "Schematic")

The major difference between algorithms is that, in MAGeT brain, segmentations from each atlas
(typically manually delineated) are propogated via image registration to a subset of
the subject images (known as the 'template library') before being propogated to each subject
image and fused. It is our hypothesis that by propogating labels to a template library,
we are able to make use of the neuroanatomical variability of the subjects in order to 'fine tune'
each individual subject's segmentation.

## Requirements

These are not requirements if running on Niagara [see below](#Running-on-Niagara)

- [Nextflow](https://www.nextflow.io/) (version 20.07.1 or later)
- [Docker](https://www.docker.com/) or [Singularity](https://sylabs.io/singularity/)
- [ANTs](https://github.com/ANTsX/ANTs)

## Data Prerequisites

- Atlases with labels. You can bring your own or use those provided by CoBrALab found here: [atlases](https://github.com/CoBrALab/atlases)
- Subject scans with compatible contrast
- Subject scans should be preprocessed in the same way as the atlases
  (regarding skull-stripping, intensity normalization, etc.)
- It's recommended to have 21 templates as a representative subset

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
   Labels for each atlas `<atlasname>_label_<labelname1>.nii.gz` should be included in the `atlases` directory.
   Atlases, templates, subjects and labels should be structured in an input directory as follows:

> [!IMPORTANT]  
> A note about labels for use with `collect_volumes_nifti_sh`
> Nextflow uses regex to match `volume_label_<label>.csv` to the corresponding majorityVote ouput
> Specifically it matches on `\w`, that is any letter, digit or underscore. Equivalent to [a-zA-Z0-9_].
> `/_label_([\w]+)\.nii.gz/`.
> \_This means only alphanumerical characters can be used\_
> other characters like `-  , . < >` etc. will cause errors

```bash
inputs
├── atlases
│   ├── atlas1_label_<labelname1>.nii.gz
│   ├── atlas1_label_<labelname2>.nii.gz
│   ├── atlas1_T1w.nii.gz
│   ├── volume_labels_<labelname1>.csv
│   ├── volume_labels_<labelname2>.csv
│   └── ...
├── subjects
│   ├── subject1_T1w.nii.gz
│   ├── subject2_T1w.nii.gz
│   ├── subject3_T1w.nii.gz
│   ├── subject4_T1w.nii.gz
│   ├── subject5_T1w.nii.gz
│   └── ...
└── templates
    ├── subject2_T1w.nii.gz
    ├── subject5_T1w.nii.gz
    └── ...
```

3. (optional) If you'd like to verify the structure of the `inputs` directory the `nextflow verify_inputs.nf`
   command can be run. This command is also run as part of `magetbrain.nf`

4. When the `inputs` directory has been set up as above,
   the workflow can be run with the following command `nextflow magetbrain.nf`

## Parameters

Parameters can be adjusted by editing `nextflow.config`.
The default values are shown below:

```
params {
    primarySpectra = 'T1w'
    inputDir = 'inputs'
    outputDir = 'output'
}
```

## Output

An example output of `magetbrain.nf` is shown below.
In this simplified example the amygdala and cerebellum atlases were used to produce the segmentation.
Note that this demonstration uses fewer subjects and templates than would be recommended for actual
research purposes

```bash
output
└── labels
    └── majorityvote
        ├── sub-031274_label_amy.nii.gz
        ├── sub-031274_label_cer.nii.gz
        ├── sub-031275_label_amy.nii.gz
        ├── sub-031275_label_cer.nii.gz
        └── collectedVolumes
            └── combined_volume_output.tsv
```

In addition to the majorityVote the volumes of the labels are collected using ANT's `LabelGeometryMeasures`.
These are collected in the `combined_volume_output.tsv` file.
The outputs for this function are as follows with some additional manipulation by `magetbrain.nf`:

| SubjectLabels               | LabelNumber | LabelName  | VolumeInVoxels | VolumeInMillimeters | SurfaceAreaInMillimetersSquared | Eccentricity | Elongation | Roundness | Flatness       | Centroid                      | AxesLengths                 | BoundingBox              |
| --------------------------- | ----------- | ---------- | -------------- | ------------------- | ------------------------------- | ------------ | ---------- | --------- | -------------- | ----------------------------- | --------------------------- | ------------------------ |
| sub-031275_label_amy.nii.gz | 26          | L_amygdala | 159            | 1272.000000         | 700.123091                      | 0.687735     | 1.173662   | 0.810901  | 2.080693       | [24.4721, -15.6447, -8.4358]  | [7.3500, 15.2932, 17.9490]  | [28, 63, 50, 36, 70, 57] |
| sub-031275_label_amy.nii.gz | 126         | R_amygdala | 165            | 1320.000000         | 695.146695                      | 0.844847     | 1.367161   | 0.837125  | 1.791465       | [-18.3960, -11.7693, -6.5362] | [7.6773, 13.7536, 18.8034]  | [49, 63, 51, 59, 69, 58] |
| sub-031275_label_cer.nii.gz | 1           | L_I_II     | 3              | 24.000000           | 33.933824                       | 0.997651     | 3.820754   | 1.185747  | 4204927.244023 | [2.0291, 6.1486, -28.3473]    | [0.0000, 2.1352, 8.1580]    | [42, 52, 47, 43, 53, 49] |
| sub-031275_label_cer.nii.gz | 2           | L_III      | 119            | 952.000000          | 691.554020                      | 0.975030     | 2.122034   | 0.676731  | 2.229119       | [6.7937, 7.2466, -27.6651]    | [5.6990, 12.7037, 26.9577]  | [35, 48, 45, 43, 58, 53] |
| sub-031275_label_cer.nii.gz | 3           | L_IV       | 386            | 3088.000000         | 1588.463573                     | 0.993717     | 2.989118   | 0.645592  | 1.611969       | [11.7454, 9.5389, -26.7099]   | [8.8352, 14.2420, 42.5711]  | [31, 44, 42, 43, 60, 56] |
| sub-031275_label_cer.nii.gz | 4           | L_V        | 630            | 5040.000000         | 2244.652713                     | 0.996707     | 3.511840   | 0.633318  | 1.140233       | [16.9547, 15.6565, -32.3521]  | [12.9096, 14.7199, 51.6940] | [27, 39, 41, 43, 60, 54] |
| sub-031275_label_cer.nii.gz | 5           | L_VI       | 729            | 5832.000000         | 2740.769300                     | 0.990676     | 2.709235   | 0.571685  | 1.757259       | [21.1760, 25.2954, -36.7663]  | [11.6904, 20.5431, 55.6560] | [25, 34, 40, 42, 58, 48] |
| sub-031275_label_cer.nii.gz | 6           | L_Crus_I   | 1056           | 8448.000000         | 4040.455378                     | 0.980065     | 2.243498   | 0.496466  | 2.344949       | [31.6046, 27.4819, -41.2604]  | [11.2453, 26.3697, 59.1605] | [19, 30, 38, 42, 56, 46] |
| sub-031275_label_cer.nii.gz | 7           | L_Crus_II  | 1005           | 8040.000000         | 3930.752935                     | 0.989745     | 2.645862   | 0.493756  | 1.617023       | [23.8352, 34.2780, -49.6458]  | [14.6968, 23.7651, 62.8792] | [20, 29, 33, 42, 56, 42] |

## Running on Niagara

### Nextflow binary

The Nextflow binary is required.  
The following steps need to only be done once.

- Download from [nextflow.io](https://www.nextflow.io/)

```bash
curl -s https://get.nextflow.io | bash
```

- The binary should be placed in `~/.local/bin`.

```bash
mv nextflow ~/.local/bin
```

- And the bin directory should be added to your path. And your `.bashrc` needs to be sourced.

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

```bash
source ~/.bashrc
```

- ensure nextflow can run

```bash
nextflow help
```

### Loading modules

Now the correct modules need to be loaded.
This needs to be done every time.

> [!IMPORTANT]
> Do not load modules from `.bashrc`.

```bash
module load cobralab
module load openjdk/17.0.9
```

> [!NOTE]  
> As of writing this (Spring 2025) openjdk/17.0.9 was the latest version on Niagara.
> Nextflow needs Java Version 17 or later

### Run command on Niagara

To ensure submission to SLURM the the Niagara profile must be used.
This is provided in `nextflow.config` file and can be passed using the `--profile` flag.
Other useful flags to pass are `-bg` to run in background and `-resume` to resume processing if there was an interuption.

```bash
nextflow run -bg magetbrain.nf -profile niagara -resume
```

> [!IMPORTANT]
> A bug when running on Niagara requires and additional script to be run to collect volumes.
> This can be done on the login node without submitting job to SLURM

```bash
nextflow run collect_and_combine_volumes_niagara.nf
```
