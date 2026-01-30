---
slug: database-is-down
id: 5oufmwnjxykq
type: challenge
title: Database is down
notes:
- type: text
  contents: |-
    # Database is Down

    We just saw what our environment looks like healthy, but in the real world, things can change fast. That’s why logs matter most when the unexpected happens.

    Unfortunately, something unexpected is happening right now, and Elastic Observability Logs Essentials has detected something unusual.

    An alert fires, signaling a potential issue in MySQL. Let’s start investigating the incident and connect the signals to the business impact.
tabs:
- id: fpwe7rzbhfq0
  title: Kibana
  type: service
  hostname: es3-api
  path: /app/observability/alerts?_a=(controlConfigs:!((exclude:!f,existsSelected:!f,fieldName:kibana.alert.status,hideActionBar:!t,selectedOptions:!(active,recovered),title:Status),(exclude:!f,existsSelected:!f,fieldName:kibana.alert.rule.name,hideActionBar:!f,selectedOptions:!(),title:Rule),(exclude:!f,existsSelected:!f,fieldName:kibana.alert.group.value,hideActionBar:!f,selectedOptions:!(),title:Group),(exclude:!f,existsSelected:!f,fieldName:tags,hideActionBar:!f,selectedOptions:!(),title:Tags)),filters:!(),groupings:!(none),kuery:%27%27,rangeFrom:now-1h,rangeTo:now)
  port: 8080
  custom_request_headers:
  - key: Content-Security-Policy
    value: 'script-src ''self'' https://kibana.estccdn.com; worker-src blob: ''self'';
      style-src ''unsafe-inline'' ''self'' https://kibana.estccdn.com; style-src-elem
      ''unsafe-inline'' ''self'' https://kibana.estccdn.com'
  custom_response_headers:
  - key: Content-Security-Policy
    value: 'script-src ''self'' https://kibana.estccdn.com; worker-src blob: ''self'';
      style-src ''unsafe-inline'' ''self'' https://kibana.estccdn.com; style-src-elem
      ''unsafe-inline'' ''self'' https://kibana.estccdn.com'
- id: plwljdx1dar4
  title: Kibana - external
  type: service
  hostname: es3-api
  path: /app/observability/alerts?_a=(controlConfigs:!((exclude:!f,existsSelected:!f,fieldName:kibana.alert.status,hideActionBar:!t,selectedOptions:!(active,recovered),title:Status),(exclude:!f,existsSelected:!f,fieldName:kibana.alert.rule.name,hideActionBar:!f,selectedOptions:!(),title:Rule),(exclude:!f,existsSelected:!f,fieldName:kibana.alert.group.value,hideActionBar:!f,selectedOptions:!(),title:Group),(exclude:!f,existsSelected:!f,fieldName:tags,hideActionBar:!f,selectedOptions:!(),title:Tags)),filters:!(),groupings:!(none),kuery:%27%27,rangeFrom:now-1h,rangeTo:now)
  port: 8080
  new_window: true
  custom_request_headers:
  - key: Content-Security-Policy
    value: 'script-src ''self'' https://kibana.estccdn.com; worker-src blob: ''self'';
      style-src ''unsafe-inline'' ''self'' https://kibana.estccdn.com; style-src-elem
      ''unsafe-inline'' ''self'' https://kibana.estccdn.com'
  custom_response_headers:
  - key: Content-Security-Policy
    value: 'script-src ''self'' https://kibana.estccdn.com; worker-src blob: ''self'';
      style-src ''unsafe-inline'' ''self'' https://kibana.estccdn.com; style-src-elem
      ''unsafe-inline'' ''self'' https://kibana.estccdn.com'
- id: jpt8efll1sux
  title: k3s
  type: terminal
  hostname: k3s
difficulty: ""
timelimit: 0
enhanced_loading: null
---
## 🚨 Red Alert 🚨

