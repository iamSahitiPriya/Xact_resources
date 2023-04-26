#!/bin/bash

for function_dir in *.py; do

    filename=$(basename -- "$function_dir")
    filename="${filename%.*}"
    zip $filename.zip $filename.py
done

terraform init
terraform plan
terraform apply -auto-approve