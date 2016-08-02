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
import json
import pbapi


def main():
    parser = argparse.ArgumentParser(description='Registers a beacon to the authenticated project')
    parser.add_argument('creds',
                        help='Path to JSON file containing service account credentials authorized to call the Google Proximity Beacon API')
    parser.add_argument('beacon_file',
                        help='Path to JSON file containing the beacon description. See the following for a full list of fields: https://developers.google.com/beacons/proximity/reference/rest/v1beta1/beacons#Beacon')

    args = parser.parse_args()

    creds = args.creds
    pb_client = pbapi.build_client_from_json(creds)

    with open(args.beacon_file, 'r') as beacon_file:
        beacon = json.load(beacon_file)

    response = pb_client.register_beacon(beacon)

    if 'beaconName' in response:
        print('Registered beacon: {}'.format(response['beaconName']))
    else:
        print('Unable to register beacon')


if __name__ == "__main__":
    main()
