#!/bin/bash

# Root directory
ROOT_DIR=$(cd "$(dirname "$0")"; cd ..; pwd)
echo "Locate project at ${ROOT_DIR}"

# Array of data splits
data_splits=('train' 'valid')


export CUDA_VISIBLE_DEVICES=4
echo "CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES}"

# 1. Generate sequences \hat{s}

model_name="esm2_t33_650M_UR50D"

for split in "${data_splits[@]}"; do
    
    # Define experiment name dynamically
    exp_name="rabd/${model_name}"

    # List of files that we want to back up and restore
    files_to_backup=("test_iter1_denoise_tau0.fasta" "native.fasta" "summary_iter1_denoise_tau0.fasta")

    # Check if the files exist and create backups if they do
    for file in "${files_to_backup[@]}"; do
        if test -f "${ROOT_DIR}/logs/${exp_name}/$file"; then
            cp "${ROOT_DIR}/logs/${exp_name}/$file" "${ROOT_DIR}/logs/${exp_name}/$file.bak"
        fi
    done

    # Generate the fasta file 
    exp_path="${ROOT_DIR}/logs/${exp_name}"
    python ${ROOT_DIR}/test.py experiment_path=${exp_path} data_split=${split} ckpt_path=best.ckpt mode=predict task.generator.max_iter=1 task.generator.strategy='denoise'

    # Rename the main output file
    mv "${ROOT_DIR}/logs/${exp_name}/test_iter1_denoise_tau0.fasta" "${ROOT_DIR}/logs/${exp_name}/${split}_iter1_denoise_tau0.fasta"

    # Recover the backup files to their original names
    for file in "${files_to_backup[@]}"; do
        if test -f "${ROOT_DIR}/logs/${exp_name}/$file.bak"; then
            mv "${ROOT_DIR}/logs/${exp_name}/$file.bak" "${ROOT_DIR}/logs/${exp_name}/$file"
        fi
    done
done


# 2. Move generated sequences to data directory 

declare -A rename_map
rename_map=( ["test_iter1_denoise_tau0.fasta"]="test_pred_${model_name}.fasta" ["train_iter1_denoise_tau0.fasta"]="train_pred_${model_name}.fasta" ["valid_iter1_denoise_tau0.fasta"]="valid_pred_${model_name}.fasta" )
    
# Source and destination directories
src_dir="${ROOT_DIR}/logs/${exp_name}"
dest_dir="${ROOT_DIR}/MEAN/summaries/cdrh3"

# Copy and rename the files
for src_file in "${!rename_map[@]}"; do
    dest_file="${rename_map[$src_file]}"
    if [[ -f "${src_dir}/${src_file}" ]]; then
        cp "${src_dir}/${src_file}" "${dest_dir}/${dest_file}"
    fi
done
