// State
let chosenType = '';
let bankName = '';
let currentStep = 1;
const banks = ['Chase','Wells Fargo','Bank of America','Citibank','Capital One','American Express','US Bank','PNC'];
const typeIcons = { account:'🏦', card:'💳', loan:'💰' };
const typeLabels = { account:'Bank Account', card:'Card', loan:'Loan' };
const bankTitles = { account:'Which bank is your account with?', card:'Which bank issued your card?', loan:'Who is the lender?' };

// Utility: smooth scroll to element
function scrollToSection(id, delay) {
  setTimeout(() => {
    const el = document.getElementById(id);
    if (!el) return;
    const area = document.getElementById('scrollArea');
    const top = el.offsetTop - 90;
    area.scrollTo({ top, behavior:'smooth' });
  }, delay || 100);
}

// Utility: reveal field groups with stagger
function revealFields(containerId) {
  const groups = document.querySelectorAll('#' + containerId + ' .field-group');
  groups.forEach((g, i) => {
    setTimeout(() => g.classList.add('visible'), 80 * (i + 1));
  });
}

// Update progress bar
function setProgress(pct) {
  document.getElementById('progressFill').style.width = pct + '%';
}

// Show a section with fade-in animation
function showSection(id) {
  const sec = document.getElementById('sec-' + id);
  sec.classList.remove('hidden-section');
  sec.style.opacity = '0';
  sec.style.transform = 'translateY(20px)';
  sec.style.transition = 'opacity 350ms cubic-bezier(0.32,0.72,0,1), transform 350ms cubic-bezier(0.32,0.72,0,1)';
  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      sec.style.opacity = '1';
      sec.style.transform = 'translateY(0)';
    });
  });
}

// Collapse a section to its summary bar
function collapseSection(id) {
  const sec = document.getElementById('sec-' + id);
  const header = sec.querySelector('.section-header');
  const body = sec.querySelector('.section-body');
  const bar = document.getElementById('collapse-' + id);
  if (header) header.style.display = 'none';
  if (body) body.style.display = 'none';
  bar.classList.remove('hidden');
  sec.classList.add('dimmed');
}

// Expand a section from its summary bar
function expandSection(id) {
  const sec = document.getElementById('sec-' + id);
  const header = sec.querySelector('.section-header');
  const body = sec.querySelector('.section-body');
  const bar = document.getElementById('collapse-' + id);
  if (header) header.style.display = '';
  if (body) body.style.display = '';
  bar.classList.add('hidden');
  sec.classList.remove('dimmed');
  scrollToSection('sec-' + id, 50);
}

// ── STEP 1: Pick type ──
function pickType(t) {
  chosenType = t;
  // Update collapse bar
  document.getElementById('collapseTypeIcon').textContent = typeIcons[t];
  document.getElementById('collapseTypeLabel').textContent = typeLabels[t];
  // Highlight selected button
  document.querySelectorAll('.choice-btn').forEach(b => b.classList.remove('selected'));
  event.currentTarget.classList.add('selected');

  setTimeout(() => {
    collapseSection('type');
    setProgress(25);
    // Show bank section
    document.getElementById('bankTitle').textContent = bankTitles[t];
    showSection('bank');
    scrollToSection('sec-bank', 200);
    setTimeout(() => {
      document.getElementById('bankInput').focus();
      revealFields('bankBody');
    }, 450);
    currentStep = 2;
  }, 300);
}

// ── STEP 2: Bank name ──
function onBankInput(v) {
  bankName = v;
  const cont = document.getElementById('bankSuggestions');
  if (v.length < 1) { cont.innerHTML = ''; return; }
  const matches = banks.filter(b => b.toLowerCase().includes(v.toLowerCase()));
  cont.innerHTML = matches.slice(0, 3).map(b =>
    `<div class="sug-chip" onclick="selectBank('${b}')">${b}</div>`
  ).join('');
}

