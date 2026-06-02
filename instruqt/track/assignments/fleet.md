
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
5. Select `Windows PowerShell`
6. Paste (control-v) the copied script from Elastic and hit enter

Once the install completes, verify telemetry reception in Elastic.

## Add Syslog Integration

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Navigate to `Fleet`
3. Select `Agent policies`
4. Click `Windows Server` policy
5. Click `Add integration`
6. Under `Select integration`, select `Syslog Router`
7. Under `Configuration integration` > `Route syslog events using the UDP input`, paste the following into `Reroute configuration`:
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
8. We are intentionally misconfiguring the TCP syslog input to conflict with a known Windows Service. Under `Configuration integration` > `Route syslog events using the TCP input`, change the port to `445` (used for SMB)
9. Click `Add integration`

## Debugging an Agent Misconfiguration

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Navigate to `Fleet`
3. Under `Agents`, wait for the `windows` host to become `Unhealthy`
3. Select the `windows` Host
4. Note that the `syslog-router-1` integration `Needs attention`
5. Open the `syslog-router-1` integration, expand `tcp` and note the failure
6. Under `Alerts`, note that we have an active alert for an unhealthy Elastic Agent
7. Click on the three dots on the left-hand side of the alert, and select `View Alert Details`
8. Open `Help me understand this alert`
9. Note the explanation
9. Click `Start conversation`
9. Ask
```
do we have a convention for syslog ports?
```

Note that AI Assistant can help deciphering alerts in the context of company IT policies.

## Fixing an Agent Misconfiguration

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Navigate to `Fleet`
3. Click `Agent Policies`
4. Open the `Windows Server` policy
5. Open the `syslog-router-1` integration
6. Change the TCP input syslog port to `9514`

Note that Agent become healthy and the alert eventually resolves.

# Agent Updates

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Navigate to `Fleet`
3. Note `Upgrade Available` for `es3-api` host 
4. Click the 3 dots on the right of that line and select `Upgrade agent`

Note that the agent updates, and that Fleet starts monitoring the updated agent's health.

