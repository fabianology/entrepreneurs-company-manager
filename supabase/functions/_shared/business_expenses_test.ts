import { eligible, features, sanitize, validateCandidates, fingerprint, type SourceTransaction } from "./business_expenses.ts";
function assert(value: unknown, message="Assertion failed"): asserts value { if(!value) throw new Error(message); }
const transaction: SourceTransaction = {id:"transaction",user_id:"owner",account_id:"personal",canonical_account_id:"canonical",amount:59.99,currency:"USD",date:"2026-09-01",merchant_name:"Adobe"};
const profiles = [{company_id:"aviation",activity:"Aviation design and marketing",enabled:true},{company_id:"other",activity:"Design",enabled:true}];
Deno.test("personal sources are eligible without changing their source",()=>{
 const before=JSON.stringify(transaction); assert(eligible(transaction)); features(transaction,{},profiles,[]); assert(JSON.stringify(transaction)===before);
});
Deno.test("pending, removed duplicates, zero and invalid amounts never screen",()=>{
 for(const change of [{screening_excluded:true},{pending:true},{is_superseded_duplicate:true},{is_stale_pending_duplicate:true},{amount:0},{amount:NaN},{amount:null},{amount:-1}]) assert(!eligible({...transaction,...change}));
});
Deno.test("effective cash flow and account exclusions take precedence",()=>{
 assert(!eligible({...transaction,merchant_name:"Chase autopay"}));
 assert(!eligible(transaction,{flow_override:"ignored"}));
 assert(!eligible(transaction,{flow_override:"refund"}));
 assert(!eligible(transaction,{},["personal"])); assert(!eligible(transaction,{},["canonical"]));
 assert(eligible({...transaction,amount:-59.99},{flow_override:"expense"}));
});
Deno.test("AI payload excludes financial identifiers and unrelated evidence",()=>{
 const payload=features({...transaction,account_id:"sensitive-account-reference",user_id:"private-owner-id"},{},profiles,[{id:"1",company_id:"aviation",merchant:"Unrelated"}]);
 assert(!JSON.stringify(payload).includes("sensitive-account-reference")); assert(!JSON.stringify(payload).includes("private-owner-id")); assert(payload.entities[0].confirmations.length===0);
 assert(sanitize("person@example.com account 123456789") === "[email] account [number]");
});
Deno.test("unverified evidence and unknown Entity IDs are rejected",()=>{
 const input=features(transaction,{},profiles,[]);
 assert(validateCandidates([{entity_ref:"someone-else",score:.95,evidence_ids:[]}],input).length===0);
 assert(validateCandidates([{entity_ref:"aviation",score:.95,evidence_ids:["made-up"]}],input).length===0);
 assert(validateCandidates([{entity_ref:"aviation",score:1.2,evidence_ids:[]}],input).length===0);
});
Deno.test("model-only confidence is capped and ambiguous Entities stay alternatives",()=>{
 const input=features(transaction,{},profiles,[]);
 const found=validateCandidates([{entity_ref:"aviation",score:.95,evidence_ids:[]},{entity_ref:"other",score:.9,evidence_ids:[]}],input);
 assert(found.length===2); assert(found.every(c=>c.confidence==="worth_reviewing"));
});
Deno.test("high relevance requires actual owner evidence; explanation ignores model text",()=>{
 const input=features(transaction,{},profiles,[1,2,3].map(i=>({id:String(i),company_id:"aviation",merchant:"Adobe"})));
 const found=validateCandidates([{entity_ref:"aviation",score:.95,evidence_ids:["1","2","3"],explanation:"Guaranteed deduction"}],input);
 assert(found[0].confidence==="high"); assert(found[0].explanation.includes("3 previous Adobe charges")); assert(!found[0].explanation.includes("deduction"));
});
Deno.test("fingerprints are stable but change when corrected input changes",async()=>{
 assert(await fingerprint(transaction)===await fingerprint(transaction)); assert(await fingerprint(transaction)!==await fingerprint({...transaction,amount:89.99}));
});

Deno.test("prior personal decisions are contrary evidence, never confirmations",()=>{
 const input=features(transaction,{},profiles,[{id:"personal-1",company_id:"aviation",merchant:"Adobe",decision:"personal"}]);
 assert(input.prior_personal_examples===1); assert(input.entities[0].confirmations.length===0);
});