Oh no! An alert has just fired, signaling a spike in MySQL error logs. Let's will investigate the alert and examine the related log events.

1. Click on `Alerts` to view the active alerts.
![Screenshot 2025-08-08 at 12.02.03.png](../assets/Screenshot%202025-08-08%20at%2012.02.03.png)
> [!NOTE]
> If the alert isn't visible yet, refresh the page.
2. Click on the `...` to see more actions for the alert.
![Screenshot 2025-08-08 at 11.53.03.png](../assets/Screenshot%202025-08-08%20at%2011.53.03.png)
3. Click on `View alert details` to see the details of the alert.
![Screenshot 2025-08-08 at 11.53.34.png](../assets/Screenshot%202025-08-08%20at%2011.53.34.png)
4. This is a custom threshold alert that we created to catch unknown issues.  It's not looking for any specific issue, but rather, it's configured to fire when there are more events than our expected threshold.  Notice how it shows the number of events have exceeded our baseline threshold of 70.
![Screenshot 2025-08-08 at 11.59.09.png](../assets/Screenshot%202025-08-08%20at%2011.59.09.png)
5. Click `Open in Discover` to see the related logs on the `Discover` page.
![Screenshot 2025-08-08 at 11.54.06.png](../assets/Screenshot%202025-08-08%20at%2011.54.06.png)
6. On the `Discover` page, we can now see relevant logs for the alert automatically filtered alert time range. This makes it easy to ensure we're looking at the right logs for this event.
![Screenshot 2025-08-08 at 12.03.42.png](../assets/Screenshot%202025-08-08%20at%2012.03.42.png)

We were able to go from alert to relevant logs in just a few clicks. Elastic links alerts to their underlying data, helping us act faster with the right context in front of us.

## Rerun the Saved Query

To see how conditions have changed, we will run the same MySQL query we saved earlier.

1. Navigate back to `Discover`.
![Screenshot 2025-08-06 at 18.27.48.png](../assets/Screenshot%202025-08-06%20at%2018.27.48.png)
2. Click the `Open Session` icon.
![Screenshot 2025-08-06 at 18.33.33.png](../assets/Screenshot%202025-08-06%20at%2018.33.33.png)
3. Select the `MySQL Events Grouped by Log Level` session that we saved earlier.
![Screenshot 2025-08-06 at 18.34.13.png](../assets/Screenshot%202025-08-06%20at%2018.34.13.png)
4. We should now see confirmation that there are now numerous errors and warnings.
![Screenshot 2025-08-06 at 18.35.06.png](../assets/Screenshot%202025-08-06%20at%2018.35.06.png)

The same query now shows new errors and warnings, giving us a clear before-and-after comparison. Being able to save and reuse queries lets us track how problems evolve and speeds up future investigations.

## Business Health Dashboard

We will continue by checking the overall health of the business using the `Business Health Dashboard` that visualizes critical metrics.

1. Open the `Dashboards` page. The `Business Health Dashboard` should show automatically if that was the last dashboard you viewed.
> [!NOTE]
>  If the `Business Health Dashboard` isn't showing, select it from the list of dashboards.
>  ![Screenshot 2025-08-06 at 18.06.06.png](../assets/Screenshot%202025-08-06%20at%2018.06.06.png)
2. We should see the `Business Health Dashboard` now shows an increase in Nginx response code errors as well as MySQL errors, which verifies that this issue is impacting our users and the company's reputation.  We need to find the root cause quick.
![Screenshot 2025-08-06 at 18.19.18.png](../assets/Screenshot%202025-08-06%20at%2018.19.18.png)

The Business Health Dashboard connects operational signals to business outcomes. It helps you track metrics like geographic distribution of users, HTTP status codes, top web pages, and SQL performance, all derived from logs. This kind of visual insight lets you spot issues before they impact customers.

## Summary
We saw how Elastic Observability Logs Essentials alerted us to the database issue and how this issue is impacting our business health.
