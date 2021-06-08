#!/bin/bash
#
# Process data.
#
# Usage:
#   ./process_data.sh <SUBJECT>
#
# Manual segmentations or labels should be located under:
# PATH_DATA/derivatives/labels/SUBJECT/<CONTRAST>/
#
# Authors: Julien Cohen-Adad

# The following global variables are retrieved from the caller sct_run_batch
# but could be overwritten by uncommenting the lines below:
# PATH_DATA_PROCESSED="~/data_processed"
# PATH_RESULTS="~/results"
# PATH_LOG="~/log"
# PATH_QC="~/qc"

# Uncomment for full verbose
set -x

# Immediately exit if error
set -e -o pipefail

# Exit if user presses CTRL+C (Linux) or CMD+C (OSX)
trap "echo Caught Keyboard Interrupt within script. Exiting now.; exit" INT

# Retrieve input params
SUBJECT_SESSION=$1

# get starting time:
start=`date +%s`


# FUNCTIONS
# ==============================================================================

# If there is an additional b=0 scan, add it to the main DWI data and update the
# bval and bvec files.
concatenate_b0_and_dwi(){
  local file_b0="$1"  # does not have extension
  local file_dwi="$2"  # does not have extension
  if [[ -e ${file_b0}.nii.gz ]]; then
    echo "Found additional b=0 scans: $file_b0.nii.gz They will be concatenated to the DWI scans."
    sct_dmri_concat_b0_and_dwi -i ${file_b0}.nii.gz ${file_dwi}.nii.gz -bval ${file_dwi}.bval -bvec ${file_dwi}.bvec -order b0 dwi -o ${file_dwi}_concat.nii.gz -obval ${file_dwi}_concat.bval -obvec ${file_dwi}_concat.bvec
    # Update global variable
    FILE_DWI="${file_dwi}_concat"
  else
    echo "No additional b=0 scans was found."
    FILE_DWI="${file_dwi}"
  fi
}

# Check if manual label already exists. If it does, copy it locally. If it does
# not, perform labeling.
label_if_does_not_exist(){
  local file="$1"
  local file_seg="$2"
  local vertlevels="$3"
  # Update global variable with segmentation file name
  FILELABEL="${file}_labels"
  FILELABELMANUAL="${PATH_DATA}/derivatives/labels/${SUBJECT}/anat/${FILELABEL}-manual.nii.gz"
  echo "Looking for manual label: $FILELABELMANUAL"
  if [[ -e $FILELABELMANUAL ]]; then
    echo "Found! Using manual labels."
    rsync -avzh $FILELABELMANUAL ${FILELABEL}.nii.gz
  else
    echo "Not found. Proceeding with automatic labeling."
    # Generate labeled segmentation
    sct_label_vertebrae -i ${file}.nii.gz -s ${file_seg}.nii.gz -c t1
    # Create labels in the cord at mid-vertebral levels
    sct_label_utils -i ${file_seg}_labeled.nii.gz -vert-body ${vertlevels} -o ${FILELABEL}.nii.gz
  fi
}

# Check if manual segmentation already exists. If it does, copy it locally. If
# it does not, perform seg.
segment_if_does_not_exist(){
  local file="$1"
  local contrast="$2"
  # Find contrast
  if [[ $contrast == "dwi" ]]; then
    folder_contrast="dwi"
  else
    folder_contrast="anat"
  fi
  # Update global variable with segmentation file name
  FILESEG="${file}_seg"
  FILESEGMANUAL="${PATH_DATA}/derivatives/labels/${SUBJECT}/${folder_contrast}/${FILESEG}-manual.nii.gz"
  echo
  echo "Looking for manual segmentation: $FILESEGMANUAL"
  if [[ -e $FILESEGMANUAL ]]; then
    echo "Found! Using manual segmentation."
    rsync -avzh $FILESEGMANUAL ${FILESEG}.nii.gz
    sct_qc -i ${file}.nii.gz -s ${FILESEG}.nii.gz -p sct_deepseg_sc -qc ${PATH_QC} -qc-subject ${SUBJECT}
  else
    echo "Not found. Proceeding with automatic segmentation."
    # Segment spinal cord
    sct_deepseg_sc -i ${file}.nii.gz -c $contrast -qc ${PATH_QC} -qc-subject ${SUBJECT}
  fi
}