function selectBank(b) {
  bankName = b;
  document.getElementById('bankInput').value = b;
  document.getElementById('collapseBankLabel').textContent = b;
  proceedToDetails();
}

// Also allow pressing Enter on bank input
document.addEventListener('DOMContentLoaded', () => {
  document.getElementById('bankInput').addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && bankName.trim()) {
      document.getElementById('collapseBankLabel').textContent = bankName;
      proceedToDetails();
    }
  });
});

function proceedToDetails() {
  setTimeout(() => {
    collapseSection('bank');
    setProgress(50);
    buildDetails();
    showSection('details');
    scrollToSection('sec-details', 200);
    setTimeout(() => revealFields('detailsBody'), 300);
    // Show save bar
    document.getElementById('saveBar').classList.remove('hidden');
    currentStep = 3;
  }, 300);
}

// ── STEP 3: Build detail fields ──
function buildDetails() {
  const c = document.getElementById('detailsBody');
  const bn = bankName || 'your bank';
  const labels = { account:'account', card:'card', loan:'loan' };
  document.getElementById('detailsTitle').textContent = `Set up your ${bn} ${labels[chosenType]}`;
  document.getElementById('detailsSub').textContent = 'Fill in the basics — you can always add more later.';

  if (chosenType === 'account') c.innerHTML = accountFields();
  else if (chosenType === 'card') c.innerHTML = cardFields();
  else c.innerHTML = loanFields();
}

function accountFields() {
  return `
    <div class="field-group" data-reveal="1"><div class="field-label">ACCOUNT NAME</div><input class="field-input" placeholder="e.g. Primary Checking" oninput="checkSave()"></div>
    <div class="field-group" data-reveal="2"><div class="field-label">TYPE</div><div class="seg-row">
      <button class="seg-btn selected" onclick="pickSeg(this)">Checking</button>
      <button class="seg-btn" onclick="pickSeg(this)">Savings</button>
      <button class="seg-btn more-btn" onclick="pickSeg(this)">Other ▾</button>
    </div></div>
    <div class="field-group" data-reveal="3"><div class="field-label">BALANCE <span class="optional">optional</span></div><div class="money-wrap"><span class="currency">$</span><input class="field-input" placeholder="0.00" inputmode="decimal"></div><div class="field-hint">Just an estimate — update anytime</div></div>
    <div class="field-group" data-reveal="4"><div class="divider-row"><div class="divider-line"></div><div class="divider-text">OPTIONAL</div><div class="divider-line"></div></div></div>
    <div class="field-group" data-reveal="5"><div class="field-label">ACCOUNT NUMBER <span class="optional">optional</span></div><input class="field-input" placeholder="e.g. 1234567890" inputmode="numeric"></div>
  `;
}

