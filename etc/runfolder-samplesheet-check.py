import sys
import os
import socket
import datetime
import collections
from sample_sheet import SampleSheet
# Sample sheet library: https://github.com/clintval/sample-sheet

import warnings
warnings.simplefilter("ignore")

SCRIPT = os.path.basename(__file__)
SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))
LOG_FILE_NAME = os.path.join(SCRIPT_DIR, SCRIPT + ".log")
UDP_IP = "127.0.0.1"
UDP_PORT = 9999

LOG_FILE = open(LOG_FILE_NAME, "a+")
SOCK = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)  # UDP


def write_log(msg):
    now = datetime.datetime.now()
    msg = "%s %s: %s" % (now, SCRIPT, msg)

    if os.getenv('DEPLOY_ENV') == 'prod':
        SOCK.sendto(bytes(msg+"\n", "utf-8"), (UDP_IP, UDP_PORT))
    else:
        print(msg)
    print(msg, file=LOG_FILE)


def main():
    write_log("Invocation with: %s" % str(sys.argv))

    # TODO: validate input parameter?
    samplesheet_file_path = sys.argv[1]

    samplesheet_name = os.path.basename(samplesheet_file_path)
    samplesheet_dir = os.path.dirname(os.path.realpath(samplesheet_file_path))

    sample_sheet = SampleSheet(samplesheet_file_path)
    write_log("INFO: Checking SampleSheet %s" % samplesheet_file_path)

    # Sort samples based on technology (truseq/10X and/or index length)
    # Also replace N indexes with ""
    sorted_samples = collections.defaultdict(list)
    for sample in sample_sheet:
        # TODO: replace N index with ""
        index_length = len(sample.index.replace("N", ""))
        sample.index = sample.index.replace("N", "")

        if sample.index2:
            index2_length = len(sample.index2.replace("N", ""))
            sample.index2 = sample.index2.replace("N", "")
        else:
            index2_length = 0

        if sample.Sample_ID.startswith("SI-GA"):
            sample.I5_index_ID = ""
            sample.Sample_Project = ""
            sample.Sample_ID = sample.Sample_Name
            sorted_samples[("10X", index_length, index2_length)].append(sample)
            write_log("DEBUG: Adding sample %s to key (10X, %s, %s)" % (sample, index_length, index2_length))
        else:
            sorted_samples[("truseq", index_length, index2_length)].append(sample)
            write_log("DEBUG: Adding sample %s to key (truseq, %s, %s)" % (sample, index_length, index2_length))

    # now that the samples have been sorted, we can write one or more custom sample sheets
    # (which may be the same as the original if no processing was necessary)
    write_log("INFO: Writing %s sample sheets." % len(sorted_samples))
    count = 0
    for key in sorted_samples:
        count += 1
        write_log("DEBUG: %s samples with index lengths %s/%s for %s dataset"
                  % (len(sorted_samples[key]), key[1], key[2], key[0]))

        new_sample_sheet = SampleSheet()
        new_sample_sheet.Header = sample_sheet.Header
        new_sample_sheet.Reads = sample_sheet.Reads
        new_sample_sheet.Settings = sample_sheet.Settings
        for sample in sorted_samples[key]:
            new_sample_sheet.add_sample(sample)

        new_sample_sheet_file = os.path.join(samplesheet_dir, samplesheet_name + ".custom." + str(count) + "." + key[0])
        write_log("INFO: Creating custom sample sheet: %s" % new_sample_sheet_file)
        f = open(new_sample_sheet_file, "w")
        new_sample_sheet.write(f)
        f.close()
        write_log("DEBUG: Created custom sample sheet: %s" % new_sample_sheet_file)

    write_log("INFO: All done.")
    LOG_FILE.close()
    SOCK.close()


if __name__ == "__main__":
    if os.getenv('DEPLOY_ENV') is None:
        print("DEPLOY_ENV is not set! Set it to either 'dev' or 'prod'.")
        exit(1)
    main()
