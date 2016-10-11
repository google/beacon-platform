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

"""
pbapi is a set of wrappers around the REST API for the Google Proximity Beacon API. These wrappers
are not meant to be a complete solution for interacting with the service, rather as a helper for
some of the common functions and a starting point for building something greater.
"""

import json
import base64
import argparse
import urllib2

from oauth2client.service_account import ServiceAccountCredentials
from oauth2client.client import AccessTokenCredentials
from httplib2 import Http
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

__author__ = 'afitzgibbon@google.com (Andrew Fitz Gibbon)'

# Debug controls, for now, whether API responses are printed to stdout when received.
DEBUG = False

# Except maybe for 'API version', these shouldn't ever change.
PROXIMITY_API_NAME = 'proximitybeacon'
PROXIMITY_API_VERSION = 'v1beta1'
PROXIMITY_API_SCOPE = 'https://www.googleapis.com/auth/userlocation.beacon.registry'


def build_client_from_access_token(token):
    """
    Creates and returns a PB API client using a raw access token.
    """
    client = PbApi()
    return client.build_from_access_token(token)


def build_client_from_json(creds):
    """
    Creates and returns a PB API client using the path to a service account's key stored as JSON
    """
    client = PbApi()
    return client.build_from_json(creds)


def build_client_from_p12(creds, client_email):
    """
    Creates and returns a PB API client using the path to a service account's key stored as .p12.

    Args:
        creds:
            file path to the key for this service client.
        client_email:
            email identifier for this service client. Usually of the form '123456789000-abc123def456@developer.gserviceaccount.com'
    """
    client = PbApi()
    return client.build_from_p12(creds, client_email)


