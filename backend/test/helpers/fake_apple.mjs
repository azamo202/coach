import { execFileSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

/**
 * مصنع سلسلة شهادات وهمية تحاكي بنية توقيع Apple.
 *
 * لا نستطيع توليد توقيع موقّع من Apple فعلاً، لكن ما نريد اختباره هو
 * **منطق التحقق** لا مفاتيح Apple: سلسلة جذر ← وسيط ← طرفية، وتوقيع
 * ES256 بصيغة P1363. فنبني سلسلة مطابقة البنية ونثبّت جذرها كمرساة ثقة.
 */

function openssl(args, cwd) {
  execFileSync('openssl', args, { cwd, stdio: ['ignore', 'pipe', 'pipe'] });
}

function b64url(buffer) {
  return Buffer.from(buffer).toString('base64url');
}

export function createFakeAppleChain() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'coachmint-apple-'));

  fs.writeFileSync(
    path.join(dir, 'ca.cnf'),
    '[ca_ext]\nbasicConstraints=critical,CA:TRUE\nkeyUsage=critical,keyCertSign,cRLSign\n' +
      '[leaf_ext]\nbasicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature\n',
  );

  // الجذر — موقّع ذاتياً.
  openssl(['ecparam', '-name', 'prime256v1', '-genkey', '-noout', '-out', 'root.key'], dir);
  openssl(
    ['req', '-new', '-x509', '-key', 'root.key', '-out', 'root.crt', '-days', '3650',
      '-sha256', '-subj', '/C=US/O=Fake Apple Inc./CN=Fake Apple Root CA - G3'],
    dir,
  );

  // الوسيط — موقّع من الجذر.
  openssl(['ecparam', '-name', 'prime256v1', '-genkey', '-noout', '-out', 'int.key'], dir);
  openssl(
    ['req', '-new', '-key', 'int.key', '-out', 'int.csr',
      '-subj', '/C=US/O=Fake Apple Inc./CN=Fake Apple Intermediate'],
    dir,
  );
  openssl(
    ['x509', '-req', '-in', 'int.csr', '-CA', 'root.crt', '-CAkey', 'root.key',
      '-CAcreateserial', '-out', 'int.crt', '-days', '3650', '-sha256',
      '-extfile', 'ca.cnf', '-extensions', 'ca_ext'],
    dir,
  );

  // الطرفية — موقّعة من الوسيط، وهي التي توقّع الحمولات.
  openssl(['ecparam', '-name', 'prime256v1', '-genkey', '-noout', '-out', 'leaf.key'], dir);
  openssl(
    ['req', '-new', '-key', 'leaf.key', '-out', 'leaf.csr',
      '-subj', '/C=US/O=Fake Apple Inc./CN=Fake Apple Signing'],
    dir,
  );
  openssl(
    ['x509', '-req', '-in', 'leaf.csr', '-CA', 'int.crt', '-CAkey', 'int.key',
      '-CAcreateserial', '-out', 'leaf.crt', '-days', '3650', '-sha256',
      '-extfile', 'ca.cnf', '-extensions', 'leaf_ext'],
    dir,
  );

  for (const name of ['root', 'int', 'leaf']) {
    openssl(['x509', '-in', `${name}.crt`, '-outform', 'DER', '-out', `${name}.der`], dir);
  }

  const der = (name) => fs.readFileSync(path.join(dir, `${name}.der`));
  const leafKey = crypto.createPrivateKey(fs.readFileSync(path.join(dir, 'leaf.key')));

  const x5c = [der('leaf'), der('int'), der('root')].map((b) => b.toString('base64'));

  /** يوقّع حمولة JSON بنفس صيغة Apple. */
  function sign(payload, { header = {} } = {}) {
    const head = b64url(JSON.stringify({ alg: 'ES256', x5c, ...header }));
    const body = b64url(JSON.stringify(payload));
    const signature = crypto
      .createSign('SHA256')
      .update(`${head}.${body}`)
      .sign({ key: leafKey, dsaEncoding: 'ieee-p1363' });
    return `${head}.${body}.${b64url(signature)}`;
  }

  return {
    dir,
    rootPath: path.join(dir, 'root.der'),
    sign,
    cleanup: () => fs.rmSync(dir, { recursive: true, force: true }),
  };
}
