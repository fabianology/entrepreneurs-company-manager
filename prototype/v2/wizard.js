let currentScreen=1,chosenType='',bankName='';
const banks=['Chase','Wells Fargo','Bank of America','Citibank','Capital One','American Express','US Bank','PNC'];
const screens={1:'s1',2:'s2',3:'s3',4:'s4'};

function goTo(n){
  const cur=document.getElementById(screens[currentScreen]);
  const nxt=document.getElementById(screens[n]);
  if(n>currentScreen){cur.className='screen hidden-left';nxt.className='screen active';}
  else{cur.className='screen hidden-right';nxt.className='screen active';}
  currentScreen=n;
  if(n===3)buildDetails();
  if(n===4)buildSuccess();
}

function pickType(t){
  chosenType=t;
  const titles={account:'Which bank is your account with?',card:'Which bank issued your card?',loan:'Who is the lender?'};
  document.getElementById('bankTitle').textContent=titles[t];
  goTo(2);
  setTimeout(()=>document.getElementById('bankInput').focus(),500);
}

function onBankInput(v){
  bankName=v;
  document.getElementById('bankNext').className=v.trim()?'next-btn active':'next-btn';
  const cont=document.getElementById('bankSuggestions');
  if(v.length<1){cont.innerHTML='';return;}
  const matches=banks.filter(b=>b.toLowerCase().includes(v.toLowerCase()));
  cont.innerHTML=matches.slice(0,3).map(b=>`<div class="sug-chip" onclick="selectBank('${b}')">${b}</div>`).join('');
}

function selectBank(b){
  bankName=b;
  document.getElementById('bankInput').value=b;
  document.getElementById('bankNext').className='next-btn active';
  goTo(3);
}

function buildDetails(){
  const c=document.getElementById('detailsContent');
  const bn=bankName||'your bank';
  const labels={account:'account',card:'card',loan:'loan'};
  document.getElementById('detailsTitle').textContent=`Set up your ${bn} ${labels[chosenType]}`;
  document.getElementById('detailsSub').textContent='Fill in the basics — you can always add more later.';
  if(chosenType==='account')c.innerHTML=accountHTML();
  else if(chosenType==='card')c.innerHTML=cardHTML();
  else c.innerHTML=loanHTML();
  setTimeout(()=>revealFields(),100);
}

function accountHTML(){
  return `
<div class="field-group" data-reveal="1"><div class="field-label">ACCOUNT NAME</div><input class="field-input" placeholder="e.g. Primary Checking" oninput="checkSave()"></div>
<div class="field-group" data-reveal="2"><div class="field-label">TYPE</div><div class="seg-row">
  <button class="seg-btn selected" onclick="pickSeg(this)">Checking</button>
  <button class="seg-btn" onclick="pickSeg(this)">Savings</button>
  <button class="seg-btn more-btn" onclick="pickSeg(this)">Other ▾</button>
</div></div>
<div class="field-group" data-reveal="3"><div class="field-label">ACCOUNT NUMBER</div><input class="field-input" placeholder="e.g. 1234567890" inputmode="numeric"></div>
<div class="field-group" data-reveal="4"><div class="field-label">BALANCE <span class="opt">optional</span></div><div class="money-wrap"><span class="sym">$</span><input class="field-input" placeholder="0.00" inputmode="decimal"></div><div class="field-hint">Just an estimate — update anytime</div></div>
<div class="divider-row" data-reveal="5"><div class="divider-line"></div><div class="divider-text">SECURE LOGIN</div><div class="divider-line"></div></div>
<div class="vault-card" data-reveal="6">
  <div class="vault-header"><div class="vault-icon">🔒</div><div><div class="vault-title">Bank Login Details</div><div class="vault-sub">Stored securely on your device</div></div></div>
  <div class="vault-field"><div class="field-label">LOGIN ID <span class="opt">email or username</span></div><input class="field-input" placeholder="you@email.com" style="background:rgba(255,255,255,.03);border-color:rgba(255,255,255,.06)"></div>
  <div class="vault-field"><div class="field-label">PASSWORD</div><input class="field-input" type="password" placeholder="••••••••" style="background:rgba(255,255,255,.03);border-color:rgba(255,255,255,.06)"></div>
  <div class="vault-field"><div class="field-label">TWO-FACTOR AUTH <span class="opt">optional</span></div><div class="tfa-row">
    <div class="tfa-pill" onclick="pickTfa(this)">📱 SMS</div>
    <div class="tfa-pill" onclick="pickTfa(this)">🔐 App</div>
    <div class="tfa-pill" onclick="pickTfa(this)">📧 Email</div>
    <div class="tfa-pill" onclick="pickTfa(this)">None</div>
  </div></div>
  <div class="vault-badge"><span>🔑 Works with iCloud Keychain · End-to-end encrypted</span></div>
</div>`;
}

