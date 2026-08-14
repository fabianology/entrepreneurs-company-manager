import React, { useState } from 'react';
import { View, Text, TouchableOpacity, Image, Clipboard } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useAppContext } from '../../context/AppContext';
import { FinancialCard, Loan, Institution, InstitutionAccount } from '../../types';
import { getFaviconUrl } from '../../services/logoService';

interface FinancialContentProps {
  onEditInstitution: (inst: Partial<Institution>) => void;
  onEditCard: (card: Partial<FinancialCard>) => void;
  onEditLoan: (loan: Partial<Loan>) => void;
  onAddInstitution: () => void;
  onAddCard: () => void;
  onAddLoan: () => void;
}

const fmt = (n: number) =>
  '$' + (n || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });

const brandColors: Record<string, [string, string]> = {
  chase: ['#1a3f8f', '#0a1f5f'],
  'bank of america': ['#8f1a1a', '#5f0a0a'],
  bofa: ['#8f1a1a', '#5f0a0a'],
  'wells fargo': ['#8f1a1a', '#5f0a0a'],
  citi: ['#1a6a8f', '#0a1f5f'],
  'capital one': ['#8f1a1a', '#1a1a8f'],
  'american express': ['#1a7a8a', '#0a1f8f'],
  amex: ['#1a7a8a', '#0a1f8f'],
  discover: ['#b85000', '#5f2a00'],
  mercury: ['#1a3a8f', '#0a1050'],
  stripe: ['#3a1a8f', '#1f0a5f'],
  ramp: ['#3a7a00', '#1a5000'],
};
const fallbackColors: [string, string][] = [
  ['#1a5f4a', '#0a2f24'],
  ['#5f1a5f', '#2f0a2f'],
  ['#1a4a8f', '#0a245f'],
  ['#7a1a3a', '#3f0a1f'],
  ['#1a7a3a', '#0a3f20'],
  ['#6a4a00', '#3a2a00'],
];

const getCardColors = (card: FinancialCard): [string, string] => {
  const name = (card.institutionName || card.network || '').trim().toLowerCase();
  const match = Object.keys(brandColors).find(k => name.includes(k));
  if (match) return brandColors[match];
  let hash = 0;
  for (let i = 0; i < name.length; i++) hash = name.charCodeAt(i) + ((hash << 5) - hash);
  return fallbackColors[Math.abs(hash) % fallbackColors.length];
};

const calcAmortization = (loan: Partial<Loan> | null) => {
  if (!loan) return null;
  const principal = loan.principalAmount || 0;
  const rate = loan.interestRate || 0;
  const isFixed = (loan as any).interestType === 'Fixed';
  const totalMonths = ((loan as any).termYears || 0) * 12 + ((loan as any).termMonths || 0);
  const scheduleFrequency: string = (loan as any).scheduleFrequency || 'Monthly';
  if (principal <= 0) return null;
  if (isFixed) {
    const totalCost = principal + rate;
    return {
      monthlyPayment: 0, totalInterest: rate, totalCost,
      totalPrincipal: principal,
      principalPct: totalCost > 0 ? (principal / totalCost) * 100 : 0,
      interestPct: totalCost > 0 ? (rate / totalCost) * 100 : 0,
      schedule: [], scheduleFrequency
    };
  }
  if (totalMonths <= 0) return null;
  let totalPeriods = totalMonths;
  let periodsPerYear = 12;
  if (scheduleFrequency === 'Weekly') { totalPeriods = Math.round((totalMonths / 12) * 52); periodsPerYear = 52; }
  else if (scheduleFrequency === 'Yearly') { totalPeriods = Math.ceil(totalMonths / 12); periodsPerYear = 1; }
  if (totalPeriods <= 0) return null;
  const r = (rate / 100) / periodsPerYear;
  let schedule: { month: number; payment: number; principal: number; interest: number; balance: number }[] = [];
  let totalInterest = 0;
  let payment = 0;
  if (r <= 0) {
    payment = principal / totalPeriods;
    let balance = principal;
    for (let i = 1; i <= totalPeriods; i++) {
      balance -= payment;
      schedule.push({ month: i, payment, principal: payment, interest: 0, balance: Math.max(0, balance) });
    }
  } else {
    payment = principal * (r * Math.pow(1 + r, totalPeriods)) / (Math.pow(1 + r, totalPeriods) - 1);
    let balance = principal;
    for (let i = 1; i <= Math.min(totalPeriods, 600); i++) {
      const interest = balance * r;
      const principalPayment = payment - interest;
      balance -= principalPayment;
      totalInterest += interest;
      schedule.push({ month: i, payment, principal: principalPayment, interest, balance: Math.max(0, balance) });
    }
  }
  const totalCost = principal + totalInterest;
  return {
    monthlyPayment: payment, totalInterest, totalCost, totalPrincipal: principal,
    principalPct: totalCost > 0 ? (principal / totalCost) * 100 : 0,
    interestPct: totalCost > 0 ? (totalInterest / totalCost) * 100 : 0,
    schedule, scheduleFrequency
  };
};

