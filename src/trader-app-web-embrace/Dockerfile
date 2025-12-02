FROM node:20 as frontend

ARG SERVICE_VERSION
ARG EMBRACE_APP_ID
ARG EMBRACE_UPLOAD_API_TOKEN

RUN mkdir -p /app
WORKDIR /app

# Copy package.json and package-lock.json to the working directory
COPY trader-app/package*.json ./
# Install dependencies
RUN npm install

COPY trader-app/src src
COPY trader-app/public public

RUN sed -i 's/$EMBRACE_APP_ID/'${EMBRACE_APP_ID}'/g' src/App.js

RUN npm run build

RUN npx embrace-web-cli upload --app-version "${SERVICE_VERSION}" -a "${EMBRACE_APP_ID}" -t "${EMBRACE_UPLOAD_API_TOKEN}" -p build

RUN chmod -R a+r /app/build

CMD rm -rf /build/* && cp -r /app/build/. /build/
