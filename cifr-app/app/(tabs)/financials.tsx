import React, { useState, useCallback } from 'react';
import {
  View, Text, ScrollView, TouchableOpacity, Modal, TextInput,
  KeyboardAvoidingView, Platform, Pressable, Alert, Clipboard
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { KeyboardAwareScrollView } from 'react-native-keyboard-aware-scroll-view';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { useAppContext } from '../../context/AppContext';
import { FinancialCard, Loan, Institution, InstitutionAccount } from '../../types';
import CompanyHeader from '../../components/CompanyHeader';

// ─────────────────────────── helpers ───────────────────────────
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

// ─────────────────────── Field Row ───────────────────────
function Field({ label, value, placeholder, onChangeText, multiline = false, keyboardType = 'default', mono = false }: {
  label: string; value: string; placeholder?: string;
  onChangeText: (t: string) => void; multiline?: boolean;
  keyboardType?: any; mono?: boolean;
}) {
  return (
    <View style={{ marginBottom: 12 }}>
      <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 10, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 2, marginBottom: 4, marginLeft: 2 }}>{label}</Text>
      <TextInput
        style={{ backgroundColor: 'rgba(0,0,0,0.3)', borderWidth: 1, borderColor: 'rgba(255,255,255,0.06)', borderRadius: 10, paddingHorizontal: 12, paddingVertical: 10, color: '#fff', fontSize: 13, fontWeight: '500', fontFamily: mono ? 'monospace' : undefined }}
        value={value}
        placeholder={placeholder}
        placeholderTextColor="rgba(255,255,255,0.2)"
        onChangeText={onChangeText}
        multiline={multiline}
        numberOfLines={multiline ? 3 : 1}
        keyboardType={keyboardType}
      />
    </View>
  );
}

function SelectField({ label, value, options, onChange }: {
  label: string; value: string;
  options: { label: string; value: string }[];
  onChange: (v: string) => void;
}) {
  const [open, setOpen] = useState(false);
  const cur = options.find(o => o.value === value);
  return (
    <View style={{ marginBottom: 12 }}>
      <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 10, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 2, marginBottom: 4, marginLeft: 2 }}>{label}</Text>
      <TouchableOpacity onPress={() => setOpen(true)} style={{ backgroundColor: 'rgba(0,0,0,0.3)', borderWidth: 1, borderColor: 'rgba(255,255,255,0.06)', borderRadius: 10, paddingHorizontal: 12, paddingVertical: 10, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
        <Text style={{ color: '#fff', fontSize: 13, fontWeight: '500' }}>{cur?.label || 'Select...'}</Text>
        <Ionicons name="chevron-down" size={14} color="rgba(255,255,255,0.3)" />
      </TouchableOpacity>
      <Modal visible={open} transparent animationType="fade">
        <Pressable style={{ flex: 1, backgroundColor: 'rgba(0,0,0,0.6)' }} onPress={() => setOpen(false)}>
          <View style={{ position: 'absolute', bottom: 0, left: 0, right: 0, backgroundColor: '#1C1C1E', borderTopLeftRadius: 24, borderTopRightRadius: 24, padding: 16, paddingBottom: 32 }}>
            <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 11, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 2, textAlign: 'center', marginBottom: 12 }}>{label}</Text>
            {options.map(o => (
              <TouchableOpacity key={o.value} onPress={() => { onChange(o.value); setOpen(false); }}
                style={{ paddingVertical: 14, paddingHorizontal: 8, borderRadius: 12, backgroundColor: value === o.value ? '#EBC351' : 'transparent', marginBottom: 2 }}>
                <Text style={{ color: value === o.value ? '#000' : '#fff', fontWeight: '600', fontSize: 15, textAlign: 'center' }}>{o.label}</Text>
              </TouchableOpacity>
            ))}
          </View>
        </Pressable>
      </Modal>
    </View>
  );
}

// ─────────────────────── Mini Credit Card Visual ───────────────────────
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
            <Text style={{ color: 'rgba(255,255,255,0.6)', fontSize: 8, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 2, marginTop: 2 }} numberOfLines={1}>{card.cardHolder || 'NAME ON CARD'}</Text>
          </View>
          <Text style={{ color: 'rgba(255,255,255,0.8)', fontWeight: '900', fontSize: 14, fontStyle: 'italic' }}>{card.network}</Text>
        </View>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
          <View style={{ width: 36, height: 26, backgroundColor: 'rgba(255,215,80,0.2)', borderRadius: 4, borderWidth: 1, borderColor: 'rgba(255,215,80,0.3)', alignItems: 'center', justifyContent: 'center' }}>
            <View style={{ width: 22, height: 16, borderRadius: 2, borderWidth: 1, borderColor: 'rgba(255,215,80,0.4)' }} />
          </View>
          <Text style={{ color: 'rgba(255,255,255,0.85)', fontSize: 15, fontFamily: 'monospace', letterSpacing: 3 }}>•••• •••• •••• {card.last4}</Text>
        </View>
        <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-end' }}>
          <View>
            <Text style={{ color: 'rgba(255,255,255,0.5)', fontSize: 7, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 2, marginBottom: 2 }}>Name on Card</Text>
            <Text style={{ color: '#fff', fontWeight: '700', fontSize: 10, textTransform: 'uppercase', letterSpacing: 1 }}>{card.cardHolder || '—'}</Text>
          </View>
          <View style={{ alignItems: 'flex-end' }}>
            <Text style={{ color: 'rgba(255,255,255,0.5)', fontSize: 7, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 2, marginBottom: 2 }}>Expires</Text>
            <Text style={{ color: '#fff', fontWeight: '700', fontSize: 11, fontFamily: 'monospace' }}>{card.expiry || '—'}</Text>
          </View>
        </View>
      </View>
    </View>
  );
}

