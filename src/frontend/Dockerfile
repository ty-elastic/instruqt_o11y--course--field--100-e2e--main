FROM node:20 as frontend

ARG ELASTICSEARCH_RUM_ENDPOINT=""
ARG ELASTICSEARCH_RUM_CREDENTIALS=false
ARG NAMESPACE
ARG ELASTICSEARCH_KIBANA_ENDPOINT
ARG ELASTICSEARCH_APIKEY
ARG SERVICE_VERSION
ARG SERVICE_NAME="trader-app-web"

RUN mkdir -p /app
WORKDIR /app

# Copy package.json and package-lock.json to the working directory
COPY trader-app/package*.json ./
# Install dependencies
RUN npm install

COPY trader-app/src src
COPY trader-app/public public

RUN echo "\
    import { init as initApm } from '@elastic/apm-rum'; \n\
    const apm = initApm({ \n\
        serviceName: '${SERVICE_NAME}', \n\
        serverUrl: '${ELASTICSEARCH_RUM_ENDPOINT}', \n\
        sendCredentials: ${ELASTICSEARCH_RUM_CREDENTIALS}, \n\
        serviceVersion: '${SERVICE_VERSION}', \n\
        environment: '${NAMESPACE}' \n\
    }); \n\
    export default apm; \n\
" > src/rum.js;
RUN echo "import apm from './rum';\n" | cat - src/index.js > temp && mv temp src/index.js;

RUN npm run build

# COPY upload_source_map.sh build/

# RUN export ELASTICSEARCH_APIKEY=$ELASTICSEARCH_APIKEY
# RUN export SERVICE_NAME=$SERVICE_NAME
# RUN export SERVICE_VERSION=$SERVICE_VERSION
# RUN cd build && ./upload_source_map.sh

CMD rm -rf /build/* && cp -r /app/build/. /build/
