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

import os
import json
import base64
import argparse
import urllib2
import csv
import uuid
import binascii
import webbrowser
import hashlib

from oauth2client.service_account import ServiceAccountCredentials
from oauth2client.client import AccessTokenCredentials
from oauth2client.client import GoogleCredentials
from oauth2client.client import flow_from_clientsecrets
from oauth2client import file as oauth2file
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
DISCOVERY_URI = 'https://{api}.googleapis.com/$discovery/rest?version={apiVersion}'
CREDS_STORAGE = '~/.pb-cli/creds'


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

def build_client_from_client_id_json(creds):
    """
    Creates and returns a PB API client using the path to client id secrets stored as JSON
    """
    client = PbApi()
    return client.build_from_client_id_json(creds)


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


def build_client_from_app_default():
    """
    Creates and returns a PB API client using the environment's default authentication, typicaly
    managed via some variation of `gcloud beta auth application-default login`
    """
    client = PbApi()
    return client.build_from_app_default()


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

    def update_beacon(self, beacon, project_id):
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
            .update(beaconName=beacon['beaconName'], projectId=project_id, body=beacon) \
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
        args_parser.add_argument('--status',
                                 help='Only return beacons with the specified status. Default: all.')
        args_parser.add_argument('--query', '-q',
                                 help='Specify an arbitrary query string for the list filter. See the API reference '
                                      'for beacons.list for a list of all options. For example: `--query '
                                      '\'status:active property:"battery-type=CR2032"\'` This takes precedence '
                                      'over any other filter option (e.g., --status). Should not be URL-encoded -- '
                                      'this will be taken care of by the client.')
        args_parser.add_argument('--property',
                                 action='append',
                                 help='Filter the list to contain only beacon with the given property. Must be given '
                                      'in the form: "<key>=<value>". If given multiple times, they will be combined '
                                      'with OR.')
        args_parser.add_argument('--print-results',
                                 action='store_true', default=False, help='Print to stdout the result.')
        args = args_parser.parse_args(arguments)

        query_string = None
        if args.query:
            query_string = args.query
        elif args.status or args.property:
            if args.status:
                query_string = 'status:{}'.format(args.status)
            if args.property:
                properties = map(lambda p: 'property:"{}"'.format(p), args.property)
                property_string = ' '.join(properties)
                if query_string:
                    query_string += ' {}'.format(property_string)
                else:
                    query_string = property_string

        if DEBUG:
            print('Query string is: {}'.format(query_string))
        request = self._client.beacons() \
            .list(projectId=args.project_id, q=query_string)

        beacons = []
        next_page_token = None
        while request is not None:
            if DEBUG:
                print 'Requesting more beacons'
            beacons_resp = request.execute()

            if 'beacons' in beacons_resp:
                if DEBUG:
                    print 'Got {} beacons: '.format(len(beacons_resp['beacons']))
                beacons += beacons_resp['beacons']

            try: 
                if DEBUG:
                    print 'Current next token: {}\nNew next token: {}' \
                        .format(next_page_token, beacons_resp['nextPageToken'])
                if next_page_token is not None and beacons_resp['nextPageToken'] == next_page_token:
                    break
                next_page_token = beacons_resp['nextPageToken']
            except KeyError:
                break

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
        args_parser.add_argument('--no-ibeacon-props',
                                 action='store_false', dest='ibeacon_props',
                                 help='If beacon.advertisedId.type is IBEACON, parse out the UUID, major, minor IDs ' +
                                      'and create matching ibeacon_ properties for each.')
        args_parser.add_argument('--maps-api-key', metavar='API_KEY',
                                 help='Maps API key with which to call geocoder or places APIs. Must at minimum have ' +
                                      'the geocoder API active.')
        args_parser.add_argument('--set-latlng-from-place',
                                 action='store_true',
                                 help='If the given beacon data has no latitude/longitude but does have a place_id, ' +
                                      'call Google Places API to determine the center of the given place and use that ' +
                                      'as the latitude and longitude of the beacon. Requires a --maps-api-key.')
        args_parser.add_argument('--print-results',
                                 action='store_true', default=False, help='Print to stdout the result.')
        beacon_arg_group = args_parser.add_mutually_exclusive_group(required=True)
        beacon_arg_group.add_argument('--beacon-json-file',
                                      help='Path to a plain-text JSON file containing the beacon\'s description')
        beacon_arg_group.add_argument('--beacon-json',
                                      help='JSON string representing the beacon')
        args_parser.set_defaults(ibeacon_props=True)

        args = args_parser.parse_args(arguments)

        if args.beacon_json_file:
            with open(args.beacon_json_file, 'r') as beacon_file:
                beacon = json.load(beacon_file)
        elif args.beacon_json:
            beacon = json.loads(args.beacon_json)
        else:
            raise ValueError('Expected beacon definition, either in file or string, found neither.')

        if args.set_latlng_from_place and not args.maps_api_key:
            print('[FATAL] Requested to set lat/lng from the place, but no Maps API key given.')
            exit(1)

        # Perform some rudimentary input validation before sending off
        try:
            parsed_beacon = beacon
            if not isinstance(beacon, dict):
                parsed_beacon = json.loads(beacon)
            ad_id = parsed_beacon['advertisedId']
        except (ValueError, KeyError):
            raise ValueError('Expected input to be json str with, at minimum, advertisedId key')

        if ad_id['type'] == 'IBEACON' and args.ibeacon_props:
            raw_id = binascii.hexlify(base64.b64decode(ad_id['id']))
            ibeacon_uuid = raw_id[0:32]
            major = int(raw_id[-8:-4], 16)
            minor = int(raw_id[-4:], 16)

            beacon['properties']['ibeacon_uuid'] = str(ibeacon_uuid)
            beacon['properties']['ibeacon_major'] = str(major)
            beacon['properties']['ibeacon_minor'] = str(minor)

        # maybe derive lat/lng from the center of the place
        if args.set_latlng_from_place and 'placeId' in beacon:
            self.lat_lng_from_place(beacon, args.maps_api_key)

        try:
            request = self._client.beacons() \
                .register(body=beacon, projectId=args.project_id)

            response = request.execute()
        except HttpError, err:
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

    def activate_beacon(self, arguments):
        """
        Activates a beacon.

        Args:
            arguments: list of arguments passed from CLI. Pass ['--help'] for details.

        Returns:
            Nothing
        """
        args_parser = argparse.ArgumentParser(description='Activates the given beacon',
                                              prog='activate-beacon')
        args_parser.add_argument('--project-id',
                                 help='Google developer project ID that owns the beacon')
        args_parser.add_argument('--beacon-name',
                                 required=True,
                                 help='Name of the beacon to deactivate')
        args_parser.add_argument('--print-results',
                                 action='store_true', default=False, help='Print to stdout the result.')
        args = args_parser.parse_args(arguments)

        response = self._client.beacons() \
            .activate(beaconName=args.beacon_name, projectId=args.project_id) \
            .execute()

        if args.print_results:
            print response
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
        Given a file with beacon_ids and place_ids, add the place_ids to the beacon registrations.

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
                                      'key and a `place_id` key.')
        args_parser.add_argument('--project-id',
                                 help='Google developer project ID that owns the beacons')
        args_parser.add_argument('--print-results',
                                 action='store_true', default=False, help='Print to stdout the result.')
        args = args_parser.parse_args(arguments)

        beacon_location_csv = args.source_csv

        with open(beacon_location_csv) as csvfile:
            reader = csv.DictReader(csvfile)

            if 'place_id' not in reader.fieldnames:
                print('[ERROR] Input file must contain a `place_id` field!')
                exit(1)

            for row in reader:
                try:
                    beacon_name = row['beacon_name']
                except KeyError:
                    print('[ERROR] Count not get beacon ID from file. Please ensure source file has a beacon_name key.')
                    return

                place_id = row['place_id']
                if not place_id:
                    print('[WARN] Not able to find place ID for beacon "{}". Please ensure the source file includes a '
                          'place_id'.format(beacon_name))
                    continue

                beacon = self.get_beacon([
                    '--beacon-name', beacon_name,
                    '--project-id', args.project_id
                ])

                if not beacon:
                    print('[WARN] beacon "{}" is not yet registered. Please register first.'.format(beacon_name))
                    continue
                else:
                    beacon['placeId'] = place_id
                    if DEBUG:
                        print('Updating beacon with place id "{}"'.format(place_id))
                    self.update_beacon(beacon, args.project_id)

    def bulk_register(self, arguments):
        args_parser = argparse.ArgumentParser(description='Register beacons based on the contents of a CSV file. See '
                                                          'README for detailed usage information.',
                                              prog='bulk-register')
        args_parser.add_argument('--source-csv', metavar='PATH',
                                 required=True,
                                 help='Path to CSV containing the beacon description. Assumes that the CSV fields '
                                      'match the Beacon resource expected by the Proximity Beacon API itself. Any '
                                      'additional, unrecognizable fields are added as properties. Minimum required '
                                      'is "id." If unspecified, status is assumed to be ACTIVE, expectedStability is '
                                      'assumed to be STABLE, and type is assumed to be EDDYSTONE.')
        args_parser.add_argument('--type',
                                 help='Overrides any type in the source CSV. Expected as one of EDDYSTONE or IBEACON. '
                                      'If IBEACON, CSV must also contain uuid (or id), major, and minor fields.')
        args_parser.add_argument('--project-id',
                                 help='Google developer project ID that should own the beacons')
        # These next two args will pass through to the single-record register_beacon() method.
        args_parser.add_argument('--maps-api-key', metavar='API_KEY',
                                 help='Maps API key with which to call geocoder or places APIs. Must at minimum have ' +
                                      'the geocoder API active.')
        args_parser.add_argument('--set-latlng-from-place',
                                 action='store_true',
                                 help='Use the center of the place as the latitude and longitude of the beacon.')
        args_parser.add_argument('--dry-run',
                                 action='store_true',
                                 help='Don\'t actually register, but builds the beacon object from source-csv.')
        args_parser.add_argument('--print-results',
                                 action='store_true', default=False, help='Print to stdout the result.')
        args = args_parser.parse_args(arguments)

        if args.set_latlng_from_place and not args.maps_api_key:
            print('[FATAL] Requested to set lat/lng from the place, but no Maps API key given.')
            exit(1)

        with open(args.source_csv) as csvfile:
            reader = csv.DictReader(csvfile)

            if 'id' not in reader.fieldnames and 'uuid' not in reader.fieldnames:
                print('[FATAL] Beacon description must, at minimum, include an ID field (either "id" or "uuid")')
                return

            for row in reader:
                try:
                    if not args.type and 'type' not in row:
                        beacon_type = 'EDDYSTONE'
                    else:
                        beacon_type = row['type']
                        row.pop('type')

                    if beacon_type == 'IBEACON':
                        # Construct IBEACON ID
                        beacon_id = self._ibeacon_to_ad_id(row['uuid'], row['major'], row['minor'])
                        row.pop('uuid')
                        row.pop('major')
                        row.pop('minor')
                    else:
                        beacon_id = self._eddystone_to_ad_id(row['id'])
                        row.pop('id')

                    beacon = {
                        'advertisedId': {
                            'type': beacon_type,
                            'id': beacon_id
                        },
                        'expectedStability': 'STABLE',
                        'status': 'ACTIVE',
                        'properties': {}
                    }

                    for key in ('place_id', 'status', 'expectedStability', 'description'):
                        if key in row:
                            beacon[self.snake_to_camel(key)] = row[key]
                            row.pop(key)

                    if 'indoorLevel' in row:
                        beacon['indoorLevel'] = {
                            'name': row['indoorLevel']
                        }
                        row.pop('indoorLevel')

                    if 'latitude' in row and 'longitude' in row:
                        beacon['latLng'] = {
                            'latitude': row['latitude'],
                            'longitude': row['longitude']
                        }
                        row.pop('latitude')
                        row.pop('longitude')

                    # TODO ephemeralIdRegistration and provisioningKey

                    for key in row:
                        beacon['properties'][key] = row[key]

                    register_args = [
                        '--beacon-json', json.dumps(beacon)
                    ]

                    if args.project_id:
                        register_args += ['--project-id', args.project_id]
                    if args.set_latlng_from_place and args.maps_api_key:
                        register_args += [
                            '--set-latlng-from-place', 
                            '--maps-api-key', args.maps_api_key
                        ]


                    if args.dry_run:
                        print('Skipping beacause dry run. Would have registered beacon: {}'.format(register_args))
                    else:
                        # TODO batch these rather than one-off call every single one
                        self.register_beacon(register_args)

                except KeyError, err:
                    print('[FATAL] Unable to find expected key "{}" for beacon.'.format(err.message))
                    return
                except ValueError, err:
                    print('[WARN] Unable to create beacon object: {}'.format(err.message))
                    continue

    def set_property(self, arguments):
        """
        Adds (or replaces) properties on beacons.

        Accepts a CSV file with a beacon_name column and additional columns whose header is the
        property name and whose values on each row are the property values.

        Args:
            arguments: list of arguments passed from CLI. Pass ['--help'] for details.

        Returns:
            Nothing.
        """
        args_parser = argparse.ArgumentParser(description='Sets properties on beacons based on the'
                                                          ' content of a CSV file.',
                                              prog='set-property')
        args_parser.add_argument('--source-csv', metavar='PATH',
                                 required=True, help='Path to the CSV file.')
        args_parser.add_argument('--project-id',
                                 help='Google developer project ID that owns the beacons')
        args_parser.add_argument('--print-results',
                                 action='store_true', default=False, help='Print to stdout the result.')
        args = args_parser.parse_args(arguments)

        beacon_location_csv = args.source_csv

        with open(beacon_location_csv) as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                try:
                    beacon_name = row['beacon_name']
                    row.pop('beacon_name')
                except KeyError:
                    print('[ERROR] Could not get beacon ID from file. Please ensure source file has a beacon_name key.')
                    return

                beacon = self.get_beacon([
                    '--beacon-name', beacon_name,
                    '--project-id', args.project_id
                ])

                if not beacon:
                    print('[WARN] beacon "{}" is not yet registered. Please register first.'.format(beacon_name))
                    continue
                else:
                    for name, value in row.items():
                        beacon['properties'][name] = value
                        if DEBUG:
                            print('Updating beacon with property "{}:{}"'.format(name, value))
                    self.update_beacon(beacon, args.project_id)

    def lat_lng_from_place(self, beacon, maps_api_key):
        """
        Set the beacon's lat/lng to the center of the place.
        """
        if maps_api_key is None or len(maps_api_key) is 0:
            print "[FATAL] api key is required to call places API, was [{}].".format(api_key)
            exit(1)
        
        if 'latLng' in beacon:
            if DEBUG:
                print('Beacon already has lat/lng, skipping so as not to erase it.')
            return

        if 'placeId' not in beacon:
            if DEBUG:
                print('No place_id in beacon, cannot infer its lat/lng.')
            return

        if DEBUG:
            print('Attempting to set lat/lng based on place id {}'.format(beacon['placeId']))

        places_api_url = ('https://maps.googleapis.com/maps/api/place/details/json'
                         '?placeid={}&key={}'.format(beacon['placeId'], maps_api_key))
        req = urllib2.urlopen(places_api_url)
        response = json.loads(req.read())

        lat_lng = None
        if response and response['status'] == 'OK':
            result = response['result']
            if result is not None and result['geometry']['location'] is not None:
                lat_lng = result['geometry']['location']
        elif 'error_message' in response:
            print '[ERROR] Failed to call places api: {}'.format(response['error_message'])
            return
        else:
            print '[ERROR] Failed to call places api: {}'.format(response['status'])
            return

        beacon['latLng'] = {'latitude': lat_lng['lat'], 'longitude': lat_lng['lng']}
        if DEBUG:
            print('Beacon lat/lng are: {}'.format(lat_lng))

    @staticmethod
    def _ibeacon_to_ad_id(ibeacon_uuid, ibeacon_major, ibeacon_minor):
        """
        Converts the UUID ("Proximity UUID") and major/minor IDs of an iBeacon into a suitable Advertised ID for the
        Proximity Beacon API.

        :param ibeacon_uuid: Hex-formated UUID, eg., 77657042-dba6-4158-ba02-61e8eb89b6fb. Dashes and case optional.
        :param ibeacon_major: major ID, in decimal
        :param ibeacon_minor: minor ID, in decimal
        :return: Base 64 encoding of the concatenated byte stream, suitable for PBAPI's Advertised ID.
        """
        beacon_id = uuid.UUID(ibeacon_uuid)
        major = PbApi._int_to_hex(int(ibeacon_major), 2)
        minor = PbApi._int_to_hex(int(ibeacon_minor), 2)
        beacon_id = beacon_id.hex + major + minor
        return base64.b64encode(binascii.unhexlify(beacon_id))

    @staticmethod
    def _eddystone_to_ad_id(eddy_id):
        beacon_id = uuid.UUID(eddy_id)
        return base64.b64encode(binascii.unhexlify(beacon_id.hex))

    @staticmethod
    def _int_to_hex(n, length):
        h = '%x' % n
        s = ('0' * (len(h) % 2) + h).zfill(length * 2)
        return s

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
            attach_id = uuid.UUID(parts[3], version=4)
        except ValueError:
            raise ValueError('Expected UUID-like string for attachment ID; instead found {}'
                             .format(parts[3]))

        return

    @staticmethod
    def snake_to_camel(string):
      components = string.split('_')
      return components[0] + "".join(x.title() for x in components[1:])

    def build_from_credentials(self, credentials):
        """
        Builds a PB API client from the given oauth2 client credentials

        :param credentials: a valid oauth2client credentials object.
        """
        http_auth = credentials.authorize(Http())
        self._client = build(PROXIMITY_API_NAME, PROXIMITY_API_VERSION,
                             http=http_auth,
                             cache_discovery=False,
                             discoveryServiceUrl=DISCOVERY_URI)
        return self

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
        return self.build_from_credentials(credentials)

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
        return self.build_from_credentials(credentials)

    def build_from_client_id_json(self, client_secret_file):
        """
        Instantiates the REST API client for the Proximity API given the path
        to a client secrets JSON file.

        Args:
            client_secret_file:
                Path to a JSON file obtained from the Google Cloud Console for
                an "OAuth 2.0 client ID".

        Returns:
            self, with a ready-to-use PB API client.
        
        """
        if self._client is not None:
            return self._client

        credsdir = os.path.expanduser(CREDS_STORAGE)
        if not os.path.exists(credsdir):
            os.makedirs(credsdir)

        credsfile = credsdir + '/' + hashlib.sha1(
            open(client_secret_file, 'r').read()).hexdigest()
        if not os.path.exists(credsfile):
            open(credsfile, 'w').close()

        storage = oauth2file.Storage(credsfile)

        credentials = storage.get()
        if (credentials is not None and not credentials.invalid):
            return self.build_from_credentials(credentials)

        flow = flow_from_clientsecrets(
            client_secret_file,
            scope='https://www.googleapis.com/auth/userlocation.beacon.registry',
            redirect_uri='urn:ietf:wg:oauth:2.0:oob')

        auth_uri = flow.step1_get_authorize_url()
        print "Opening web browser to initiate OAuth dance."
        print "Please copy and paste the resulting token here."
        print "(Please ignore any error messages about 'Failed to launch GPU process'.)"
        webbrowser.open(auth_uri)
    
        auth_code = raw_input('Enter the authentication code: ')
    
        credentials = flow.step2_exchange(auth_code)
        storage.put(credentials)
        return self.build_from_credentials(credentials)

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
        return self.build_from_credentials(credentials)

    def build_from_app_default(self):
        """
        Instantiates the REST API client for the Proximity API. Full PyDoc for this
        client is available here: https://developers.google.com/resources/api-libraries/documentation/proximitybeacon/v1beta1/python/latest/index.html

        Args:

        Returns:
            self, with a ready-to-use PB API client.
        """
        if self._client is not None:
            return self._client

        credentials = GoogleCredentials.get_application_default()
        return self.build_from_credentials(credentials)

