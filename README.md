# MAAS Smoke Tests

This repository provides setup instructions for running functional smoke tests against a MAAS installation through the [`NRPE`](https://charmhub.io/nrpe) and [`Nagios`](https://charmhub.io/nagios) charms.

## Setup

1. On a host with the NRPE subordinate charm installed, install `pip3` and the `python-libmaas` library:

    ```sh
    juju exec --unit <nrpe_unit_name> apt update \; apt install python3-pip \; pip3 install python-libmaas
    ```

1. Enter the MAAS API URL in `nrpe_host/etc/nagios/nrpe.d/check_maas_provisioning.cfg`

1. On a host with the NRPE subordinate charm installed, copy recursively the content of the [`nrpe_host`](./nrpe_host) folder of this repository from the root:

    ```sh
    juju scp nrpe_host/etc/nagios/nrpe.d/* <nrpe_unit_name>:/etc/nagios/nrpe.d/
    juju scp nrpe_host/usr/local/lib/nagios/plugins/* <nrpe_unit_name>:nrpe_host/usr/local/lib/nagios/plugins/
    ```

1. Ensure the NRPE check can be executed:

    ```sh
    juju exec --unit <nrpe_unit_name> chmod +x /usr/local/lib/nagios/plugins/check_maas_provisioning.sh
    ```

1. Create a file containing an MAAS admin API key to be used by the check:

    ```sh
    juju exec --unit <nrpe_unit_name> -- echo -n "${MAAS_API_KEY}" \> /var/lib/juju/agents/unit-nrpe-0/charm/maas_api_key
    ```

1. At this point you already can trigger the manual execution of the check with:

    ```sh
    juju run-action <nrpe_unit_name> run-nrpe-check name=check_maas_provisioning --wait
    ```

    Replace in the command above `<nrpe_unit_name>` with the actual unit name of the subordinate `NRPE`](https://charmhub.io/nrpe) running on the host on which you have installed the files of this repository.

1. Customize the `nagios_host/etc/nagios3/conf.d/maas-liveness-check.cfg` to add the right hosts or hostgroups into the `maas_hosts` host group (see the [Nagios3 Documentation](https://assets.nagios.com/downloads/nagioscore/docs/nagioscore/3/en/objectdefinitions.html#hostgroup) for reference.)

1. Upload the new configuration to Nagios:

    ```sh
    juju config <nagios_app_name> extraconfig=@nagios_host/etc/nagios3/conf.d/maas-liveness-check.cfg
    ```

6. Confirm that the Nagios configuration has reload correctly looking in `juju debug-log`. You can also verify the validity of Nagios config files via Juju exec:

    ```sh
    juju exec --app <nagios_app_name> -- /usr/sbin/nagios3 -v /etc/nagios3/nagios.cfg
    ```

## Limitations

1. When spawning new MAAS hosts:
  * the NRPE check must be manually uploaded to the machine
  * the new MAAS host may have to be registered in Nagios' `maas_hosts` host group
