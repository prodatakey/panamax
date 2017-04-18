# Get layers for the two nginx images
node pull.js

# Decompress all of the layers
gunzip layer*.gz

# Generate the layer deltas
time xdelta3 -s layer-1.11.7-sha256:325b624bee1c2cdb2a603102412eec6fc20386a60965f33244f1ef256f29e299.tar -f layer-1.11.8-sha256:9cac4850e5df710bce8b514acee92630e27f36761a36e55cbef0cc8d1d0317d5.tar > layer1.delta
time xdelta3 -s layer-1.11.7-sha256:64f0219ba3ea802cf10ed9b7e73146ea4189a1341cbebae855035d85b420c3ae.tar -f layer-1.11.8-sha256:d7a91cdb22f0fe7b35f7f492de75096d491b2cb5ea9a3a9bd775210a003af7f3.tar > layer2.delta
time xdelta3 -s layer-1.11.7-sha256:75a822cd7888e394c49828b951061402d31745f596b1f502758570f2d0ee79e2.tar -f layer-1.11.8-sha256:5040bd2983909aa8896b9932438c3f1479d25ae837a5f6220242a264d0221f2d.tar > layer3.delta

docker pull nginx:1.11.7
docker pull nginx:1.11.8

docker save nginx:1.11.7 > nginx-1.11.7.tar
docker save nginx:1.11.8 > nginx-1.11.8.tar

time xdelta3 -B 1000000000 -s nginx-1.11.7.tar nginx-1.11.8.tar nginx.delta