function CardVisual({ card, width = 280 }: { card: FinancialCard; width?: number }) {
  const [from, to] = getCardColors(card);
  const h = width * 0.6;
  return (
    <View style={{ width, height: h, borderRadius: 16, overflow: 'hidden', backgroundColor: from, shadowColor: '#000', shadowOpacity: 0.6, shadowRadius: 12, elevation: 8 }}>
      <View style={{ backgroundColor: to, position: 'absolute', bottom: 0, right: 0, width: '70%', height: '70%', borderTopLeftRadius: 80, opacity: 0.6 }} />
      <View style={{ flex: 1, padding: 18, justifyContent: 'space-between' }}>
        <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <View style={{ flex: 1, paddingRight: 12 }}>
            <Text style={{ color: '#fff', fontWeight: '700', fontSize: 13, letterSpacing: 0.5 }} numberOfLines={1}>{card.name}</Text>
            <Text style={{ color: 'rgba(255,255,255,0.6)', fontSize: 11, fontWeight: '500', letterSpacing: 0, marginTop: 2 }} numberOfLines={1}>{card.cardHolder || 'Name on Card'}</Text>
          </View>
          <Text style={{ color: 'rgba(255,255,255,0.8)', fontWeight: '600', fontSize: 14, fontStyle: 'italic' }}>{card.network}</Text>
        </View>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
          <View style={{ width: 36, height: 26, backgroundColor: 'rgba(255,215,80,0.2)', borderRadius: 4, borderWidth: 1, borderColor: 'rgba(255,215,80,0.3)', alignItems: 'center', justifyContent: 'center' }}>
            <View style={{ width: 22, height: 16, borderRadius: 2, borderWidth: 1, borderColor: 'rgba(255,215,80,0.4)' }} />
          </View>
          <Text style={{ color: 'rgba(255,255,255,0.85)', fontSize: 15, fontFamily: 'monospace', letterSpacing: 3 }}>•••• •••• •••• {card.last4}</Text>
        </View>
        <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-end' }}>
          <View>
            <Text style={{ color: 'rgba(255,255,255,0.5)', fontSize: 11, fontWeight: '500', letterSpacing: 0, marginBottom: 2 }}>Name on Card</Text>
            <Text style={{ color: '#fff', fontWeight: '600', fontSize: 11, letterSpacing: 0 }}>{card.cardHolder || '—'}</Text>
          </View>
          <View style={{ alignItems: 'flex-end' }}>
            <Text style={{ color: 'rgba(255,255,255,0.5)', fontSize: 11, fontWeight: '500', letterSpacing: 0, marginBottom: 2 }}>Expires</Text>
            <Text style={{ color: '#fff', fontWeight: '700', fontSize: 11, fontFamily: 'monospace' }}>{card.expiry || '—'}</Text>
          </View>
        </View>
      </View>
    </View>
  );
}

