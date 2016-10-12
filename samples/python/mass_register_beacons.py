#!/usr/bin/env python

# Copyright (C) 2016 Google Inc.
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
import csv
import binascii
import base64


def main():
    # TODO hook this into pb-cli.py
    parser = argparse.ArgumentParser(description='Registers a beacon to the authenticated project')
    parser.add_argument('--access-token', required=True, help='Access token authorized to use the PBAPI')
    parser.add_argument('--csv-beacons', required=True, help='Path to CSV file with ')
    parser.add_argument('--project-id', required=True, help='Which project should own these beacons.')

    args = parser.parse_args()
    token = args.access_token
    beacons_csv = args.csv_beacons
    project = args.project_id
    print 'attempting to use project ' + project

    pb_client = pbapi.build_client_from_access_token(token)

    print 'reading from ' + beacons_csv
    with open(beacons_csv) as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            beacon = get_beacon_from_csv_row(row)
            response = pb_client.register_beacon(beacon, project)
            print 'Registering beacon: ' + json.dumps(beacon)

            if 'beaconName' in response:
                print('Registered beacon: {}'.format(response['beaconName']))
            else:
                print('Unable to register beacon')


def get_beacon_from_csv_row(row):
    """
    This method should be customized to your application, depending on how your input CSV is formatted. It's
    certainly possible to format your CSV in a way that doesn't require this function at all. In which case this is
    just here as an example.

    :param row: a dict object containing the fields of the beacon.
    :return: a dict following the beacon object format required for the PBAPI
    """
    return {
        'advertisedId': {
            'type': 'EDDYSTONE',
            'id': encode_id(row['Namespace ID'] + row['Instance ID'])
        },
        'status': 'ACTIVE',
        'expectedStability': 'STABLE',
        'latLng': {
            'latitude': row['Latitude'],
            'longitude': row['Longitude']
        },
        'indoorLevel': {
            'name': row['Indoor Floor Level']
        },
        'description': row['Text Descr'],
        'properties': {
            'interval': row['Interval'],
            'tx-power': row['TX Power'],
            'eddystone-url': row['Eddystone URL'],
            'ibeacon-uuid': row['Proximity UUID'],
            'ibeacon-major': row['Major'],
            'ibeacon-minor': row['Minor']
        }
    }

def encode_id(beacon_id):
    """
    Encodes a hex ID to the expected format for the PBAPI -- that is, base64 encoding of the binary byte-stream.

    :param beacon_id: The hex ID
    :return: the encoded ID.
    """
    return base64.b64encode(binascii.unhexlify(beacon_id))

def decode_id(advertised_id):
    """
    Reverse of encode_id: takes an AdvertisedId from the PBAPI (only 'id' field) and decodes to a hex-ID.

    :param advertised_id: the ID to decode.
    :return: the decoded hex ID
    """
    return binascii.hexlify(base64.b64decode(advertised_id))


if __name__ == "__main__":
    main()
