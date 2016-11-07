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
    parser = argparse.ArgumentParser(description=
                                     'Creates and adds an attachment to a beacon')
    parser.add_argument('--access-token',
                        required=True,
                        help='Access token for interacting with the API. Must be tied to a project that has activated the Proximity Beacon API')
    parser.add_argument('--beacon-name',
                        required=True,
                        help='Name of the beacon to attach to. Format is "beacons/N!<beacon ID>"')
    parser.add_argument('--attachment-data',
                        required=True,
                        help='Un-encoded data for the attachment')
    parser.add_argument('--namespaced-type',
                        required=True,
                        help='In the from of "namespace/type" for the attachment. Namespace is most likely your project ID')
    parser.add_argument('--project-id',
                        required=False,
                        help='ID for the project ')

    args = parser.parse_args()

    access_token = args.access_token
    pb_client = pbapi.build_client_from_access_token(access_token)

    pb_client.add_attachment(args.beacon_name, args.namespaced_type, args.attachment_data, args.project_id)

if __name__ == "__main__":
    main()
