docker kill keep_glue
docker rm keep_glue
docker build -t keep_glue .
docker run --name keep_glue -d -p 9393:5000 keep_glue

docker logs keep-keep-backend-dev-1 2>&1 | grep "ngrok-free"