## Question

Is the content-based layer ID the same for the same content, irregardless of progenitor?

## Test
Here we create two images, one based on debian and one based on alpine.
Each of them then has a layer that copies the `blah.conf` fromm this directory, into the image.

We then see if the layers that represents the `blah.conf` copy have the same ID.

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

But the content-based ID is supposed to be a hash of the contents...

Let's dig a bit deeper and do a diff of the hexdumps of these 'identical' layers.

```
# tar xOf debian.tar 8f9cd17cd4e4dd7688baaba8522401aaefd3789b037749b6052530cdee6d8509/layer.tar | xxd > debian.hex
# tar xOf alpine.tar a5492ee14e891e935493d8fbf3ee2e51263627aae3b4b416dab37328010be9ef/layer.tar | xxd > alpine.hex
# diff -u alpine.hex debian.hex
--- debian.hex	2017-01-20 12:16:30.000000000 -0700
+++ alpine.hex	2017-01-20 12:16:05.000000000 -0700
@@ -7,7 +7,7 @@
 00000060: 0000 0000 3030 3430 3735 3500 3030 3030  ....0040755.0000
 00000070: 3030 3000 3030 3030 3030 3000 3030 3030  000.0000000.0000
 00000080: 3030 3030 3030 3000 3133 3034 3034 3630  0000000.13040460
-00000090: 3237 3200 3031 3030 3231 0020 3500 0000  272.010021. 5...
+00000090: 3237 3100 3031 3030 3230 0020 3500 0000  271.010020. 5...
 000000a0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
 000000b0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
 000000c0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
```

Interesting, two small differences. Looking at this in context of the complete dump and referencing the [tar documentation](https://www.gnu.org/software/tar/manual/html_node/Standard.html) we can derive that the mtime on the `/etc` folder entry in the tar is 1 second older in the alpine layer.
My hypothesis is that this is the time that the conf file was copied into the directory, each build ran in < 1 second giving mtimes inside that range.

Doing another build bypassing the cache, we can confirm this:

```
# docker build -t layerid-alpine --no-cache -f Dockerfile.alpine .
# # Find and extract the layer tar hex and do a new diff
--- alpine.hex	2017-01-20 12:50:26.000000000 -0700
+++ debian.hex	2017-01-20 12:16:30.000000000 -0700
@@ -6,8 +6,8 @@
 00000050: 0000 0000 0000 0000 0000 0000 0000 0000  ................
 00000060: 0000 0000 3030 3430 3735 3500 3030 3030  ....0040755.0000
 00000070: 3030 3000 3030 3030 3030 3000 3030 3030  000.0000000.0000
-00000080: 3030 3030 3030 3000 3133 3034 3034 3634  0000000.13040464
-00000090: 3233 3400 3031 3030 3233 0020 3500 0000  234.010023. 5...
+00000080: 3030 3030 3030 3000 3133 3034 3034 3630  0000000.13040460
+00000090: 3237 3200 3031 3030 3231 0020 3500 0000  272.010021. 5...
 000000a0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
 000000b0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
 000000c0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
```

Yup the clock has jumped forward quite a bit now compared to when we did the original Debian build.

## Answer

Yes, it is a content-based ID. If the content of the tar are identical then you will get the same content ID.
Modified date is very important for build systems and for many runtime environments. Because of this importance this value it is included in the content-based ID hash.

This also means that the layer ID will most likely change for every build, even if there are no changes to the "contents" of the file.
The build process alone modifies the mtime to be the current date, for any directory that has a file added.

This will happen if you flush your cache, or if you build the container on two different systems.

This would be an especially critical reason to be able to [share build caches](https://github.com/docker/docker/issues/20316).
If you don't build from cache, every layer that adds a file will get a new layer ID every build, and will need to be pushed and pulled.

This is a bit at odds of our use-case of building an ultra-efficient image transport system; we'll still get value out of using identical layer IDs from other images that already reside on the host in cases where caches are used efficiently.

We'll just need to be smarter with layers that _don't_ have the same layer IDs. On the positive side this will mean a much bigger win for the value of doing the cross-stack binary deltas work

The binary delta would compare every layer residing on the target node against every layer we want to send (since we have all layers in a registry we can just ask the target node for a full manifest metadata) and seeing if a binary delta between the two (using xdelta3) can beat bzip2's 20:1ish.
Some early experiments show promise (50Mb layer update reduced to a 56Kb delta).
