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

REQUIRED_FIELDS = [
    'url',
    'title',
    'description'
]

RECOMMENDED_FIELDS = [

]

NEARBY_NS_TYPE = 'com.google.nearby/en'

IDEAL_TITLE_DESC_MAX = 40
HARD_TITLE_DESC_MAX = 50


def main():
    parser = argparse.ArgumentParser(description=
                                     'Creates and adds an attachment to a beacon and verifies it to be a valid Nearby Notifications attachment')
    parser.add_argument('creds',
                        help='Path to JSON file containing service account credentials authorized to call the Google Proximity Beacon API')
    parser.add_argument('beacon_name',
                        help='Name of the beacon to attach to. Format is "beacons/N!<beacon ID>"')
    parser.add_argument('attachment',
                        help='Path to the JSON file of the attachment to add (data only)')

    args = parser.parse_args()

    creds = args.creds
    pb_client = pbapi.build_client_from_json(creds)

    print('Checking that "{}" is registered with current project'
          .format(args.beacon_name))
    beacons = pb_client.list_beacons()
    beacon_names = map(lambda b: b['beaconName'], beacons)
    if args.beacon_name not in beacon_names:
        print('Beacon name {} not registered yet. Please register it first.'
              .format(args.beacon_name))
        exit(1)

    attachment_file = args.attachment
    print('Reading attachment from "{}" and verifying fields'
          .format(attachment_file))
    with open(args.attachment, 'r') as data_file:
        attachment = json.load(data_file)

    print('Checking attachment for required fields.')
    for field in REQUIRED_FIELDS:
        if field not in attachment:
            print('[ERROR] Nearby requires "{}" field in attachment json, but was not found.'
                  .format(field))
            exit(1)

    print('Checking attachment for recommended fields.')
    for field in RECOMMENDED_FIELDS:
        if field not in attachment:
            print('[WARN] "{}" is recommended to have in a Nearby attachment, but was not found.'
                  .format(field))

    print('Checking title + description length')
    title_desc_len = 0
    if 'title' in attachment:
        title_desc_len += len(attachment['title'])
    if 'description' in attachment:
        title_desc_len += len(attachment['description'])

    if title_desc_len > HARD_TITLE_DESC_MAX:
        print('[ERROR] Title + Description length surpassed hard max of {}. Values given: "{} - {}" (length: {})'
              .format(HARD_TITLE_DESC_MAX, attachment['title'], attachment['description'], title_desc_len))
        exit(1)

    if title_desc_len > IDEAL_TITLE_DESC_MAX:
        print('[WARN] Title + Description length greater than soft max of {}. Values given: "{} - {}" (length: {})'
              .format(IDEAL_TITLE_DESC_MAX, attachment['title'], attachment['description'], title_desc_len))

    # Add attachment to beacon
    print('Adding attachment to "' + args.beacon_name + '"')
    pb_client.add_attachment(args.beacon_name, NEARBY_NS_TYPE, json.dumps(attachment))


if __name__ == "__main__":
    main()