// ─────────────────────── Edit Bank Modal ───────────────────────
function EditBankModal({ inst, loans, cards, onSave, onDelete, onClose, onAddCard, onUpdateCard, onDeleteCard, onAddLoan, companyId }: {
  inst: Partial<Institution>; loans: Loan[]; cards: FinancialCard[];
  onSave: (updated: Partial<Institution>) => void;
  onDelete: () => void;
  onClose: () => void;
  onAddCard: (c: Partial<FinancialCard>) => void;
  onUpdateCard: (id: string, c: Partial<FinancialCard>) => void;
  onDeleteCard: (id: string) => void;
  onAddLoan: (l: Partial<Loan>) => void;
  companyId: string;
}) {
  const [data, setData] = useState<Partial<Institution>>(inst);
  const [showDelete, setShowDelete] = useState(false);
  const [expandedIdx, setExpandedIdx] = useState<Set<number>>(new Set());
  const [confirmDeleteAcc, setConfirmDeleteAcc] = useState<number | null>(null);
  const [showLoanModal, setShowLoanModal] = useState(false);
  const insets = useSafeAreaInsets();

  const cardTypes = ['Credit Card', 'Debit Card', 'Debit (Linked)', 'FSA', 'HSA'];
  const accountTypes = ['Checking', 'Savings', 'Investing', '401(k)', 'Roth 401(k)', 'IRA', 'Roth IRA', 'SEP IRA', '529', 'CD', 'Other'];

  const addAccount = (type: string) => {
    const newId = Math.random().toString(36).substr(2, 9);
    const newAcc: InstitutionAccount = { id: newId, name: '', type: type as any, last4: '', balance: 0 };
    const idx = (data.accounts || []).length;
    setData(d => ({ ...d, accounts: [...(d.accounts || []), newAcc] }));
    setExpandedIdx(s => new Set(s).add(idx));
  };

  const updateAcc = (idx: number, updates: Partial<InstitutionAccount>) => {
    setData(d => {
      const accs = [...(d.accounts || [])];
      accs[idx] = { ...accs[idx], ...updates };
      return { ...d, accounts: accs };
    });
  };

  const deleteAcc = (idx: number) => {
    setData(d => ({ ...d, accounts: (d.accounts || []).filter((_, i) => i !== idx) }));
    setConfirmDeleteAcc(null);
  };

  const instLoans = loans.filter(l => l.lender?.toLowerCase() === (data.name || '').toLowerCase());

  const handleSave = () => {
    // Sync card-type accounts to global cards
    const accs = data.accounts || [];
    accs.forEach(acc => {
      if (!cardTypes.includes(acc.type)) return;
      const cardData: Partial<FinancialCard> = {
        id: acc.id, name: acc.name || `${data.name} Card`,
        institutionName: data.name || '', last4: acc.last4 || '',
        expiry: (acc as any).expiry || '', type: acc.type === 'Credit Card' ? 'Credit' : 'Debit',
        status: (acc.status as any) || 'Active', limit: acc.limit || 0,
        paidFrom: (acc as any).paidFrom || '', paidOn: (acc as any).paidOn || '',
        autopay: (acc as any).autopay || 'N/A', cardHolder: (acc as any).cardHolder || ''
      };
      const exists = cards.find(c => c.id === acc.id);
      if (exists) onUpdateCard(acc.id, cardData);
      else onAddCard(cardData);
    });
    // Remove deleted card-type accounts from global cards
    if (inst.id) {
      const original = inst.accounts || [];
      const newIds = accs.map(a => a.id);
      original.filter(a => cardTypes.includes(a.type) && !newIds.includes(a.id))
        .forEach(a => onDeleteCard(a.id));
    }
    onSave(data);
  };

  return (
    <Modal visible animationType="slide" transparent onRequestClose={onClose}>
      <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={{ flex: 1 }}>
        <View style={{ flex: 1, backgroundColor: 'rgba(0,0,0,0.7)', justifyContent: 'flex-end' }}>
          <View style={{ backgroundColor: '#1C1C1E', borderTopLeftRadius: 28, borderTopRightRadius: 28, maxHeight: '92%', borderWidth: 1, borderColor: 'rgba(255,255,255,0.1)' }}>
            {/* Header */}
            <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20, paddingVertical: 16, borderBottomWidth: 1, borderBottomColor: 'rgba(255,255,255,0.05)' }}>
              <Text style={{ color: '#fff', fontWeight: '900', fontSize: 16, letterSpacing: 1 }}>{inst.id ? 'EDIT BANK' : 'ADD BANK'}</Text>
              <TouchableOpacity onPress={onClose}><Ionicons name="close" size={22} color="rgba(255,255,255,0.4)" /></TouchableOpacity>
            </View>

            <ScrollView contentContainerStyle={{ padding: 20, paddingBottom: insets.bottom + 100 }}>
              {/* Basic Fields */}
              <View style={{ flexDirection: 'row', gap: 12 }}>
                <View style={{ flex: 1 }}><Field label="Institution" value={data.name || ''} placeholder="Mercury" onChangeText={v => setData(d => ({ ...d, name: v }))} /></View>
                <View style={{ flex: 1 }}><Field label="Website" value={data.loginUrl || ''} placeholder="bank.com" onChangeText={v => setData(d => ({ ...d, loginUrl: v }))} /></View>
              </View>
              <View style={{ flexDirection: 'row', gap: 12 }}>
                <View style={{ flex: 1 }}><Field label="Login ID" value={data.username || ''} placeholder="user_admin" onChangeText={v => setData(d => ({ ...d, username: v }))} /></View>
                <View style={{ flex: 1 }}><Field label="Password" value={data.password || ''} placeholder="••••••" onChangeText={v => setData(d => ({ ...d, password: v }))} /></View>
              </View>

              {/* Divider */}
              <View style={{ height: 1, backgroundColor: 'rgba(255,255,255,0.05)', marginVertical: 16 }} />

              {/* Add Card Button */}
              <TouchableOpacity onPress={() => addAccount('Credit Card')} style={{ backgroundColor: '#1C1C1E', borderWidth: 1, borderColor: 'rgba(255,255,255,0.08)', borderRadius: 12, height: 56, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 10, marginBottom: 8 }}>
                <Text style={{ fontSize: 20 }}>💳</Text>
                <Text style={{ color: 'rgba(255,255,255,0.6)', fontWeight: '700', fontSize: 11, textTransform: 'uppercase', letterSpacing: 2 }}>Add Card</Text>
              </TouchableOpacity>

              {/* Card-type accounts */}
              {(data.accounts || []).filter(a => cardTypes.includes(a.type)).map((acc, i) => {
                const idx = (data.accounts || []).indexOf(acc);
                const expanded = expandedIdx.has(idx);
                return (
                  <View key={acc.id || i} style={{ backgroundColor: 'rgba(0,0,0,0.25)', borderRadius: 12, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', marginBottom: 6, overflow: 'hidden' }}>
                    <TouchableOpacity onPress={() => setExpandedIdx(s => { const n = new Set(s); n.has(idx) ? n.delete(idx) : n.add(idx); return n; })}
                      style={{ flexDirection: 'row', alignItems: 'center', paddingHorizontal: 14, height: 48, justifyContent: 'space-between' }}>
                      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, flex: 1 }}>
                        {confirmDeleteAcc === idx ? (
                          <View style={{ flexDirection: 'row', gap: 6 }}>
                            <TouchableOpacity onPress={() => deleteAcc(idx)} style={{ backgroundColor: 'rgba(239,68,68,0.2)', paddingHorizontal: 10, paddingVertical: 4, borderRadius: 6 }}><Text style={{ color: '#ef4444', fontWeight: '700', fontSize: 11 }}>Delete</Text></TouchableOpacity>
                            <TouchableOpacity onPress={() => setConfirmDeleteAcc(null)} style={{ paddingHorizontal: 10, paddingVertical: 4 }}><Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 11 }}>Cancel</Text></TouchableOpacity>
                          </View>
                        ) : (
                          <TouchableOpacity onPress={() => setConfirmDeleteAcc(idx)}>
                            <Ionicons name="close" size={16} color="rgba(255,255,255,0.2)" />
                          </TouchableOpacity>
                        )}
                        <Text style={{ color: '#fff', fontSize: 13, fontWeight: '500' }}>{acc.name || 'New Card'}</Text>
                        <Text style={{ color: 'rgba(255,255,255,0.3)', fontSize: 10, fontFamily: 'monospace' }}>•••• {acc.last4 || '••••'}</Text>
                        <View style={{ width: 6, height: 6, borderRadius: 3, backgroundColor: (acc as any).status === 'Frozen' ? '#EBC351' : (acc as any).status === 'Expired' ? '#ef4444' : '#1FE400' }} />
                      </View>
                      <Ionicons name={expanded ? 'chevron-up' : 'chevron-down'} size={14} color="rgba(255,255,255,0.3)" />
                    </TouchableOpacity>
                    {expanded && (
                      <View style={{ padding: 14, borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.05)' }}>
                        <View style={{ flexDirection: 'row', gap: 10 }}>
                          <View style={{ flex: 1 }}><Field label="Card Nickname" value={acc.name} placeholder="Chase Sapphire" onChangeText={v => updateAcc(idx, { name: v })} /></View>
                          <View style={{ flex: 1 }}>
                            <SelectField label="Type" value={acc.type} options={cardTypes.map(t => ({ label: t, value: t }))} onChange={v => updateAcc(idx, { type: v as any })} />
                          </View>
                        </View>
                        <View style={{ flexDirection: 'row', gap: 10 }}>
                          <View style={{ flex: 1 }}><Field label="Last 4" value={acc.last4} placeholder="1234" onChangeText={v => updateAcc(idx, { last4: v.replace(/\D/g, '').slice(0, 4) })} mono keyboardType="numeric" /></View>
                          <View style={{ flex: 1 }}>
                            <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 10, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 2, marginBottom: 4, marginLeft: 2 }}>Expiry</Text>
                            <TextInput style={{ backgroundColor: 'rgba(0,0,0,0.3)', borderWidth: 1, borderColor: 'rgba(255,255,255,0.06)', borderRadius: 10, paddingHorizontal: 12, paddingVertical: 10, color: '#fff', fontSize: 13, fontFamily: 'monospace' }}
                              value={(acc as any).expiry || ''} placeholder="MM/YY" placeholderTextColor="rgba(255,255,255,0.2)" maxLength={5} keyboardType="numeric"
                              onChangeText={v => { let val = v.replace(/\D/g, ''); if (val.length > 2) val = val.slice(0, 2) + '/' + val.slice(2, 4); updateAcc(idx, { expiry: val } as any); }} />
                          </View>
                        </View>
                        <View style={{ flexDirection: 'row', gap: 10 }}>
                          <View style={{ flex: 1 }}><Field label="Name on Card" value={(acc as any).cardHolder || ''} placeholder="Jane Doe" onChangeText={v => updateAcc(idx, { cardHolder: v } as any)} /></View>
                          <View style={{ flex: 1 }}>
                            <SelectField label="Status" value={(acc as any).status || 'Active'} options={[{ label: 'Active', value: 'Active' }, { label: 'Frozen', value: 'Frozen' }, { label: 'Expired', value: 'Expired' }]} onChange={v => updateAcc(idx, { status: v as any })} />
                          </View>
                        </View>
                        <Field label="Paid On" value={(acc as any).paidOn || ''} placeholder="15th of Month" onChangeText={v => updateAcc(idx, { paidOn: v } as any)} />
                        <View style={{ flexDirection: 'row', gap: 10 }}>
                          <View style={{ flex: 1 }}><Field label="Balance" value={String(acc.balance || '')} placeholder="0.00" onChangeText={v => updateAcc(idx, { balance: parseFloat(v) || 0 })} keyboardType="decimal-pad" /></View>
                          {acc.type === 'Credit Card' && (
                            <><View style={{ flex: 1 }}><Field label="Credit Limit" value={String(acc.limit || '')} placeholder="5000" onChangeText={v => updateAcc(idx, { limit: parseFloat(v) || 0 })} keyboardType="decimal-pad" /></View>
                            <View style={{ flex: 1 }}><Field label="Mo. Payment" value={String((acc as any).monthlyPayment || '')} placeholder="0.00" onChangeText={v => updateAcc(idx, { monthlyPayment: parseFloat(v) || 0 } as any)} keyboardType="decimal-pad" /></View></>
                          )}
                        </View>
                      </View>
                    )}
                  </View>
                );
              })}

              {/* Divider */}
              <View style={{ height: 1, backgroundColor: 'rgba(255,255,255,0.05)', marginVertical: 16 }} />

              {/* Add Account Button */}
              <TouchableOpacity onPress={() => addAccount('Checking')} style={{ backgroundColor: '#1C1C1E', borderWidth: 1, borderColor: 'rgba(255,255,255,0.08)', borderRadius: 12, height: 56, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 10, marginBottom: 8 }}>
                <Text style={{ fontSize: 20 }}>🏦</Text>
                <Text style={{ color: 'rgba(255,255,255,0.6)', fontWeight: '700', fontSize: 11, textTransform: 'uppercase', letterSpacing: 2 }}>Add Account</Text>
              </TouchableOpacity>

              {/* Bank accounts (non-card) */}
              {(data.accounts || []).filter(a => !cardTypes.includes(a.type)).map((acc, i) => {
                const idx = (data.accounts || []).indexOf(acc);
                return (
                  <View key={`acc-${i}`} style={{ backgroundColor: 'rgba(0,0,0,0.25)', borderRadius: 12, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', padding: 14, marginBottom: 8, position: 'relative' }}>
                    <TouchableOpacity onPress={() => setConfirmDeleteAcc(idx)} style={{ position: 'absolute', top: 10, right: 10, zIndex: 1 }}>
                      <Ionicons name="close" size={14} color="rgba(255,255,255,0.2)" />
                    </TouchableOpacity>
                    {confirmDeleteAcc === idx && (
                      <View style={{ flexDirection: 'row', gap: 8, marginBottom: 10 }}>
                        <TouchableOpacity onPress={() => deleteAcc(idx)} style={{ backgroundColor: 'rgba(239,68,68,0.2)', paddingHorizontal: 12, paddingVertical: 6, borderRadius: 8 }}><Text style={{ color: '#ef4444', fontWeight: '700', fontSize: 12 }}>Delete</Text></TouchableOpacity>
                        <TouchableOpacity onPress={() => setConfirmDeleteAcc(null)} style={{ paddingHorizontal: 12, paddingVertical: 6 }}><Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 12 }}>Cancel</Text></TouchableOpacity>
                      </View>
                    )}
                    <View style={{ flexDirection: 'row', gap: 10 }}>
                      <View style={{ flex: 1 }}><Field label="Account Name" value={acc.name} placeholder="Checking" onChangeText={v => updateAcc(idx, { name: v })} /></View>
                      <View style={{ flex: 1 }}><SelectField label="Type" value={acc.type} options={accountTypes.map(t => ({ label: t, value: t }))} onChange={v => updateAcc(idx, { type: v as any })} /></View>
                    </View>
                    <View style={{ flexDirection: 'row', gap: 10 }}>
                      <View style={{ flex: 1 }}><Field label="Account Number" value={acc.last4} placeholder="••••••" onChangeText={v => updateAcc(idx, { last4: v })} mono /></View>
                      <View style={{ flex: 1 }}><Field label="Balance" value={String(acc.balance || '')} placeholder="0.00" onChangeText={v => updateAcc(idx, { balance: parseFloat(v) || 0 })} keyboardType="decimal-pad" /></View>
                    </View>
                  </View>
                );
              })}

              {/* Divider */}
              <View style={{ height: 1, backgroundColor: 'rgba(255,255,255,0.05)', marginVertical: 16 }} />

              {/* Add Loan */}
              <TouchableOpacity onPress={() => setShowLoanModal(true)} style={{ backgroundColor: '#1C1C1E', borderWidth: 1, borderColor: 'rgba(255,255,255,0.08)', borderRadius: 12, height: 56, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 10, marginBottom: 8 }}>
                <Text style={{ fontSize: 20 }}>💸</Text>
                <Text style={{ color: 'rgba(255,255,255,0.6)', fontWeight: '700', fontSize: 11, textTransform: 'uppercase', letterSpacing: 2 }}>Add Loan</Text>
              </TouchableOpacity>

              {/* Loans inside bank */}
              {instLoans.map(loan => {
                const amort = calcAmortization(loan);
                return (
                  <View key={loan.id} style={{ backgroundColor: 'rgba(0,0,0,0.25)', borderRadius: 12, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', padding: 14, marginBottom: 8 }}>
                    <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginBottom: 10 }}>
                      <View>
                        <Text style={{ color: '#fff', fontWeight: '700', fontSize: 13 }}>{loan.name}</Text>
                        <Text style={{ color: loan.status === 'Paid Off' ? '#10b981' : '#EBC351', fontSize: 10, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 1 }}>{loan.status}</Text>
                      </View>
                      <View style={{ alignItems: 'flex-end' }}>
                        <Text style={{ color: '#fff', fontWeight: '700', fontSize: 13 }}>${(loan.principalAmount || 0).toLocaleString()}</Text>
                        <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 9, fontWeight: '700', textTransform: 'uppercase' }}>Loan Amount</Text>
                      </View>
                    </View>
                    {amort && (
                      <View style={{ gap: 4 }}>
                        <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
                          <Text style={{ color: '#EBC351', fontSize: 9, fontWeight: '700', textTransform: 'uppercase' }}>Principal {amort.principalPct.toFixed(0)}%</Text>
                          <Text style={{ color: '#f97316', fontSize: 9, fontWeight: '700', textTransform: 'uppercase' }}>Interest {amort.interestPct.toFixed(0)}%</Text>
                        </View>
                        <View style={{ height: 4, backgroundColor: 'rgba(255,255,255,0.1)', borderRadius: 2, flexDirection: 'row', overflow: 'hidden' }}>
                          <View style={{ height: 4, backgroundColor: '#EBC351', width: `${amort.principalPct}%` as any }} />
                          <View style={{ height: 4, backgroundColor: '#f97316', width: `${amort.interestPct}%` as any }} />
                        </View>
                      </View>
                    )}
                  </View>
                );
              })}
            </ScrollView>

            {/* Footer */}
            <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 20, paddingVertical: 14, borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.05)', backgroundColor: 'rgba(0,0,0,0.2)', paddingBottom: insets.bottom + 14 }}>
              {inst.id ? (
                showDelete ? (
                  <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, backgroundColor: 'rgba(249,115,22,0.1)', borderRadius: 12, borderWidth: 1, borderColor: 'rgba(249,115,22,0.3)', paddingHorizontal: 12, paddingVertical: 8 }}>
                    <Text style={{ color: '#f97316', fontSize: 11, fontWeight: '700', textTransform: 'uppercase' }}>Confirm?</Text>
                    <TouchableOpacity onPress={onDelete} style={{ paddingHorizontal: 12, paddingVertical: 6, backgroundColor: 'rgba(0,0,0,0.4)', borderRadius: 8 }}><Text style={{ color: '#fff', fontWeight: '700', fontSize: 11 }}>YES</Text></TouchableOpacity>
                    <TouchableOpacity onPress={() => setShowDelete(false)} style={{ paddingHorizontal: 12, paddingVertical: 6 }}><Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 11 }}>NO</Text></TouchableOpacity>
                  </View>
                ) : (
                  <TouchableOpacity onPress={() => setShowDelete(true)} style={{ padding: 10 }}>
                    <Ionicons name="trash-outline" size={20} color="rgba(255,255,255,0.2)" />
                  </TouchableOpacity>
                )
              ) : <View />}
              <View style={{ flexDirection: 'row', gap: 12, alignItems: 'center' }}>
                <TouchableOpacity onPress={onClose}><Text style={{ color: 'rgba(255,255,255,0.4)', fontWeight: '700', fontSize: 12, textTransform: 'uppercase', letterSpacing: 1 }}>Cancel</Text></TouchableOpacity>
                <TouchableOpacity onPress={handleSave} style={{ backgroundColor: '#f97316', borderRadius: 10, paddingHorizontal: 24, paddingVertical: 10 }}>
                  <Text style={{ color: '#fff', fontWeight: '700', fontSize: 12, textTransform: 'uppercase', letterSpacing: 1 }}>Save Bank</Text>
                </TouchableOpacity>
              </View>
            </View>
          </View>
        </View>
      </KeyboardAvoidingView>
      {showLoanModal && (
        <EditLoanModal
          loan={{ role: 'Lendee', lender: data.name, _fromBank: true } as any}
          onSave={loan => { onAddLoan({ ...loan, companyId }); setShowLoanModal(false); }}
          onDelete={() => setShowLoanModal(false)}
          onClose={() => setShowLoanModal(false)}
        />
      )}
    </Modal>
  );
}

