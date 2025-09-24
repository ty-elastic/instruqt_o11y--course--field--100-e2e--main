FROM node:20-alpine as frontend

ARG ELASTICSEARCH_RUM_ENDPOINT=""
ARG ELASTICSEARCH_RUM_CREDENTIALS=false
ARG NAMESPACE
ARG ELASTICSEARCH_KIBANA_ENDPOINT
ARG ELASTICSEARCH_APIKEY

RUN mkdir -p /app
WORKDIR /app

# Copy package.json and package-lock.json to the working directory
COPY trader-app/package*.json ./
# Install dependencies
RUN npm install

COPY trader-app/src src
COPY trader-app/public public


RUN if [[ "$ELASTICSEARCH_RUM_ENDPOINT" == "" ]]; then \
        echo "skipping RUM"; \
    else \
        export SERVICE_VERSION=1.0.0; \
        export SERVICE_NAME=trader-app-web; \
        echo -e "\
            import { init as initApm } from '@elastic/apm-rum' \n\
            const apm = initApm({ \n\
                serviceName: '${SERVICE_NAME}', \n\
                serverUrl: '${ELASTICSEARCH_RUM_ENDPOINT}', \n\
                sendCredentials: ${ELASTICSEARCH_RUM_CREDENTIALS}, \n\
                serviceVersion: '${SERVICE_VERSION}', \n\
                environment: '${NAMESPACE}' \n\
            }) \n\
            export default apm; \n\
        " > src/rum.js; \
        echo -e "import apm from './rum'\n" | cat - src/index.js > temp && mv temp src/index.js; \
    fi

RUN npm run build

COPY upload_source_map.sh build/
RUN if [[ "$ELASTIC_APM_SERVER_RUM_ENDPOINT" == "" ]]; then \
        echo "skipping RUM"; \
    else \
        export ELASTICSEARCH_KIBANA_ENDPOINT=$ELASTICSEARCH_KIBANA_ENDPOINT; \
        export ELASTICSEARCH_APIKEY=$ELASTICSEARCH_APIKEY; \
        cd build && ./upload_source_map.sh; \
    fi

CMD rm -rf /build/* && cp -r /app/build/. /build/
