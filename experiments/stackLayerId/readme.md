## Question

Is the content-based layer ID the same for the same content based on its whole Root FS stack contents?

## Test
Here we create two images based on alpine.
The first image adds a file that doesn't exist in the alpine base.
The second image removes the file added by the first.

If the layerId is based on the contents of the whole stack then the first and last layers of the second image should have the same layer ID.

```
# docker build -t stacklayerid1 -f Dockerfile.alpine1 .
# docker build -t stacklayerid2 -f Dockerfile.alpine2 .

# docker inspect alpine
        "RootFS": {
            "Type": "layers",
            "Layers": [
                "sha256:60ab55d3379d47c1ba6b6225d59d10e1f52096ee9d5c816e42c635ccc57a5a2b"
            ]
        }

# docker inspect stacklayerid2
        "RootFS": {
            "Type": "layers",
            "Layers": [
                "sha256:60ab55d3379d47c1ba6b6225d59d10e1f52096ee9d5c816e42c635ccc57a5a2b",
                "sha256:d5f8d80831706f9f481b47b52b60199d5105be87fe02818961ece78fb5665007",
                "sha256:43f44eefc110bb4d898a1921763839e8185805eeea9965e329a557fe0dce6bcb"
            ]
        }
```

## Answer

Nope, it looks like the content-based layer IDs are different for layers that have identical content but different parent.