export default function FinancialContent({
  onEditInstitution,
  onEditCard,
  onEditLoan,
  onAddInstitution,
  onAddCard,
  onAddLoan,
}: FinancialContentProps) {
  const { state, selectedCompanyId } = useAppContext();
  
  const [expandedInsts, setExpandedInsts] = useState<Set<string>>(new Set());
  const [copiedId, setCopiedId] = useState<{ id: string; field: string } | null>(null);
  const [showPw, setShowPw] = useState<Set<string>>(new Set());
  const [poppedCard, setPoppedCard] = useState<string | null>(null);

  if (!selectedCompanyId) {
    return <View />;
  }

  const cards = (state?.financialCards || []).filter(c => c.companyId === selectedCompanyId);
  const loans = (state?.loans || []).filter(l => l.companyId === selectedCompanyId);
  const institutions = (state?.institutions || []).filter(i => i.companyId === selectedCompanyId);
  
  const standaloneLoans = loans.filter(l =>
    !institutions.some(inst => inst.name.toLowerCase() === l.lender?.toLowerCase())
  );

  const copyField = (id: string, field: string, text: string) => {
    if (!text) return;
    Clipboard.setString(text);
    setCopiedId({ id, field });
    setTimeout(() => setCopiedId(null), 2000);
  };

  const togglePw = (id: string) => {
    setShowPw(s => { const n = new Set(s); n.has(id) ? n.delete(id) : n.add(id); return n; });
  };

  const toggleInst = (id: string) => {
    setExpandedInsts(s => { const n = new Set(s); n.has(id) ? n.delete(id) : n.add(id); return n; });
  };

  return (
    <View style={{ flex: 1 }}>
      {/* ── Empty State ── */}
      {cards.length === 0 && institutions.length === 0 && loans.length === 0 && (
        <TouchableOpacity onPress={onAddInstitution}
          style={{ alignSelf: 'center', width: 300, height: 200, borderRadius: 28, borderWidth: 1, borderStyle: 'dashed', borderColor: 'rgba(255,255,255,0.2)', alignItems: 'center', justifyContent: 'center', backgroundColor: 'rgba(28,28,30,0.5)', marginTop: 20 }}>
          <Text style={{ fontSize: 40, marginBottom: 12 }}>🏦</Text>
          <Text style={{ color: 'rgba(255,255,255,0.5)', fontWeight: '500', fontSize: 13, letterSpacing: 0 }}>+ Add Your First Institution</Text>
        </TouchableOpacity>
      )}

      {/* ── Institutions ── */}
      {institutions.length > 0 && (
        <View style={{ marginBottom: 32 }}>
          <View style={{ borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.08)', paddingTop: 24, marginBottom: 16 }}>
            <Text style={{ color: 'rgba(255,255,255,0.3)', fontWeight: '600', fontSize: 16 }}>Financial Institutions</Text>
          </View>
          {institutions.map((inst, instIdx) => {
            const instCards = cards.filter(c => c.institutionName?.toLowerCase() === inst.name.toLowerCase());
            const instLoans = loans.filter(l => l.lender?.toLowerCase() === inst.name.toLowerCase());
            const instAccounts = (inst.accounts || []).filter(a => !['Credit Card', 'Debit Card', 'Debit (Linked)', 'FSA', 'HSA'].includes(a.type)).length;
            const expanded = expandedInsts.has(inst.id);

            const totalMonthly = instLoans.reduce((sum, l) => {
              const amort = calcAmortization(l);
              return sum + (Number(l.monthlyPayment) || (amort?.monthlyPayment ?? 0));
            }, 0) + (inst.accounts || []).reduce((sum, a) => sum + (Number((a as any).monthlyPayment) || 0), 0);

            // Card peek constants
            const PEEK = 36; // px each card peeks above inst card
            const CARD_H = 110; // approximate card height in stack

            return (
              <View key={inst.id} style={{
                marginBottom: 24,
                // make room above for peeking cards
                marginTop: instCards.length > 0 ? instCards.length * PEEK + 8 : 0,
                position: 'relative',
              }}>
                {/* Cards positioned absolutely with negative top — they appear BEHIND the institution card */}
                {instCards.map((card, ci) => {
                  const [from, to] = getCardColors(card);
                  const isPopped = poppedCard === card.id;
                  // Negative top: cards peek above the institution card's top edge
                  // ci=0 is front (closest to inst card), higher ci = further back / higher up
                  const topOffset = isPopped
                    ? -(CARD_H + instCards.length * PEEK) // fly fully above when popped
                    : -(PEEK + ci * PEEK); // each card peeks PEEK px above the one in front
                  const scale = isPopped ? 1.0 : 1 - ci * 0.03;
                  // All cards have zIndex < 20 so institution card renders over them
                  const zIndex = isPopped ? 25 : (instCards.length - ci);
                  return (
                    <TouchableOpacity key={card.id} onPress={() => setPoppedCard(isPopped ? null : card.id)}
                      style={{
                        position: 'absolute', left: 0, right: 0,
                        height: CARD_H, borderRadius: 20,
                        backgroundColor: from, top: topOffset,
                        transform: [{ scale }], zIndex,
                        borderWidth: 1,
                        borderColor: isPopped ? 'rgba(255,255,255,0.3)' : 'rgba(255,255,255,0.08)',
                        shadowColor: '#000', shadowOpacity: 0.4, shadowRadius: 8,
                      }} activeOpacity={0.85}>
                      <View style={{ position: 'absolute', bottom: 0, right: 0, width: '60%', height: '70%', backgroundColor: to, borderTopLeftRadius: 70, opacity: 0.5 }} />
                      <View style={{ padding: 14, flex: 1, justifyContent: 'space-between' }}>
                        <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
                          <Text style={{ color: '#fff', fontWeight: '700', fontSize: 12 }}>{card.name}</Text>
                          <Text style={{ color: 'rgba(255,255,255,0.7)', fontWeight: '600', fontSize: 12, fontStyle: 'italic' }}>{card.network}</Text>
                        </View>
                        {isPopped && (
                          <>
                            <Text style={{ color: 'rgba(255,255,255,0.85)', fontFamily: 'monospace', fontSize: 14, letterSpacing: 3 }}>•••• •••• •••• {card.last4}</Text>
                            <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
                              <Text style={{ color: 'rgba(255,255,255,0.6)', fontSize: 11, fontWeight: '500', letterSpacing: 0 }}>{card.cardHolder}</Text>
                              <Text style={{ color: 'rgba(255,255,255,0.6)', fontSize: 11, fontWeight: '700' }}>{card.expiry}</Text>
                            </View>
                          </>
                        )}
                      </View>
                    </TouchableOpacity>
                  );
                })}

                {/* Institution Card — zIndex 20 keeps it ON TOP of all payment cards */}
                <TouchableOpacity onPress={() => onEditInstitution(inst)} activeOpacity={0.85}
                  style={{ backgroundColor: '#1C1C1E', borderRadius: 24, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', overflow: 'hidden', zIndex: 20 }}>
                  <View style={{ padding: 22 }}>
                    {/* Header */}
                    <View style={{ flexDirection: 'row', alignItems: 'flex-start', marginBottom: 20 }}>
                      <View style={{ width: 52, height: 52, backgroundColor: 'rgba(255,255,255,0.05)', borderRadius: 16, alignItems: 'center', justifyContent: 'center', marginRight: 14, overflow: 'hidden' }}>
                        {getFaviconUrl(inst.loginUrl) ? (
                          <Image
                            source={{ uri: getFaviconUrl(inst.loginUrl)! }}
                            style={{ width: 34, height: 34 }}
                            resizeMode="contain"
                          />
                        ) : (
                          <Ionicons name="business" size={22} color="rgba(255,255,255,0.4)" />
                        )}
                      </View>
                      <View style={{ flex: 1 }}>
                        <Text style={{ color: '#fff', fontWeight: '600', fontSize: 17, letterSpacing: 0 }}>{inst.name}</Text>
                        <Text style={{ color: '#fff', fontWeight: '900', fontSize: 17, marginTop: 2 }}>${totalMonthly.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</Text>
                        <Text style={{ color: 'rgba(255,255,255,0.35)', fontSize: 11, fontWeight: '500', letterSpacing: 0 }}>Mo. Payment</Text>
                      </View>
                    </View>
                    {/* Accounts / Cards / Loans count */}
                    <View style={{ flexDirection: 'row', gap: 8, marginBottom: 18 }}>
                      {[{ label: 'Accounts', count: instAccounts }, { label: 'Cards', count: instCards.length }, { label: 'Loans', count: instLoans.length }].map(({ label, count }) => (
                        <View key={label} style={{ flexDirection: 'row', gap: 4, alignItems: 'center' }}>
                          <Text style={{ color: '#EBC351', fontWeight: '700', fontSize: 11 }}>{count}</Text>
                          <Text style={{ color: 'rgba(255,255,255,0.4)', fontWeight: '500', fontSize: 12, letterSpacing: 0 }}>{label}</Text>
                          {label !== 'Loans' && <Text style={{ color: 'rgba(255,255,255,0.15)', marginHorizontal: 4 }}>|</Text>}
                        </View>
                      ))}
                    </View>
                    {/* Credentials */}
                    <View style={{ flexDirection: 'row', gap: 12 }}>
                      <TouchableOpacity onPress={() => copyField(inst.id, 'username', inst.username || inst.email || '')} style={{ flex: 1 }}>
                        <Text style={{ color: copiedId?.id === inst.id && copiedId?.field === 'username' ? '#f97316' : 'rgba(255,255,255,0.35)', fontSize: 11, fontWeight: '500', letterSpacing: 0, marginBottom: 4 }}>
                          {copiedId?.id === inst.id && copiedId?.field === 'username' ? 'Copied ✓' : 'Login ID'}
                        </Text>
                        <View style={{ backgroundColor: 'rgba(0,0,0,0.2)', borderRadius: 10, paddingHorizontal: 12, paddingVertical: 8, borderWidth: 1, borderColor: 'rgba(255,255,255,0.03)' }}>
                          <Text style={{ color: '#fff', fontSize: 12, fontWeight: '500' }} numberOfLines={1}>{inst.username || inst.email || '—'}</Text>
                        </View>
                      </TouchableOpacity>
                      <View style={{ flex: 1 }}>
                        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 4 }}>
                          <TouchableOpacity onPress={() => copyField(inst.id, 'password', inst.password || '')}>
                            <Text style={{ color: copiedId?.id === inst.id && copiedId?.field === 'password' ? '#f97316' : 'rgba(255,255,255,0.35)', fontSize: 11, fontWeight: '500', letterSpacing: 0 }}>
                              {copiedId?.id === inst.id && copiedId?.field === 'password' ? 'Copied ✓' : 'Password'}
                            </Text>
                          </TouchableOpacity>
                          <TouchableOpacity onPress={() => togglePw(inst.id)}>
                            <Ionicons name={showPw.has(inst.id) ? 'eye-off-outline' : 'eye-outline'} size={13} color="rgba(255,255,255,0.25)" />
                          </TouchableOpacity>
                        </View>
                        <TouchableOpacity onPress={() => copyField(inst.id, 'password', inst.password || '')}>
                          <View style={{ backgroundColor: 'rgba(0,0,0,0.2)', borderRadius: 10, paddingHorizontal: 12, paddingVertical: 8, borderWidth: 1, borderColor: 'rgba(255,255,255,0.03)' }}>
                            <Text style={{ color: '#fff', fontSize: 12, fontWeight: '500', letterSpacing: showPw.has(inst.id) ? 0 : 3 }} numberOfLines={1}>
                              {showPw.has(inst.id) ? (inst.password || '—') : '••••••••'}
                            </Text>
                          </View>
                        </TouchableOpacity>
                      </View>
                    </View>
                  </View>

                  {/* Linked Accounts Accordion */}
                  <TouchableOpacity onPress={() => { toggleInst(inst.id); }}
                    style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 20, paddingVertical: 14, borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.05)' }}>
                    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
                      <Text style={{ color: 'rgba(255,255,255,0.4)', fontWeight: '500', fontSize: 13, letterSpacing: 0 }}>{expanded ? 'Less Details' : 'More Details'}</Text>
                      <Text style={{ color: 'rgba(255,255,255,0.2)', fontWeight: '900', fontSize: 12 }}>({instAccounts + instLoans.length})</Text>
                    </View>
                    <Ionicons name={expanded ? 'chevron-up' : 'chevron-down'} size={16} color="rgba(255,255,255,0.3)" />
                  </TouchableOpacity>

                  {expanded && (
                    <View style={{ paddingHorizontal: 20, paddingBottom: 18, gap: 10 }}>
                      {(inst.accounts || []).map((acc, ai) => (
                        <View key={`${acc.id || ai}`} style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
                          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
                            <View style={{ width: 6, height: 6, borderRadius: 3, backgroundColor: acc.type === 'Credit Card' ? '#f97316' : acc.type === 'Checking' ? '#EBC351' : '#1FE400' }} />
                            <Text style={{ color: 'rgba(255,255,255,0.85)', fontSize: 13, fontWeight: '500', letterSpacing: 0 }}>{acc.name}</Text>
                            <Text style={{ color: 'rgba(255,255,255,0.35)', fontSize: 11, fontWeight: '500', letterSpacing: 0 }}>{acc.type}</Text>
                            {acc.last4 && <Text style={{ color: '#EBC351', fontSize: 11, fontWeight: '700' }}>••{acc.last4}</Text>}
                          </View>
                          <Text style={{ color: '#fff', fontSize: 12, fontWeight: '700' }}>
                            ${((acc as any).monthlyPayment || acc.balance || 0).toLocaleString()}
                            <Text style={{ color: 'rgba(255,255,255,0.3)', fontSize: 11 }}>{(acc as any).monthlyPayment ? '/mo' : ''}</Text>
                          </Text>
                        </View>
                      ))}
                      {instLoans.map(loan => {
                        const amort = calcAmortization(loan);
                        const pmt = Number(loan.monthlyPayment) || amort?.monthlyPayment || 0;
                        return (
                          <View key={loan.id} style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
                            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
                              <View style={{ width: 6, height: 6, borderRadius: 3, backgroundColor: '#EBC351' }} />
                              <Text style={{ color: 'rgba(255,255,255,0.85)', fontSize: 13, fontWeight: '500', letterSpacing: 0 }}>{loan.name}</Text>
                              <Text style={{ color: 'rgba(255,255,255,0.35)', fontSize: 11, fontWeight: '500', letterSpacing: 0 }}>Loan{loan.interestRate ? ` • ${loan.interestRate}%` : ''}</Text>
                            </View>
                            <Text style={{ color: '#fff', fontSize: 12, fontWeight: '700' }}>${pmt.toLocaleString(undefined, { maximumFractionDigits: 0 })}<Text style={{ color: 'rgba(255,255,255,0.3)', fontSize: 11 }}>/mo</Text></Text>
                          </View>
                        );
                      })}
                      {instAccounts + instLoans.length === 0 && <Text style={{ color: 'rgba(255,255,255,0.3)', fontWeight: '500', fontSize: 12, letterSpacing: 0 }}>No linked accounts</Text>}
                      <TouchableOpacity onPress={() => onEditInstitution(inst)} style={{ paddingTop: 4 }}>
                        <Text style={{ color: 'rgba(255,255,255,0.25)', fontWeight: '500', fontSize: 12, letterSpacing: 0 }}>+ Add Account</Text>
                      </TouchableOpacity>
                    </View>
                  )}
                </TouchableOpacity>
              </View>
            );
          })}
        </View>
      )}

      {/* ── Standalone Loans ── */}
      {standaloneLoans.length > 0 && (
        <View style={{ marginBottom: 32 }}>
          <View style={{ borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.08)', paddingTop: 24, marginBottom: 16 }}>
            <Text style={{ color: 'rgba(255,255,255,0.3)', fontWeight: '600', fontSize: 16 }}>Loans & Debt</Text>
          </View>
          {standaloneLoans.map(loan => {
            const amort = calcAmortization(loan);
            return (
              <TouchableOpacity key={loan.id} onPress={() => onEditLoan(loan)} activeOpacity={0.85}
                style={{ backgroundColor: '#1C1C1E', borderRadius: 24, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', padding: 22, marginBottom: 16 }}>
                <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginBottom: 20 }}>
                  <View style={{ flex: 1 }}>
                    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 4 }}>
                      <Text style={{ color: '#fff', fontWeight: '600', fontSize: 17 }}>{loan.name}</Text>
                      {loan.role && <View style={{ borderRadius: 20, borderWidth: 1, borderColor: 'rgba(255,255,255,0.15)', paddingHorizontal: 8, paddingVertical: 2 }}><Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 11, fontWeight: '500', letterSpacing: 0 }}>{loan.role}</Text></View>}
                    </View>
                    <Text style={{ color: 'rgba(255,255,255,0.4)', fontWeight: '500', fontSize: 11, letterSpacing: 0 }}>{loan.lender || 'Unknown'} | <Text style={{ color: loan.status === 'Paid Off' ? '#10b981' : '#EBC351' }}>{loan.status}</Text></Text>
                  </View>
                  <View style={{ alignItems: 'flex-end' }}>
                    <Text style={{ color: '#fff', fontWeight: '700', fontSize: 20 }}>${(loan.principalAmount || 0).toLocaleString()}</Text>
                    <Text style={{ color: 'rgba(255,255,255,0.35)', fontSize: 11, fontWeight: '500', letterSpacing: 0 }}>Loan Amount</Text>
                  </View>
                </View>
                <View style={{ flexDirection: 'row', gap: 16, marginBottom: 16 }}>
                  {[['Loan Date', loan.startDate || '—'], ['Interest', `$${(amort?.totalInterest || 0).toLocaleString(undefined, { maximumFractionDigits: 0 })}`], ['Total', `$${((loan.principalAmount || 0) + (amort?.totalInterest || 0)).toLocaleString(undefined, { maximumFractionDigits: 0 })}`]].map(([label, val]) => (
                    <View key={label} style={{ flex: 1 }}>
                      <Text style={{ color: 'rgba(255,255,255,0.35)', fontSize: 11, fontWeight: '500', letterSpacing: 0, marginBottom: 2 }}>{label}</Text>
                      <Text style={{ color: '#fff', fontWeight: '600', fontSize: 14 }}>{val}</Text>
                    </View>
                  ))}
                </View>
                {amort && (
                  <View style={{ gap: 6 }}>
                    <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
                      <Text style={{ color: '#EBC351', fontSize: 11, fontWeight: '500', letterSpacing: 0 }}>Principal ${amort.totalPrincipal.toLocaleString(undefined, { maximumFractionDigits: 0 })}</Text>
                      <Text style={{ color: '#f97316', fontSize: 11, fontWeight: '500', letterSpacing: 0 }}>Interest ${amort.totalInterest.toLocaleString(undefined, { maximumFractionDigits: 0 })}</Text>
                    </View>
                    <View style={{ height: 5, backgroundColor: 'rgba(255,255,255,0.06)', borderRadius: 3, flexDirection: 'row', overflow: 'hidden' }}>
                      <View style={{ flex: amort.principalPct, backgroundColor: '#EBC351' }} />
                      <View style={{ flex: amort.interestPct, backgroundColor: '#f97316' }} />
                    </View>
                  </View>
                )}
              </TouchableOpacity>
            );
          })}
        </View>
      )}

      {/* ── Payment Methods (stacked card stack) ── */}
      {cards.length > 0 && (
        <View style={{ marginBottom: 32 }}>
          <View style={{ borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.08)', paddingTop: 24, marginBottom: 16 }}>
            <Text style={{ color: 'rgba(255,255,255,0.3)', fontWeight: '600', fontSize: 16 }}>Payment Methods</Text>
          </View>
          <View style={{ height: cards.length * 44 + 168, position: 'relative' }}>
            {cards.map((card, ci) => {
              const topOffset = ci * 44;
              const scale = 1 - (cards.length - 1 - ci) * 0.02;
              return (
                <TouchableOpacity key={card.id} onPress={() => onEditCard(card)}
                  style={{ position: 'absolute', left: 0, right: 0, top: topOffset, zIndex: ci, transform: [{ scale }] }} activeOpacity={0.85}>
                  <CardVisual card={card} />
                </TouchableOpacity>
              );
            })}
          </View>
        </View>
      )}
    </View>
  );
}
