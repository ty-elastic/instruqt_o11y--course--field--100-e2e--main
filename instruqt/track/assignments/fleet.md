
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




can you graph fan speed over time? ignore ****

can you graph temperate over time?

yes, please correlate temp spike with fan speed changes