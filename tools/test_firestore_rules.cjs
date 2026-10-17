// Run against a local Firestore emulator, never a real project.
const assert = require('node:assert/strict');
const base = 'http://127.0.0.1:8089/v1/projects/demo-tradinggame/databases/(default)/documents/';
function token(uid) {
  const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  return `${encode({alg: 'none', typ: 'JWT'})}.${encode({sub: uid, user_id: uid, aud: 'demo-tradinggame', iss: 'https://securetoken.google.com/demo-tradinggame', iat: Math.floor(Date.now()/1000), exp: Math.floor(Date.now()/1000)+3600, firebase: {sign_in_provider: 'password'}})}.`;
}
async function request(path, uid, fields, expected) {
  const headers = {'Content-Type': 'application/json'};
  if (uid) headers.Authorization = `Bearer ${token(uid)}`;
  const response = await fetch(base + path, {method: fields ? 'PATCH' : 'GET', headers,
    body: fields ? JSON.stringify({fields}) : undefined});
  const body = await response.text();
  assert.equal(response.status, expected, `${uid ?? 'anonymous'} ${path}: ${body}`);
}
async function main() {
  const profile = {displayName: {stringValue: 'Trader'}, countryCode: {stringValue: 'AT'}};
  await request('profiles/alice', 'alice', profile, 200);
  await request('profiles/alice', 'alice', null, 200);
  await request('profiles/alice', null, null, 403);
  await request('profiles/alice', 'bob', null, 403);
  await request('profiles/alice', 'bob', profile, 403);
  await request('profiles/alice', 'alice', {...profile, admin: {booleanValue: true}}, 403);
  await request('profiles/alice', 'alice', {...profile, countryCode: {stringValue: 'XX'}}, 403);
  await request('profiles/alice', 'alice', {...profile, displayName: {integerValue: '123'}}, 403);
  await request('portfolios/alice', 'alice', {cash: {doubleValue: 100}}, 200);
  await request('portfolios/alice', 'bob', null, 403);
  await request('portfolios/alice/positions/one', 'bob', {amount: {integerValue: '5'}}, 403);
  await request('users/alice', 'bob', {displayName: {stringValue: 'Impostor'}}, 403);
  await request('leaderboard/alice', 'alice', {name: {stringValue: 'Trader'}}, 200);
  await request('leaderboard/alice', null, null, 200);
  await request('leaderboard/alice', 'bob', {name: {stringValue: 'Impostor'}}, 403);
  console.log('15 Firestore ownership and profile validation checks passed.');
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