function cardFields() {
  return `
    <div class="field-group" data-reveal="1"><div class="field-label">CARD NICKNAME</div><input class="field-input" placeholder="e.g. Sapphire Reserve" oninput="checkSave()" id="cardName"></div>
    <div class="field-group" data-reveal="2"><div class="field-label">CARD NUMBER <span class="optional">or just last 4</span></div><input class="field-input" id="cardNum" placeholder="0000 0000 0000 0000" inputmode="numeric" oninput="onCardNum(this.value)"></div>
    <div class="field-group" data-reveal="3"><div class="field-label">NETWORK <span id="autoLabel" style="display:none" class="optional">· auto-detected</span></div><div class="network-row" id="netRow">
      <div class="net-pill" onclick="pickNet(this)">Visa</div>
      <div class="net-pill" onclick="pickNet(this)">Mastercard</div>
      <div class="net-pill" onclick="pickNet(this)">Amex</div>
      <div class="net-pill" onclick="pickNet(this)">Discover</div>
    </div></div>
    <div class="field-group" data-reveal="4"><div class="field-label">TYPE</div><div class="seg-row">
      <button class="seg-btn selected" onclick="pickSeg(this)">Credit</button>
      <button class="seg-btn" onclick="pickSeg(this)">Debit</button>
    </div></div>
    <div class="field-group" data-reveal="5"><div class="divider-row"><div class="divider-line"></div><div class="divider-text">FINANCIALS</div><div class="divider-line"></div></div></div>
    <div class="field-group" data-reveal="6"><div class="hstack"><div><div class="field-label">BALANCE</div><div class="money-wrap"><span class="currency">$</span><input class="field-input" placeholder="0.00" inputmode="decimal"></div></div><div><div class="field-label">CREDIT LIMIT</div><div class="money-wrap"><span class="currency">$</span><input class="field-input" placeholder="0.00" inputmode="decimal"></div></div></div></div>
    <div class="field-group" data-reveal="7"><div class="hstack"><div><div class="field-label">APR %</div><input class="field-input" placeholder="0.00" inputmode="decimal"></div><div><div class="field-label">EXPIRES</div><input class="field-input" placeholder="MM/YY" inputmode="numeric"></div></div></div>
    <div class="field-group" data-reveal="8"><div class="field-label">NAME ON CARD <span class="optional">optional</span></div><input class="field-input" placeholder="e.g. Jane Doe"></div>
    <div class="field-group" data-reveal="9"><div class="divider-row"><div class="divider-line"></div><div class="divider-text">PAYMENT</div><div class="divider-line"></div></div></div>
    <div class="field-group" data-reveal="10"><div class="field-label">AUTOPAY</div><div class="toggle-wrap"><span class="toggle-label">Autopay enabled</span><div class="toggle on" onclick="this.classList.toggle('on')"></div></div></div>
  `;
}

function loanFields() {
  return `
    <div class="field-group" data-reveal="1"><div class="field-label">LOAN NAME</div><input class="field-input" placeholder="e.g. Equipment Loan" oninput="checkSave()"></div>
    <div class="field-group" data-reveal="2"><div class="field-label">ROLE</div><div class="seg-row">
      <button class="seg-btn selected" onclick="pickSeg(this)">I Owe</button>
      <button class="seg-btn" onclick="pickSeg(this)">I'm Lending</button>
    </div></div>
    <div class="field-group" data-reveal="3"><div class="field-label">PRINCIPAL AMOUNT</div><div class="money-wrap"><span class="currency">$</span><input class="field-input" placeholder="0.00" inputmode="decimal"></div></div>
    <div class="field-group" data-reveal="4"><div class="field-label">INTEREST RATE</div><input class="field-input" placeholder="0.00 %" inputmode="decimal"></div>
    <div class="field-group" data-reveal="5"><div class="divider-row"><div class="divider-line"></div><div class="divider-text">OPTIONAL</div><div class="divider-line"></div></div></div>
    <div class="field-group" data-reveal="6"><div class="hstack"><div><div class="field-label">TERM (YEARS)</div><input class="field-input" placeholder="e.g. 5" inputmode="numeric"></div><div><div class="field-label">TERM (MONTHS)</div><input class="field-input" placeholder="e.g. 0" inputmode="numeric"></div></div></div>
    <div class="field-group" data-reveal="7"><div class="field-label">NOTES <span class="optional">optional</span></div><input class="field-input" placeholder="Add notes..." style="height:80px;padding-top:14px;"></div>
  `;
}

// ── Interaction helpers ──
function pickSeg(el) {
  el.parentElement.querySelectorAll('.seg-btn').forEach(b => b.classList.remove('selected'));
  el.classList.add('selected');
}

function pickNet(el) {
  el.parentElement.querySelectorAll('.net-pill').forEach(b => { b.classList.remove('selected'); b.classList.remove('auto'); });
  el.classList.add('selected');
}

