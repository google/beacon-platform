#!/usr/bin/env python

import pbapi
import json
import argparse

# List of commands and they methods they map to.
aliases = {
    'bulk-register': pbapi.PbApi.bulk_register,
    'create-attachment': pbapi.PbApi.create_attachment,
    'activate-beacon': pbapi.PbApi.activate_beacon,
    'deactivate-beacon': pbapi.PbApi.deactivate_beacon,
    'delete-attachment': pbapi.PbApi.delete_attachment,
    'delete-beacon': pbapi.PbApi.delete_beacon,
    'get-beacon': pbapi.PbApi.get_beacon,
    'list-attachments': pbapi.PbApi.list_attachments,
    'list-beacons': pbapi.PbApi.list_beacons,
    'register-beacon': pbapi.PbApi.register_beacon,
    'set-places':  pbapi.PbApi.set_places,
    'set-property':  pbapi.PbApi.set_property,
}


def main():
    parser = argparse.ArgumentParser(description='CLI wrapper for the Proximity Beacon API',
                                     add_help=False)
    parser.add_argument('command',
                        nargs='?', metavar='command', choices=aliases.keys(),
                        help='Name of the Proximity Beacon API method to execute. Supported options are: '
                             + str(aliases.keys()))
    parser.add_argument('--help', '-h',
                        nargs='?', default=False, const=True, metavar='command',
                        help='This help message or the help message for the given command')
    parser.add_argument('--list-commands',
                        action='store_true',
                        help='Lists the Proximity Beacon API methods available to run')
    parser.add_argument('--service-account-creds',
                        help='Path to file containing credentials for a service account. If this is a p12 file, you ' +
                             'must also supply --service-account-email. Otherwise, this is expected to be JSON.')
    parser.add_argument('--service-account-email',
                        help='Client email of the service account to use if --service-account-creds is a p12. Not ' +
                             'needed if using an access token or a JSON service account file.')
    parser.add_argument('--access-token',
                        help='OAuth2 access token ')
    parser.add_argument('--client-secret',
                        help='Path to a JSON file containing oauth client ID secrets.')
    parser.add_argument('--print-results',
                        action='store_true', default=False, help='Print the command\'s return value to stdout.')

    args, extra_args = parser.parse_known_args()

    if args.help:
        handle_help(parser, args)
        exit(0)

    if args.list_commands:
        list_commands()
        exit(0)

    if args.command is None:
        print('[ERROR] command name is required')
        parser.print_help()
        exit(1)

    # TODO: support specifying creds via env vars
    pb_client = None
    if args.service_account_creds is not None and args.service_account_email is not None:
        pb_client = pbapi.build_client_from_p12(args.service_account_creds, args.service_account_email)
    elif args.service_account_creds is not None:
        pb_client = pbapi.build_client_from_json(args.service_account_creds)
    elif args.access_token is not None:
        pb_client = pbapi.build_client_from_access_token(args.access_token)
    elif args.client_secret is not None:
        pb_client = pbapi.build_client_from_client_id_json(args.client_secret)
    else:
        try:
            pb_client = pbapi.build_client_from_app_default()
        except Exception, err:
            # TODO: if no creds found, attempt web-based oauth flow
            print('[ERROR] No usable access credentials specified. Cannot create API client: {}'.format(err.message))
            exit(1)

    if args.command in aliases:
        try:
            result = aliases[args.command](pb_client, extra_args + ['--print-results'])
            if result is not None and args.print_results:
                print result
        except ValueError, e:
            print('"%s" failed with message %s' % (args.command, e.message))
    else:
        print('[Error] Unknown command ' + args.command)
        print('Supported commands are:\n\t* ' + '\n\t* '.join(aliases.keys()))
        exit(1)


def handle_help(parser, args):
    pb = pbapi.PbApi()
    if args.command and args.command in aliases:
        aliases[args.command](pb, ['--help'])
    elif args.help in aliases:
        aliases[args.help](pb, ['--help'])
    else:
        parser.print_help()


def list_commands():
    for cmd in sorted(aliases.keys()):
        print cmd


if __name__ == "__main__":
    main()