class PbApi(object):
    """
    The core class for interacting with the various Proximity Beacon API methods.
    """
    _client = None

    def __init__(self, client=None):
        """
        Args:
            client:
                If a googleapiclient has already been created, use this one instead of creating a
                new one.
        """
        if client is not None:
            self._client = client

    def get_beacon(self, arguments):
        """
        Searches for the given beacon

        Args:
            arguments: list of arguments passed from CLI. Pass ['--help'] for details.

        Returns:
            the beacon
        """
        args_parser = argparse.ArgumentParser(description='Gets the beacon with the specified name',
                                              prog='get-beacon')
        args_parser.add_argument('--project-id',
                                 help='Google developer project ID that owns the beacon')
        args_parser.add_argument('--beacon-name',
                                 help='Name of the beacon to get. Format is "beacons/N!<beacon ID>"')
        args_parser.add_argument('--print-results',
                                 action='store_true', default=False, help='Print to stdout the result.')
        args = args_parser.parse_args(arguments)

        beacon = self._client.beacons() \
            .get(beaconName=args.beacon_name, projectId=args.project_id) \
            .execute()

        if args.print_results:
            if type(beacon) is dict:
                print(json.dumps(beacon))
            else:
                print(beacon)
        else:
            return beacon

    def update_beacon(self, beacon):
        """
        Updates the given beacon in the PB API. Note: must be a full beacon object following the read, modify, write pattern.

        This method is not designed for use from the command line.

        Args:
            beacon: full beacon object to update.

        Returns: the updated beacon
        """
        if not beacon or 'beaconName' not in beacon:
            print '[ERROR] Given beacon must be a full beacon object with, at minimum, the beaconName identifier.'
            return

        return self._client.beacons() \
            .update(beaconName=beacon['beaconName'], body=beacon) \
            .execute()

    def list_beacons(self, arguments):
        """
        Get all beacons registered with this client.

        Args:
            arguments: list of arguments passed from CLI. Pass ['--help'] for details.

        Returns:
            List of objects representing the beacons. For a description of all
            fields, see https://developers.google.com/beacons/proximity/reference/rest/v1beta1/beacons#Beacon
        """
        args_parser = argparse.ArgumentParser(description='Lists beacons with the associated creds and project',
                                              prog='list-beacons')
        args_parser.add_argument('--project-id',
                                 help='Google developer project ID that owns the beacons')
        args_parser.add_argument('--names-only',
                                 action='store_true',
                                 help='Only return the names of the beacons')
        args_parser.add_argument('--print-results',
                                 action='store_true', default=False, help='Print to stdout the result.')
        args = args_parser.parse_args(arguments)

        request = self._client.beacons() \
            .list(projectId=args.project_id)

        beacons = []
        next_page_token = None
        while request is not None:
            if DEBUG:
                print 'Requesting more beacons'
            beacons_resp = request.execute()

            if DEBUG:
                print 'Current next token: {}\nNew next token: {}' \
                    .format(next_page_token, beacons_resp['nextPageToken'])
            if next_page_token is not None and beacons_resp['nextPageToken'] == next_page_token:
                break
            next_page_token = beacons_resp['nextPageToken']

            if 'beacons' in beacons_resp:
                if DEBUG:
                    print 'Got {} beacons: '.format(len(beacons_resp['beacons']))
                beacons += beacons_resp['beacons']
            request = self._client.beacons().list_next(request, beacons_resp)

        if DEBUG:
            print 'Got beacons: {}'.format(beacons)

        if args.names_only:
            beacons = map(lambda b: b['beaconName'], beacons)

        if args.print_results:
            for beacon in beacons:
                if type(beacon) is dict:
                    print(json.dumps(beacon))
                else:
                    print(beacon)
        else:
            return beacons

    def register_beacon(self, arguments):
        """
        Registers a beacon with the given data. This method will fail if the beacon
        already exists. Example JSON for a beacon is as follows (not all fields are required):

             {
              "advertisedId": {
                "type": "EDDYSTONE",
                "id": "1ZHr0aBOYe+hF+2ZlCXy8A=="
              },
              "status": "ACTIVE",
              "placeId": "ChIJFfPv7ZYys1IRra2cAf_PkZU",
              "latLng": {
                "latitude": "44.974874",
                "longitude": "-93.2744246"
              },
              "indoorLevel": {
                "name": "2"
              },
              "expectedStability": "STABLE",
              "description": "2nd Floor Store Threshold.",
              "properties": {
                "position": "entryway"
              }
            }

        For a description of all fields, see
            https://developers.google.com/beacons/proximity/reference/rest/v1beta1/beacons#Beacon

        Args:
            arguments: list of arguments passed from CLI. Pass ['--help'] for details.

        Returns:
            JSON representing the beacon. Same as above, but with the added
            "beaconName" field.
        """
        args_parser = argparse.ArgumentParser(description='Registers the given beacon to the specified project',
                                              prog='register-beacon')
        args_parser.add_argument('--project-id',
                                 help='Google developer project ID that will own the beacon')
        args_parser.add_argument('--ibeacon-props',
                                 action='store_true', default=True,
                                 help='If beacon.advertisedId.type is IBEACON, parse out the UUID, major, minor IDs ' +
                                      'and create matching ibeacon_ properties for each.')
        args_parser.add_argument('--print-results',
                                 action='store_true', default=False, help='Print to stdout the result.')
        beacon_arg_group = args_parser.add_mutually_exclusive_group(required=True)
        beacon_arg_group.add_argument('--beacon-json-file',
                                      help='Path to a plain-text JSON file containing the beacon\'s description')
        beacon_arg_group.add_argument('--beacon-json',
                                      help='JSON string representing the beacon')

        args = args_parser.parse_args(arguments)

        if args.beacon_json_file:
            with open(args.beacon_json_file, 'r') as beacon_file:
                beacon = json.load(beacon_file)
        elif args.beacon_json:
            beacon = json.loads(args.beacon_json)
        else:
            raise ValueError('Expected beacon definition, either in file or string, found neither.')

        # Perform some rudimentary input validation before sending off
        try:
            parsed_beacon = beacon
            if not isinstance(beacon, dict):
                parsed_beacon = json.loads(beacon)
            ad_id = parsed_beacon['advertisedId']
        except (ValueError, KeyError):
            raise ValueError('Expected input to be json str with, at minimum, advertisedId key')

        if ad_id['type'] == 'IBEACON' and args.ibeacon_props:
            import binascii
            raw_id = binascii.hexlify(base64.b64decode(ad_id['id']))
            ibeacon_uuid = raw_id[0:31]
            major = int(raw_id[-8:-4], 16)
            minor = int(raw_id[-4:], 16)

            beacon['properties']['ibeacon_uuid'] = str(ibeacon_uuid)
            beacon['properties']['ibeacon_major'] = major
            beacon['properties']['ibeacon_minor'] = minor

        try:
            request = self._client.beacons() \
                .register(body=beacon, projectId=args.project_id)

            response = request.execute()
        except HttpError, err:
            import pprint
            # pprint.pprint(err.resp)
            # pprint.pprint(json.dumps(err.content, sort_keys=True, indent=2))
            error = json.loads(err.content)
            if error['error']['status'] == 'ALREADY_EXISTS':
                raise ValueError('Beacon with ID of "%s" already exists.' % ad_id['id'])
            else:
                raise ValueError('Error registering beacon: %s' % json.dumps(error))

        if DEBUG:
            print json.dumps(response, sort_keys=True, indent=4)

        if args.print_results:
            print json.dumps(response, sort_keys=True, indent=4)
        else:
            return response

    def deactivate_beacon(self, arguments):
        """
        Deactivates a beacon.

        Args:
            arguments: list of arguments passed from CLI. Pass ['--help'] for details.

        Returns:
            Nothing
        """
        args_parser = argparse.ArgumentParser(description='Deactivates the given beacon',
                                              prog='deactivate-beacon')
        args_parser.add_argument('--project-id',
                                 help='Google developer project ID that will own the beacon')
        args_parser.add_argument('--beacon-name',
                                 required=True,
                                 help='Name of the beacon to deactivate')
        args_parser.add_argument('--print-results',
                                 action='store_true', default=False, help='Print to stdout the result.')
        args = args_parser.parse_args(arguments)

        response = self._client.beacons() \
            .deactivate(beaconName=args.beacon_name, projectId=args.project_id) \
            .execute()

        if args.print_results:
            print response
        else:
            return response

    def delete_beacon(self, arguments):
        """
        Deletes a beacon.

        Args:
            arguments: list of arguments passed from CLI. Pass ['--help'] for details.

        Returns:
            Nothing
        """
        args_parser = argparse.ArgumentParser(description='Deletes the given beacon',
                                              prog='delete-beacon')
        args_parser.add_argument('--project-id',
                                 help='Google developer project ID that will own the beacon')
        args_parser.add_argument('--beacon-name',
                                 required=True,
                                 help='Name of the beacon to delete')
        args_parser.add_argument('--print-results',
                                 action='store_true', default=False, help='Print to stdout the result.')
        args = args_parser.parse_args(arguments)

        response = self._client.beacons() \
            .delete(beaconName=args.beacon_name, projectId=args.project_id) \
            .execute()

        return response

    def create_attachment(self, arguments):
        """
        Adds an attachment to the specified beacon with the given namespace/type and
        data.

        Args:
            arguments: list of arguments passed from CLI. Pass ['--help'] for details.

        Returns:
            The attachment object as stored by the Proximity API. Current is JSON
            with the keys: attachmentName, data, namespaced_type.
        """
        args_parser = argparse.ArgumentParser(description='Adds an attachment to the specified beacon',
                                              prog='create-attachment')
        args_parser.add_argument('--project-id',
                                 help='Google developer project ID that will own the attachment')
        args_parser.add_argument('--beacon-name',
                                 required=True,
                                 help='Name of the beacon to add the attachment to')
        args_parser.add_argument('--namespaced-type',
                                 required=True,
                                 help='the namespace/type of the attachment. Typically something like ' +
                                      '\'project-name/json\' or \'project-name/xml\'')
        args_parser.add_argument('--data',
                                 required=True,
                                 help='Arbitrary String representing the content of the attachment. This ' +
                                      'will be base64 encoded. Should not contain namespace, attachment ' +
                                      'name, or anything other than the "body" of your attachment.')
        args_parser.add_argument('--print-results',
                                 action='store_true', default=False, help='Print to stdout the result.')
        args = args_parser.parse_args(arguments)

        encoded_data = base64.b64encode(args.data)

        # Beacon Attachments have an "attachmentName" field, but for creating one,
        # these are left off and generated server-side by the API.
        request_body = {'data': encoded_data, 'namespaced_type': args.namespaced_type}

        request = self._client.beacons() \
            .attachments() \
            .create(beaconName=args.beacon_name, body=request_body, projectId=args.project_id)

        response = request.execute()

        if DEBUG:
            print json.dumps(response, sort_keys=True, indent=4)

        return response

    def delete_attachment(self, arguments):
        """
        Deletes the attachment with the specified name

        Args:
            arguments: list of arguments passed from CLI. Pass ['--help'] for details.

        Returns:
            Nothing. See:
                https://developers.google.com/resources/api-libraries/documentation/proximitybeacon/v1beta1/python/latest/proximitybeacon_v1beta1.beacons.attachments.html#delete
        """
        args_parser = argparse.ArgumentParser(description='Deletes the given attachment',
                                              prog='delete-attachment')
        args_parser.add_argument('--project-id',
                                 help='Google developer project ID that owns the attachment')
        args_parser.add_argument('--attachment-name',
                                 required=True,
                                 help='Name of the attachment to delete')
        args_parser.add_argument('--print-results',
                                 action='store_true', default=False, help='Print to stdout the result.')
        args = args_parser.parse_args(arguments)

        self._validate_attachment_name(args.attachment_name)

        self._client.beacons() \
            .attachments() \
            .delete(attachmentName=args.attachment_name, projectId=args.project_id) \
            .execute()

    def list_attachments(self, arguments):
        """
        Retrieves the attachments, still base64 encoded, for the given beacon and namespace/type.

        Args:
            arguments: list of arguments passed from CLI. Pass ['--help'] for details.

        Returns:
            List of attachments. Each item is json with the keys: attachmentName,
            data, namespaced_type.
        """
        args_parser = argparse.ArgumentParser(description='Lists attachments on the given beacon',
                                              prog='list-attachments')
        args_parser.add_argument('--beacon-name',
                                 help='Optional beacon name to list attachments for. Otherwise, lists attachments ' +
                                      'for all beacons under the given project.')
        args_parser.add_argument('--project-id',
                                 help='Google developer project ID that owns the attachments')
        args_parser.add_argument('--beacon-project-id',
                                 help='Google developer project ID that owns the beacons')
        args_parser.add_argument('--namespaced-type',
                                 default='*/*',
                                 help='namespace/type of the attachments.')
        args_parser.add_argument('--print-results',
                                 action='store_true', default=False, help='Print to stdout the result.')
        args = args_parser.parse_args(arguments)

        if args.beacon_name is None:
            list_args = []
            if args.beacon_project_id is not None:
                list_args.append('--project-id')
                list_args.append(args.beacon_project_id)

            beacons = self.list_beacons(['--names-only'])
        else:
            beacons = [args.beacon_name]

        all_attachments = {}
        for beacon in beacons:
            request = self._client.beacons() \
                .attachments() \
                .list(beaconName=beacon, namespacedType=args.namespaced_type, projectId=args.project_id)

            attachments = request.execute()

            if DEBUG:
                print json.dumps(attachments, sort_keys=True, indent=4)

            if 'attachments' in attachments:
                attachments = attachments['attachments']
            else:
                attachments = []

            all_attachments[beacon] = attachments

        if args.print_results:
            for beacon in all_attachments.keys():
                print("Attachments for beacon '%s':" % beacon)

                for attachment in all_attachments[beacon]:
                    attachment['data'] = base64.b64decode(attachment['data'])
                    print("\t%s" % json.dumps(attachment))
        else:
            return all_attachments

    def set_places(self, arguments):
        """
        Given a file with beacon_id{sep}address, find the matching place ID and update the PBAPI record with it.

        Args:
            arguments: list of arguments passed from CLI. Pass ['--help'] for details.

        Returns:
            Nothing.
        """
        args_parser = argparse.ArgumentParser(description='Updates the Place IDs for the given beacon,location pairs.',
                                              prog='set-places')
        args_parser.add_argument('--source-csv', metavar='PATH',
                                 required=True,
                                 help='Path to CSV containing beacon,location tuples. Must contain a `beacon_name` ' +
                                      'key and one of place_id; latitude,longitude (both); or address.')
        args_parser.add_argument('--maps-api-key', metavar='API_KEY',
                                 help='Maps API key with which to call geocoder or places APIs. Must at minimum have ' +
                                      'the geocoder API active.')
        args_parser.add_argument('--print-results',
                                 action='store_true', default=False, help='Print to stdout the result.')
        args = args_parser.parse_args(arguments)

        beacon_location_csv = args.source_csv

        import csv
        with open(beacon_location_csv) as csvfile:
            reader = csv.DictReader(csvfile)

            if 'place_id' not in reader.fieldnames:
                if not args.maps_api_key:
                    print('[ERROR] Maps API key needed to decode addresses to place IDs.')
                    exit(1)

            for row in reader:
                beacon_name = None
                try:
                    beacon_name = row['beacon_name']
                except KeyError, err:
                    print('[ERROR] Count not get beacon ID from file. Please ensure source file has a beacon_name key.')
                    return

                place_id = None
                if 'place_id' in row:
                    place_id = row['place_id']
                elif 'latitude' in row and 'longitude' in row:
                    lat = row['latitude']
                    lng = row['longitude']
                    place_id = self._geocoder_to_placeid(args.maps_api_key, 'latlng', ','.join([lat, lng]))
                elif 'address' in row:
                    addr = row['address']
                    place_id = self._geocoder_to_placeid(args.maps_api_key, 'address', addr)
                else:
                    print('[WARN] No location key found for beacon id "%s"' % beacon_name)
                    continue

                if not place_id:
                    print('[WARN] Not able to find place ID for beacon "{}".'.format(beacon_name) +
                          'Please ensure the source file includes a place_id, address, or lat/long.')
                    continue

                beacon = self.get_beacon(['--beacon-name', beacon_name])
                print 'got beacon: {}'.format(beacon)
                if not beacon:
                    print('[WARN] beacon "{}" is not yet registered. Please register first.'.format(beacon_name))
                    continue
                else:
                    beacon['placeId'] = place_id
                    if DEBUG:
                        print('Updating beacon with place id "{}"'.format(place_id))
                    self.update_beacon(beacon)

    @staticmethod
    def _geocoder_to_placeid(api_key, type, value):
        """
        Calls the Google Maps Geocoder API to lookup a place ID for a given location.

        Args:
            api_key: Geocoder-enabled API key
            type: one of {address,latlng} indicating which type of lookup to perform.
            value: Either an address or a lat/long pair.

        Returns:
            a place id, if found.
        """
        value = urllib2.quote(value)
        geocode_url = 'http://maps.googleapis.com/maps/api/geocode/json?{}={}'.format(type, value)
        req = urllib2.urlopen(geocode_url)
        response = json.loads(req.read())

        place_id = None
        if response and response['status'] == 'OK':
            results = response['results']
            if len(results) > 0 and 'place_id' in results[0]:
                place_id = results[0]['place_id']
        elif 'error_message' in response:
            print '[ERROR] Failed to call geocoder: {}'.format(response['error_message'])
        else:
            print '[ERROR] Failed to call geocoder: {}'.format(response['status'])

        return place_id

    @staticmethod
    def _validate_attachment_name(name):
        """
        Does not guarantee that this is a valid attachment, or even a valid attachment name. Only
        validates that the given name has the expected structure. Destined to fail in the future
        if/when the PBAPI decides to change attachment names.
        """
        parts = name.split('/')

        expected_parts = 4
        # [0]: 'beacons'
        # [1]: beacon ID in form N!<id>
        # [2]: 'attachments'
        # [3]: UUID, including dashes

        if len(parts) != expected_parts:
            raise ValueError('Expected attachment name to contain {} parts; instead found {}'
                             .format(expected_parts, len(parts)))

        if parts[0] != 'beacons':
            raise ValueError('Expected attachment name to begin with "beacons"; instead found {}'
                             .format(parts[0]))

        # Trivial validation of beacon ID to avoid re-implementing PBAPI's advertised ID format
        if len(parts[1]) == 0:
            raise ValueError('Expected non-zero length for beacon ID.')

        if parts[2] != 'attachments':
            raise ValueError('Expected attachment name to include literal "attachments"; instead found {}'
                             .format(parts[2]))

        try:
            from uuid import UUID
            attach_id = UUID(parts[3], version=4)
        except ValueError:
            raise ValueError('Expected UUID-like string for attachment ID; instead found {}'
                             .format(parts[3]))

        return

    def build_from_access_token(self, access_token):
        """
        Instantiates the REST API client for the Proximity API. Full PyDoc for this
        client is available here: https://developers.google.com/resources/api-libraries/documentation/proximitybeacon/v1beta1/python/latest/index.html

        Args:
            access_token:
                a valid access token for the Proximity API.

        Returns:
            self, with a ready-to-use PB API client.
        """
        if self._client is not None:
            return self._client

        credentials = AccessTokenCredentials(access_token, 'python-api-client/1.0')

        http_auth = credentials.authorize(Http())
        self._client = build(PROXIMITY_API_NAME, PROXIMITY_API_VERSION, http=http_auth)

        return self

    def build_from_json(self, json_credentials):
        """
        Instantiates the REST API client for the Proximity API. Full PyDoc for this
        client is available here: https://developers.google.com/resources/api-libraries/documentation/proximitybeacon/v1beta1/python/latest/index.html

        Args:
            json_credentials:
                file path to the service credentials.

        Returns:
            self, with a ready-to-use PB API client.
        """
        if self._client is not None:
            return self._client

        credentials = ServiceAccountCredentials.from_json_keyfile_name(
            json_credentials, PROXIMITY_API_SCOPE)

        http_auth = credentials.authorize(Http())
        self._client = build(PROXIMITY_API_NAME, PROXIMITY_API_VERSION, http=http_auth)

        return self

    def build_from_p12(self, p12_keyfile, client_email):
        """
        Instantiates the REST API client for the Proximity API. Full PyDoc for this
        client is available here: https://developers.google.com/resources/api-libraries/documentation/proximitybeacon/v1beta1/python/latest/index.html

        Args:
            p12_keyfile:
                file path to the key for this service client.
            client_email:
                email identifier for this service client. Usually of the form '123456789000-abc123def456@developer.gserviceaccount.com'

        Returns:
            self, with a ready-to-use PB API client.
        """
        if self._client is not None:
            return self._client

        credentials = ServiceAccountCredentials.from_p12_keyfile(
            client_email, p12_keyfile, 'notasecret', PROXIMITY_API_SCOPE)

        http_auth = credentials.authorize(Http())
        self._client = build(PROXIMITY_API_NAME, PROXIMITY_API_VERSION, http=http_auth)

        return self
