# Stage 1: Collect and hold the files
FROM alpine AS file-holder

# Copy your local files into the container
WORKDIR /dashboards
COPY ./dashboards /dashboards

# Keep the container running in the background
CMD ["tail", "-f", "/dev/null"]