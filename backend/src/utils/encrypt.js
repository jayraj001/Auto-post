const CryptoJS = require('crypto-js');

const KEY = process.env.ENCRYPTION_KEY;

const encrypt = (text) => CryptoJS.AES.encrypt(text, KEY).toString();

const decrypt = (ciphertext) => {
  const bytes = CryptoJS.AES.decrypt(ciphertext, KEY);
  return bytes.toString(CryptoJS.enc.Utf8);
};

module.exports = { encrypt, decrypt };
