# Proximity Beacon API Scripts

This is not an official Google product

## Introduction

These scripts provide a wrapper around the REST service for the [Proximity Beacon API](https://developers.google.com/beacons/proximity/guides)
 (PBAPI), Google's service for registering and monitoring beacons and related data. They are not meant to be a complete
 solution for interacting with the service, rather as a helper for some of the common functions and a starting point for
 building something greater.

Other tools for the PBAPI that have similar function include:
- The Beacon Tools apps ([Android](https://play.google.com/store/apps/details?id=com.google.android.apps.location.beacon.beacontools), [iOS](https://itunes.apple.com/us/app/beacon-tools/id1094371356))
- The [beacon management dashboard](https://developers.google.com/beacons/dashboard/)

## Getting Started

This project is based around the [Python Google API client](https://developers.google.com/api-client-library/python/)
for which you can find installation instructions [here](https://developers.google.com/api-client-library/python/start/installation).

You can install the specific package versions required via `pip install -r requirements.txt`

### Credentials and Authentication

The PBAPI is an authenticated service, and requires a Google developer project with an associated service client. At a
 high level, you can generate the required credentials via the following steps:

1. Create (or select) a project in the [developer console](https://console.developers.google.com).
2. Enable the Google Proximity Beacon API
3. From credentials, create a new 'Service account key'
4. Select the JSON key type
5. Save the key in a safe place, but preferably on the same filesystem as these scripts

This key should be of the following format (note that this is a _service account_ key, distinctly different from an
OAuth client ID):

    {
      "private_key_id": "123456789abcdefghijklmnop",
      "private_key": "-----BEGIN PRIVATE KEY-----\nENCRYPTEDKEY-----END PRIVATE KEY-----\n",
      "client_email": "1234567890-exampleserviceaccount1234567890@developer.gserviceaccount.com",
      "client_id": "1234567890-exampleserviceaccount1234567890.apps.googleusercontent.com",
      "type": "service_account"
    }

**_NEVER CHECK THIS FILE INTO VERSION CONTROL! ADD TO .gitignore IMMEDIATELY!_**

The client also supports these credentials in p12 format, as well as temporary OAuth access tokens.

## Running

The `pb-cli.py` script wraps most of the methods into a CLI-like tool. It follows the form of:

    pb-cli.py {global opts} [command] {command-specific opts}

`{global opts}` are almost exclusively around authentication. See `pb-cli.py --help` for more details, `pb-cli.py 
--list-commands` for a list of which PBAPI methods are supported, or `pb-cli.py [command] --help` for usage details on 
a specific method.
 
### Examples

#### List names of all beacons owned by a service account

    $ pb-cli.py --service-account-creds ./creds.json list-beacons --names-only
    beacons/3!12345678901234567890123456789012
    beacons/3!abcdefabcdefabcdefabcdefabcdefab
    beacons/3!abcdef1234567890abcdef1234567890
    *snip*

#### List names of all beacons owned by a different project

This scenario requires that the service account client email has been given an appropriate PBAPI IAM role in 
`my-beacon-project`. A more common scenario is that your developer account (e.g., name@gmail.com) has been granted this 
IAM role (e.g., by joining a Google Group). In that case, substitute `--service-account-creds <creds file>` with 
`--access-token <access token>`, using an OAuth token tied to you developer account and a projec that has the PBAPI 
enabled.

    $ pb-cli.py --service-account-creds ./creds.json list-beacons --names-only --project-id my-beacon-project
    beacons/3!12345678901234567890123456789012
    beacons/3!abcdefabcdefabcdefabcdefabcdefab
    beacons/3!abcdef1234567890abcdef1234567890
    *snip*
    
#### Register a beacon

    $ ./pb-cli.py --service-account-creds ./creds.json register-beacon --beacon-json '{"advertisedId":{"type":"EDDYSTONE","id":"<id>"},"status":"ACTIVE"}'
    *snip*
    
Note that `<id>` is expected to be already encoded [as expected by the API](https://developers.google.com/beacons/proximity/reference/rest/v1beta1/AdvertisedId).
 If you have a 32-byte UUID-like string (e.g., 'abcdef1234567890abcdef1234567890'), you can generate the encoded ID 
 with the following one-liner:

    $ id='abcdef1234567890abcdef1234567890'; python -c "import binascii; import base64; print base64.b64encode(binascii.unhexlify('$id'))"

#### Create an attachment

Since attachments in the PBAPI have only two user-settable fields, the `create-attachment` method accepts these 
straight on the command line. A couple of important notes for `create-attachment`:

* Specifying `--project-id <ID>` dictates the owning project of the **attachment**, not of the beacon.
* If you need to create an attachment on a beacon you don't own, ensure that your authenticated user has been grated 
an IAM role for attachment editing in the owning project. _You may need to contact the project's owner for this._
* Beacon names include an exclamation point, which is a special shell-expansion character. Be sure to properly quote 
or escape.

```
$ pb-cli.py --service-account-creds ./creds.json create-attachment \
    --beacon-name 'beacons/3!12345678901234567890123456789012' \
    --namespaced-type my-beacon-project/json \
    --data '{"key":"value"}'
```

#### Look up and set place IDs for beacons

The pbapi module includes a helper function for looking up a place ID and associating it with a beacon. If you 
already have a beacon name to place ID mapping, this function can also handle the updates for you. In order to do the
 lookup though, you must have a valid [Google Maps API key](https://developers.google.com/maps/web/). 

The `set-places` method takes in the path to a CSV file that has a `beacon_name` field and a location. The location 
field can be one of `place_id`, `latitude,longitude`, or `address`. All entries in the file must use the same 
location type.

For example, if we knew the lat/long for all of our beacons, we might have an input CSV that looks like:

    beacon_name,latitude,longitude
    beacons/3!12345678901234567890123456789012,47.6489529,-122.3508952
    beacons/3!abcdefabcdefabcdefabcdefabcdefab,47.6487529,-122.3509592
    beacons/3!abcdef1234567890abcdef1234567890,47.649585,-122.350420

`set-places` will lookup the closest place to these coordinates (in this case, Google Seattle for all three), and 
update the beacon with that place ID:

    $ pb-cli.py --service-account-creds ./creds.json set-places --source-csv ./beacon-places.csv --maps-api-key <API KEY>
    *snip*
    

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

