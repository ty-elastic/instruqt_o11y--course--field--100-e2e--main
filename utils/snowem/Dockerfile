FROM node:20-alpine

RUN mkdir -p /home/node/app/node_modules
WORKDIR /home/node/app

COPY . .

RUN --mount=type=cache,target=/root/.npm npm install
RUN --mount=type=cache,target=/root/.npm npm run build

ENV NO_TLS 1

CMD [ "npm", "start"]