// ─────────────────────── Edit Card Modal ───────────────────────
function EditCardModal({ card, onSave, onDelete, onClose }: {
  card: Partial<FinancialCard>;
  onSave: (c: Partial<FinancialCard>) => void;
  onDelete: () => void;
  onClose: () => void;
}) {
  const [data, setData] = useState<Partial<FinancialCard>>(card);
  const [showDelete, setShowDelete] = useState(false);
  const insets = useSafeAreaInsets();

  return (
    <Modal visible animationType="slide" transparent onRequestClose={onClose}>
      <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={{ flex: 1 }}>
        <View style={{ flex: 1, backgroundColor: 'rgba(0,0,0,0.7)', justifyContent: 'flex-end' }}>
          <View style={{ backgroundColor: '#1C1C1E', borderTopLeftRadius: 28, borderTopRightRadius: 28, maxHeight: '88%', borderWidth: 1, borderColor: 'rgba(255,255,255,0.1)' }}>
            <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20, paddingVertical: 16, borderBottomWidth: 1, borderBottomColor: 'rgba(255,255,255,0.05)', backgroundColor: 'rgba(0,0,0,0.2)' }}>
              <Text style={{ color: '#fff', fontWeight: '900', fontSize: 14, textTransform: 'uppercase', letterSpacing: 1 }}>{card.id ? 'Edit Card Details' : 'Add New Card'}</Text>
              <TouchableOpacity onPress={onClose} style={{ padding: 4 }}><Ionicons name="close" size={20} color="rgba(255,255,255,0.4)" /></TouchableOpacity>
            </View>
            <ScrollView contentContainerStyle={{ padding: 20, paddingBottom: insets.bottom + 80 }}>
              {/* Live card preview */}
              {(data.last4 || data.name) && (
                <View style={{ alignItems: 'center', marginBottom: 20 }}>
                  <CardVisual card={data as FinancialCard} />
                </View>
              )}
              <Field label="Card Nickname" value={data.name || ''} placeholder="Amex Gold – Advertising" onChangeText={v => setData(d => ({ ...d, name: v }))} />
              <View style={{ flexDirection: 'row', gap: 12 }}>
                <View style={{ flex: 1 }}><Field label="Institution Name" value={data.institutionName || ''} placeholder="Chase, Amex" onChangeText={v => setData(d => ({ ...d, institutionName: v }))} /></View>
                <View style={{ flex: 1 }}><SelectField label="Type" value={data.type || 'Credit'} options={[{ label: 'Credit', value: 'Credit' }, { label: 'Debit', value: 'Debit' }]} onChange={v => setData(d => ({ ...d, type: v as any }))} /></View>
              </View>
              <View style={{ flexDirection: 'row', gap: 12 }}>
                <View style={{ flex: 1 }}><Field label="Login" value={data.login || ''} placeholder="username or email" onChangeText={v => setData(d => ({ ...d, login: v }))} /></View>
                <View style={{ flex: 1 }}><Field label="Password" value={data.password || ''} placeholder="••••••••" onChangeText={v => setData(d => ({ ...d, password: v }))} /></View>
              </View>
              <View style={{ flexDirection: 'row', gap: 12 }}>
                <View style={{ flex: 2 }}>
                  <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 10, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 2, marginBottom: 4, marginLeft: 2 }}>Card Number (Last 4)</Text>
                  <View style={{ position: 'relative' }}>
                    <Text style={{ position: 'absolute', left: 12, top: 10, color: 'rgba(255,255,255,0.2)', fontFamily: 'monospace', fontSize: 13, zIndex: 1 }}>•••• •••• •••• </Text>
                    <TextInput style={{ backgroundColor: 'rgba(0,0,0,0.3)', borderWidth: 1, borderColor: 'rgba(255,255,255,0.06)', borderRadius: 10, paddingLeft: 128, paddingRight: 12, paddingVertical: 10, color: '#fff', fontSize: 13, fontFamily: 'monospace' }}
                      maxLength={4} keyboardType="numeric" value={data.last4 || ''} placeholder="1234" placeholderTextColor="rgba(255,255,255,0.2)"
                      onChangeText={v => setData(d => ({ ...d, last4: v.replace(/\D/g, '') }))} />
                  </View>
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 10, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 2, marginBottom: 4, marginLeft: 2 }}>Expiry</Text>
                  <TextInput style={{ backgroundColor: 'rgba(0,0,0,0.3)', borderWidth: 1, borderColor: 'rgba(255,255,255,0.06)', borderRadius: 10, paddingHorizontal: 12, paddingVertical: 10, color: '#fff', fontSize: 13, fontFamily: 'monospace', textAlign: 'center' }}
                    placeholder="MM/YY" placeholderTextColor="rgba(255,255,255,0.2)" maxLength={5} keyboardType="numeric" value={data.expiry || ''}
                    onChangeText={v => { let val = v.replace(/\D/g, ''); if (val.length > 2) val = val.slice(0, 2) + '/' + val.slice(2, 4); setData(d => ({ ...d, expiry: val })); }} />
                </View>
              </View>
              <View style={{ flexDirection: 'row', gap: 12 }}>
                <View style={{ flex: 1 }}><SelectField label="Network" value={data.network || 'Visa'} options={[{ label: 'Visa', value: 'Visa' }, { label: 'Mastercard', value: 'Mastercard' }, { label: 'Amex', value: 'Amex' }, { label: 'Discover', value: 'Discover' }]} onChange={v => setData(d => ({ ...d, network: v as any }))} /></View>
                <View style={{ flex: 1 }}><SelectField label="Status" value={data.status || 'Active'} options={[{ label: 'Active', value: 'Active' }, { label: 'Frozen', value: 'Frozen' }, { label: 'Expired', value: 'Expired' }]} onChange={v => setData(d => ({ ...d, status: v as any }))} /></View>
              </View>
              <Field label="Credit Limit / Balance $" value={String(data.limit || '')} placeholder="5000" onChangeText={v => setData(d => ({ ...d, limit: parseFloat(v) || 0 }))} keyboardType="decimal-pad" />
            </ScrollView>
            <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 20, paddingVertical: 14, borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.05)', backgroundColor: 'rgba(0,0,0,0.2)', paddingBottom: insets.bottom + 14 }}>
              {card.id ? (
                showDelete ? (
                  <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, backgroundColor: 'rgba(249,115,22,0.1)', borderRadius: 12, borderWidth: 1, borderColor: 'rgba(249,115,22,0.3)', paddingHorizontal: 12, paddingVertical: 8 }}>
                    <Text style={{ color: '#f97316', fontSize: 11, fontWeight: '700', textTransform: 'uppercase' }}>Confirm?</Text>
                    <TouchableOpacity onPress={onDelete} style={{ paddingHorizontal: 12, paddingVertical: 6, backgroundColor: 'rgba(0,0,0,0.4)', borderRadius: 8 }}><Text style={{ color: '#fff', fontWeight: '700', fontSize: 11 }}>YES</Text></TouchableOpacity>
                    <TouchableOpacity onPress={() => setShowDelete(false)} style={{ paddingHorizontal: 12, paddingVertical: 6 }}><Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 11 }}>NO</Text></TouchableOpacity>
                  </View>
                ) : (
                  <TouchableOpacity onPress={() => setShowDelete(true)} style={{ padding: 10 }}><Ionicons name="trash-outline" size={20} color="rgba(255,255,255,0.2)" /></TouchableOpacity>
                )
              ) : <View />}
              <View style={{ flexDirection: 'row', gap: 12, alignItems: 'center' }}>
                <TouchableOpacity onPress={onClose}><Text style={{ color: 'rgba(255,255,255,0.4)', fontWeight: '700', fontSize: 12, textTransform: 'uppercase', letterSpacing: 1 }}>Cancel</Text></TouchableOpacity>
                <TouchableOpacity onPress={() => onSave(data)} style={{ backgroundColor: '#f97316', borderRadius: 10, paddingHorizontal: 24, paddingVertical: 10 }}>
                  <Text style={{ color: '#fff', fontWeight: '700', fontSize: 12, textTransform: 'uppercase', letterSpacing: 1 }}>Save Card</Text>
                </TouchableOpacity>
              </View>
            </View>
          </View>
        </View>
      </KeyboardAvoidingView>
    </Modal>
  );
}

