
Fleet
===

# Windows

## Create Policy

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Navigate to `Fleet`
3. Click `Add` > `Agent`
4. Click `Create new agent policy` 
5. Name the policy `Windows Server`
6. Click `Create policy`

## Enroll

1. Under `Install Elastic Agent on your host`, select `Windows_x86_64`
2. Click the `copy` button in the Powershell script
3. Open the [button label="Windows"](tab-0) tab
4. Click the `Windows` (start) menu in the lower-left
5. Right-click on `Windows PowerShell` and select `Run as Administrator`
6. Paste (control-v) the copied script from Elastic and hit enter

Once the install completes, verify telemetry reception in Elastic.

## Add Syslog Integration

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Navigate to `Fleet`
3. Select `Agent policies`
4. Click `Windows Server` policy
5. Click `Add integration`
6. Under `Select integration`, select `Syslog Router`
7. Under `Configuration integration`, turn off `Route syslog events using the TCP input`
8. Under `Configuration integration` > `Route syslog events using the UDP input`, paste the following into `Reroute configuration`:
```
- if:
    and:
      - not.has_fields: _conf.dataset
      - regexp.message: 'hpc-'
  then:
    - add_fields:
        target: ''
        fields:
          _conf.dataset: "hpc"
    - syslog:
        field: message
        format: rfc5424
```
9. Click `Add integration`

## Streams

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Navigate to `Streams`
3. Select `Agent policies`






can you graph fan speed over time? ignore ****

can you graph temperate over time?

yes, please correlate temp spike with fan speed changes