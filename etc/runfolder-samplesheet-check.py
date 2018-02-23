import sys
import os
import socket
import datetime
from sample_sheet import SampleSheet

SCRIPT = os.path.basename(__file__)
DIR = os.path.dirname(os.path.realpath(__file__))
LOG_FILE_NAME = os.path.join(DIR, SCRIPT + ".log")
UDP_IP = "127.0.0.1"
UDP_PORT = 9999
SOCK = socket.socket(socket.AF_INET, socket.SOCK_DGRAM) # UDP

LOG_FILE = open(LOG_FILE_NAME, "a+")


def write_log(msg):
  now = datetime.datetime.now()
  msg = "%s %s: %s " % (now, SCRIPT, msg)
  SOCK.sendto(bytes(msg, "utf-8"), (UDP_IP, UDP_PORT))
  print(msg, file=LOG_FILE)



sample_sheet = SampleSheet(sys.argv[1])
write_log("INFO: Checking SampleSheet %s" % sys.argv[1])

# first create all index length tuples
index_tuples = set()
for sample in sample_sheet:
    index_length = len(sample.index.replace("N",""))

    if sample.index2:
        index2_length = len(sample.index2.replace("N",""))
    else:
        index2_length = 0

    index_tuples.add((index_length, index2_length))


# then check if we have index combinations we cannot handle
# if there are more than one combination, we abort as a custom sample sheet is required
if len(index_tuples) is not 1:
    write_log("INFO: Unsupported use case: multiple index combinations")
    exit(1)

# there is only a single index combination
index_tuple = index_tuples.pop()
# if the second index is 0 we are fine
if index_tuple[1] is 0:
    write_log("INFO: Second index is missing... all good.")
    exit(0)

if index_tuple[0] is not index_tuple[1]:
    write_log("INFO: Unsupported use case: indexes with different length")
    exit(1)

write_log("INFO: Indexes have same length... all good.")


LOG_FILE.close()
