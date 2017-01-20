docker build -t stacklayerid1 -f Dockerfile.alpine1 .
docker build -t stacklayerid2 -f Dockerfile.alpine2 .

docker inspect alpine
docker inspect stacklayerid2
