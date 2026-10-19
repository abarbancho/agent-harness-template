// Template maintenance tool. Not copied to projects: init deletes modules/.
// Checks every non-stub schema against its examples:
//   schemas/examples/<name>.valid.json   must validate
//   schemas/examples/<name>.invalid.json must NOT validate (the first error is printed so a
//   human can confirm it fails for the intended reason)
//
// Usage: AJV_DIR=<dir containing node_modules/ajv> node modules/tools/validate-examples.cjs [root]
//   npm install --prefix <dir> ajv@8     (install it outside the project)
const fs = require('fs');
const path = require('path');

const ajvDir = process.env.AJV_DIR || process.cwd();
let Ajv2020;
try {
  Ajv2020 = require(require.resolve('ajv/dist/2020', { paths: [ajvDir] }));
} catch (e) {
  console.error('Cannot load ajv/dist/2020. Set AJV_DIR to a directory with ajv@8 installed.');
  process.exit(2);
}

const root = path.resolve(process.argv[2] || path.join(__dirname, '..', '..'));
const dirs = [path.join(root, 'schemas')];
const modulesDir = path.join(root, 'modules');
if (fs.existsSync(modulesDir)) {
  for (const m of fs.readdirSync(modulesDir)) dirs.push(path.join(modulesDir, m, 'files', 'schemas'));
}

const read = (p) => JSON.parse(fs.readFileSync(p, 'utf8'));
const schemas = [];
for (const dir of dirs) {
  if (!fs.existsSync(dir)) continue;
  for (const f of fs.readdirSync(dir).filter((n) => n.endsWith('.schema.json')).sort()) {
    const file = path.join(dir, f);
    const schema = read(file);
    schemas.push({ name: f.replace('.schema.json', ''), dir, file, schema, stub: /TODO/.test(schema.description || '') });
  }
}

const ajv = new Ajv2020({ allErrors: true });
for (const s of schemas.filter((x) => !x.stub)) ajv.addSchema(s.schema);

let failures = 0;
const fail = (msg) => { failures++; console.log('  FAIL ' + msg); };

for (const s of schemas) {
  console.log(`${s.name}${s.stub ? '  (stub, skipped)' : ''}`);
  if (s.stub) continue;
  const validate = ajv.getSchema(s.schema.$id);
  if (!validate) { fail('schema not compiled'); continue; }
  for (const kind of ['valid', 'invalid']) {
    const file = path.join(s.dir, 'examples', `${s.name}.${kind}.json`);
    if (!fs.existsSync(file)) { fail(`missing example: ${path.relative(root, file)}`); continue; }
    const ok = validate(read(file));
    if (kind === 'valid' && ok) console.log('  ok   valid example validates');
    else if (kind === 'valid') fail('valid example rejected: ' + ajv.errorsText(validate.errors));
    else if (!ok) console.log(`  ok   invalid example rejected (${validate.errors[0].instancePath || '/'} ${validate.errors[0].message})`);
    else fail('invalid example was accepted');
  }
}

// Files that modules ship as ready-to-use instances of a schema. They must validate.
// To ship another instance, add a line here.
const INSTANCES = [
  { file: 'config/guardrails.policy.json', schema: 'policy' },
  { file: 'evals/suite.json', schema: 'eval-suite' },
];
for (const inst of INSTANCES) {
  const candidates = [path.join(root, inst.file)];
  if (fs.existsSync(modulesDir)) {
    for (const m of fs.readdirSync(modulesDir)) candidates.push(path.join(modulesDir, m, 'files', inst.file));
  }
  for (const file of candidates.filter((c) => fs.existsSync(c))) {
    console.log(`instance ${path.relative(root, file)} against ${inst.schema}`);
    const target = schemas.find((s) => s.name === inst.schema && !s.stub);
    if (!target) { fail(`schema ${inst.schema} not found or is a stub`); continue; }
    const validate = ajv.getSchema(target.schema.$id);
    if (validate(read(file))) console.log('  ok   shipped instance validates');
    else fail('shipped instance rejected: ' + ajv.errorsText(validate.errors));
  }
}

console.log(failures ? `\n${failures} failure(s)` : '\nall examples behave as expected');
process.exit(failures ? 1 : 0);
