SET GLOBAL require_secure_transport = OFF;

CREATE DATABASE IF NOT EXISTS main;
USE main;

-- UPDATE performance_schema.setup_instruments SET ENABLED = 'YES', TIMED = 'YES' WHERE NAME LIKE 'wait/%';
-- UPDATE performance_schema.setup_consumers SET ENABLED = 'YES' WHERE NAME = 'events_statements_current';
-- UPDATE performance_schema.setup_consumers SET ENABLED = 'YES' WHERE NAME = 'statements_digest';
-- UPDATE performance_schema.setup_consumers SET ENABLED = 'YES' WHERE NAME = 'events_waits_current';

CREATE USER 'otelu'@'%' IDENTIFIED BY 'otelp';
GRANT PROCESS ON *.* TO 'otelu'@'%';
GRANT SELECT ON performance_schema.* TO 'otelu'@'%';
GRANT SELECT ON main.* TO 'otelu'@'%';
GRANT SUPER, REPLICATION CLIENT ON *.* TO 'otelu'@'%';
FLUSH PRIVILEGES;

CREATE TABLE IF NOT EXISTS trades (
    share_price float4, 
    shares integer, 
    action varchar(255), 
    customer_id varchar(255), 
    symbol varchar(255), 
    trade_id varchar(255) not null, 
    primary key (trade_id));