// ─────────────────────── Edit Loan Modal ───────────────────────
function EditLoanModal({ loan, onSave, onDelete, onClose }: {
  loan: Partial<Loan> & { _fromBank?: boolean };
  onSave: (l: Partial<Loan>) => void;
  onDelete: () => void;
  onClose: () => void;
}) {
  const [data, setData] = useState<any>(loan);
  const [showDelete, setShowDelete] = useState(false);
  const [showAmort, setShowAmort] = useState(false);
  const insets = useSafeAreaInsets();
  const amort = calcAmortization(data);

  return (
    <Modal visible animationType="slide" transparent onRequestClose={onClose}>
      <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={{ flex: 1 }}>
        <View style={{ flex: 1, backgroundColor: 'rgba(0,0,0,0.7)', justifyContent: 'flex-end' }}>
          <View style={{ backgroundColor: '#1C1C1E', borderTopLeftRadius: 28, borderTopRightRadius: 28, maxHeight: '92%', borderWidth: 1, borderColor: 'rgba(255,255,255,0.1)' }}>
            <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20, paddingVertical: 16, borderBottomWidth: 1, borderBottomColor: 'rgba(255,255,255,0.05)', backgroundColor: 'rgba(0,0,0,0.2)' }}>
              <Text style={{ color: '#fff', fontWeight: '900', fontSize: 14, textTransform: 'uppercase', letterSpacing: 1 }}>{loan.id ? 'Edit Loan Details' : 'Add New Financing'}</Text>
              <TouchableOpacity onPress={onClose} style={{ padding: 4 }}><Ionicons name="close" size={20} color="rgba(255,255,255,0.4)" /></TouchableOpacity>
            </View>
            <ScrollView contentContainerStyle={{ padding: 20, paddingBottom: insets.bottom + 80 }}>
              {/* Lender / Lendee Toggle */}
              {!data._fromBank && !data.id && (
                <View style={{ flexDirection: 'row', backgroundColor: 'rgba(0,0,0,0.4)', padding: 4, borderRadius: 24, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', marginBottom: 16, alignSelf: 'center', minWidth: 200 }}>
                  {['Lender', 'Lendee'].map(role => (
                    <TouchableOpacity key={role} onPress={() => setData((d: any) => ({ ...d, role }))}
                      style={{ flex: 1, paddingVertical: 8, borderRadius: 20, backgroundColor: data.role === role ? '#EBC351' : 'transparent', alignItems: 'center' }}>
                      <Text style={{ color: data.role === role ? '#000' : 'rgba(255,255,255,0.4)', fontWeight: '700', fontSize: 12, textTransform: 'uppercase', letterSpacing: 1 }}>{role}</Text>
                    </TouchableOpacity>
                  ))}
                </View>
              )}

              {/* Fields */}
              <View style={{ flexDirection: 'row', gap: 12 }}>
                <View style={{ flex: 1 }}><Field label={data.role === 'Lender' ? 'Lent To' : 'Lender / Institution'} value={data.lender || ''} placeholder="Silicon Valley Bank" onChangeText={v => setData((d: any) => ({ ...d, lender: v }))} /></View>
                <View style={{ flex: 1 }}><Field label="Loan ID / Name" value={data.name || ''} placeholder="Series A Venture Debt" onChangeText={v => setData((d: any) => ({ ...d, name: v }))} /></View>
              </View>
              <Field label="Loan Summary" value={data.term || ''} placeholder="36 Months notes..." onChangeText={v => setData((d: any) => ({ ...d, term: v }))} multiline />
              <View style={{ flexDirection: 'row', gap: 12 }}>
                <View style={{ flex: 1 }}>
                  <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 10, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 2, marginBottom: 4, marginLeft: 2 }}>Loan Date</Text>
                  <TextInput style={{ backgroundColor: 'rgba(0,0,0,0.3)', borderWidth: 1, borderColor: 'rgba(255,255,255,0.06)', borderRadius: 10, paddingHorizontal: 12, paddingVertical: 10, color: '#fff', fontSize: 13}}
                    value={data.startDate || ''} placeholder="YYYY-MM-DD" placeholderTextColor="rgba(255,255,255,0.2)"
                    onChangeText={v => setData((d: any) => ({ ...d, startDate: v }))} />
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 10, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 2, marginBottom: 4, marginLeft: 2 }}>Paid Off Date</Text>
                  <TextInput style={{ backgroundColor: 'rgba(0,0,0,0.3)', borderWidth: 1, borderColor: 'rgba(255,255,255,0.06)', borderRadius: 10, paddingHorizontal: 12, paddingVertical: 10, color: '#fff', fontSize: 13}}
                    value={data.paidOffDate || ''} placeholder="YYYY-MM-DD" placeholderTextColor="rgba(255,255,255,0.2)"
                    onChangeText={v => setData((d: any) => ({ ...d, paidOffDate: v }))} />
                </View>
              </View>
              <View style={{ flexDirection: 'row', gap: 12, alignItems: 'flex-end', marginBottom: 12 }}>
                <View style={{ flex: 1 }}>
                  <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 10, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 2, marginBottom: 4, marginLeft: 2 }}>Loan Amount $</Text>
                  <TextInput style={{ backgroundColor: 'rgba(0,0,0,0.3)', borderWidth: 1, borderColor: 'rgba(255,255,255,0.06)', borderRadius: 10, paddingHorizontal: 12, paddingVertical: 10, color: '#fff', fontSize: 13, fontFamily: 'monospace' }}
                    value={String(data.principalAmount || '')} placeholder="50000" placeholderTextColor="rgba(255,255,255,0.2)" keyboardType="decimal-pad"
                    onChangeText={v => setData((d: any) => ({ ...d, principalAmount: parseFloat(v) || 0 }))} />
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 10, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 2, marginBottom: 4, marginLeft: 2 }}>
                    {data.interestType === 'Fixed' ? 'Fixed Fee $' : 'YR APR %'}
                  </Text>
                  <TextInput style={{ backgroundColor: 'rgba(0,0,0,0.3)', borderWidth: 1, borderColor: 'rgba(255,255,255,0.06)', borderRadius: 10, paddingHorizontal: 12, paddingVertical: 10, color: '#fff', fontSize: 13, fontFamily: 'monospace' }}
                    value={String(data.interestRate || '')} placeholder={data.interestType === 'Fixed' ? '500' : '5.5'} placeholderTextColor="rgba(255,255,255,0.2)" keyboardType="decimal-pad"
                    onChangeText={v => setData((d: any) => ({ ...d, interestRate: parseFloat(v) || 0 }))} />
                </View>
              </View>

              {/* Term + Frequency */}
              <View style={{ flexDirection: 'row', gap: 12, alignItems: 'flex-end', marginBottom: 12 }}>
                <View style={{ flex: 1 }}>
                  <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 10, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 2, marginBottom: 4, marginLeft: 2 }}>Term (Yrs)</Text>
                  <TextInput style={{ backgroundColor: 'rgba(0,0,0,0.3)', borderWidth: 1, borderColor: 'rgba(255,255,255,0.06)', borderRadius: 10, paddingHorizontal: 12, paddingVertical: 10, color: '#fff', fontSize: 13, fontFamily: 'monospace' }}
                    value={String(data.termYears || '')} placeholder="5" placeholderTextColor="rgba(255,255,255,0.2)" keyboardType="number-pad"
                    onChangeText={v => setData((d: any) => ({ ...d, termYears: parseInt(v) || 0 }))} />
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 10, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 2, marginBottom: 4, marginLeft: 2 }}>Term (Mos)</Text>
                  <TextInput style={{ backgroundColor: 'rgba(0,0,0,0.3)', borderWidth: 1, borderColor: 'rgba(255,255,255,0.06)', borderRadius: 10, paddingHorizontal: 12, paddingVertical: 10, color: '#fff', fontSize: 13, fontFamily: 'monospace' }}
                    value={String(data.termMonths || '')} placeholder="0" placeholderTextColor="rgba(255,255,255,0.2)" keyboardType="number-pad"
                    onChangeText={v => setData((d: any) => ({ ...d, termMonths: parseInt(v) || 0 }))} />
                </View>
                <View style={{ flex: 1 }}>
                  <SelectField label="Frequency" value={data.scheduleFrequency || 'Monthly'}
                    options={[{ label: 'Weekly', value: 'Weekly' }, { label: 'Monthly', value: 'Monthly' }, { label: 'Yearly', value: 'Yearly' }]}
                    onChange={v => setData((d: any) => ({ ...d, scheduleFrequency: v }))} />
                </View>
              </View>

              {/* Interest Type */}
              <View style={{ marginBottom: 16 }}>
                <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 10, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 2, marginBottom: 6, marginLeft: 2 }}>Interest Type</Text>
                <View style={{ flexDirection: 'row', backgroundColor: 'rgba(0,0,0,0.4)', padding: 4, borderRadius: 12, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)' }}>
                  {[{ label: 'Interest %', value: 'Percentage' }, { label: 'Fixed Fee', value: 'Fixed' }].map(opt => (
                    <TouchableOpacity key={opt.value} onPress={() => setData((d: any) => ({ ...d, interestType: opt.value }))}
                      style={{ flex: 1, paddingVertical: 8, borderRadius: 8, backgroundColor: (data.interestType || 'Percentage') === opt.value ? '#EBC351' : 'transparent', alignItems: 'center' }}>
                      <Text style={{ color: (data.interestType || 'Percentage') === opt.value ? '#000' : 'rgba(255,255,255,0.4)', fontWeight: '700', fontSize: 11, textTransform: 'uppercase', letterSpacing: 1 }}>{opt.label}</Text>
                    </TouchableOpacity>
                  ))}
                </View>
              </View>

              {/* Amortization calculator */}
              {amort && (
                <View style={{ backgroundColor: 'rgba(0,0,0,0.25)', borderRadius: 14, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', padding: 16, marginTop: 8 }}>
                  <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginBottom: 14 }}>
                    <View>
                      <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 9, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 1 }}>{amort.scheduleFrequency} Pmt</Text>
                      <Text style={{ color: '#fff', fontWeight: '900', fontSize: 20 }}>{fmt(amort.monthlyPayment)}</Text>
                    </View>
                    <View style={{ alignItems: 'center' }}>
                      <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 9, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 1 }}>Total Int.</Text>
                      <Text style={{ color: '#fff', fontWeight: '700', fontSize: 14 }}>{fmt(amort.totalInterest)}</Text>
                    </View>
                    <View style={{ alignItems: 'flex-end' }}>
                      <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 9, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 1 }}>Total Cost</Text>
                      <Text style={{ color: '#fff', fontWeight: '700', fontSize: 14 }}>{fmt(amort.totalCost)}</Text>
                    </View>
                  </View>
                  <View style={{ gap: 4 }}>
                    <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
                      <Text style={{ color: '#EBC351', fontSize: 9, fontWeight: '700', textTransform: 'uppercase' }}>Principal ({amort.principalPct.toFixed(1)}%)</Text>
                      <Text style={{ color: '#f97316', fontSize: 9, fontWeight: '700', textTransform: 'uppercase' }}>Interest ({amort.interestPct.toFixed(1)}%)</Text>
                    </View>
                    <View style={{ height: 6, backgroundColor: 'rgba(0,0,0,0.4)', borderRadius: 3, flexDirection: 'row', overflow: 'hidden' }}>
                      <View style={{ flex: amort.principalPct, backgroundColor: '#EBC351', borderRadius: 3 }} />
                      <View style={{ flex: amort.interestPct, backgroundColor: '#f97316', borderRadius: 3 }} />
                    </View>
                  </View>

                  {/* Amortization Schedule Toggle */}
                  <TouchableOpacity onPress={() => setShowAmort(!showAmort)}
                    style={{ marginTop: 14, height: 36, backgroundColor: 'rgba(0,0,0,0.2)', borderRadius: 10, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 8 }}>
                    <Text style={{ color: 'rgba(255,255,255,0.6)', fontWeight: '700', fontSize: 10, textTransform: 'uppercase', letterSpacing: 1 }}>{showAmort ? 'Hide Schedule' : 'Amortization Schedule'}</Text>
                    <Ionicons name={showAmort ? 'chevron-up' : 'chevron-down'} size={14} color="rgba(255,255,255,0.4)" />
                  </TouchableOpacity>

                  {showAmort && amort.schedule.length > 0 && (
                    <View style={{ marginTop: 10, borderRadius: 10, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', overflow: 'hidden' }}>
                      {/* Header */}
                      <View style={{ flexDirection: 'row', backgroundColor: '#1C1C1E', paddingVertical: 8, paddingHorizontal: 8 }}>
                        {[amort.scheduleFrequency === 'Weekly' ? 'Wk' : amort.scheduleFrequency === 'Yearly' ? 'Yr' : 'Mo', 'Pmt', 'Prin', 'Int', 'Bal'].map((h, i) => (
                          <Text key={h} style={{ flex: i === 0 ? 0.6 : 1, color: i === 2 ? '#EBC351' : i === 3 ? '#f97316' : 'rgba(255,255,255,0.4)', fontSize: 9, fontWeight: '700', textTransform: 'uppercase', textAlign: i === 0 ? 'left' : 'right' }}>{h}</Text>
                        ))}
                      </View>
                      <ScrollView style={{ maxHeight: 220 }} nestedScrollEnabled>
                        {amort.schedule.slice(0, 200).map((row, i) => (
                          <View key={row.month} style={{ flexDirection: 'row', paddingVertical: 6, paddingHorizontal: 8, backgroundColor: i % 2 === 0 ? 'rgba(0,0,0,0.25)' : 'transparent' }}>
                            <Text style={{ flex: 0.6, color: 'rgba(255,255,255,0.4)', fontSize: 10, fontFamily: 'monospace' }}>{row.month}</Text>
                            <Text style={{ flex: 1, color: 'rgba(255,255,255,0.8)', fontSize: 10, fontFamily: 'monospace', textAlign: 'right' }}>${row.payment.toLocaleString(undefined, { maximumFractionDigits: 0 })}</Text>
                            <Text style={{ flex: 1, color: '#EBC351', fontSize: 10, fontFamily: 'monospace', textAlign: 'right', opacity: 0.8 }}>${row.principal.toLocaleString(undefined, { maximumFractionDigits: 0 })}</Text>
                            <Text style={{ flex: 1, color: '#f97316', fontSize: 10, fontFamily: 'monospace', textAlign: 'right', opacity: 0.8 }}>${row.interest.toLocaleString(undefined, { maximumFractionDigits: 0 })}</Text>
                            <Text style={{ flex: 1, color: '#fff', fontSize: 10, fontFamily: 'monospace', textAlign: 'right' }}>${row.balance.toLocaleString(undefined, { maximumFractionDigits: 0 })}</Text>
                          </View>
                        ))}
                        {amort.schedule.length > 200 && <Text style={{ color: 'rgba(255,255,255,0.3)', fontSize: 10, textAlign: 'center', padding: 8 }}>…{amort.schedule.length - 200} more periods</Text>}
                      </ScrollView>
                    </View>
                  )}
                </View>
              )}
            </ScrollView>
            <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 20, paddingVertical: 14, borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.05)', backgroundColor: 'rgba(0,0,0,0.2)', paddingBottom: insets.bottom + 14 }}>
              {loan.id ? (
                showDelete ? (
                  <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, backgroundColor: 'rgba(249,115,22,0.1)', borderRadius: 12, borderWidth: 1, borderColor: 'rgba(249,115,22,0.3)', paddingHorizontal: 12, paddingVertical: 8 }}>
                    <Text style={{ color: '#f97316', fontSize: 11, fontWeight: '700', textTransform: 'uppercase' }}>Confirm?</Text>
                    <TouchableOpacity onPress={onDelete} style={{ paddingHorizontal: 12, paddingVertical: 6, backgroundColor: 'rgba(0,0,0,0.4)', borderRadius: 8 }}><Text style={{ color: '#fff', fontWeight: '700', fontSize: 11 }}>YES</Text></TouchableOpacity>
                    <TouchableOpacity onPress={() => setShowDelete(false)} style={{ paddingHorizontal: 12, paddingVertical: 6 }}><Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 11 }}>NO</Text></TouchableOpacity>
                  </View>
                ) : (
                  <TouchableOpacity onPress={() => setShowDelete(true)} style={{ padding: 10 }}><Ionicons name="trash-outline" size={20} color="rgba(255,255,255,0.2)" /></TouchableOpacity>
                )
              ) : <View />}
              <View style={{ flexDirection: 'row', gap: 12, alignItems: 'center' }}>
                <TouchableOpacity onPress={onClose}><Text style={{ color: 'rgba(255,255,255,0.4)', fontWeight: '700', fontSize: 12, textTransform: 'uppercase', letterSpacing: 1 }}>Cancel</Text></TouchableOpacity>
                <TouchableOpacity onPress={() => onSave(data)} style={{ backgroundColor: '#f97316', borderRadius: 10, paddingHorizontal: 24, paddingVertical: 10 }}>
                  <Text style={{ color: '#fff', fontWeight: '700', fontSize: 12, textTransform: 'uppercase', letterSpacing: 1 }}>Save Loan</Text>
                </TouchableOpacity>
              </View>
            </View>
          </View>
        </View>
      </KeyboardAvoidingView>
    </Modal>
  );
}

