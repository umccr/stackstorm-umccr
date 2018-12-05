from __future__ import print_function

import sys
import os
import time
import json
import socket
import datetime
import collections
import requests
from sample_sheet import SampleSheet
# Sample sheet library: https://github.com/clintval/sample-sheet

import warnings
warnings.simplefilter("ignore")

DEPLOY_ENV = os.getenv('DEPLOY_ENV')
SCRIPT = os.path.basename(__file__)
SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))
LOG_FILE_NAME = os.path.join(SCRIPT_DIR, SCRIPT + ".log")
UDP_IP = "127.0.0.1"
UDP_PORT = 9999

ST2_WEBHOOK_URL = "https://stackstorm.{}.umccr.org/api/v1/webhooks/st2".format(DEPLOY_ENV)
ST2_TASK_NAME = 'samplesheet_check'
ST2_TRIGGER = "umccr.pipeline"

LOG_FILE = open(LOG_FILE_NAME, "a+")
SOCK = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)  # UDP


def write_log(msg):
    now = datetime.datetime.now()
    msg = "{} {}: {}".format(now, SCRIPT, msg)

    if DEPLOY_ENV == 'prod':
        SOCK.sendto(bytes(msg+"\n", "utf-8"), (UDP_IP, UDP_PORT))
    else:
        print(msg)
    print(msg, file=LOG_FILE)


def st2_callback(api_key, status, runfolder_name, workdir, error_message=None):
    """ Call ST2 webhook endpoint
        https://docs.stackstorm.com/webhooks.html
    """
    headers = {
        'Content-Type': 'application/json',
        'St2-Api-Key': api_key
    }
    payload = {
        'trigger': ST2_TRIGGER,
        'payload': {
            'task': ST2_TASK_NAME,
            'status': status,
            'runfolder_name': runfolder_name,
            'workdir': workdir
        }
    }
    if error_message:
        payload['payload']['error_message'] = error_message

    response = requests.post(ST2_WEBHOOK_URL, headers=headers, data=json.dumps(payload))
    response.raise_for_status()

    return response.json()


def main():
    write_log("Invocation with: samplesheet_path:{} runfolder_name:{} st2_api_key:{}..."
              .format(sys.argv[1], sys.argv[2], sys.argv[3][:10]))

    # TODO: validate input parameters
    samplesheet_file_path = sys.argv[1]
    runfolder_name = sys.argv[2]
    st2_api_key = sys.argv[3]

    samplesheet_name = os.path.basename(samplesheet_file_path)
    samplesheet_dir = os.path.dirname(os.path.realpath(samplesheet_file_path))

    sample_sheet = SampleSheet(samplesheet_file_path)
    write_log("INFO: Checking SampleSheet {}".format(samplesheet_file_path))

    # Sort samples based on technology (truseq/10X and/or index length)
    # Also replace N indexes with ""
    sorted_samples = collections.defaultdict(list)
    for sample in sample_sheet:
        # TODO: replace N index with ""
        sample.index = sample.index.replace("N", "")
        index_length = len(sample.index)

        if sample.index2:
            sample.index2 = sample.index2.replace("N", "")
            index2_length = len(sample.index2)
            # make sure to remove the index ID if there is no index sequence
            if index2_length is 0:
                sample.I5_Index_ID = ""
        else:
            index2_length = 0

        if sample.Sample_ID.startswith("SI-GA"):
            sample.Sample_ID = sample.Sample_Name
            sorted_samples[("10X", index_length, index2_length)].append(sample)
            write_log("DEBUG: Adding sample {} to key (10X, {}, {})".format(sample, index_length, index2_length))
        else:
            sorted_samples[("truseq", index_length, index2_length)].append(sample)
            write_log("DEBUG: Adding sample {} to key (truseq, {}, {})".format(sample, index_length, index2_length))

    # now that the samples have been sorted, we can write one or more custom sample sheets
    # (which may be the same as the original if no processing was necessary)
    write_log("INFO: Writing {} sample sheets.".format(len(sorted_samples)))

    count = 0
    exit_status = "success"
    for key in sorted_samples:
        count += 1
        write_log("DEBUG: {} samples with index lengths {}/{} for {} dataset"
                  .format(len(sorted_samples[key]), key[1], key[2], key[0]))

        new_sample_sheet = SampleSheet()
        new_sample_sheet.Header = sample_sheet.Header
        new_sample_sheet.Reads = sample_sheet.Reads
        new_sample_sheet.Settings = sample_sheet.Settings
        for sample in sorted_samples[key]:
            new_sample_sheet.add_sample(sample)

        new_sample_sheet_file = os.path.join(samplesheet_dir, samplesheet_name + ".custom." + str(count) + "." + key[0])
        write_log("INFO: Creating custom sample sheet: {}".format(new_sample_sheet_file))
        try:
            with open(new_sample_sheet_file, "w") as ss_writer:
                new_sample_sheet.write(ss_writer)
        except Exception as error:
            write_log("ERROR: Exception writing new sample sheet.")
            write_log("ERROR: {}".format(error))
            exit_status = "failure"
            
        write_log("DEBUG: Created custom sample sheet: {}".format(new_sample_sheet_file))

    write_log("INFO: Callback to ST2...")
    try:
        response_json = st2_callback(api_key=st2_api_key, status=exit_status,
                                     runfolder_name=runfolder_name, workdir=samplesheet_dir)
        write_log("DEBUG: ST2 webhook response json: {}".format(json.dumps(response_json)))
    except requests.exceptions.HTTPError as error:
        write_log("Failed to callback ST2! {}".format(error))

    write_log("INFO: All done.")
    LOG_FILE.close()
    SOCK.close()


if __name__ == "__main__":
    if DEPLOY_ENV == "prod":
        write_log("Running script in prod mode.")
    elif DEPLOY_ENV == "dev":
        write_log("Running script in dev mode.")
        # Wait a bit to simulate work (and avoid tasks running too close to each other)
        time.sleep(5)
    else:
        print("DEPLOY_ENV is not set! Set it to either 'dev' or 'prod'.")
        exit(1)
    main()
