#!/usr/bin/env python3

""" Copyright (C) 2021  Canonical

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program - see the LICENSE file.  If not, see <https://www.gnu.org/licenses/>.
 """

import maas.client
import argparse
import os
import signal

from pathlib import Path

MAAS_API_KEY_ENV_VAR_NAME = "MAAS_API_KEY"


def get_maas_api_key():
    maas_api_key_env = os.getenv(MAAS_API_KEY_ENV_VAR_NAME)

    if maas_api_key_env:
        return maas_api_key_env

    maas_api_key_file_path = Path("./maas_api_key").absolute()

    if not maas_api_key_file_path.is_file():
        raise Exception(
            "Neither the '{}' environment variable is set nor the '{}' MAAS API key file exists".format(
                MAAS_API_KEY_ENV_VAR_NAME, maas_api_key_file_path
            )
        )

    with open(maas_api_key_file_path) as file:
        return file.read()


def timeout_handler(signum, frame):
    raise Exception("Timed out")


def main():
    parser = argparse.ArgumentParser(
        description="Test a MAAS installation can refresh all LXD VM hosts. "
        + "Returns 0 if all ok or 2 if any of them fail. API key must be stored in env variable 'MAAS_API_KEY', or in a 'maas_api_key' file in the working directory from which this program is launched."
        + "Assumes MAAS runs on standard port 5240 and is http.",
        epilog=" Example usage: python3 maas-lxd-ping.py -t http://192.168.200.16:5240/MAAS/ -u admin",
    )
    parser.add_argument(
        "-t",
        "--target",
        help="Target MAAS API URL",
        action="store",
        default="http://localhost:5240/MAAS/",
    )
    parser.add_argument(
        "-u",
        "--user-name",
        help="User name for MAAS host. Should be an admin.",
        action="store",
        default="admin",
    )
    args = parser.parse_args()

    maas_api_key = None
    try:
        maas_api_key = get_maas_api_key().strip()
    except Exception as e:
        print(
            "Couldn't retrieve the MAAS API key."
        )
        print(f"ERROR - {e}")
        exit(2)

    client = None
    try:
        client = maas.client.connect(f"{args.target}", apikey=maas_api_key)
    except Exception as e:
        print(
            "Couldn't log in. Invalid credentials or server not available."
        )
        print(f"ERROR - {e}")
        exit(2)

    myself = client.users.whoami()
    assert myself.is_admin, "%s is not an admin" % myself.username

    signal.signal(signal.SIGALRM, timeout_handler)

    pods = client.pods.list()
    for p in pods:
        pod = client.pods.get(p.id)
        try:
            signal.alarm(15)
            x = pod.refresh()
        except Exception as e:
            print(f"ERROR - Could not refresh pod with id: {p.id}.\nException: {e}")
            exit(2)
        signal.alarm(0)

    print("OK")
    exit(0)


if __name__ == "__main__":
    main()
