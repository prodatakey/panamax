# Experiments

These experiments are mainly meant to explore more deeply how docker and the registry create, transfer, and store layers.

An understanding of these pieces of the stack are focused on learning how to get an image from one system to another
when each system already has a number of images in their local storage. The target system usually stores a much smaller number
of local images.

## TLDR

We've found that while the layering system works well for some optimizations, it does not work well as a transfer optimization.

## A Little More

Because of how the docker build system modifies mtimes when it copies files into the images, and hence modifies layers,
we've found that we can't rely on the layer hashes that docker generates in order to judge changed layers.

We were mainly interested in this to do layer-level deltas of each filesystem at each layer in the stack, even between
totally different images that share base layers. Why transfer layer 1-4 when just a couple files in the base layer
change, and transfer them once again for each image that shares a progenitor layer chain.

We would need to crack open each layer and do a full-content hash of each file in each layer's filesystem ourselves.
In order to do this, we would need to also rebuild the filesystem while taking whiteouts into account
or mount them stacked alternately into overlayfs.

See the [singleLayerId](https://github.com/prodatakey/panamax/tree/master/experiments/singleLayerId) experiment for deeper info.

## A Tad More

Instead of building this complex system, we did some additional experimentation with using binary deltas between fully stacked
images while taking advantage of images existing on the target system.

We also experimented with finding two layers in a registry, a source and a target. The source image already resides on a
remote system, we want to deliver the target there. Which pair of a source out of any layer residing on the remote system and the
target layer will provide the smallest delta.

We use a Locality Sensitive Hash paired with a hamming function to estimate a relative "distance" between two pairs of
images, and it seems to show good corellation between delta size and hamming distance.

The [xdelta](https://github.com/prodatakey/panamax/edit/master/experiments/xdelta) experiment goes into more details 
