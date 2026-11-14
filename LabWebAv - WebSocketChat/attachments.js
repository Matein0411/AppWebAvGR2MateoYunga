const { createHash, randomUUID } = require('node:crypto');
const { mkdir, rename, unlink, writeFile } = require('node:fs/promises');
const { join } = require('node:path');

const maxAttachmentSize = 8 * 1024 * 1024;
const maxJsonSize = 16 * 1024;
const messageIdPattern = /^[a-f0-9]{64}$/;

function decodePacket(data, binary) {
  if (!binary) {
    if (data.length > maxJsonSize) throw new Error('Trama demasiado grande');
    return { packet: JSON.parse(data.toString()) };
  }
  const separator = data.indexOf(10);
  if (separator < 1 || separator > maxJsonSize) throw new Error('Cabecera inválida');
  return {
    packet: JSON.parse(data.toString('utf8', 0, separator)),
    file: data.subarray(separator + 1)
  };
}

function describeAttachment(file, filename, declaredType) {
  const name = typeof filename === 'string' ? filename.trim() : '';
  if (!file.length || file.length > maxAttachmentSize || !name ||
      /[\u0000-\u001f\u007f/\\]/u.test(name) || name.length > 180) return null;

  let mime = 'application/octet-stream';
  const matches = (hex) => file.subarray(0, hex.length / 2).toString('hex') === hex;
  const ascii = (start, end) => file.toString('ascii', start, end);
  if (matches('89504e470d0a1a0a')) mime = 'image/png';
  else if (matches('ffd8ff')) mime = 'image/jpeg';
  else if (['GIF87a', 'GIF89a'].includes(ascii(0, 6))) mime = 'image/gif';
  else if (ascii(0, 4) === 'RIFF' && ascii(8, 12) === 'WEBP') mime = 'image/webp';
  else if (ascii(0, 4) === 'RIFF' && ascii(8, 12) === 'WAVE') mime = 'audio/wav';
  else if (ascii(0, 4) === 'OggS' && declaredType === 'audio/ogg') mime = 'audio/ogg';
  else if (matches('1a45dfa3') && declaredType === 'audio/webm') mime = 'audio/webm';
  else if (ascii(4, 8) === 'ftyp' && ['audio/mp4', 'audio/x-m4a'].includes(declaredType)) mime = 'audio/mp4';
  else if (declaredType === 'audio/mpeg' && (ascii(0, 3) === 'ID3' ||
      (file[0] === 255 && (file[1] & 224) === 224))) mime = 'audio/mpeg';
  const kind = mime.startsWith('image/') ? 'image' : mime.startsWith('audio/') ? 'audio' : 'file';
  return { name, size: file.length, mime, kind, digest: createHash('sha256').update(file).digest('hex') };
}

function attachmentStore(directory) {
  const pathFor = (id, digest) => join(directory, `${id}-${digest}`);
  return {
    pathFor,
    async write(id, digest, file) {
      await mkdir(directory, { recursive: true });
      const temporary = join(directory, `${randomUUID()}.tmp`);
      try {
        await writeFile(temporary, file, { flag: 'wx' });
        // Un reintento con el mismo hash escribe exactamente los mismos bytes.
        await rename(temporary, pathFor(id, digest));
      } finally {
        await unlink(temporary).catch(() => {});
      }
    }
  };
}

module.exports = { attachmentStore, decodePacket, describeAttachment, maxAttachmentSize, maxJsonSize, messageIdPattern };
