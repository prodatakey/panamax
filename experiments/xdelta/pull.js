const registry = require('docker-registry-client');
const bunyan = require('bunyan');
const fs = require('fs');

var log = bunyan.createLogger({
    name: 'regplay',
    level: 'trace'
});

const client = registry.createClientV2({ name: 'nginx', maxSchemaVersion: 2 });

client.listTags((err, tags) => {
  console.log(JSON.stringify(tags, null, 4));
});

const downloadBlob = (client, digest, file) => {
  client.createBlobReadStream({ digest }, (err, stream) => {
    var fout = fs.createWriteStream(file);
    fout.on('finish', function () {
      console.log('Done downloading blob', digest);
      client.close();
    });
    stream.pipe(fout);
    stream.resume();
  });
};

const layerFileExists = (digest) => {
  // Get the contents of the directory
  const files = fs.readdirSync('./');

  // See if any of the file names contain this digest
  for(file of files)
    if(file.includes(digest))
      return true;

  return false;
};

const downloadLayer = (client, ref, digest) => {
  if(!layerFileExists(digest))
    downloadBlob(client, digest, `layer-${ref}-${digest}.tar.gz`);
};

const downloadImage = (client, ref) => {
  client.getManifest({ ref }, (err, manifest) => {
    if(manifest.schemaVersion !== 2)
      return;

    fs.writeFile(`registry-manifest-${ref}.json`, JSON.stringify(manifest, null, 4));
    downloadBlob(client, manifest.config.digest, `manifest-${ref}.json`);

    for(const layer of manifest.layers)
      downloadLayer(client, ref, layer.digest);
  });
}

downloadImage(client, '1.11.7');
downloadImage(client, '1.11.8');
