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
from oauth2client.service_account import ServiceAccountCredentials
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

    def _get_client(self):
        """
        Returns:
            The low-level API client being used to call the PB API service.
        """
        return self._client

    def list_beacons(self):
        """
        Get all beacons registered with this client.

        Returns:
            List of objects representing the beacons. For a description of all
            fields, see https://developers.google.com/beacons/proximity/reference/rest/v1beta1/beacons#Beacon
        """
        request = self._client.beacons() \
            .list()

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

        return beacons

    def register_beacon(self, beacon_json):
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
            beacon_json (Required):
                json string representing the beacon. See above for example json.

        Returns:
            JSON representing the beacon. Same as above, but with the added
            "beaconName" field.
        """

        # Perform some rudimentary input validation before sending off
        try:
            parsed_beacon = beacon_json
            if not isinstance(beacon_json, dict):
                parsed_beacon = json.loads(beacon_json)
            ad_id = parsed_beacon['advertisedId']
        except (ValueError, KeyError):
            raise ValueError('Expected input to be json str with, at minimum, advertisedId key')

        try:
            response = self._client.beacons() \
                .register(body=beacon_json) \
                .execute()
        except HttpError, err:
            import pprint
            pprint.pprint(err.resp)
            pprint.pprint(json.dumps(err.content, sort_keys=True, indent=2))
            return {}

        if DEBUG:
            print json.dumps(response, sort_keys=True, indent=4)

        return response

    def deactivate_beacon(self, beacon_name):
        """
        Deactivates a beacon.

        Args:
            beacon_name: Name of the beacon to deactivate. Format is "beacons/N!<beacon ID>"

        Returns:
            Nothing
        """
        response = self._client.beacons() \
            .deactivate(beaconName=beacon_name) \
            .execute()

        return response

    def add_attachment(self, beacon_name, namespaced_type, data):
        """
        Adds an attachment to the specified beacon with the given namespace/type and
        data.

        Args:
            beacon_name (Required):
                the name of the beacon to add an attachment to. Proximity
                API expects them in the format 'beacons/N!beaconId'. Easiest to
                pull these from proximity API's "list" method.
            namespaced_type (Required):
                the namespace/type of the attachment. Typically
                something like 'project-name/json' or 'project-name/xml'
            data:
                Arbitrary String representing the content of the attachment. This
                will be base64 encoded. *Should not contain namespace, attachment
                name, or anything other than the "body" of your attachment.

        Returns:
            The attachment object as stored by the Proximity API. Current is JSON
            with the keys: attachmentName, data, namespaced_type.
        """
        # TODO verify that data is string; not json, dict, file, file path, or already b64 encoded
        encoded_data = base64.b64encode(data)

        # Beacon Attachments have an "attachmentName" field, but for creating one,
        # these are left off and generated server-side by the API.
        request_body = {'data': encoded_data, 'namespaced_type': namespaced_type}

        response = self._client.beacons() \
            .attachments() \
            .create(beaconName=beacon_name, body=request_body) \
            .execute()

        if DEBUG:
            print json.dumps(response, sort_keys=True, indent=4)

        return response

    def delete_attachment(self, attachment_name):
        """
        Deletes the attachment with the specified name

        Args:
            attachment_name (Required):
                The name of the attachment to delete. The Proximity API expects this to be in the form:
                    beacons/beacon_id/attachments/attachment_id.
                It's easiest to get this via the list_attachments method.

        Returns:
            Nothing. See:
                https://developers.google.com/resources/api-libraries/documentation/proximitybeacon/v1beta1/python/latest/proximitybeacon_v1beta1.beacons.attachments.html#delete
        """
        self._validate_attachment_name(attachment_name)

        self._client.beacons() \
            .attachments() \
            .delete(attachmentName=attachment_name) \
            .execute()

    def list_attachments(self, beacon_name, namespaced_type='*/*'):
        """
        Retrieves the attachments, still base64 encoded, for the given beacon and namespace/type.

        Args:
            beacon_name:
                the name of the beacon to fetch attachments for. (Required)
            namespaced_type:
              the namespace/type of the attachments to fetch. Defaults to '*/*', all attachments.

        Returns:
            List of attachments. Each item is json with the keys: attachmentName,
            data, namespaced_type.
        """
        attachments = self._client.beacons() \
            .attachments() \
            .list(beaconName=beacon_name, namespacedType=namespaced_type) \
            .execute()

        if DEBUG:
            print json.dumps(attachments, sort_keys=True, indent=4)

        if 'attachments' in attachments:
            return attachments['attachments']
        else:
            return None

    @staticmethod
    def _validate_attachment_name(name):
        """
        Does not guarentee that this is a valid attachment, or even a valid attachment name. Only
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
