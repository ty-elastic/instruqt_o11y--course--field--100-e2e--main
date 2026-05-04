
Fleet
===

# Windows


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