// ─────────────────────── Main Screen ───────────────────────
export default function FinancialsScreen() {
  const { state, selectedCompanyId,
    handleAddFinancialCard, handleUpdateFinancialCard, handleDeleteFinancialCard,
    handleAddLoan, handleUpdateLoan, handleDeleteLoan,
    handleAddInstitution, handleUpdateInstitution, handleDeleteInstitution,
  } = useAppContext();
  const insets = useSafeAreaInsets();

  const [editingCard, setEditingCard] = useState<Partial<FinancialCard> | null>(null);
  const [editingLoan, setEditingLoan] = useState<Partial<Loan> | null>(null);
  const [editingInst, setEditingInst] = useState<Partial<Institution> | null>(null);
  const [expandedInsts, setExpandedInsts] = useState<Set<string>>(new Set());
  const [copiedId, setCopiedId] = useState<{ id: string; field: string } | null>(null);
  const [showPw, setShowPw] = useState<Set<string>>(new Set());
  const [poppedCard, setPoppedCard] = useState<string | null>(null);

  if (!state || !selectedCompanyId) {
    return (
      <View style={{ flex: 1, backgroundColor: '#000', alignItems: 'center', justifyContent: 'center' }}>
        <Text style={{ color: 'rgba(255,255,255,0.3)', fontWeight: '700', fontSize: 13, textTransform: 'uppercase', letterSpacing: 2 }}>Select a Company</Text>
      </View>
    );
  }

  const cards = state.financialCards.filter(c => c.companyId === selectedCompanyId);
  const loans = state.loans.filter(l => l.companyId === selectedCompanyId);
  const institutions = (state.institutions || []).filter(i => i.companyId === selectedCompanyId);

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

  const standaloneLoans = loans.filter(l =>
    !institutions.some(inst => inst.name.toLowerCase() === l.lender?.toLowerCase())
  );

  const BOTTOM_PAD = insets.bottom + 120;

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: '#000' }}>
      <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 16, paddingBottom: BOTTOM_PAD }}>

        <CompanyHeader activeTab="financial" />

        {/* ── Action Bar ── */}
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginBottom: 24 }} contentContainerStyle={{ flexGrow: 1, gap: 8, paddingVertical: 4, paddingHorizontal: 8 }}>
          <TouchableOpacity onPress={() => setEditingCard({ name: '', cardHolder: '', last4: '', expiry: '', network: 'Visa', type: 'Credit', status: 'Active', limit: 0 })}
            style={{ backgroundColor: '#1C1C1E', borderRadius: 24, paddingHorizontal: 16, height: 32, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 6, borderWidth: 1, borderColor: 'rgba(255,255,255,0.08)' }}>
            <Ionicons name="add" size={14} color="rgba(255,255,255,0.4)" />
            <Text style={{ color: '#fff', fontWeight: '600', fontSize: 10, textTransform: 'uppercase', letterSpacing: 1 }}>Card</Text>
          </TouchableOpacity>
          <TouchableOpacity onPress={() => setEditingLoan({ role: 'Lendee', lender: '', name: '', principalAmount: 0, interestRate: 0, status: 'Active' })}
            style={{ backgroundColor: '#1C1C1E', borderRadius: 24, paddingHorizontal: 16, height: 32, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 6, borderWidth: 1, borderColor: 'rgba(255,255,255,0.08)' }}>
            <Ionicons name="add" size={14} color="rgba(255,255,255,0.4)" />
            <Text style={{ color: '#fff', fontWeight: '600', fontSize: 10, textTransform: 'uppercase', letterSpacing: 1 }}>Loan</Text>
          </TouchableOpacity>
          <View style={{ flex: 1 }} />
          <TouchableOpacity onPress={() => setEditingInst({ name: '', loginUrl: '', email: '', username: '', password: '', accounts: [] })}
            style={{ backgroundColor: '#fff', borderRadius: 24, paddingHorizontal: 16, height: 32, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 6 }}>
            <Ionicons name="add" size={14} color="rgba(0,0,0,0.5)" />
            <Text style={{ color: '#000', fontWeight: '700', fontSize: 10, textTransform: 'uppercase', letterSpacing: 1 }}>Institution</Text>
          </TouchableOpacity>
        </ScrollView>

        {/* ── Empty State ── */}
        {cards.length === 0 && institutions.length === 0 && loans.length === 0 && (
          <TouchableOpacity onPress={() => setEditingInst({ name: '', loginUrl: '', email: '', username: '', password: '', accounts: [] })}
            style={{ alignSelf: 'center', width: 300, height: 200, borderRadius: 28, borderWidth: 1, borderStyle: 'dashed', borderColor: 'rgba(255,255,255,0.2)', alignItems: 'center', justifyContent: 'center', backgroundColor: 'rgba(28,28,30,0.5)', marginTop: 20 }}>
            <Text style={{ fontSize: 40, marginBottom: 12 }}>🏦</Text>
            <Text style={{ color: 'rgba(255,255,255,0.5)', fontWeight: '700', fontSize: 11, textTransform: 'uppercase', letterSpacing: 2 }}>+ Add Your First Institution</Text>
          </TouchableOpacity>
        )}

        {/* ── Institutions ── */}
        {institutions.length > 0 && (
          <View style={{ marginBottom: 32 }}>
            <View style={{ borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.08)', paddingTop: 24, marginBottom: 16 }}>
              <Text style={{ color: 'rgba(255,255,255,0.3)', fontWeight: '900', fontSize: 16 }}>Financial Institutions</Text>
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
                            <Text style={{ color: 'rgba(255,255,255,0.7)', fontWeight: '900', fontSize: 12, fontStyle: 'italic' }}>{card.network}</Text>
                          </View>
                          {isPopped && (
                            <>
                              <Text style={{ color: 'rgba(255,255,255,0.85)', fontFamily: 'monospace', fontSize: 14, letterSpacing: 3 }}>•••• •••• •••• {card.last4}</Text>
                              <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
                                <Text style={{ color: 'rgba(255,255,255,0.6)', fontSize: 10, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 1 }}>{card.cardHolder}</Text>
                                <Text style={{ color: 'rgba(255,255,255,0.6)', fontSize: 10, fontWeight: '700' }}>{card.expiry}</Text>
                              </View>
                            </>
                          )}
                        </View>
                      </TouchableOpacity>
                    );
                  })}

                  {/* Institution Card — zIndex 20 keeps it ON TOP of all payment cards */}
                  <TouchableOpacity onPress={() => setEditingInst(inst)} activeOpacity={0.85}
                    style={{ backgroundColor: '#1C1C1E', borderRadius: 24, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', overflow: 'hidden', zIndex: 20 }}>
                    <View style={{ padding: 22 }}>
                      {/* Header */}
                      <View style={{ flexDirection: 'row', alignItems: 'flex-start', marginBottom: 20 }}>
                        <View style={{ width: 52, height: 52, backgroundColor: 'rgba(255,255,255,0.05)', borderRadius: 16, alignItems: 'center', justifyContent: 'center', marginRight: 14 }}>
                          <Ionicons name="business" size={22} color="rgba(255,255,255,0.4)" />
                        </View>
                        <View style={{ flex: 1 }}>
                          <Text style={{ color: '#fff', fontWeight: '700', fontSize: 15, textTransform: 'uppercase', letterSpacing: 0.5 }}>{inst.name}</Text>
                          <Text style={{ color: '#fff', fontWeight: '900', fontSize: 17, marginTop: 2 }}>${totalMonthly.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</Text>
                          <Text style={{ color: 'rgba(255,255,255,0.35)', fontSize: 9, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 2 }}>Mo. Payment</Text>
                        </View>
                      </View>
                      {/* Accounts / Cards / Loans count */}
                      <View style={{ flexDirection: 'row', gap: 8, marginBottom: 18 }}>
                        {[{ label: 'Accounts', count: instAccounts }, { label: 'Cards', count: instCards.length }, { label: 'Loans', count: instLoans.length }].map(({ label, count }) => (
                          <View key={label} style={{ flexDirection: 'row', gap: 4, alignItems: 'center' }}>
                            <Text style={{ color: '#EBC351', fontWeight: '700', fontSize: 11 }}>{count}</Text>
                            <Text style={{ color: 'rgba(255,255,255,0.4)', fontWeight: '700', fontSize: 11, textTransform: 'uppercase', letterSpacing: 1 }}>{label}</Text>
                            {label !== 'Loans' && <Text style={{ color: 'rgba(255,255,255,0.15)', marginHorizontal: 4 }}>|</Text>}
                          </View>
                        ))}
                      </View>
                      {/* Credentials */}
                      <View style={{ flexDirection: 'row', gap: 12 }}>
                        <TouchableOpacity onPress={() => copyField(inst.id, 'username', inst.username || inst.email || '')} style={{ flex: 1 }}>
                          <Text style={{ color: copiedId?.id === inst.id && copiedId?.field === 'username' ? '#f97316' : 'rgba(255,255,255,0.35)', fontSize: 10, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 1, marginBottom: 4 }}>
                            {copiedId?.id === inst.id && copiedId?.field === 'username' ? 'Copied' : 'Login ID'}
                          </Text>
                          <View style={{ backgroundColor: 'rgba(0,0,0,0.2)', borderRadius: 10, paddingHorizontal: 12, paddingVertical: 8, borderWidth: 1, borderColor: 'rgba(255,255,255,0.03)' }}>
                            <Text style={{ color: '#fff', fontSize: 12, fontWeight: '500' }} numberOfLines={1}>{inst.username || inst.email || '—'}</Text>
                          </View>
                        </TouchableOpacity>
                        <View style={{ flex: 1 }}>
                          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 4 }}>
                            <TouchableOpacity onPress={() => copyField(inst.id, 'password', inst.password || '')}>
                              <Text style={{ color: copiedId?.id === inst.id && copiedId?.field === 'password' ? '#f97316' : 'rgba(255,255,255,0.35)', fontSize: 10, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 1 }}>
                                {copiedId?.id === inst.id && copiedId?.field === 'password' ? 'Copied' : 'Password'}
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
                        <Text style={{ color: 'rgba(255,255,255,0.4)', fontWeight: '600', fontSize: 12, textTransform: 'uppercase', letterSpacing: 2 }}>{expanded ? 'Less Details' : 'More Details'}</Text>
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
                              <Text style={{ color: 'rgba(255,255,255,0.85)', fontSize: 12, fontWeight: '500', textTransform: 'uppercase' }}>{acc.name}</Text>
                              <Text style={{ color: 'rgba(255,255,255,0.35)', fontSize: 9, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 1 }}>{acc.type}</Text>
                              {acc.last4 && <Text style={{ color: '#EBC351', fontSize: 10, fontWeight: '700' }}>••{acc.last4}</Text>}
                            </View>
                            <Text style={{ color: '#fff', fontSize: 12, fontWeight: '700' }}>
                              ${((acc as any).monthlyPayment || acc.balance || 0).toLocaleString()}
                              <Text style={{ color: 'rgba(255,255,255,0.3)', fontSize: 10 }}>{(acc as any).monthlyPayment ? '/mo' : ''}</Text>
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
                                <Text style={{ color: 'rgba(255,255,255,0.85)', fontSize: 12, fontWeight: '500', textTransform: 'uppercase' }}>{loan.name}</Text>
                                <Text style={{ color: 'rgba(255,255,255,0.35)', fontSize: 9, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 1 }}>Loan{loan.interestRate ? ` • ${loan.interestRate}%` : ''}</Text>
                              </View>
                              <Text style={{ color: '#fff', fontSize: 12, fontWeight: '700' }}>${pmt.toLocaleString(undefined, { maximumFractionDigits: 0 })}<Text style={{ color: 'rgba(255,255,255,0.3)', fontSize: 10 }}>/mo</Text></Text>
                            </View>
                          );
                        })}
                        {instAccounts + instLoans.length === 0 && <Text style={{ color: 'rgba(255,255,255,0.3)', fontWeight: '700', fontSize: 10, textTransform: 'uppercase', letterSpacing: 2 }}>No linked accounts</Text>}
                        <TouchableOpacity onPress={() => setEditingInst(inst)} style={{ paddingTop: 4 }}>
                          <Text style={{ color: 'rgba(255,255,255,0.25)', fontWeight: '700', fontSize: 10, textTransform: 'uppercase', letterSpacing: 2 }}>+ add account</Text>
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
              <Text style={{ color: 'rgba(255,255,255,0.3)', fontWeight: '900', fontSize: 16 }}>Loans & Debt</Text>
            </View>
            {standaloneLoans.map(loan => {
              const amort = calcAmortization(loan);
              return (
                <TouchableOpacity key={loan.id} onPress={() => setEditingLoan(loan)} activeOpacity={0.85}
                  style={{ backgroundColor: '#1C1C1E', borderRadius: 24, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', padding: 22, marginBottom: 16 }}>
                  <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginBottom: 20 }}>
                    <View style={{ flex: 1 }}>
                      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 4 }}>
                        <Text style={{ color: '#fff', fontWeight: '900', fontSize: 16 }}>{loan.name}</Text>
                        {loan.role && <View style={{ borderRadius: 20, borderWidth: 1, borderColor: 'rgba(255,255,255,0.15)', paddingHorizontal: 8, paddingVertical: 2 }}><Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 9, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 1 }}>{loan.role}</Text></View>}
                      </View>
                      <Text style={{ color: 'rgba(255,255,255,0.4)', fontWeight: '700', fontSize: 10, textTransform: 'uppercase', letterSpacing: 1 }}>{loan.lender || 'Unknown'} | <Text style={{ color: loan.status === 'Paid Off' ? '#10b981' : '#EBC351' }}>{loan.status}</Text></Text>
                    </View>
                    <View style={{ alignItems: 'flex-end' }}>
                      <Text style={{ color: '#fff', fontWeight: '900', fontSize: 20 }}>${(loan.principalAmount || 0).toLocaleString()}</Text>
                      <Text style={{ color: 'rgba(255,255,255,0.35)', fontSize: 9, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 1 }}>Loan Amount</Text>
                    </View>
                  </View>
                  <View style={{ flexDirection: 'row', gap: 16, marginBottom: 16 }}>
                    {[['Loan Date', loan.startDate || '—'], ['Interest', `$${(amort?.totalInterest || 0).toLocaleString(undefined, { maximumFractionDigits: 0 })}`], ['Total', `$${((loan.principalAmount || 0) + (amort?.totalInterest || 0)).toLocaleString(undefined, { maximumFractionDigits: 0 })}`]].map(([label, val]) => (
                      <View key={label} style={{ flex: 1 }}>
                        <Text style={{ color: 'rgba(255,255,255,0.35)', fontSize: 9, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 1, marginBottom: 2 }}>{label}</Text>
                        <Text style={{ color: '#fff', fontWeight: '900', fontSize: 12 }}>{val}</Text>
                      </View>
                    ))}
                  </View>
                  {amort && (
                    <View style={{ gap: 6 }}>
                      <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
                        <Text style={{ color: '#EBC351', fontSize: 9, fontWeight: '700', textTransform: 'uppercase' }}>Principal ${amort.totalPrincipal.toLocaleString(undefined, { maximumFractionDigits: 0 })}</Text>
                        <Text style={{ color: '#f97316', fontSize: 9, fontWeight: '700', textTransform: 'uppercase' }}>Interest ${amort.totalInterest.toLocaleString(undefined, { maximumFractionDigits: 0 })}</Text>
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
              <Text style={{ color: 'rgba(255,255,255,0.3)', fontWeight: '900', fontSize: 16 }}>Payment Methods</Text>
            </View>
            <View style={{ height: cards.length * 44 + 168, position: 'relative' }}>
              {cards.map((card, ci) => {
                const topOffset = ci * 44;
                const scale = 1 - (cards.length - 1 - ci) * 0.02;
                return (
                  <TouchableOpacity key={card.id} onPress={() => setEditingCard(card)}
                    style={{ position: 'absolute', left: 0, right: 0, top: topOffset, zIndex: ci, transform: [{ scale }] }} activeOpacity={0.85}>
                    <CardVisual card={card} />
                  </TouchableOpacity>
                );
              })}
            </View>
          </View>
        )}
      </ScrollView>

      {/* ── Modals ── */}
      {editingInst && (
        <EditBankModal
          inst={editingInst}
          loans={loans}
          cards={cards}
          onSave={updated => {
            if (updated.id) handleUpdateInstitution(updated.id, updated);
            else handleAddInstitution({ ...updated, companyId: selectedCompanyId! });
            setEditingInst(null);
          }}
          onDelete={() => { if (editingInst.id) handleDeleteInstitution(editingInst.id); setEditingInst(null); }}
          onClose={() => setEditingInst(null)}
          onAddCard={c => handleAddFinancialCard({ ...c, companyId: selectedCompanyId! })}
          onUpdateCard={(id, c) => handleUpdateFinancialCard(id, c)}
          onDeleteCard={id => handleDeleteFinancialCard(id)}
          onAddLoan={l => handleAddLoan({ ...l, companyId: selectedCompanyId! })}
          companyId={selectedCompanyId!}
        />
      )}
      {editingCard && (
        <EditCardModal
          card={editingCard}
          onSave={updated => {
            if (updated.id) handleUpdateFinancialCard(updated.id, updated);
            else handleAddFinancialCard({ ...updated, companyId: selectedCompanyId });
            setEditingCard(null);
          }}
          onDelete={() => { if (editingCard.id) handleDeleteFinancialCard(editingCard.id); setEditingCard(null); }}
          onClose={() => setEditingCard(null)}
        />
      )}
      {editingLoan && (
        <EditLoanModal
          loan={editingLoan}
          onSave={updated => {
            if ((updated as any).id) handleUpdateLoan((updated as any).id, updated);
            else handleAddLoan({ ...updated, companyId: selectedCompanyId });
            setEditingLoan(null);
          }}
          onDelete={() => { if ((editingLoan as any).id) handleDeleteLoan((editingLoan as any).id); setEditingLoan(null); }}
          onClose={() => setEditingLoan(null)}
        />
      )}
    </SafeAreaView>
  );
}
