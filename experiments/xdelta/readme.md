## Question

Can we shrink layer transfer sizes by doing a binary delta against the same layer in a previous release?
How about with an unrelated layer?
How about a layer from a different image?
Does doing a delta against an unrelated source layer have better win when the source layer is much larger than the target?

The big benefit here would be that we can leverage layers already resident on a target node to create a binary delta for a layer that we _want_ on the node.
This will be most beneficial if the service generating these diff packages has local high-speed connectivity to the source registry.

bzip2 gives us about 15-20:1 compression ratio for the couple images I tried it on. Docker registry uses gzip when handling layers but `docker save` and `docker load` do not.
The hope is to be able to improve on this ratio by more than an order of magnitude in most cases.

## Test

Here we'll analyze layers from two versions of nginx `1.11.7` and `1.11.8`.

The `pull.js` script grabs the registry manifest, image manifest, and all layers for these images from docker hub.

If we look at the layers we see what is expected in an image that has been rebuilt for an update.
This is particularly poignant because of the necessity of updating directory mtimes to the image build time found in the [singleLayerId](https://github.com/prodatakey/panamax/tree/master/experiments/singleLayerId) experiment.

```console
-rw-r--r--  1 josh staff 3.5K Jan 21 15:21 layer-1.11.7-sha256:325b624bee1c2cdb2a603102412eec6fc20386a60965f33244f1ef256f29e299.tar
-rw-r--r--  1 josh staff  58M Jan 21 15:16 layer-1.11.7-sha256:64f0219ba3ea802cf10ed9b7e73146ea4189a1341cbebae855035d85b420c3ae.tar
-rw-r--r--  1 josh staff 123M Jan 21 15:16 layer-1.11.7-sha256:75a822cd7888e394c49828b951061402d31745f596b1f502758570f2d0ee79e2.tar

-rw-r--r--  1 josh staff 3.5K Jan 21 15:16 layer-1.11.8-sha256:9cac4850e5df710bce8b514acee92630e27f36761a36e55cbef0cc8d1d0317d5.tar
-rw-r--r--  1 josh staff  58M Jan 21 15:16 layer-1.11.8-sha256:d7a91cdb22f0fe7b35f7f492de75096d491b2cb5ea9a3a9bd775210a003af7f3.tar
-rw-r--r--  1 josh staff 123M Jan 21 15:16 layer-1.11.8-sha256:5040bd2983909aa8896b9932438c3f1479d25ae837a5f6220242a264d0221f2d.tar
```

Each layer has a corresponding layer in the other image and they share nearly identical sizes.
In this case none of the layers share identical hashes so we can not save resources with the elide-identical-layers strategy.

We can easily tell which layers in this sample are derived from the same commands in each release. All updates will not be this unambiguous.
How, for example, do we teach the system to find corresponding layers when one is added or removed in a later build or they vary wildly in size?

### Corresponding Layer Delta

Our goal is to find the minimum binary delta for a target layer by leveraging another layer.
Logic seems to dictate that if we diff layers have the most similarities that we'll get the smallest delta. Let's give it a try.

```console
# xdelta3 -s layer-1.11.7-sha256:325b624bee1c2cdb2a603102412eec6fc20386a60965f33244f1ef256f29e299.tar -f layer-1.11.8-sha256:9cac4850e5df710bce8b514acee92630e27f36761a36e55cbef0cc8d1d0317d5.tar > layer1.delta
# xdelta3 -s layer-1.11.7-sha256:64f0219ba3ea802cf10ed9b7e73146ea4189a1341cbebae855035d85b420c3ae.tar -f layer-1.11.8-sha256:d7a91cdb22f0fe7b35f7f492de75096d491b2cb5ea9a3a9bd775210a003af7f3.tar > layer1.delta
# xdelta3 -s layer-1.11.7-sha256:75a822cd7888e394c49828b951061402d31745f596b1f502758570f2d0ee79e2.tar -f layer-1.11.8-sha256:5040bd2983909aa8896b9932438c3f1479d25ae837a5f6220242a264d0221f2d.tar > layer1.delta
# ls -la *.delta
-rw-r--r-- 1 josh staff  373 Jan 21 15:33 layer1.delta
-rw-r--r-- 1 josh staff 886K Jan 21 15:33 layer2.delta
-rw-r--r-- 1 josh staff 1.1M Jan 21 15:33 layer3.delta
```

These are pretty good "compression" ratios:
layer1 10:1
layer2 65:1
layer3 111:1

Let's compare to gzip compression:

```console
# gzip layer-1.11.8*
# ls -la *.gz
-rw-r--r-- 1 josh staff 280 Jan 21 15:16 layer-1.11.8-sha256:9cac4850e5df710bce8b514acee92630e27f36761a36e55cbef0cc8d1d0317d5.tar.gz
-rw-r--r-- 1 josh staff 20M Jan 21 15:16 layer-1.11.8-sha256:d7a91cdb22f0fe7b35f7f492de75096d491b2cb5ea9a3a9bd775210a003af7f3.tar.gz
-rw-r--r-- 1 josh staff 50M Jan 21 15:16 layer-1.11.8-sha256:5040bd2983909aa8896b9932438c3f1479d25ae837a5f6220242a264d0221f2d.tar.gz
```

Looks like binary delta beats gzip in all cases except the incredibly small 3.5K layer.
The 100 bytes might not be worth the complexity of deciding when we should use a binary delta vs sending the layer compressed instead.
Though, this determination would be valuable in cases where the target node has no image layers with a decent delta from the target image.

Another good test would be to do a delta on all files contained in the two layers and see if we get a better aggregate size than doing a delta on the layers themselves.
This would be fairly complex, and considering the sizes of the deltas that we've been able to achieve so far doesn't really bear out the necessity of testing this method right now.

### Combined Layer Delta

Another easy test would be to do the delta with each image's layers in a tar.

```console
# tar cvf layers-1.11.7.tar layer-1.11.7*
# tar cvf layers-1.11.8.tar layer-1.11.8*
# xdelta3 -s layers-1.11.7.tar -f layers-1.11.8.tar > layers.delta
# ls -la layers*
-rw-r--r-- 1 josh staff 181M Jan 21 15:39 layers-1.11.7.tar
-rw-r--r-- 1 josh staff 181M Jan 21 15:39 layers-1.11.8.tar
-rw-r--r-- 1 josh staff  53M Jan 21 15:41 layers.delta
```

Interesting. The deltas on the individual layers sum to about 2M but a delta of the combined layers comes in at a hefty 53MB.
Perhaps some tweaking of xdelta could help a little, but I doubt by 25x.

Testing with an increased source window size actually provides better compression than even the layers individually.

The individual layers delta comes to 1986373 bytes, and the full image delta:

```console
# xdelta3 -B 1000000000 -s nginx-1.11.7.tar nginx-1.11.8.tar nginx.delta
# ls -la nginx*
-rw-r--r--  1 josh josh 189597184 Apr 17 18:49 nginx-1.11.7.tar
-rw-r--r--  1 josh josh 189599744 Apr 17 18:49 nginx-1.11.8.tar
-rw-r--r--  1 josh josh   1935144 Apr 17 18:50 nginx.delta
```

With this it looks like doing a delta on the whole image is going to be just as efficient as going through layer matching machinations.

The only feature this may impact is efficiently sending an image where an old version of the same is not already on the target host.

Trying a delta between two images that share the same base OS and runtime layers does work well:

```console
# xdelta3 -B 1000000000 -s server1.tar server2.tar server.delta
# ls -la server*
-rw-r--r--  1 josh josh 382237696 Apr 17 19:06 server1.tar
-rw-r--r--  1 josh josh 270725632 Apr 17 18:11 server2.tar
-rw-r--r--  1 josh josh   9321569 Apr 17 19:17 server.delta
```

This looks to be viable method of sending, even dissimilar images, by doing a hamming check (like described in the next section) between images that do exist on the target to see if any are similar enough to bother with a binary diff.

Doing a diff with an image that uses a similar, but different distribution, Linux OS and completely different workload shows that we can still best gzip:

```console
# xdelta3 -B 1000000000 -s postgres.tar server.tar different.delta 
# ls -la
-rw-r--r--  1 josh josh  42927435 Apr 17 19:47 different.delta
-rw-r--r--  1 josh josh 128911872 Apr 17 19:38 postgres.tar
-rw-r--r--  1 josh josh 270725632 Apr 17 18:11 server.tar
# gzip server.tar
# ls -la server.tar.gz
-rw-r--r--  1 josh josh  88227974 Apr 17 18:11 server.tar.gz
```

This particular delta shows that we've been able to save another 50% over gzip.

### Finding Corresponding Layers

One obvious way to find what layer would be best to use as the source is to take every layer in the target image and calculate a binary delta against every layer in every image on the target node.
This could give us an advantage in cases where the target node has no layers from an earlier build of the target transfer image.
The downside of this method is that we have no way efficient way to compare the viability of a source and target layer pair without actually calculating a delta.

This isn't inviable, but having a method to compare how different two images using a once computed value would save a large amount of IO and CPU resources.

One method that could work to give us a qualitative value to the viability of two layers being used for a binary delta is the [Locality Sensitive Hash](https://en.wikipedia.org/wiki/Locality-sensitive_hashing).
This hashing process, quite the opposite of cryptographic hashes, will create values that are "close" to eachother when the contents of two inputs are close to eachother.

The hashes can then be computed once for each layer (and cached) and then compared using a hamming function to estimate the similarity of the two layers.

We'll be using an implementation of LSH by [TrendMicro called TLSH](https://github.com/trendmicro/tlsh) that was created mainly for efficiently finding similar files during digital forensics.

```console
# ./tlsh -c layer-1.11.8-sha256:d7a91cdb22f0fe7b35f7f492de75096d491b2cb5ea9a3a9bd775210a003af7f3.tar -f layer-1.11.7-sha256:325b624bee1c2cdb2a603102412eec6fc20386a60965f33244f1ef256f29e299.tar
1469	layer-1.11.7-sha256:325b624bee1c2cdb2a603102412eec6fc20386a60965f33244f1ef256f29e299.tar

# ./tlsh -c layer-1.11.8-sha256:d7a91cdb22f0fe7b35f7f492de75096d491b2cb5ea9a3a9bd775210a003af7f3.tar -f layer-1.11.7-sha256:64f0219ba3ea802cf10ed9b7e73146ea4189a1341cbebae855035d85b420c3ae.tar
   6	layer-1.11.7-sha256:64f0219ba3ea802cf10ed9b7e73146ea4189a1341cbebae855035d85b420c3ae.tar

# ./tlsh -c layer-1.11.8-sha256:d7a91cdb22f0fe7b35f7f492de75096d491b2cb5ea9a3a9bd775210a003af7f3.tar -f layer-1.11.7-sha256:75a822cd7888e394c49828b951061402d31745f596b1f502758570f2d0ee79e2.tar
 213	layer-1.11.7-sha256:75a822cd7888e394c49828b951061402d31745f596b1f502758570f2d0ee79e2.tar

# xdelta3 -s layer-1.11.7-sha256:325b624bee1c2cdb2a603102412eec6fc20386a60965f33244f1ef256f29e299.tar -f layer-1.11.8-sha256:d7a91cdb22f0fe7b35f7f492de75096d491b2cb5ea9a3a9bd775210a003af7f3.tar > layer.delta
# ls -la layer.delta
-rw-r--r-- 1 josh staff 17M Jan 21 18:52 layer.delta

# xdelta3 -s layer-1.11.7-sha256:64f0219ba3ea802cf10ed9b7e73146ea4189a1341cbebae855035d85b420c3ae.tar -f layer-1.11.8-sha256:d7a91cdb22f0fe7b35f7f492de75096d491b2cb5ea9a3a9bd775210a003af7f3.tar > layer.delta
# ls -la layer.delta
-rw-r--r-- 1 josh staff 886K Jan 21 18:53 layer.delta

# xdelta3 -s layer-1.11.7-sha256:75a822cd7888e394c49828b951061402d31745f596b1f502758570f2d0ee79e2.tar -f layer-1.11.8-sha256:d7a91cdb22f0fe7b35f7f492de75096d491b2cb5ea9a3a9bd775210a003af7f3.tar > layer.delta
# ls -la layer.delta
-rw-r--r-- 1 josh staff 17M Jan 21 18:53 layer.delta
```

This is a small sampling but there seems to be a positive correlation between delta size and the hamming distance.

## Conclusion 

We've seen that using a binary delta from a previous build of an image can give us incredible savings in the amount af data that would be needed to reify the image on the target node.

Taking advantage of LSH also seems like it would provide a high-efficiency method of finding the most viable layer out of a set for using as a binary delta source for a specific target layer.
