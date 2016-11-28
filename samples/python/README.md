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

For all other dependencies, just run setup.py:

  python setup.py install

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

Once installed, the primary entry point is via the `pb-cli` command. Its arguments follow this pattern:

    pb-cli {global opts} [command] {command-specific opts}

`{global opts}` are almost exclusively around authentication. See `pb-cli --help` for more details, `pb-cli 
--list-commands` for a list of which PBAPI methods are supported, or `pb-cli [command] --help` for usage details on 
a specific method.

### List names of all beacons owned by a service account

    $ pb-cli --service-account-creds ./creds.json list-beacons --names-only
    beacons/3!12345678901234567890123456789012
    beacons/3!abcdefabcdefabcdefabcdefabcdefab
    beacons/3!abcdef1234567890abcdef1234567890
    *snip*

### List names of all beacons owned by a different project

This scenario requires that the service account client email has been given an appropriate PBAPI IAM role in 
`my-beacon-project`. A more common scenario is that your developer account (e.g., name@gmail.com) has been granted this 
IAM role (e.g., by joining a Google Group). In that case, substitute `--service-account-creds <creds file>` with 
`--access-token <access token>`, using an OAuth token tied to you developer account and a projec that has the PBAPI 
enabled.

    $ pb-cli --service-account-creds ./creds.json list-beacons --names-only --project-id my-beacon-project
    beacons/3!12345678901234567890123456789012
    beacons/3!abcdefabcdefabcdefabcdefabcdefab
    beacons/3!abcdef1234567890abcdef1234567890
    *snip*

### Filter beacon list by query

The PB CLI also supports filtering beacons by the given values. Status (`--status`) and property key/values
(`--property`) are first-class options, but you can also give arbitrary query strings as specified by the 
[beacons.list](https://developers.google.com/beacons/proximity/reference/rest/v1beta1/beacons/list) API documentation.

For example, the following will return only the active beacons:

  $ pb-cli --service-account-creds ./creds.json list-beacons --status active

And the following command will return the beacons that have places set in the Seattle area:

  $ pb-cli --service-account-creds ./creds.json list-beacons --query 'city:"Seattle"'
    
### Register a beacon

    $ pb-cli --service-account-creds ./creds.json register-beacon --beacon-json '{"advertisedId":{"type":"EDDYSTONE","id":"<id>"},"status":"ACTIVE"}'
    *snip*
    
Note that `<id>` is expected to be already encoded [as expected by the API](https://developers.google.com/beacons/proximity/reference/rest/v1beta1/AdvertisedId).
 If you have a 32-byte UUID-like string (e.g., 'abcdef1234567890abcdef1234567890'), you can generate the encoded ID 
 with the following one-liner:

    $ id='abcdef1234567890abcdef1234567890'; python -c "import binascii; import base64; print base64.b64encode(binascii.unhexlify('$id'))"

If the beacon is an iBeacon `register-beacon` will decode the ID to separate out the Proximity UUID and the 
major/minor IDs. For each of these, it will add properties to the beacon: `ibeacon_uuid`, `ibeacon_major`, and 
`ibeacon_minor`. To turn off this feature, specify the `--no-ibeacon-props` option.

### Create an attachment

Since attachments in the PBAPI have only two user-settable fields, the `create-attachment` method accepts these 
straight on the command line. A couple of important notes for `create-attachment`:

* Specifying `--project-id <ID>` dictates the owning project of the **attachment**, not of the beacon.
* If you need to create an attachment on a beacon you don't own, ensure that your authenticated user has been grated 
an IAM role for attachment editing in the owning project. _You may need to contact the project's owner for this._
* Beacon names include an exclamation point, which is a special shell-expansion character. Be sure to properly quote 
or escape.

```
$ pb-cli --service-account-creds ./creds.json create-attachment \
    --beacon-name 'beacons/3!12345678901234567890123456789012' \
    --namespaced-type my-beacon-project/json \
    --data '{"key":"value"}'
```

### Look up and set place IDs for beacons

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

    $ pb-cli --service-account-creds ./creds.json set-places --source-csv ./beacon-places.csv --maps-api-key <API KEY>
    *snip*

Note that in particularly dense locations or in cases where multiple places share the same address (e.g., malls), 
this may not return the desired Place ID. It's recommended that you spot check these in the [Beacon Dashboard](https://developers.google.com/beacons/dashboard). 

### Bulk Register Beacons

Using `pb-cli`, you can register a set of beacons using a single command. For example:

    $ pb-cli --service-account-creds ./creds.json bulk-register --source-csv ./beacons.csv
    
The input CSV file must at minimum have an ID field (i.e., the broadcast ID of the beacon), but can contain any 
number of fields. The primary [Beacon Resource fields](https://developers.google.com/beacons/proximity/reference/rest/v1beta1/beacons#Beacon)
are expected to be in snake_case and are individually set if available. Any remaining, unknown fields (e.g., custom 
fields like `store_name`) are included as keys in the beacon's `properties` map.

For example, suppose `beacons.csv` has the following contents:

    id,latitude,longitude,indoor_level,description,tx_power
    12345678901234567890123456789012,47.6489529,-122.3508952,1,Entry way,-40 dBm
    abcdefabcdefabcdefabcdefabcdefab,47.6487529,-122.3509592,2,Second floor cafe,-20 dBm
    abcdef1234567890abcdef1234567890,47.649585,-122.350420,3,Desk,-60 dBm

The first beacon would be created as:

```
{
    'beaconName': 'beacons/3!12345678901234567890123456789012',
    'advertisedId': {
        'id': 'EjRWeJASNFZ4kBI0VniQEg==',
        'type': 'EDDYSTONE'
    },
    'status': 'ACTIVE',
    'expectedStability': 'STABLE',
    'latLng': {
        'latitude': 47.6489529,
        'longitude': -122.3508952
    },
    'indoorLevel': {
        'name': '1'
    },
    'description': 'Entry way',
    'properties': {
        'tx_power': '-40 dBm'
    }
}
```

The `bulk-register` command can also register iBeacons. It will perform the proper encoding of the UUID, Major, and 
Minor IDs and set these as additional properties. For example, given the following input CSV:

    type,uuid,major,minor
    IBEACON,12345678-9012-3456-7890-123456789012,111,222

`bulk-register` would create the following beacon:

```
{
    'beaconName': 'beacons/1!12345678901234567890123456789012006f00de'
    'advertisedId': {
        'type': 'IBEACON',
        'id': 'EjRWeJASNFZ4kBI0VniQEgBvAN4='
    },
    'status': 'ACTIVE',
    'expectedStability': 'STABLE',
    'properties': {
        'ibeacon_major': '111',
        'ibeacon_uuid': '12345678901234567890123456789012',
        'ibeacon_minor': '222'
    }
}
```

Finally, `bulk-register` can also make use of the same facilities as the `set-places` command. That is, by supplying 
`--set-places` and a Google Maps API key as part of the `bulk-register` command, an address or lat/long will be 
parsed out of the input CSV and used to look up a plausible Google Maps Place ID.

See `pb-cli bulk-register --help` for additional information.

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