function onCardNum(v) {
  const digits = v.replace(/\D/g, '');
  const netRow = document.getElementById('netRow');
  if (!netRow) return;
  const pills = netRow.querySelectorAll('.net-pill');
  const autoLabel = document.getElementById('autoLabel');
  pills.forEach(p => { p.classList.remove('selected'); p.classList.remove('auto'); });
  if (digits.length >= 1) {
    let net = '';
    if (digits[0]==='4') net='Visa';
    else if (digits[0]==='5') net='Mastercard';
    else if (digits[0]==='3') net='Amex';
    else if (digits[0]==='6') net='Discover';
    if (net) {
      pills.forEach(p => { if (p.textContent===net) { p.classList.add('selected','auto'); } });
      autoLabel.style.display = 'inline';
    } else { autoLabel.style.display = 'none'; }
  } else { autoLabel.style.display = 'none'; }
  checkSave();
}

function checkSave() {
  const btn = document.getElementById('saveBtn');
  const inputs = document.querySelectorAll('#detailsBody .field-input');
  const hasName = inputs[0] && inputs[0].value.trim().length > 0;
  btn.className = hasName ? 'save-btn active' : 'save-btn';
}

// ── Save ──
function doSave() {
  const btn = document.getElementById('saveBtn');
  if (!btn.classList.contains('active')) return;

  // Hide save bar
  document.getElementById('saveBar').classList.add('hidden');
  setProgress(100);

  // Build success content
  const labels = { account:'account', card:'card', loan:'loan' };
  const bn = bankName || 'Your';
  const nameInput = document.querySelector('#detailsBody .field-input');
  const itemName = nameInput ? nameInput.value || labels[chosenType] : labels[chosenType];
  document.getElementById('successTitle').textContent = `${itemName} added!`;
  document.getElementById('successSub').textContent = `Your ${bn} ${labels[chosenType]} is ready to go.`;
  document.getElementById('addAnotherBtn').innerHTML = `➕ Add Another at ${bn}`;

  // Collapse details
  collapseSection('details');

  // Show success
  setTimeout(() => {
    showSection('success');
    scrollToSection('sec-success', 200);
    currentStep = 4;
  }, 300);
}

// ── Add Another ──
function addAnother() {
  // Hide success
  document.getElementById('sec-success').classList.add('hidden-section');
  // Expand type section, collapse bank keeps its value
  document.getElementById('sec-details').classList.add('hidden-section');
  document.getElementById('sec-details').querySelector('.section-header').style.display = '';
  document.getElementById('sec-details').querySelector('.section-body').style.display = '';
  document.getElementById('collapse-details')?.classList.add('hidden');
  document.getElementById('sec-details').classList.remove('dimmed');
  // Keep bank collapsed with pre-filled value, expand type
  expandSection('type');
  setProgress(25);
  currentStep = 1;
  scrollToSection('sec-type', 50);
}

// ── Reset ──
function resetAll() {
  chosenType = '';
  bankName = '';
  currentStep = 1;
  setProgress(0);

  // Reset type section
  const typeSec = document.getElementById('sec-type');
  typeSec.querySelector('.section-header').style.display = '';
  typeSec.querySelector('.section-body').style.display = '';
  document.getElementById('collapse-type').classList.add('hidden');
  typeSec.classList.remove('dimmed');
  document.querySelectorAll('.choice-btn').forEach(b => b.classList.remove('selected'));

  // Hide other sections
  ['bank','details','success'].forEach(id => {
    const sec = document.getElementById('sec-' + id);
    sec.classList.add('hidden-section');
    sec.classList.remove('dimmed');
    const h = sec.querySelector('.section-header');
    const b = sec.querySelector('.section-body');
    if (h) h.style.display = '';
    if (b) b.style.display = '';
    const bar = document.getElementById('collapse-' + id);
    if (bar) bar.classList.add('hidden');
  });

  // Reset bank input
  document.getElementById('bankInput').value = '';
  document.getElementById('bankSuggestions').innerHTML = '';

  // Hide save bar
  document.getElementById('saveBar').classList.add('hidden');

  // Scroll to top
  document.getElementById('scrollArea').scrollTo({ top:0, behavior:'smooth' });
}
