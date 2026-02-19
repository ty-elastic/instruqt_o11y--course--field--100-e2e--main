FROM mysql:9.4 as builder

# Set environment variables for MySQL initialization
ENV MYSQL_ROOT_PASSWORD=password
ENV MYSQL_DATABASE=main

# Copy your SQL file into the entrypoint initialization directory
# The official MySQL image automatically runs scripts in this directory on startup
COPY init.sql /docker-entrypoint-initdb.d/

RUN ["sed", "-i", "s/exec \"$@\"/echo \"not running $@\"/", "/usr/local/bin/docker-entrypoint.sh"]

# Change the data directory to a non-volume path for the build stage to capture changes
# The default /var/lib/mysql is a VOLUME, so changes are discarded if made after the VOLUME instruction
ENV MYSQL_DATADIR=/initialized-db
RUN ["/usr/local/bin/docker-entrypoint.sh", "mysqld", "--datadir", "/initialized-db"]

FROM mysql:9.4

COPY my.cnf /etc/mysql/conf.d/

COPY --from=builder /initialized-db /var/lib/mysql
