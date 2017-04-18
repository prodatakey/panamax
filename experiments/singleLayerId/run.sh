docker build -t layerid-alpine -f Dockerfile.alpine . &
docker build -t layerid-debian -f Dockerfile.debian . &

wait

docker inspect layerid-alpine
docker inspect layerid-debian

docker save layerid-alpine > alpine.tar
docker save layerid-debian > debian.tar