function cardHTML(){
  return `
<div class="field-group" data-reveal="1"><div class="field-label">CARD NICKNAME</div><input class="field-input" placeholder="e.g. Sapphire Reserve" oninput="checkSave()" id="cardName"></div>
<div class="field-group" data-reveal="2"><div class="field-label">CARD NUMBER</div><input class="field-input" id="cardNum" placeholder="0000 0000 0000 0000" inputmode="numeric" oninput="onCardNum(this)"></div>
<div class="field-group" data-reveal="3" id="networkGroup" style="max-height:0;overflow:hidden;margin:0;opacity:0;transition:all .5s cubic-bezier(.32,.72,0,1)"><div class="field-label">NETWORK</div><div class="net-row" id="netRow">
  <div class="net-pill" onclick="pickNet(this)"><span class="net-logo visa">V</span> Visa</div>
  <div class="net-pill" onclick="pickNet(this)"><span class="net-logo mc">MC</span> Mastercard</div>
  <div class="net-pill" onclick="pickNet(this)"><span class="net-logo amex">AX</span> Amex</div>
  <div class="net-pill" onclick="pickNet(this)"><span class="net-logo disc">D</span> Discover</div>
</div></div>
<div class="field-group" data-reveal="4"><div class="field-label">NAME ON CARD <span class="opt">optional</span></div><input class="field-input" placeholder="e.g. Jane Doe"></div>
<div class="field-group" data-reveal="5"><div class="hstack"><div><div class="field-label">EXPIRES</div><input class="field-input" placeholder="MM/YY" inputmode="numeric"></div><div><div class="field-label">TYPE</div><div class="seg-row"><button class="seg-btn selected" onclick="pickSeg(this)">Credit</button><button class="seg-btn" onclick="pickSeg(this)">Debit</button></div></div></div></div>
<div class="divider-row" data-reveal="6"><div class="divider-line"></div><div class="divider-text">FINANCIALS</div><div class="divider-line"></div></div>
<div class="field-group" data-reveal="7"><div class="hstack"><div><div class="field-label">BALANCE</div><div class="money-wrap"><span class="sym">$</span><input class="field-input" placeholder="0.00" inputmode="decimal"></div></div><div><div class="field-label">CREDIT LIMIT</div><div class="money-wrap"><span class="sym">$</span><input class="field-input" placeholder="0.00" inputmode="decimal"></div></div></div></div>
<div class="field-group" data-reveal="8"><div class="hstack"><div><div class="field-label">APR %</div><input class="field-input" placeholder="0.00" inputmode="decimal"></div><div><div class="field-label">MO. PAYMENT</div><div class="money-wrap"><span class="sym">$</span><input class="field-input" placeholder="0.00" inputmode="decimal"></div></div></div></div>
<div class="field-group" data-reveal="9"><div class="field-label">AUTOPAY</div><div class="toggle-wrap"><span class="toggle-label">Autopay enabled</span><div class="toggle on" onclick="this.classList.toggle('on')"></div></div></div>
<div class="divider-row" data-reveal="10"><div class="divider-line"></div><div class="divider-text">SECURE LOGIN</div><div class="divider-line"></div></div>
<div class="vault-card" data-reveal="11">
  <div class="vault-header"><div class="vault-icon">🔒</div><div><div class="vault-title">Bank Login Details</div><div class="vault-sub">Stored securely on your device</div></div></div>
  <div class="vault-field"><div class="field-label">LOGIN ID</div><input class="field-input" placeholder="you@email.com" style="background:rgba(255,255,255,.03);border-color:rgba(255,255,255,.06)"></div>
  <div class="vault-field"><div class="field-label">PASSWORD</div><input class="field-input" type="password" placeholder="••••••••" style="background:rgba(255,255,255,.03);border-color:rgba(255,255,255,.06)"></div>
  <div class="vault-badge"><span>🔑 Works with iCloud Keychain · End-to-end encrypted</span></div>
</div>`;
}

