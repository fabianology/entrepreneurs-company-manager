// Explicit staging-only, synthetic accounts, no emails, automatic exact-ID cleanup.
// Run: node supabase/ops/staging_loan_payment_smoke.mjs --staging-only
// Requires an authenticated Supabase CLI. Credentials stay in memory.
import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import assert from 'node:assert/strict';

if (process.argv[2] !== '--staging-only') throw new Error('Explicit --staging-only required');
const ref = 'bvtuyzhyospqxvpzcrmv';
const url = `https://${ref}.supabase.co`;
const keys = JSON.parse(execFileSync('supabase', ['projects','api-keys','--project-ref',ref,'--output','json'],
  { encoding:'utf8', stdio:['ignore','pipe','pipe'] }));
const service = keys.find(k => k.name === 'service_role' && k.type === 'legacy')?.api_key;
const anon = keys.find(k => k.name === 'anon' && k.type === 'legacy')?.api_key;
if (!service || !anon) throw new Error('Missing staging credentials');
const run = `loan-atomic-${randomUUID()}`;
const password = `${randomUUID()}aA!9`;
const company = randomUUID(), loanA = randomUUID(), loanB = randomUUID();
const bankA = randomUUID(), bankB = randomUUID(), card = randomUUID(), document = randomUUID();
const users = [], sessions = {};
let checks = 0;
function check(value, message) { assert.ok(value, message); checks++; }
async function request(path, token = service, method = 'GET', body) {
  const response = await fetch(url + path, { method, signal: AbortSignal.timeout(30000),
    headers: { apikey: token === service ? service : anon, Authorization: `Bearer ${token}`,
      'Content-Type':'application/json', Prefer:'return=representation' },
    body: body === undefined ? undefined : JSON.stringify(body) });
  const raw = await response.text(); let data;
  try { data = JSON.parse(raw); } catch { data = null; }
  return { status: response.status, data };
}
async function ok(...args) {
  const result = await request(...args);
  if (result.status < 200 || result.status >= 300) {
    throw new Error(`${args[2] ?? 'GET'} ${args[0].split('?')[0]}: ${result.status} ${result.data?.code ?? ''}`);
  }
  return result.data;
}
const rpc = (name, token, body = {}) => ok(`/rest/v1/rpc/${name}`,token,'POST',body);
const read = token => rpc('miloom_read_loans',token);
const saveBody = (snapshot, payments = snapshot.payments) => ({
  p_loan: snapshot.loan, p_payments: payments, p_expected_revision: snapshot.loan.revision ?? null
});
const save = (token, body) => rpc('miloom_save_loan',token,body);
async function denied(token, body, code) {
  const result = await request('/rest/v1/rpc/miloom_save_loan',token,'POST',body);
  check(result.status >= 400 && result.data?.code === code, `Expected ${code}, got ${result.status}/${result.data?.code}`);
}

async function createUser(role) {
  const email = `${run}-${role}@example.com`;
  const user = await ok('/auth/v1/admin/users',service,'POST',{
    email,password,email_confirm:true,user_metadata:{fixture:run,test_only:true}
  });
  users.push({id:user.id,email,role});
  sessions[role] = (await ok('/auth/v1/token?grant_type=password',anon,'POST',{email,password})).access_token;
}

