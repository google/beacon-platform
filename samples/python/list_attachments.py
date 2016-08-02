#!/usr/bin/env python

# Copyright (C) 2015 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import argparse
import base64
import pbapi
import json


def main():
    parser = argparse.ArgumentParser(description='Lists known attachments for this beacon/project.')
    parser.add_argument('creds',
                        help='Path to JSON file containing service account credentials authorized to call the Google Proximity Beacon API')
    parser.add_argument('beacon_name', nargs='?',
                        help='Optional beacon name to list attachments for. Otherwise, lists all attachments for all beacons under this project.')

    args = parser.parse_args()

    creds = args.creds
    pb_client = pbapi.build_client_from_json(creds)

    beacon_name = args.beacon_name

    if beacon_name is None:
        beacons = pb_client.list_beacons()
        beacon_names = map(lambda b: b['beaconName'], beacons)
    else:
        beacon_names = [beacon_name]

    for beacon in beacon_names:
        attachments = pb_client.list_attachments(beacon, '*/*')
        print("Attachments for beacon '%s':" % beacon)

        if attachments is not None:
            for attachment in attachments:
                attachment['data'] = base64.b64decode(attachment['data'])
                print("\t%s" % json.dumps(attachment))
        else:
            print('\tNone')
    
if __name__ == "__main__":
    main()

