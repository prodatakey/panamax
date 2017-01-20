## Question

Is the content-based layer ID the same for the same content, irregardless of progenitor?

## Test
Here we create two images, one based on debian and one based on alpine.
Each of them then has a layer that copies the `resolv.conf` fromm this directory, into the image.

We then see if the layers that represents the `resolv.conf` copy have the same ID.

```
# docker build -t layerid-debian -f Dockerfile.debian .
# docker build -t layerid-alpine -f Dockerfile.alpine .

# docker inspect layerid-debian
        "RootFS": {
            "Type": "layers",
            "Layers": [
                "sha256:a2ae92ffcd29f7ededa0320f4a4fd709a723beae9a4e681696874932db7aee2c",
                "sha256:f4aed2f088fcc34e04a55130926ba7f9bb9f5b75ff5857c682fced03fa682fc4"
            ]
        }

# docker inspect layerid-alpine
        "RootFS": {
            "Type": "layers",
            "Layers": [
                "sha256:60ab55d3379d47c1ba6b6225d59d10e1f52096ee9d5c816e42c635ccc57a5a2b",
                "sha256:594df0df505222106fb92e25967c47d5b6fd1f470c835047763046babaccc794"
            ]
        }
```

## Answer

Nope, it looks like the content-based layer IDs are different for layers that have identical content but different parent.

## Extra Credit

Cracking the tar files open does indeed show the content is identical.

```
# docker save layerid-debian > debian.tar
# tar xvOf debian.tar 8f9cd17cd4e4dd7688baaba8522401aaefd3789b037749b6052530cdee6d8509/layer.tar | tar tvf -
x 8f9cd17cd4e4dd7688baaba8522401aaefd3789b037749b6052530cdee6d8509/layer.tar
drwxr-xr-x  0 0      0           0 Jan 19 10:57 etc/
-rw-r--r--  0 0      0          19 Jan 19 10:49 etc/resolv.conf

# docker save layerid-alpine > alpine.tar
# tar xvOf alpine.tar a5492ee14e891e935493d8fbf3ee2e51263627aae3b4b416dab37328010be9ef/layer.tar | tar tvf -
x a5492ee14e891e935493d8fbf3ee2e51263627aae3b4b416dab37328010be9ef/layer.tar
drwxr-xr-x  0 0      0           0 Jan 19 10:57 etc/
-rw-r--r--  0 0      0          19 Jan 19 10:49 etc/resolv.conf
```