try {
  for (const role of ['owner','editor','viewer']) await createUser(role);
  const ownerID = users.find(u => u.role === 'owner').id;
  console.log('Disposable users ready; testing loan transactions.');
  await ok('/rest/v1/companies',sessions.owner,'POST',{id:company,user_id:ownerID,name:run,structure:'LLC'});
  await ok('/rest/v1/institutions?select=id',sessions.owner,'POST',[bankA,bankB].map((id,i)=>({
    id,user_id:ownerID,company_id:company,name:`Synthetic Bank ${i}`,accounts_data:[],is_disconnected:false
  })));
  await ok('/rest/v1/financial_cards?select=id',sessions.owner,'POST',{
    id:card,user_id:ownerID,company_id:company,name:'Unshared synthetic card',network:'Visa',
    type:'Credit',status:'Active',limit:1000,autopay:'No',balance:0,mo_payment:0,apr:0,promo_apr:0,card_holder_type:'Mine'
  });
  await ok('/rest/v1/company_documents',sessions.owner,'POST',{
    id:document,user_id:ownerID,company_id:company,name:'Unshared synthetic document',type:'Legal',visibility:'entity',renewal_metadata:{}
  });
  const draft = id => ({id,user_id:ownerID,company_id:company,name:`${run} loan`,role:'Borrower',lender:null,
    principal_amount:1000,remaining_balance:1000,interest_type:'Percentage',interest_rate:0,
    term:'10 months',term_years:0,term_months:10,schedule_frequency:'Monthly',monthly_payment:100,
    start_date:'2026-09-22T12:00:00Z',status:'Active'});
  const payment = (id,amount) => ({id:randomUUID(),user_id:ownerID,loan_id:id,date:'2026-09-22T12:00:00Z',amount,source:run});
  let a = await save(sessions.owner,{p_loan:draft(loanA),p_payments:[],p_expected_revision:null});
  const b = await save(sessions.owner,{p_loan:draft(loanB),p_payments:[payment(loanB,7)],p_expected_revision:null});
  check(a.loan.revision === 0 && b.payments.length === 1, 'Owner create receipt');
  async function share(role,type,id,level) {
    const result = await rpc('miloom_share_resource',sessions.owner,{
      p_email:users.find(u=>u.role===role).email,p_role:level,p_resource_id:id,p_resource_type:type
    });
    check(result.status === 'shared_directly', 'Expected direct synthetic share, no email');
  }
  await share('editor','loan',loanA,'Editor');
  await share('viewer','loan',loanA,'Viewer');
  const editorLoans = await read(sessions.editor);
  check(editorLoans.length === 1 && editorLoans[0].loan.id === loanA, 'Exact Editor read leaked sibling');
  a = editorLoans[0];
  a.loan.name = 'Atomic shared loan saved'; a.loan.remaining_balance = 975;
  const body = saveBody(a,[payment(loanA,25)]);
  a = await save(sessions.editor,body);
  check(a.loan.name === 'Atomic shared loan saved' && a.payments.length === 1 && a.payments[0].amount === 25,
    'Editor atomic save missing data');
  const reloaded = (await read(sessions.editor))[0];
  assert.deepEqual(reloaded,a); checks++;
  check((await read(sessions.viewer))[0].payments.length === 1, 'Viewer ledger read missing');
  await denied(sessions.viewer,saveBody(a),'42501');
  await denied(sessions.editor,saveBody(b),'42501');
  await denied(sessions.editor,body,'PT409');
  await denied(sessions.editor,{...saveBody(a),p_expected_revision:null},'PT409');
  await denied(sessions.editor,saveBody(a,[{...payment(loanA,1),user_id:users[1].id}]),'22023');
  await denied(sessions.editor,saveBody(a,[payment(loanB,1)]),'22023');
  await denied(sessions.editor,saveBody(a,[payment(loanA,-1)]),'22023');
  await denied(sessions.editor,saveBody(a,[a.payments[0],a.payments[0]]),'22023');
  await denied(sessions.editor,saveBody(a,[{...b.payments[0],loan_id:loanA}]),'22023');
  assert.deepEqual((await read(sessions.editor))[0],a); checks++;
  const rawInsert = await request('/rest/v1/loan_payments',sessions.editor,'POST',payment(loanA,1));
  check(rawInsert.status >= 400, 'Collaborator bypassed transaction via REST');

  // Two actual concurrent HTTP saves from the same revision: exactly one wins.
  const contenders = ['one','two'].map(label => ({
    ...saveBody(a,[...a.payments,payment(loanA,5)]), p_loan:{...a.loan,name:`Concurrent ${label}`,remaining_balance:970}
  }));
  const outcomes = await Promise.all(contenders.map(payload => request('/rest/v1/rpc/miloom_save_loan',sessions.editor,'POST',payload)));
  check(outcomes.filter(r=>r.status===200).length === 1 && outcomes.filter(r=>r.status===409 && r.data?.code==='PT409').length === 1,
    'Concurrent saves did not serialize with one conflict');
  a = (await read(sessions.editor))[0];
  check(a.payments.length === 2, 'Concurrent write lost or duplicated a payment');
  await ok('/rest/v1/loan_payments',sessions.owner,'POST',payment(loanA,3));
  await denied(sessions.editor,saveBody(a),'PT409');
  a = (await read(sessions.editor))[0];
  check(a.payments.length === 3, 'Legacy owner write not visible to Editor');
  a = await save(sessions.editor,saveBody(a,[]));
  check(a.payments.length === 0, 'Explicit ledger removal failed');

  const managed = await rpc('miloom_list_managed_access',sessions.owner);
  const grant = managed.find(g=>g.resource_id===loanA && g.subject_user_id===users[1].id && g.role==='Editor');
  check(!!grant, 'Cannot resolve exact synthetic grant');
  await rpc('miloom_revoke_access',sessions.owner,{p_access_id:grant.access_id,p_access_kind:grant.access_kind,p_scope:'resource'});
  await denied(sessions.editor,saveBody(a),'42501');
  check((await read(sessions.editor)).length === 0, 'Revoked Editor still reads ledger');
  // Regression gate: collection creation must now succeed, never be skipped.
  await share('editor','all_institutions',company,'Editor');
  await denied(sessions.editor,saveBody(a),'42501');
  const visibleBanks = await rpc('miloom_visible_institutions',sessions.editor);
  check(visibleBanks.length === 2 && visibleBanks.every(b=>[bankA,bankB].includes(b.id)), 'Bank collection read scope');
  check((await read(sessions.editor)).length === 0,'Bank collection revealed loans');
  check((await rpc('miloom_visible_financial_cards',sessions.editor)).length === 0,'Bank collection revealed cards');
  check((await ok(`/rest/v1/company_documents?select=id`,sessions.editor)).length === 0,'Bank collection revealed documents');
  const editedBank = await ok(`/rest/v1/institutions?id=eq.${bankA}&select=id`,sessions.editor,'PATCH',{name:'Edited synthetic bank'});
  const reloadedBank = (await rpc('miloom_visible_institutions',sessions.editor)).find(b=>b.id===bankA);
  check(editedBank.length === 1 && reloadedBank?.name === 'Edited synthetic bank','Bank collection Editor save');

  // Pending invitation path must accept into the same restricted scope. No
  // email is sent; the invitee is created only after the invitation exists.
  const pending = await rpc('miloom_share_resource',sessions.owner,{
    p_email:`${run}-invitee@example.com`,p_role:'Viewer',p_resource_id:company,p_resource_type:'all_institutions'
  });
  check(pending.status === 'invitation_created' && !!pending.invitation_id,'Bank collection invitation creation');
  await createUser('invitee');
  check((await rpc('miloom_visible_institutions',sessions.invitee)).length === 0,'Pending invitation already granted access');
  const accepted = await rpc('miloom_accept_invitation',sessions.invitee,{p_invitation_id:pending.invitation_id});
  check(accepted.status === 'accepted' && accepted.resource_type === 'all_institutions','Bank collection invitation acceptance');
  check((await rpc('miloom_visible_institutions',sessions.invitee)).length === 2,'Accepted Viewer cannot read banks');
  const viewerEdit = await ok(`/rest/v1/institutions?id=eq.${bankA}&select=id`,sessions.invitee,'PATCH',{name:'Must not save'});
  check(viewerEdit.length === 0,'Collection Viewer edited bank');
  check((await read(sessions.invitee)).length === 0,'Collection Viewer inherited loan access');
  const replay = await request('/rest/v1/rpc/miloom_accept_invitation',sessions.invitee,'POST',{p_invitation_id:pending.invitation_id});
  check(replay.status >= 400 && replay.data?.code === 'P0002','Invitation replay accepted');

  await share('editor','all_financials',company,'Editor');
  a = await save(sessions.editor,saveBody(a,[payment(loanA,2)]));
  check(a.payments.length === 1 && (await read(sessions.editor)).length === 2, 'Financial collection scope failed');
  console.log(JSON.stringify({project:ref,checks,result:'loan and bank-collection contracts passed',concurrentSaves:'one accepted, one rejected',invitation:'pending → accepted; replay denied'}));
} finally {
  // Only IDs created in this process, verified against the unique marker.
  for (const user of users) {
    const current = await ok(`/auth/v1/admin/users/${user.id}`);
    if (current.user_metadata?.fixture !== run) throw new Error('Cleanup marker mismatch');
  }
  await ok(`/rest/v1/resource_shares?resource_id=in.(${company},${loanA},${loanB})`,service,'DELETE');
  await ok(`/rest/v1/resource_invitations?resource_id=in.(${company},${loanA},${loanB})`,service,'DELETE');
  await ok(`/rest/v1/companies?id=eq.${company}&name=eq.${encodeURIComponent(run)}`,service,'DELETE');
  for (const user of users) {
    await ok(`/auth/v1/admin/users/${user.id}`,service,'DELETE');
    assert.equal((await request(`/auth/v1/admin/users/${user.id}`)).status,404);
  }
  check((await ok(`/rest/v1/loan_payments?loan_id=in.(${loanA},${loanB})&select=id`)).length === 0,'Payment cleanup incomplete');
  check((await ok(`/rest/v1/loans?id=in.(${loanA},${loanB})&select=id`)).length === 0,'Loan cleanup incomplete');
  for (const [table,ids] of [['institutions',[bankA,bankB]],['financial_cards',[card]],['company_documents',[document]]]) {
    check((await ok(`/rest/v1/${table}?id=in.(${ids.join(',')})&select=id`)).length === 0,`${table} cleanup incomplete`);
  }
  console.log('Cleanup verified: synthetic loans/payments removed; all created users confirmed 404.');
}
