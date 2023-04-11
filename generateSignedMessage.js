const EthereumTx = require('ethereumjs-tx').Transaction;
const { keccak256, toBuffer, ecsign, stripHexPrefix } = require('ethereumjs-util');

// Private key of the signer
const privateKey = 'e95e45c0b1d86090b642a28c872827941e11f30fcba09cd3af0cbf2410a41d95';

// Message to sign
const message = 'Hello World';
const hexStr = Buffer.from(message, 'utf8').toString('hex');

// Calculate the hash of the message
const messageHash = keccak256(Buffer.from(hexStr));

// Sign the message hash with the private key
const signature = ecsign(messageHash, toBuffer('0x'+stripHexPrefix(privateKey)));

// Format the signature as a hex string
const r = '0x' + signature.r.toString('hex');
const s = '0x' + signature.s.toString('hex');
const v = '0x' + signature.v.toString(16);

// Construct the signed message
const signedMessage = '0x' + messageHash.toString('hex') + v.slice(2) + r.slice(2) + s.slice(2);

console.log(signedMessage);