function loanHTML(){
  return `
<div class="field-group" data-reveal="1"><div class="field-label">LOAN NAME</div><input class="field-input" placeholder="e.g. Equipment Loan" oninput="checkSave()"></div>
<div class="field-group" data-reveal="2"><div class="field-label">ROLE</div><div class="seg-row">
  <button class="seg-btn selected" onclick="pickSeg(this)">I Owe</button>
  <button class="seg-btn" onclick="pickSeg(this)">I'm Lending</button>
</div></div>
<div class="field-group" data-reveal="3"><div class="field-label">PRINCIPAL AMOUNT</div><div class="money-wrap"><span class="sym">$</span><input class="field-input" placeholder="0.00" inputmode="decimal"></div></div>
<div class="field-group" data-reveal="4"><div class="field-label">INTEREST RATE</div><input class="field-input" placeholder="0.00 %" inputmode="decimal"></div>
<div class="field-group" data-reveal="5"><div class="hstack"><div><div class="field-label">TERM (YEARS)</div><input class="field-input" placeholder="5" inputmode="numeric"></div><div><div class="field-label">TERM (MONTHS)</div><input class="field-input" placeholder="0" inputmode="numeric"></div></div></div>
<div class="field-group" data-reveal="6"><div class="field-label">NOTES <span class="opt">optional</span></div><textarea class="field-input" placeholder="Add notes..." style="height:80px;padding-top:14px;resize:none"></textarea></div>`;
}

function revealFields(){
  document.querySelectorAll('#detailsContent [data-reveal]').forEach((g,i)=>{
    setTimeout(()=>g.classList.add('visible'),80*(i+1));
  });
}

function pickSeg(el){el.parentElement.querySelectorAll('.seg-btn').forEach(b=>b.classList.remove('selected'));el.classList.add('selected');}

function pickNet(el){
  el.parentElement.querySelectorAll('.net-pill').forEach(b=>b.classList.remove('selected'));
  el.classList.add('selected');
}

function pickTfa(el){
  el.parentElement.querySelectorAll('.tfa-pill').forEach(b=>b.classList.remove('selected'));
  el.classList.add('selected');
}

function onCardNum(el){
  let v=el.value.replace(/\D/g,'');
  // Auto-format with spaces
  let formatted='';
  for(let i=0;i<v.length&&i<16;i++){
    if(i>0&&i%4===0)formatted+=' ';
    formatted+=v[i];
  }
  el.value=formatted;

  const ng=document.getElementById('networkGroup');
  const pills=document.getElementById('netRow').querySelectorAll('.net-pill');
  pills.forEach(p=>p.classList.remove('selected'));

  if(v.length>=1){
    let net='';
    if(v[0]==='4')net='Visa';
    else if(v[0]==='5')net='Mastercard';
    else if(v[0]==='3')net='Amex';
    else if(v[0]==='6')net='Discover';
    if(net){
      pills.forEach(p=>{if(p.textContent.trim().startsWith(net.substring(0,2))||p.textContent.includes(net))p.classList.add('selected');});
      // Smoothly reveal network group
      ng.style.maxHeight='100px';ng.style.opacity='1';ng.style.marginBottom='18px';
    }
  }else{
    ng.style.maxHeight='0';ng.style.opacity='0';ng.style.marginBottom='0';
  }
  checkSave();
}

function checkSave(){
  const btn=document.getElementById('saveBtn');
  const inputs=document.querySelectorAll('#detailsContent .field-input');
  const hasName=inputs[0]&&inputs[0].value.trim().length>0;
  btn.className=hasName?'nav-btn save active':'nav-btn save';
}

function buildSuccess(){
  const labels={account:'account',card:'card',loan:'loan'};
  const bn=bankName||'Your';
  const nameInput=document.querySelector('#detailsContent .field-input');
  const itemName=nameInput?nameInput.value||labels[chosenType]:labels[chosenType];
  document.getElementById('successTitle').textContent=`${itemName} added!`;
  document.getElementById('successSub').textContent=`Your ${bn} ${labels[chosenType]} is ready to go.`;
  document.getElementById('addAnotherBtn').innerHTML=`➕ Add Another at ${bn}`;
}

function addAnother(){goTo(1);}

function resetAll(){
  chosenType='';bankName='';
  document.getElementById('bankInput').value='';
  document.getElementById('bankSuggestions').innerHTML='';
  document.getElementById('bankNext').className='next-btn';
  Object.values(screens).forEach(id=>{
    document.getElementById(id).className=id==='s1'?'screen active':'screen hidden-right';
  });
  currentScreen=1;
}
