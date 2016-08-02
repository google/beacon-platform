# Proximity Beacon API Scripts

This is not an official Google product

## Introduction

These scripts provide a wrapper around the REST service for the [Proximity Beacon API](https://developers.google.com/beacons/proximity/guides) (PBAPI), Google's service for registering and monitoring beacons and related data. They are not meant to be a complete solution for interacting with the service, rather as a helper for some of the common functions and a starting point for building something greater.

Other tools for the PBAPI that have similar function include:
- The Beacon Tools apps ([Android](https://play.google.com/store/apps/details?id=com.google.android.apps.location.beacon.beacontools), [iOS](https://itunes.apple.com/us/app/beacon-tools/id1094371356))
- The [beacon management dashboard](https://developers.google.com/beacons/dashboard/)

## Getting Started

This project is based around the [Python Google API client](https://developers.google.com/api-client-library/python/) for which you can find installation instructions [here](https://developers.google.com/api-client-library/python/start/installation).

You can install the specific package versions required via `pip install -r requirements.txt`

### Credentials and Authentication

The PBAPI is an authenticated service, and requires a Google developer project with an associated service client. At a high level, you can generate the required credentials via the following steps:

1. Create (or select) a project in the [developer console](https://console.developers.google.com).
2. Enable the Google Proximity Beacon API
3. From credentials, create a new 'Service account key'
4. Select the JSON key type (ostensibly these scripts work with the P12 script type, but they're better tested with JSON)
5. Save the key in a safe place, but preferably on the same filesystem as these scripts

This key should be of the following format (note that this is a _service account_ key, distinctly different from an OAuth client ID):

    {
      "private_key_id": "123456789abcdefghijklmnop",
      "private_key": "-----BEGIN PRIVATE KEY-----\nENCRYPTEDKEY-----END PRIVATE KEY-----\n",
      "client_email": "1234567890-exampleserviceaccount1234567890@developer.gserviceaccount.com",
      "client_id": "1234567890-exampleserviceaccount1234567890.apps.googleusercontent.com",
      "type": "service_account"
    }

**_NEVER CHECK THIS FILE INTO VERSION CONTROL! ADD TO .gitignore IMMEDIATELY!_**

## Running

Each of the major functions of the PBAPI have been pulled out into their own scripts: listing beacons, listing attachments, creating attachments, etc.

In almost all cases, each script requires as its first argument the path to the previously downloaded credentials JSON file. See each script's `--help` option for specific usage information.

License
=======

    Copyright 2016 Google, Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