# Check if manual segmentation already exists. If it does, copy it locally. If
# it does not, perform seg.
segment_gm_if_does_not_exist(){
  local file="$1"
  local contrast="$2"
  # Update global variable with segmentation file name
  FILESEG="${file}_gmseg"
  FILESEGMANUAL="${PATH_DATA}/derivatives/labels/${SUBJECT}/anat/${FILESEG}-manual.nii.gz"
  echo "Looking for manual segmentation: $FILESEGMANUAL"
  if [[ -e $FILESEGMANUAL ]]; then
    echo "Found! Using manual segmentation."
    rsync -avzh $FILESEGMANUAL ${FILESEG}.nii.gz
    sct_qc -i ${file}.nii.gz -s ${FILESEG}.nii.gz -p sct_deepseg_gm -qc ${PATH_QC} -qc-subject ${SUBJECT}
  else
    echo "Not found. Proceeding with automatic segmentation."
    # Segment spinal cord
    sct_deepseg_gm -i ${file}.nii.gz -qc ${PATH_QC} -qc-subject ${SUBJECT}
  fi
}



# SCRIPT STARTS HERE
# ==============================================================================
# Display useful info for the log, such as SCT version, RAM and CPU cores available
sct_check_dependencies -short

# Update SUBJECT variable to the prefix for BIDS file names, considering the "ses" entity
SUBJECT=`cut -d "/" -f1 <<< "$SUBJECT_SESSION"`
SESSION=`cut -d "/" -f2 <<< "$SUBJECT_SESSION"`

# Go to folder where data will be copied and processed
cd $PATH_DATA_PROCESSED
# Copy list of participants in processed data folder
if [[ ! -f "participants.tsv" ]]; then
  rsync -avzh $PATH_DATA/participants.tsv .
fi
# Copy source images
mkdir -p $SUBJECT
rsync -avzh $PATH_DATA/$SUBJECT_SESSION $SUBJECT/
# Go to anat folder where all structural data are located
cd ${SUBJECT_SESSION}/anat/

# Update SUBJECT variable to the prefix for BIDS file names, considering the "ses" entity
SUBJECT="${SUBJECT}_${SESSION}"


# T2
# ------------------------------------------------------------------------------
file_t2="${SUBJECT}_bp-cspine_T2w"
# Segment spinal cord (only if it does not exist)
segment_if_does_not_exist $file_t2 "t2"
file_t2_seg=$FILESEG
# Create mid-vertebral levels in the cord (only if it does not exist)
label_if_does_not_exist ${file_t2} ${file_t2_seg} "2,5"
file_label=$FILELABEL

# Compute average cord CSA between C2 and C3
sct_process_segmentation -i ${file_t2_seg}.nii.gz -vert 2:3 -vertfile PAM50_levels2${file_t2}.nii.gz -o ${PATH_RESULTS}/csa-SC_T2w.csv -append 1


