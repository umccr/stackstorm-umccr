import sys
import os
import socket
import datetime
import collections
from sample_sheet import SampleSheet

SCRIPT = os.path.basename(__file__)
SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))
LOG_FILE_NAME = os.path.join(SCRIPT_DIR, SCRIPT + ".log")
UDP_IP = "127.0.0.1"
UDP_PORT = 9999

LOG_FILE = open(LOG_FILE_NAME, "a+")
SOCK = socket.socket(socket.AF_INET, socket.SOCK_DGRAM) # UDP


def write_log(msg):
    now = datetime.datetime.now()
    msg = "%s %s: %s \n" % (now, SCRIPT, msg)
    SOCK.sendto(bytes(msg, "utf-8"), ( UDP_IP, UDP_PORT ))
    print(msg, file=LOG_FILE)

# TODO: validate input parameter?
samplesheet_file_path = sys.argv[1]

samplesheet_name = os.path.basename(samplesheet_file_path)
samplesheet_dir = os.path.dirname(os.path.realpath(samplesheet_file_path))

sample_sheet = SampleSheet(samplesheet_file_path)
write_log("INFO: Checking SampleSheet %s" % samplesheet_file_path)

# first create all index length tuples
sorted_samples = collections.defaultdict(list)
for sample in sample_sheet:
    index_length = len(sample.index.replace("N",""))

    if sample.index2:
        index2_length = len(sample.index2.replace("N",""))
    else:
        index2_length = 0

    sorted_samples[(index_length, index2_length)].append(sample)
    write_log("DEBUG: Adding sample %s to key (%s, %s)" % ( sample, index_length, index2_length ))



samplesheet_files = list()
if len(sorted_samples) is 1:
    key, value = sorted_samples.popitem()
    write_log("INFO: Only one index lengths combination (%s\%s). No need for custom sample sheets." % ( key[0], key[1] ))
else:
    write_log("INFO: Multiple index lengths combination. Need custom sample sheets.")
    count=0
    for key in sorted_samples:
        count += 1
        write_log("DEBUG: %s samples with index lengths %s/%s" % ( len(sorted_samples[key]), key[0], key[1] ))

        new_sample_sheet = SampleSheet()
        new_sample_sheet.Header = sample_sheet.Header
        new_sample_sheet.Reads = sample_sheet.Reads
        new_sample_sheet.Settings = sample_sheet.Settings
        for sample in sorted_samples[key]:
          new_sample_sheet.add_sample(sample)

        new_sample_sheet_file = os.path.join(samplesheet_dir, samplesheet_name + ".custom" + count)
        samplesheet_files.append(new_sample_sheet_file)
        f = open(new_sample_sheet_file, "w")
        new_sample_sheet.write(f)
        f.close()


write_log("INFO: Created files: %s" % samplesheet_files)

LOG_FILE.close()
SOCK.close()
