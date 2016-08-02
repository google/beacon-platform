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
    parser = argparse.ArgumentParser(description='Lists all beacon ')
    parser.add_argument('creds',
                        help='Path to JSON file containing service account credentials authorized to call the Google Proximity Beacon API')
    parser.add_argument('--names-only', action='store_true', help='Only output names, rather than full JSON')
    args = parser.parse_args()

    creds = args.creds
    pb_client = pbapi.build_client_from_json(creds)
        
    beacons = pb_client.list_beacons()

    if args.names_only:
        beacon_names = map(lambda b: b['beaconName'], beacons)
        for beacon in beacon_names:
            print(beacon)
    else:
        for beacon in beacons:
            print(json.dumps(beacon))
    
if __name__ == "__main__":
    main()