# T1w
# ------------------------------------------------------------------------------
file_t1="${SUBJECT}_T1w"
# Reorient to RPI and resample to 1mm iso (supposed to be the effective resolution)
# sct_image -i ${file_t1}.nii.gz -setorient RPI -o ${file_t1}_RPI.nii.gz
# sct_resample -i ${file_t1}_RPI.nii.gz -mm 1x1x1 -o ${file_t1}_RPI_r.nii.gz
# file_t1="${file_t1}_RPI_r"
# Segment spinal cord (only if it does not exist)
segment_if_does_not_exist $file_t1 "t1"
file_t1_seg=$FILESEG
# # Bring vertebral level into T2 space
# sct_register_multimodal -i label_T1w/template/PAM50_levels.nii.gz -d ${file_t2_seg}.nii.gz -o PAM50_levels2${file_t2}.nii.gz -identity 1 -x nn
# # Compute average cord CSA between C2 and C3
# sct_process_segmentation -i ${file_t2_seg}.nii.gz -vert 2:3 -vertfile PAM50_levels2${file_t2}.nii.gz -o ${PATH_RESULTS}/csa-SC_T2w.csv -append 1
# 
# # Generate QC report to assess vertebral labeling
# sct_qc -i ${file_t1}.nii.gz -s ${file_label} -p sct_label_utils -qc ${PATH_QC} -qc-subject ${SUBJECT}
# # Compute average cord CSA between C2 and C3
# sct_process_segmentation -i ${file_t1_seg}.nii.gz -vert 2:3 -vertfile label_T1w/template/PAM50_levels.nii.gz -o ${PATH_RESULTS}/csa-SC_T1w.csv -append 1
# 
# # MTS
# # ------------------------------------------------------------------------------
# file_t1w="${SUBJECT}_acq-T1w_MTS"
# file_mton="${SUBJECT}_acq-MTon_MTS"
# file_mtoff="${SUBJECT}_acq-MToff_MTS"
# 
# if [[ -e "${file_t1w}.nii.gz" && -e "${file_mton}.nii.gz" && -e "${file_mtoff}.nii.gz" ]]; then
#   # Segment spinal cord (only if it does not exist)
#   segment_if_does_not_exist $file_t1w "t1"
#   file_t1w_seg=$FILESEG
#   # Create mask
#   sct_create_mask -i ${file_t1w}.nii.gz -p centerline,${file_t1w_seg}.nii.gz -size 35mm -o ${file_t1w}_mask.nii.gz
#   # Crop data for faster processing
#   sct_crop_image -i ${file_t1w}.nii.gz -m ${file_t1w}_mask.nii.gz -o ${file_t1w}_crop.nii.gz
#   file_t1w="${file_t1w}_crop"
#   # Register PD->T1w
#   # Tips: here we only use rigid transformation because both images have very similar sequence parameters. We don't want to use SyN/BSplineSyN to avoid introducing spurious deformations.
#   sct_register_multimodal -i ${file_mtoff}.nii.gz -d ${file_t1w}.nii.gz -dseg ${file_t1w_seg}.nii.gz -param step=1,type=im,algo=rigid,slicewise=1,metric=CC -x spline -qc ${PATH_QC} -qc-subject ${SUBJECT}
#   file_mtoff="${file_mtoff}_reg"
#   # Register MT->T1w
#   sct_register_multimodal -i ${file_mton}.nii.gz -d ${file_t1w}.nii.gz -dseg ${file_t1w_seg}.nii.gz -param step=1,type=im,algo=rigid,slicewise=1,metric=CC -x spline -qc ${PATH_QC} -qc-subject ${SUBJECT}
#   file_mton="${file_mton}_reg"
#   # Copy json files to match file basename (it will later be used by sct_compute_mtsat)
#   cp ${SUBJECT}_acq-T1w_MTS.json ${file_t1w}.json
#   cp ${SUBJECT}_acq-MToff_MTS.json ${file_mtoff}.json
#   cp ${SUBJECT}_acq-MTon_MTS.json ${file_mton}.json
#   # Register template->T1w_ax (using template-T1w as initial transformation)
#   sct_register_multimodal -i $SCT_DIR/data/PAM50/template/PAM50_t1.nii.gz -iseg $SCT_DIR/data/PAM50/template/PAM50_cord.nii.gz -d ${file_t1w}.nii.gz -dseg ${file_t1w_seg}.nii.gz -param step=1,type=seg,algo=slicereg,metric=MeanSquares,smooth=2:step=2,type=im,algo=syn,metric=CC,iter=5,gradStep=0.5 -initwarp warp_template2T1w.nii.gz -initwarpinv warp_T1w2template.nii.gz
#   # Rename warping field for clarity
#   mv warp_PAM50_t12${file_t1w}.nii.gz warp_template2axT1w.nii.gz
#   mv warp_${file_t1w}2PAM50_t1.nii.gz warp_axT1w2template.nii.gz
#   # Warp template
#   sct_warp_template -d ${file_t1w}.nii.gz -w warp_template2axT1w.nii.gz -ofolder label_axT1w -qc ${PATH_QC} -qc-subject ${SUBJECT}
#   # Compute MTR
#   sct_compute_mtr -mt0 ${file_mtoff}.nii.gz -mt1 ${file_mton}.nii.gz
#   # Compute MTsat
#   sct_compute_mtsat -mt ${file_mton}.nii.gz -pd ${file_mtoff}.nii.gz -t1 ${file_t1w}.nii.gz
#   # Extract MTR, MTsat and T1 in WM between C2 and C5 vertebral levels
#   sct_extract_metric -i mtr.nii.gz -f label_axT1w/atlas -l 51 -vert 2:5 -vertfile label_axT1w/template/PAM50_levels.nii.gz -o ${PATH_RESULTS}/MTR.csv -append 1
#   sct_extract_metric -i mtsat.nii.gz -f label_axT1w/atlas -l 51 -vert 2:5 -vertfile label_axT1w/template/PAM50_levels.nii.gz -o ${PATH_RESULTS}/MTsat.csv -append 1
#   sct_extract_metric -i t1map.nii.gz -f label_axT1w/atlas -l 51 -vert 2:5 -vertfile label_axT1w/template/PAM50_levels.nii.gz -o ${PATH_RESULTS}/T1.csv -append 1
# else
#   echo "WARNING: MTS dataset is incomplete."
# fi
# 
# # T2s
# # ------------------------------------------------------------------------------
# file_t2s="${SUBJECT}_T2star"
# # Compute root-mean square across 4th dimension (if it exists), corresponding to all echoes in Philips scans.
# sct_maths -i ${file_t2s}.nii.gz -rms t -o ${file_t2s}_rms.nii.gz
# file_t2s="${file_t2s}_rms"
# # Bring vertebral level into T2s space
# sct_register_multimodal -i label_T1w/template/PAM50_levels.nii.gz -d ${file_t2s}.nii.gz -o PAM50_levels2${file_t2s}.nii.gz -identity 1 -x nn
# # Segment gray matter (only if it does not exist)
# segment_gm_if_does_not_exist $file_t2s "t2s"
# file_t2s_seg=$FILESEG
# # Compute the gray matter CSA between C3 and C4 levels
# # NB: Here we set -no-angle 1 because we do not want angle correction: it is too
# # unstable with GM seg, and t2s data were acquired orthogonal to the cord anyways.
# sct_process_segmentation -i ${file_t2s_seg}.nii.gz -angle-corr 0 -vert 3:4 -vertfile PAM50_levels2${file_t2s}.nii.gz -o ${PATH_RESULTS}/csa-GM_T2s.csv -append 1
# 
# # DWI
# # ------------------------------------------------------------------------------
# file_dwi="${SUBJECT}_dwi"
# cd ../dwi
# # If there is an additional b=0 scan, add it to the main DWI data
# concatenate_b0_and_dwi "${SUBJECT}_acq-b0_dwi" $file_dwi
# file_dwi=$FILE_DWI
# file_bval=${file_dwi}.bval
# file_bvec=${file_dwi}.bvec
# # Separate b=0 and DW images
# sct_dmri_separate_b0_and_dwi -i ${file_dwi}.nii.gz -bvec ${file_bvec}
# # Get centerline
# sct_get_centerline -i ${file_dwi}_dwi_mean.nii.gz -c dwi -qc ${PATH_QC} -qc-subject ${SUBJECT}
# # Create mask to help motion correction and for faster processing
# sct_create_mask -i ${file_dwi}_dwi_mean.nii.gz -p centerline,${file_dwi}_dwi_mean_centerline.nii.gz -size 30mm
# # Motion correction
# sct_dmri_moco -i ${file_dwi}.nii.gz -bvec ${file_dwi}.bvec -m mask_${file_dwi}_dwi_mean.nii.gz -x spline
# file_dwi=${file_dwi}_moco
# file_dwi_mean=${file_dwi}_dwi_mean
# # Segment spinal cord (only if it does not exist)
# segment_if_does_not_exist ${file_dwi_mean} "dwi"
# file_dwi_seg=$FILESEG
# # Register template->dwi (using template-T1w as initial transformation)
# sct_register_multimodal -i $SCT_DIR/data/PAM50/template/PAM50_t1.nii.gz -iseg $SCT_DIR/data/PAM50/template/PAM50_cord.nii.gz -d ${file_dwi_mean}.nii.gz -dseg ${file_dwi_seg}.nii.gz -param step=1,type=seg,algo=centermass:step=2,type=im,algo=syn,metric=CC,iter=5,gradStep=0.5 -initwarp ../anat/warp_template2T1w.nii.gz -initwarpinv ../anat/warp_T1w2template.nii.gz
# # Rename warping field for clarity
# mv warp_PAM50_t12${file_dwi_mean}.nii.gz warp_template2dwi.nii.gz
# mv warp_${file_dwi_mean}2PAM50_t1.nii.gz warp_dwi2template.nii.gz
# # Warp template
# sct_warp_template -d ${file_dwi_mean}.nii.gz -w warp_template2dwi.nii.gz -qc ${PATH_QC} -qc-subject ${SUBJECT}
# # Create mask around the spinal cord (for faster computing)
# sct_maths -i ${file_dwi_seg}.nii.gz -dilate 1 -shape ball -o ${file_dwi_seg}_dil.nii.gz
# # Compute DTI
# sct_dmri_compute_dti -i ${file_dwi}.nii.gz -bvec ${file_bvec} -bval ${file_bval} -method standard -m ${file_dwi_seg}_dil.nii.gz
# # Compute FA, MD and RD in WM between C2 and C5 vertebral levels
# sct_extract_metric -i dti_FA.nii.gz -f label/atlas -l 51 -vert 2:5 -o ${PATH_RESULTS}/DWI_FA.csv -append 1
# sct_extract_metric -i dti_MD.nii.gz -f label/atlas -l 51 -vert 2:5 -o ${PATH_RESULTS}/DWI_MD.csv -append 1
# sct_extract_metric -i dti_RD.nii.gz -f label/atlas -l 51 -vert 2:5 -o ${PATH_RESULTS}/DWI_RD.csv -append 1

# Go back to parent folder
cd ..

# Verify presence of output files and write log file if error
# ------------------------------------------------------------------------------
FILES_TO_CHECK=(
  "anat/${SUBJECT}_T2w_bp-cspine_seg.nii.gz"
  "anat/${SUBJECT}_T1_seg.nii.gz"
)
for file in ${FILES_TO_CHECK[@]}; do
  if [[ ! -e $file ]]; then
    echo "${SUBJECT}/${file} does not exist" >> $PATH_LOG/_error_check_output_files.log
  fi
done

# Display useful info for the log
end=`date +%s`
runtime=$((end-start))
echo
echo "~~~"
echo "SCT version: `sct_version`"
echo "Ran on:      `uname -nsr`"
echo "Duration:    $(($runtime / 3600))hrs $((($runtime / 60) % 60))min $(($runtime % 60))sec"
echo "~~~"
