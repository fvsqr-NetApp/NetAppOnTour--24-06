curl -fsSL https://raw.githubusercontent.com/fvsqr-NetApp/NetAppOnTour--24-06/main/install.sh | sudo sh

## Prep
Build images for LOD on MacOS
```
cd tetris
docker-buildx build --platform linux/amd64 -t quay.io/str_netappontour/tetris:latest .
docker push quay.io/str_netappontour/tetris:latest
cd quotes
docker-buildx build --platform linux/amd64 -t quay.io/str_netappontour/tetris-quotes:latest .
docker push quay.io/str_netappontour/tetris-quotes:latest

cd ../..
cd mines
docker-buildx build --platform linux/amd64 -t quay.io/str_netappontour/mines:latest .
docker push quay.io/str_netappontour/mines:latest
```
