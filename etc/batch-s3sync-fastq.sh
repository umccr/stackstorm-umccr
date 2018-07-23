#!/bin/bash
set -e
set -o pipefail

# global data/variable definitions
script=$(basename $0)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOG_FILE=$DIR/${script}.log

fastq_data_base="/data/cephfs/punim0010/data/FASTQ"

datasets_1=("170427_A00130_0009_AH25F3DMXX"
            "170519_A00121_0011_AH23HJDMXX"
            "170519_A00121_0012_BH2355DMXX"
            "170621_A00130_0013_BH25HWDMXX"
            "170704_A00130_0014_AH2C33DMXX"
            "170707_A00130_0015_BH27LKDMXX")

datasets_2=("170802_A00130_0016_AH2JGGDMXX"
            "170802_A00130_0017_BH2N5WDMXX"
            "170823_A00130_0019_AH2N2FDMXX"
            "170829_A00130_0020_AH2MKTDMXX"
            "170829_A00130_0021_BH3KC2DMXX"
            "170912_A00130_0022_AH3JV3DMXX")

datasets_3=("170918_A00130_0023_BH3M2HDMXX"
            "171009_A00130_0024_BH52VYDMXX"
            "171009_A00130_0025_AH52WFDMXX"
            "171012_A00130_0026_AH52VVDMXX"
            "171016_A00130_0028_BH533CDMXX"
            "171016_A00130_0029_AH533JDMXX"
            "171019_A00130_0030_AH5G27DMXX")


# functions
setup_aws_env () {
    export AWS_REGION=ap-southeast-2
    echo "Assuming AWS role"
    echo "aws sts assume-role --role-arn \"arn:aws:iam::$aws_account_number:role/fastq_data_uploader\" --role-session-name \"temp_session\" --duration-seconds=21600"
    temp_role=$(aws sts assume-role --role-arn "arn:aws:iam::$aws_account_number:role/fastq_data_uploader" --role-session-name "temp_session" --duration-seconds=21600)

    export AWS_ACCESS_KEY_ID=$(echo $temp_role | jq .Credentials.AccessKeyId | xargs)
    export AWS_SECRET_ACCESS_KEY=$(echo $temp_role | jq .Credentials.SecretAccessKey | xargs)
    export AWS_SESSION_TOKEN=$(echo $temp_role | jq .Credentials.SessionToken | xargs)
}

process_datasets () {
  arr=("$@")

  for dataset in "${arr[@]}"; do
    echo "Processing $dataset"
    if test ! -d "$fastq_data_base/$dataset"; then
      echo "Not a valid directory: $fastq_data_base/$dataset"
      exit 1
    fi

    cmd="./sync-to-s3.sh -s $fastq_data_base/$dataset -d $dataset/$dataset -b $aws_bucket_name  -a $aws_account_number -f"
    echo "$cmd" >> "$LOG_FILE"
    #eval "$cmd"
  done
}


# the actual program

if test -z "$AWS_ACCOUNT_ALIAS"; then
    echo "AWS_ACCOUNT_ALIAS not set!"
    exit 1
fi

if test "$AWS_ACCOUNT_ALIAS" = "dev"; then
    echo "Running against AWS dev account."
    aws_account_number="620123204273"
    aws_bucket_name="umccr-fastq-data-dev"
elif test "$AWS_ACCOUNT_ALIAS" = "prod"; then
    echo "Running against AWS prod account."
    aws_account_number="472057503814"
    aws_bucket_name="umccr-fastq-data-prod"
else
    echo "Unknown AWS account!"
    exit 1
fi


setup_aws_env

process_datasets "${datasets_1[@]}" &
process_datasets "${datasets_2[@]}" &
process_datasets "${datasets_3[@]}" &