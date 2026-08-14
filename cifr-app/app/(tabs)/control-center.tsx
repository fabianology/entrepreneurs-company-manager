import React, { useState, useRef, useEffect } from 'react';
import {
  View, Text, TouchableOpacity, Modal, TextInput,
  ScrollView, KeyboardAvoidingView, Platform, Pressable, Alert, Clipboard
} from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { useAppContext } from '../../context/AppContext';
import { FinancialCard, Loan, Institution, Subscription, SubService, LinkedEmail, InstitutionAccount } from '../../types';
import ControlCenterView from '../../components/ControlCenter/ControlCenterView';
import { getFaviconUrl } from '../../services/logoService';

const genId = () => Math.random().toString(36).substr(2, 9);

// ─── Amortization calculator (copied from financials.tsx) ──────────
const fmt = (n: number) =>
  '$' + (n || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });

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

// ─── Card colors (copied from financials.tsx) ──────────
const brandColors: Record<string, [string, string]> = {
  chase: ['#1a3f8f', '#0a1f5f'], 'bank of america': ['#8f1a1a', '#5f0a0a'],
  bofa: ['#8f1a1a', '#5f0a0a'], 'wells fargo': ['#8f1a1a', '#5f0a0a'],
  citi: ['#1a6a8f', '#0a1f5f'], 'capital one': ['#8f1a1a', '#1a1a8f'],
  'american express': ['#1a7a8a', '#0a1f8f'], amex: ['#1a7a8a', '#0a1f8f'],
  discover: ['#b85000', '#5f2a00'], mercury: ['#1a3a8f', '#0a1050'],
  stripe: ['#3a1a8f', '#1f0a5f'], ramp: ['#3a7a00', '#1a5000'],
};
const fallbackColors: [string, string][] = [
  ['#1a5f4a', '#0a2f24'], ['#5f1a5f', '#2f0a2f'],
  ['#1a4a8f', '#0a245f'], ['#7a1a3a', '#3f0a1f'],
  ['#1a7a3a', '#0a3f20'], ['#6a4a00', '#3a2a00'],
];
const getCardColors = (card: Partial<FinancialCard>): [string, string] => {
  const name = ((card as any).institutionName || (card as any).network || '').trim().toLowerCase();
  const match = Object.keys(brandColors).find(k => name.includes(k));
  if (match) return brandColors[match];
  let hash = 0;
  for (let i = 0; i < name.length; i++) hash = name.charCodeAt(i) + ((hash << 5) - hash);
  return fallbackColors[Math.abs(hash) % fallbackColors.length];
};

// ─── Field components (copied from financials.tsx) ──────────
function Field({ label, value, placeholder, onChangeText, multiline = false, keyboardType = 'default', mono = false }: {
  label: string; value: string; placeholder?: string;
  onChangeText: (t: string) => void; multiline?: boolean;
  keyboardType?: any; mono?: boolean;
}) {
  return (
    <View style={{ marginBottom: 12 }}>
      <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 12, fontWeight: '500', letterSpacing: 0, marginBottom: 4, marginLeft: 2 }}>{label}</Text>
      <TextInput
        style={{ backgroundColor: 'rgba(0,0,0,0.3)', borderWidth: 1, borderColor: 'rgba(255,255,255,0.06)', borderRadius: 10, paddingHorizontal: 12, paddingVertical: 10, color: '#fff', fontSize: 13, fontWeight: '500', fontFamily: mono ? 'monospace' : undefined }}
        value={value} placeholder={placeholder}
        placeholderTextColor="rgba(255,255,255,0.2)"
        onChangeText={onChangeText} multiline={multiline}
        numberOfLines={multiline ? 3 : 1} keyboardType={keyboardType}
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
      <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 12, fontWeight: '500', letterSpacing: 0, marginBottom: 4, marginLeft: 2 }}>{label}</Text>
      <TouchableOpacity onPress={() => setOpen(true)} style={{ backgroundColor: 'rgba(0,0,0,0.3)', borderWidth: 1, borderColor: 'rgba(255,255,255,0.06)', borderRadius: 10, paddingHorizontal: 12, paddingVertical: 10, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
        <Text style={{ color: '#fff', fontSize: 13, fontWeight: '500' }}>{cur?.label || 'Select...'}</Text>
        <Ionicons name="chevron-down" size={14} color="rgba(255,255,255,0.3)" />
      </TouchableOpacity>
      <Modal visible={open} transparent animationType="fade">
        <Pressable style={{ flex: 1, backgroundColor: 'rgba(0,0,0,0.6)' }} onPress={() => setOpen(false)}>
          <View style={{ position: 'absolute', bottom: 0, left: 0, right: 0, backgroundColor: '#1C1C1E', borderTopLeftRadius: 24, borderTopRightRadius: 24, padding: 16, paddingBottom: 32 }}>
            <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 12, fontWeight: '500', letterSpacing: 0, textAlign: 'center', marginBottom: 12 }}>{label}</Text>
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

// ─── Card Visual (copied from financials.tsx) ──────────
function CardVisual({ card, width = 280 }: { card: Partial<FinancialCard>; width?: number }) {
  const [from, to] = getCardColors(card);
  const h = width * 0.6;
  return (
    <View style={{ width, height: h, borderRadius: 16, overflow: 'hidden', backgroundColor: from, shadowColor: '#000', shadowOpacity: 0.6, shadowRadius: 12, elevation: 8 }}>
      <View style={{ backgroundColor: to, position: 'absolute', bottom: 0, right: 0, width: '70%', height: '70%', borderTopLeftRadius: 80, opacity: 0.6 }} />
      <View style={{ flex: 1, padding: 18, justifyContent: 'space-between' }}>
        <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <View style={{ flex: 1, paddingRight: 12 }}>
            <Text style={{ color: '#fff', fontWeight: '700', fontSize: 13, letterSpacing: 0.5 }} numberOfLines={1}>{(card as any).name}</Text>
            <Text style={{ color: 'rgba(255,255,255,0.6)', fontSize: 11, fontWeight: '500', marginTop: 2 }} numberOfLines={1}>{(card as any).cardHolder || 'Name on Card'}</Text>
          </View>
          <Text style={{ color: 'rgba(255,255,255,0.8)', fontWeight: '600', fontSize: 14, fontStyle: 'italic' }}>{(card as any).network}</Text>
        </View>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
          <View style={{ width: 36, height: 26, backgroundColor: 'rgba(255,215,80,0.2)', borderRadius: 4, borderWidth: 1, borderColor: 'rgba(255,215,80,0.3)', alignItems: 'center', justifyContent: 'center' }}>
            <View style={{ width: 22, height: 16, borderRadius: 2, borderWidth: 1, borderColor: 'rgba(255,215,80,0.4)' }} />
          </View>
          <Text style={{ color: 'rgba(255,255,255,0.85)', fontSize: 15, fontFamily: 'monospace', letterSpacing: 3 }}>•••• •••• •••• {(card as any).last4}</Text>
        </View>
        <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-end' }}>
          <View>
            <Text style={{ color: 'rgba(255,255,255,0.5)', fontSize: 11, fontWeight: '500', marginBottom: 2 }}>Name on Card</Text>
            <Text style={{ color: '#fff', fontWeight: '600', fontSize: 11 }}>{(card as any).cardHolder || '—'}</Text>
          </View>
          <View style={{ alignItems: 'flex-end' }}>
            <Text style={{ color: 'rgba(255,255,255,0.5)', fontSize: 11, fontWeight: '500', marginBottom: 2 }}>Expires</Text>
            <Text style={{ color: '#fff', fontWeight: '700', fontSize: 11, fontFamily: 'monospace' }}>{(card as any).expiry || '—'}</Text>
          </View>
        </View>
      </View>
    </View>
  );
}

// ─── Paid From Picker (copied from subscriptions.tsx) ──────────
const PAYABLE_ACCOUNT_TYPES = new Set(['Checking', 'Savings', 'Credit Card', 'Debit Card', 'Debit (Linked)']);
function getLinkedAccountOptions(state: any, companyId: string | null): { label: string; sublabel: string; icon: string }[] {
  if (!state || !companyId) return [];
  const options: { label: string; sublabel: string; icon: string }[] = [];
  const seen = new Set<string>();
  (state.institutions || []).filter((inst: any) => inst.companyId === companyId).forEach((inst: any) => {
    (inst.accounts || []).filter((acc: any) => PAYABLE_ACCOUNT_TYPES.has(acc.type)).forEach((acc: any) => {
      const isCard = acc.type === 'Credit Card' || acc.type === 'Debit Card' || acc.type === 'Debit (Linked)';
      const networkPrefix = acc.network ? `${acc.network} ` : '';
      const label = isCard ? `${networkPrefix}••${acc.last4}` : `${inst.name} ••${acc.last4}`;
      if (!seen.has(label)) { seen.add(label); options.push({ label, sublabel: isCard ? `${inst.name} · ${acc.type}` : acc.type, icon: isCard ? '💳' : '🏦' }); }
    });
  });
  (state.financialCards || []).filter((c: any) => c.companyId === companyId && c.status === 'Active').forEach((c: any) => {
    const networkPrefix = c.network ? `${c.network} ` : '';
    const label = `${networkPrefix}••${c.last4}`;
    if (!seen.has(label)) { seen.add(label); options.push({ label, sublabel: `${c.institutionName || c.name} · ${c.type} Card`, icon: '💳' }); }
  });
  return options;
}

function PaidFromPicker({ visible, onClose, onSelect, currentValue, state, companyId }: {
  visible: boolean; onClose: () => void; onSelect: (value: string) => void;
  currentValue: string; state: any; companyId: string | null;
}) {
  const [customText, setCustomText] = React.useState('');
  const options = getLinkedAccountOptions(state, companyId);
  React.useEffect(() => { if (!visible) setCustomText(''); }, [visible]);
  const commit = (value: string) => { onSelect(value); onClose(); };
  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <Pressable style={{ flex: 1, backgroundColor: 'rgba(0,0,0,0.55)' }} onPress={onClose}>
        <Pressable onPress={() => {}} style={{ position: 'absolute', bottom: 0, left: 0, right: 0, backgroundColor: '#1C1C1E', borderTopLeftRadius: 28, borderTopRightRadius: 28, borderTopWidth: 1, borderColor: 'rgba(255,255,255,0.1)', paddingBottom: 48 }}>
          <View style={{ alignItems: 'center', paddingTop: 12, paddingBottom: 20 }}><View style={{ width: 36, height: 4, borderRadius: 2, backgroundColor: 'rgba(255,255,255,0.2)' }} /></View>
          <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20, marginBottom: 20 }}>
            <Text style={{ color: '#fff', fontWeight: '700', fontSize: 17 }}>Paid From</Text>
            {!!currentValue && <TouchableOpacity onPress={() => commit('')}><Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 14 }}>Clear</Text></TouchableOpacity>}
          </View>
          {options.length > 0 && (
            <View style={{ paddingHorizontal: 20, marginBottom: 16 }}>
              {options.map(o => (
                <TouchableOpacity key={o.label} onPress={() => commit(o.label)} style={{ flexDirection: 'row', alignItems: 'center', paddingVertical: 14, paddingHorizontal: 12, borderRadius: 16, backgroundColor: currentValue === o.label ? 'rgba(235,195,81,0.1)' : 'transparent', marginBottom: 2 }}>
                  <Text style={{ fontSize: 18, marginRight: 12 }}>{o.icon}</Text>
                  <View style={{ flex: 1 }}>
                    <Text style={{ color: currentValue === o.label ? '#EBC351' : '#fff', fontWeight: '600', fontSize: 14 }}>{o.label}</Text>
                    <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 11, fontWeight: '500' }}>{o.sublabel}</Text>
                  </View>
                  {currentValue === o.label && <Ionicons name="checkmark" size={18} color="#EBC351" />}
                </TouchableOpacity>
              ))}
            </View>
          )}
          <View style={{ paddingHorizontal: 20 }}>
            <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 12, fontWeight: '500', marginBottom: 6, marginLeft: 4 }}>Custom</Text>
            <View style={{ flexDirection: 'row', gap: 8 }}>
              <TextInput style={{ flex: 1, backgroundColor: 'rgba(0,0,0,0.3)', borderWidth: 1, borderColor: 'rgba(255,255,255,0.06)', borderRadius: 10, paddingHorizontal: 12, paddingVertical: 10, color: '#fff', fontSize: 13, fontWeight: '500' }} value={customText} placeholder="Type account..." placeholderTextColor="rgba(255,255,255,0.2)" onChangeText={setCustomText} />
              <TouchableOpacity onPress={() => { if (customText.trim()) commit(customText.trim()); }} style={{ backgroundColor: '#EBC351', borderRadius: 10, paddingHorizontal: 16, justifyContent: 'center' }}>
                <Text style={{ color: '#000', fontWeight: '600', fontSize: 13 }}>Set</Text>
              </TouchableOpacity>
            </View>
          </View>
        </Pressable>
      </Pressable>
    </Modal>
  );
}

// ─────────────────────── Edit Bank Modal ───────────────────────
function EditBankModal({ inst, loans, cards, onSave, onDelete, onClose, onAddCard, onUpdateCard, onDeleteCard, onAddLoan, companyId }: {
  inst: Partial<Institution>; loans: Loan[]; cards: FinancialCard[];
  onSave: (updated: Partial<Institution>) => void;
  onDelete: () => void; onClose: () => void;
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
    setData(d => { const accs = [...(d.accounts || [])]; accs[idx] = { ...accs[idx], ...updates }; return { ...d, accounts: accs }; });
  };
  const deleteAcc = (idx: number) => { setData(d => ({ ...d, accounts: (d.accounts || []).filter((_, i) => i !== idx) })); setConfirmDeleteAcc(null); };

  const instLoans = loans.filter(l => l.lender?.toLowerCase() === (data.name || '').toLowerCase());

  const handleSave = () => {
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
      if (exists) onUpdateCard(acc.id, cardData); else onAddCard(cardData);
    });
    if (inst.id) {
      const original = inst.accounts || [];
      const newIds = accs.map(a => a.id);
      original.filter(a => cardTypes.includes(a.type) && !newIds.includes(a.id)).forEach(a => onDeleteCard(a.id));
    }
    onSave(data);
  };

  return (
    <Modal visible animationType="slide" transparent onRequestClose={onClose}>
      <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={{ flex: 1 }}>
        <View style={{ flex: 1, backgroundColor: 'rgba(0,0,0,0.7)', justifyContent: 'flex-end' }}>
          <View style={{ backgroundColor: '#1C1C1E', borderTopLeftRadius: 28, borderTopRightRadius: 28, maxHeight: '92%', borderWidth: 1, borderColor: 'rgba(255,255,255,0.1)' }}>
            <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20, paddingVertical: 16, borderBottomWidth: 1, borderBottomColor: 'rgba(255,255,255,0.05)' }}>
              <Text style={{ color: '#fff', fontWeight: '600', fontSize: 20 }}>{inst.id ? 'Edit Bank' : 'Add Bank'}</Text>
              <TouchableOpacity onPress={onClose}><Ionicons name="close" size={22} color="rgba(255,255,255,0.4)" /></TouchableOpacity>
            </View>
            <ScrollView contentContainerStyle={{ padding: 20, paddingBottom: insets.bottom + 100 }}>
              <View style={{ flexDirection: 'row', gap: 12 }}>
                <View style={{ flex: 1 }}><Field label="Institution" value={data.name || ''} placeholder="Mercury" onChangeText={v => setData(d => ({ ...d, name: v }))} /></View>
                <View style={{ flex: 1 }}><Field label="Website" value={data.loginUrl || ''} placeholder="bank.com" onChangeText={v => setData(d => ({ ...d, loginUrl: v }))} /></View>
              </View>
              <View style={{ flexDirection: 'row', gap: 12 }}>
                <View style={{ flex: 1 }}><Field label="Login ID" value={data.username || ''} placeholder="user_admin" onChangeText={v => setData(d => ({ ...d, username: v }))} /></View>
                <View style={{ flex: 1 }}><Field label="Password" value={data.password || ''} placeholder="••••••" onChangeText={v => setData(d => ({ ...d, password: v }))} /></View>
              </View>
              <View style={{ height: 1, backgroundColor: 'rgba(255,255,255,0.05)', marginVertical: 16 }} />
              <TouchableOpacity onPress={() => addAccount('Credit Card')} style={{ backgroundColor: '#1C1C1E', borderWidth: 1, borderColor: 'rgba(255,255,255,0.08)', borderRadius: 12, height: 56, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 10, marginBottom: 8 }}>
                <Text style={{ fontSize: 20 }}>💳</Text>
                <Text style={{ color: 'rgba(255,255,255,0.6)', fontWeight: '500', fontSize: 15 }}>Add Card</Text>
              </TouchableOpacity>
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
                            <TouchableOpacity onPress={() => deleteAcc(idx)} style={{ backgroundColor: 'rgba(239,68,68,0.2)', paddingHorizontal: 10, paddingVertical: 4, borderRadius: 6 }}><Text style={{ color: '#ef4444', fontWeight: '600', fontSize: 13 }}>Delete</Text></TouchableOpacity>
                            <TouchableOpacity onPress={() => setConfirmDeleteAcc(null)} style={{ paddingHorizontal: 10, paddingVertical: 4 }}><Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 13, fontWeight: '500' }}>Cancel</Text></TouchableOpacity>
                          </View>
                        ) : (
                          <TouchableOpacity onPress={() => setConfirmDeleteAcc(idx)}><Ionicons name="close" size={16} color="rgba(255,255,255,0.2)" /></TouchableOpacity>
                        )}
                        <Text style={{ color: '#fff', fontSize: 13, fontWeight: '500' }}>{acc.name || 'New Card'}</Text>
                        <Text style={{ color: 'rgba(255,255,255,0.3)', fontSize: 11, fontFamily: 'monospace' }}>•••• {acc.last4 || '••••'}</Text>
                        <View style={{ width: 6, height: 6, borderRadius: 3, backgroundColor: (acc as any).status === 'Frozen' ? '#EBC351' : (acc as any).status === 'Expired' ? '#ef4444' : '#1FE400' }} />
                      </View>
                      <Ionicons name={expanded ? 'chevron-up' : 'chevron-down'} size={14} color="rgba(255,255,255,0.3)" />
                    </TouchableOpacity>
                    {expanded && (
                      <View style={{ padding: 14, borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.05)' }}>
                        <View style={{ flexDirection: 'row', gap: 10 }}>
                          <View style={{ flex: 1 }}><Field label="Card Nickname" value={acc.name} placeholder="Chase Sapphire" onChangeText={v => updateAcc(idx, { name: v })} /></View>
                          <View style={{ flex: 1 }}><SelectField label="Type" value={acc.type} options={cardTypes.map(t => ({ label: t, value: t }))} onChange={v => updateAcc(idx, { type: v as any })} /></View>
                        </View>
                        <View style={{ flexDirection: 'row', gap: 10 }}>
                          <View style={{ flex: 1 }}><Field label="LAST 4" value={acc.last4} placeholder="1234" onChangeText={v => updateAcc(idx, { last4: v.replace(/\D/g, '').slice(0, 4) })} mono keyboardType="numeric" /></View>
                          <View style={{ flex: 1 }}>
                            <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 11, fontWeight: '500', marginBottom: 4, marginLeft: 2 }}>Expiry</Text>
                            <TextInput style={{ backgroundColor: 'rgba(0,0,0,0.3)', borderWidth: 1, borderColor: 'rgba(255,255,255,0.06)', borderRadius: 10, paddingHorizontal: 12, paddingVertical: 10, color: '#fff', fontSize: 13, fontFamily: 'monospace' }}
                              value={(acc as any).expiry || ''} placeholder="MM/YY" placeholderTextColor="rgba(255,255,255,0.2)" maxLength={5} keyboardType="numeric"
                              onChangeText={v => { let val = v.replace(/\D/g, ''); if (val.length > 2) val = val.slice(0, 2) + '/' + val.slice(2, 4); updateAcc(idx, { expiry: val } as any); }} />
                          </View>
                        </View>
                        <View style={{ flexDirection: 'row', gap: 10 }}>
                          <View style={{ flex: 1 }}><Field label="Name on Card" value={(acc as any).cardHolder || ''} placeholder="Jane Doe" onChangeText={v => updateAcc(idx, { cardHolder: v } as any)} /></View>
                          <View style={{ flex: 1 }}><SelectField label="Status" value={(acc as any).status || 'Active'} options={[{ label: 'Active', value: 'Active' }, { label: 'Frozen', value: 'Frozen' }, { label: 'Expired', value: 'Expired' }]} onChange={v => updateAcc(idx, { status: v as any })} /></View>
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
              <View style={{ height: 1, backgroundColor: 'rgba(255,255,255,0.05)', marginVertical: 16 }} />
              <TouchableOpacity onPress={() => addAccount('Checking')} style={{ backgroundColor: '#1C1C1E', borderWidth: 1, borderColor: 'rgba(255,255,255,0.08)', borderRadius: 12, height: 56, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 10, marginBottom: 8 }}>
                <Text style={{ fontSize: 20 }}>🏦</Text>
                <Text style={{ color: 'rgba(255,255,255,0.6)', fontWeight: '500', fontSize: 15 }}>Add Account</Text>
              </TouchableOpacity>
              {(data.accounts || []).filter(a => !cardTypes.includes(a.type)).map((acc, i) => {
                const idx = (data.accounts || []).indexOf(acc);
                return (
                  <View key={`acc-${i}`} style={{ backgroundColor: 'rgba(0,0,0,0.25)', borderRadius: 12, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', padding: 14, marginBottom: 8, position: 'relative' }}>
                    <TouchableOpacity onPress={() => setConfirmDeleteAcc(idx)} style={{ position: 'absolute', top: 10, right: 10, zIndex: 1 }}><Ionicons name="close" size={14} color="rgba(255,255,255,0.2)" /></TouchableOpacity>
                    {confirmDeleteAcc === idx && (
                      <View style={{ flexDirection: 'row', gap: 8, marginBottom: 10 }}>
                        <TouchableOpacity onPress={() => deleteAcc(idx)} style={{ backgroundColor: 'rgba(239,68,68,0.2)', paddingHorizontal: 12, paddingVertical: 6, borderRadius: 8 }}><Text style={{ color: '#ef4444', fontWeight: '600', fontSize: 13 }}>Delete</Text></TouchableOpacity>
                        <TouchableOpacity onPress={() => setConfirmDeleteAcc(null)} style={{ paddingHorizontal: 12, paddingVertical: 6 }}><Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 13, fontWeight: '500' }}>Cancel</Text></TouchableOpacity>
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
              <View style={{ height: 1, backgroundColor: 'rgba(255,255,255,0.05)', marginVertical: 16 }} />
              <TouchableOpacity onPress={() => setShowLoanModal(true)} style={{ backgroundColor: '#1C1C1E', borderWidth: 1, borderColor: 'rgba(255,255,255,0.08)', borderRadius: 12, height: 56, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 10, marginBottom: 8 }}>
                <Text style={{ fontSize: 20 }}>💸</Text>
                <Text style={{ color: 'rgba(255,255,255,0.6)', fontWeight: '500', fontSize: 15 }}>Add Loan</Text>
              </TouchableOpacity>
              {instLoans.map(loan => {
                const amort = calcAmortization(loan);
                return (
                  <View key={loan.id} style={{ backgroundColor: 'rgba(0,0,0,0.25)', borderRadius: 12, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', padding: 14, marginBottom: 8 }}>
                    <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginBottom: 10 }}>
                      <View><Text style={{ color: '#fff', fontWeight: '700', fontSize: 13 }}>{loan.name}</Text><Text style={{ color: loan.status === 'Paid Off' ? '#10b981' : '#EBC351', fontSize: 11, fontWeight: '600', textTransform: 'uppercase' }}>{loan.status}</Text></View>
                      <View style={{ alignItems: 'flex-end' }}><Text style={{ color: '#fff', fontWeight: '700', fontSize: 13 }}>${(loan.principalAmount || 0).toLocaleString()}</Text><Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 11, fontWeight: '500' }}>Loan Amount</Text></View>
                    </View>
                    {amort && (
                      <View style={{ gap: 4 }}>
                        <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
                          <Text style={{ color: '#EBC351', fontSize: 11, fontWeight: '600' }}>Principal {amort.principalPct.toFixed(0)}%</Text>
                          <Text style={{ color: '#f97316', fontSize: 11, fontWeight: '600' }}>Interest {amort.interestPct.toFixed(0)}%</Text>
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
            <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 20, paddingVertical: 14, borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.05)', backgroundColor: 'rgba(0,0,0,0.2)', paddingBottom: insets.bottom + 14 }}>
              {inst.id ? (
                showDelete ? (
                  <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, backgroundColor: 'rgba(249,115,22,0.1)', borderRadius: 12, borderWidth: 1, borderColor: 'rgba(249,115,22,0.3)', paddingHorizontal: 12, paddingVertical: 8 }}>
                    <Text style={{ color: '#f97316', fontSize: 12, fontWeight: '600' }}>Confirm?</Text>
                    <TouchableOpacity onPress={onDelete} style={{ paddingHorizontal: 12, paddingVertical: 6, backgroundColor: 'rgba(0,0,0,0.4)', borderRadius: 8 }}><Text style={{ color: '#fff', fontWeight: '600', fontSize: 13 }}>Yes</Text></TouchableOpacity>
                    <TouchableOpacity onPress={() => setShowDelete(false)} style={{ paddingHorizontal: 12, paddingVertical: 6 }}><Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 13, fontWeight: '500' }}>No</Text></TouchableOpacity>
                  </View>
                ) : (
                  <TouchableOpacity onPress={() => setShowDelete(true)} style={{ padding: 10 }}><Ionicons name="trash-outline" size={20} color="rgba(255,255,255,0.2)" /></TouchableOpacity>
                )
              ) : <View />}
              <View style={{ flexDirection: 'row', gap: 12, alignItems: 'center' }}>
                <TouchableOpacity onPress={onClose}><Text style={{ color: 'rgba(255,255,255,0.4)', fontWeight: '500', fontSize: 15 }}>Cancel</Text></TouchableOpacity>
                <TouchableOpacity onPress={handleSave} style={{ backgroundColor: '#f97316', borderRadius: 10, paddingHorizontal: 24, paddingVertical: 10 }}><Text style={{ color: '#fff', fontWeight: '600', fontSize: 15 }}>Save Bank</Text></TouchableOpacity>
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
  card: Partial<FinancialCard>; onSave: (c: Partial<FinancialCard>) => void; onDelete: () => void; onClose: () => void;
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
              <Text style={{ color: '#fff', fontWeight: '600', fontSize: 20 }}>{card.id ? 'Edit Card Details' : 'Add New Card'}</Text>
              <TouchableOpacity onPress={onClose} style={{ padding: 4 }}><Ionicons name="close" size={20} color="rgba(255,255,255,0.4)" /></TouchableOpacity>
            </View>
            <ScrollView contentContainerStyle={{ padding: 20, paddingBottom: insets.bottom + 80 }}>
              {(data.last4 || data.name) && <View style={{ alignItems: 'center', marginBottom: 20 }}><CardVisual card={data as FinancialCard} /></View>}
              <Field label="Card Nickname" value={data.name || ''} placeholder="Amex Gold" onChangeText={v => setData(d => ({ ...d, name: v }))} />
              <View style={{ flexDirection: 'row', gap: 12 }}>
                <View style={{ flex: 1 }}><Field label="Institution Name" value={data.institutionName || ''} placeholder="Chase" onChangeText={v => setData(d => ({ ...d, institutionName: v }))} /></View>
                <View style={{ flex: 1 }}><SelectField label="Type" value={data.type || 'Credit'} options={[{ label: 'Credit', value: 'Credit' }, { label: 'Debit', value: 'Debit' }]} onChange={v => setData(d => ({ ...d, type: v as any }))} /></View>
              </View>
              <View style={{ flexDirection: 'row', gap: 12 }}>
                <View style={{ flex: 1 }}><Field label="Login" value={(data as any).login || ''} placeholder="username" onChangeText={v => setData(d => ({ ...d, login: v }))} /></View>
                <View style={{ flex: 1 }}><Field label="Password" value={(data as any).password || ''} placeholder="••••••" onChangeText={v => setData(d => ({ ...d, password: v }))} /></View>
              </View>
              <View style={{ flexDirection: 'row', gap: 12 }}>
                <View style={{ flex: 2 }}>
                  <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 12, fontWeight: '500', marginBottom: 4, marginLeft: 2 }}>Card Number (Last 4)</Text>
                  <View style={{ position: 'relative' }}>
                    <Text style={{ position: 'absolute', left: 12, top: 10, color: 'rgba(255,255,255,0.2)', fontFamily: 'monospace', fontSize: 13, zIndex: 1 }}>•••• •••• •••• </Text>
                    <TextInput style={{ backgroundColor: 'rgba(0,0,0,0.3)', borderWidth: 1, borderColor: 'rgba(255,255,255,0.06)', borderRadius: 10, paddingLeft: 128, paddingRight: 12, paddingVertical: 10, color: '#fff', fontSize: 13, fontFamily: 'monospace' }}
                      maxLength={4} keyboardType="numeric" value={data.last4 || ''} placeholder="1234" placeholderTextColor="rgba(255,255,255,0.2)"
                      onChangeText={v => setData(d => ({ ...d, last4: v.replace(/\D/g, '') }))} />
                  </View>
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 12, fontWeight: '500', marginBottom: 4, marginLeft: 2 }}>Expiry</Text>
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
              {card.id ? (showDelete ? (
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, backgroundColor: 'rgba(249,115,22,0.1)', borderRadius: 12, borderWidth: 1, borderColor: 'rgba(249,115,22,0.3)', paddingHorizontal: 12, paddingVertical: 8 }}>
                  <Text style={{ color: '#f97316', fontSize: 12, fontWeight: '600' }}>Confirm?</Text>
                  <TouchableOpacity onPress={onDelete} style={{ paddingHorizontal: 12, paddingVertical: 6, backgroundColor: 'rgba(0,0,0,0.4)', borderRadius: 8 }}><Text style={{ color: '#fff', fontWeight: '600', fontSize: 13 }}>Yes</Text></TouchableOpacity>
                  <TouchableOpacity onPress={() => setShowDelete(false)} style={{ paddingHorizontal: 12, paddingVertical: 6 }}><Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 13, fontWeight: '500' }}>No</Text></TouchableOpacity>
                </View>
              ) : (
                <TouchableOpacity onPress={() => setShowDelete(true)} style={{ padding: 10 }}><Ionicons name="trash-outline" size={20} color="rgba(255,255,255,0.2)" /></TouchableOpacity>
              )) : <View />}
              <View style={{ flexDirection: 'row', gap: 12, alignItems: 'center' }}>
                <TouchableOpacity onPress={onClose}><Text style={{ color: 'rgba(255,255,255,0.4)', fontWeight: '500', fontSize: 15 }}>Cancel</Text></TouchableOpacity>
                <TouchableOpacity onPress={() => onSave(data)} style={{ backgroundColor: '#f97316', borderRadius: 10, paddingHorizontal: 24, paddingVertical: 10 }}><Text style={{ color: '#fff', fontWeight: '600', fontSize: 15 }}>Save Card</Text></TouchableOpacity>
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
  loan: Partial<Loan> & { _fromBank?: boolean }; onSave: (l: Partial<Loan>) => void; onDelete: () => void; onClose: () => void;
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
              <Text style={{ color: '#fff', fontWeight: '600', fontSize: 20 }}>{loan.id ? 'Edit Loan Details' : 'Add New Financing'}</Text>
              <TouchableOpacity onPress={onClose} style={{ padding: 4 }}><Ionicons name="close" size={20} color="rgba(255,255,255,0.4)" /></TouchableOpacity>
            </View>
            <ScrollView contentContainerStyle={{ padding: 20, paddingBottom: insets.bottom + 80 }}>
              {!data._fromBank && !data.id && (
                <View style={{ flexDirection: 'row', backgroundColor: 'rgba(0,0,0,0.4)', padding: 4, borderRadius: 24, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', marginBottom: 16, alignSelf: 'center', minWidth: 200 }}>
                  {['Lender', 'Lendee'].map(role => (
                    <TouchableOpacity key={role} onPress={() => setData((d: any) => ({ ...d, role }))}
                      style={{ flex: 1, paddingVertical: 8, borderRadius: 20, backgroundColor: data.role === role ? '#EBC351' : 'transparent', alignItems: 'center' }}>
                      <Text style={{ color: data.role === role ? '#000' : 'rgba(255,255,255,0.4)', fontWeight: '600', fontSize: 13 }}>{role}</Text>
                    </TouchableOpacity>
                  ))}
                </View>
              )}
              <View style={{ flexDirection: 'row', gap: 12 }}>
                <View style={{ flex: 1 }}><Field label={data.role === 'Lender' ? 'Lent To' : 'Lender / Institution'} value={data.lender || ''} placeholder="Silicon Valley Bank" onChangeText={v => setData((d: any) => ({ ...d, lender: v }))} /></View>
                <View style={{ flex: 1 }}><Field label="Loan ID / Name" value={data.name || ''} placeholder="Series A Debt" onChangeText={v => setData((d: any) => ({ ...d, name: v }))} /></View>
              </View>
              <Field label="Loan Summary" value={data.term || ''} placeholder="36 Months notes..." onChangeText={v => setData((d: any) => ({ ...d, term: v }))} multiline />
              <View style={{ flexDirection: 'row', gap: 12 }}>
                <View style={{ flex: 1 }}>
                  <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 12, fontWeight: '500', marginBottom: 4, marginLeft: 2 }}>Loan Date</Text>
                  <TextInput style={{ backgroundColor: 'rgba(0,0,0,0.3)', borderWidth: 1, borderColor: 'rgba(255,255,255,0.06)', borderRadius: 10, paddingHorizontal: 12, paddingVertical: 10, color: '#fff', fontSize: 13 }}
                    value={data.startDate || ''} placeholder="YYYY-MM-DD" placeholderTextColor="rgba(255,255,255,0.2)" onChangeText={v => setData((d: any) => ({ ...d, startDate: v }))} />
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 12, fontWeight: '500', marginBottom: 4, marginLeft: 2 }}>Paid Off Date</Text>
                  <TextInput style={{ backgroundColor: 'rgba(0,0,0,0.3)', borderWidth: 1, borderColor: 'rgba(255,255,255,0.06)', borderRadius: 10, paddingHorizontal: 12, paddingVertical: 10, color: '#fff', fontSize: 13 }}
                    value={data.paidOffDate || ''} placeholder="YYYY-MM-DD" placeholderTextColor="rgba(255,255,255,0.2)" onChangeText={v => setData((d: any) => ({ ...d, paidOffDate: v }))} />
                </View>
              </View>
              <View style={{ flexDirection: 'row', gap: 12, alignItems: 'flex-end', marginBottom: 12 }}>
                <View style={{ flex: 1 }}>
                  <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 12, fontWeight: '500', marginBottom: 4, marginLeft: 2 }}>Loan Amount $</Text>
                  <TextInput style={{ backgroundColor: 'rgba(0,0,0,0.3)', borderWidth: 1, borderColor: 'rgba(255,255,255,0.06)', borderRadius: 10, paddingHorizontal: 12, paddingVertical: 10, color: '#fff', fontSize: 13, fontFamily: 'monospace' }}
                    value={String(data.principalAmount || '')} placeholder="50000" placeholderTextColor="rgba(255,255,255,0.2)" keyboardType="decimal-pad"
                    onChangeText={v => setData((d: any) => ({ ...d, principalAmount: parseFloat(v) || 0 }))} />
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 12, fontWeight: '500', marginBottom: 4, marginLeft: 2 }}>{data.interestType === 'Fixed' ? 'Fixed Fee $' : 'YR APR %'}</Text>
                  <TextInput style={{ backgroundColor: 'rgba(0,0,0,0.3)', borderWidth: 1, borderColor: 'rgba(255,255,255,0.06)', borderRadius: 10, paddingHorizontal: 12, paddingVertical: 10, color: '#fff', fontSize: 13, fontFamily: 'monospace' }}
                    value={String(data.interestRate || '')} placeholder={data.interestType === 'Fixed' ? '500' : '5.5'} placeholderTextColor="rgba(255,255,255,0.2)" keyboardType="decimal-pad"
                    onChangeText={v => setData((d: any) => ({ ...d, interestRate: parseFloat(v) || 0 }))} />
                </View>
              </View>
              <View style={{ flexDirection: 'row', gap: 12, alignItems: 'flex-end', marginBottom: 12 }}>
                <View style={{ flex: 1 }}>
                  <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 12, fontWeight: '500', marginBottom: 4, marginLeft: 2 }}>Term (Yrs)</Text>
                  <TextInput style={{ backgroundColor: 'rgba(0,0,0,0.3)', borderWidth: 1, borderColor: 'rgba(255,255,255,0.06)', borderRadius: 10, paddingHorizontal: 12, paddingVertical: 10, color: '#fff', fontSize: 13, fontFamily: 'monospace' }}
                    value={String(data.termYears || '')} placeholder="5" placeholderTextColor="rgba(255,255,255,0.2)" keyboardType="number-pad"
                    onChangeText={v => setData((d: any) => ({ ...d, termYears: parseInt(v) || 0 }))} />
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 12, fontWeight: '500', marginBottom: 4, marginLeft: 2 }}>Term (Mos)</Text>
                  <TextInput style={{ backgroundColor: 'rgba(0,0,0,0.3)', borderWidth: 1, borderColor: 'rgba(255,255,255,0.06)', borderRadius: 10, paddingHorizontal: 12, paddingVertical: 10, color: '#fff', fontSize: 13, fontFamily: 'monospace' }}
                    value={String(data.termMonths || '')} placeholder="0" placeholderTextColor="rgba(255,255,255,0.2)" keyboardType="number-pad"
                    onChangeText={v => setData((d: any) => ({ ...d, termMonths: parseInt(v) || 0 }))} />
                </View>
                <View style={{ flex: 1 }}><SelectField label="Frequency" value={data.scheduleFrequency || 'Monthly'} options={[{ label: 'Weekly', value: 'Weekly' }, { label: 'Monthly', value: 'Monthly' }, { label: 'Yearly', value: 'Yearly' }]} onChange={v => setData((d: any) => ({ ...d, scheduleFrequency: v }))} /></View>
              </View>
              <View style={{ marginBottom: 16 }}>
                <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 12, fontWeight: '500', marginBottom: 6, marginLeft: 2 }}>Interest Type</Text>
                <View style={{ flexDirection: 'row', backgroundColor: 'rgba(0,0,0,0.4)', padding: 4, borderRadius: 12, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)' }}>
                  {[{ label: 'Interest %', value: 'Percentage' }, { label: 'Fixed Fee', value: 'Fixed' }].map(opt => (
                    <TouchableOpacity key={opt.value} onPress={() => setData((d: any) => ({ ...d, interestType: opt.value }))}
                      style={{ flex: 1, paddingVertical: 8, borderRadius: 8, backgroundColor: (data.interestType || 'Percentage') === opt.value ? '#EBC351' : 'transparent', alignItems: 'center' }}>
                      <Text style={{ color: (data.interestType || 'Percentage') === opt.value ? '#000' : 'rgba(255,255,255,0.4)', fontWeight: '600', fontSize: 13 }}>{opt.label}</Text>
                    </TouchableOpacity>
                  ))}
                </View>
              </View>
              {amort && (
                <View style={{ backgroundColor: 'rgba(0,0,0,0.25)', borderRadius: 14, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', padding: 16, marginTop: 8 }}>
                  <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginBottom: 14 }}>
                    <View><Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 11, fontWeight: '500' }}>{amort.scheduleFrequency} Pmt</Text><Text style={{ color: '#fff', fontWeight: '700', fontSize: 20 }}>{fmt(amort.monthlyPayment)}</Text></View>
                    <View style={{ alignItems: 'center' }}><Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 11, fontWeight: '500' }}>Total Int.</Text><Text style={{ color: '#fff', fontWeight: '700', fontSize: 14 }}>{fmt(amort.totalInterest)}</Text></View>
                    <View style={{ alignItems: 'flex-end' }}><Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 11, fontWeight: '500' }}>Total Cost</Text><Text style={{ color: '#fff', fontWeight: '700', fontSize: 14 }}>{fmt(amort.totalCost)}</Text></View>
                  </View>
                  <View style={{ gap: 4 }}>
                    <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
                      <Text style={{ color: '#EBC351', fontSize: 11, fontWeight: '600' }}>Principal ({amort.principalPct.toFixed(1)}%)</Text>
                      <Text style={{ color: '#f97316', fontSize: 11, fontWeight: '600' }}>Interest ({amort.interestPct.toFixed(1)}%)</Text>
                    </View>
                    <View style={{ height: 6, backgroundColor: 'rgba(0,0,0,0.4)', borderRadius: 3, flexDirection: 'row', overflow: 'hidden' }}>
                      <View style={{ flex: amort.principalPct, backgroundColor: '#EBC351', borderRadius: 3 }} />
                      <View style={{ flex: amort.interestPct, backgroundColor: '#f97316', borderRadius: 3 }} />
                    </View>
                  </View>
                  <TouchableOpacity onPress={() => setShowAmort(!showAmort)} style={{ marginTop: 14, height: 36, backgroundColor: 'rgba(0,0,0,0.2)', borderRadius: 10, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 8 }}>
                    <Text style={{ color: 'rgba(255,255,255,0.6)', fontWeight: '500', fontSize: 13 }}>{showAmort ? 'Hide Schedule' : 'Amortization Schedule'}</Text>
                    <Ionicons name={showAmort ? 'chevron-up' : 'chevron-down'} size={14} color="rgba(255,255,255,0.4)" />
                  </TouchableOpacity>
                  {showAmort && amort.schedule.length > 0 && (
                    <View style={{ marginTop: 10, borderRadius: 10, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', overflow: 'hidden' }}>
                      <View style={{ flexDirection: 'row', backgroundColor: '#1C1C1E', paddingVertical: 8, paddingHorizontal: 8 }}>
                        {[amort.scheduleFrequency === 'Weekly' ? 'Wk' : amort.scheduleFrequency === 'Yearly' ? 'Yr' : 'Mo', 'Pmt', 'Prin', 'Int', 'Bal'].map((h, i) => (
                          <Text key={h} style={{ flex: i === 0 ? 0.6 : 1, color: i === 2 ? '#EBC351' : i === 3 ? '#f97316' : 'rgba(255,255,255,0.4)', fontSize: 11, fontWeight: '500', textAlign: i === 0 ? 'left' : 'right' }}>{h}</Text>
                        ))}
                      </View>
                      <ScrollView style={{ maxHeight: 220 }} nestedScrollEnabled>
                        {amort.schedule.slice(0, 200).map((row, i) => (
                          <View key={row.month} style={{ flexDirection: 'row', paddingVertical: 6, paddingHorizontal: 8, backgroundColor: i % 2 === 0 ? 'rgba(0,0,0,0.25)' : 'transparent' }}>
                            <Text style={{ flex: 0.6, color: 'rgba(255,255,255,0.4)', fontSize: 11, fontFamily: 'monospace' }}>{row.month}</Text>
                            <Text style={{ flex: 1, color: 'rgba(255,255,255,0.8)', fontSize: 11, fontFamily: 'monospace', textAlign: 'right' }}>${row.payment.toLocaleString(undefined, { maximumFractionDigits: 0 })}</Text>
                            <Text style={{ flex: 1, color: '#EBC351', fontSize: 11, fontFamily: 'monospace', textAlign: 'right', opacity: 0.8 }}>${row.principal.toLocaleString(undefined, { maximumFractionDigits: 0 })}</Text>
                            <Text style={{ flex: 1, color: '#f97316', fontSize: 11, fontFamily: 'monospace', textAlign: 'right', opacity: 0.8 }}>${row.interest.toLocaleString(undefined, { maximumFractionDigits: 0 })}</Text>
                            <Text style={{ flex: 1, color: '#fff', fontSize: 11, fontFamily: 'monospace', textAlign: 'right' }}>${row.balance.toLocaleString(undefined, { maximumFractionDigits: 0 })}</Text>
                          </View>
                        ))}
                      </ScrollView>
                    </View>
                  )}
                </View>
              )}
            </ScrollView>
            <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 20, paddingVertical: 14, borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.05)', backgroundColor: 'rgba(0,0,0,0.2)', paddingBottom: insets.bottom + 14 }}>
              {loan.id ? (showDelete ? (
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, backgroundColor: 'rgba(249,115,22,0.1)', borderRadius: 12, borderWidth: 1, borderColor: 'rgba(249,115,22,0.3)', paddingHorizontal: 12, paddingVertical: 8 }}>
                  <Text style={{ color: '#f97316', fontSize: 12, fontWeight: '600' }}>Confirm?</Text>
                  <TouchableOpacity onPress={onDelete} style={{ paddingHorizontal: 12, paddingVertical: 6, backgroundColor: 'rgba(0,0,0,0.4)', borderRadius: 8 }}><Text style={{ color: '#fff', fontWeight: '600', fontSize: 13 }}>Yes</Text></TouchableOpacity>
                  <TouchableOpacity onPress={() => setShowDelete(false)} style={{ paddingHorizontal: 12, paddingVertical: 6 }}><Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 13, fontWeight: '500' }}>No</Text></TouchableOpacity>
                </View>
              ) : (
                <TouchableOpacity onPress={() => setShowDelete(true)} style={{ padding: 10 }}><Ionicons name="trash-outline" size={20} color="rgba(255,255,255,0.2)" /></TouchableOpacity>
              )) : <View />}
              <View style={{ flexDirection: 'row', gap: 12, alignItems: 'center' }}>
                <TouchableOpacity onPress={onClose}><Text style={{ color: 'rgba(255,255,255,0.4)', fontWeight: '500', fontSize: 15 }}>Cancel</Text></TouchableOpacity>
                <TouchableOpacity onPress={() => onSave(data)} style={{ backgroundColor: '#f97316', borderRadius: 10, paddingHorizontal: 24, paddingVertical: 10 }}><Text style={{ color: '#fff', fontWeight: '600', fontSize: 15 }}>Save Loan</Text></TouchableOpacity>
              </View>
            </View>
          </View>
        </View>
      </KeyboardAvoidingView>
    </Modal>
  );
}

// ═══════════════════════════════════════════════════════════════════
// ────────────── MAIN CONTROL CENTER TAB SCREEN ──────────────────
// ═══════════════════════════════════════════════════════════════════
export default function ControlCenterScreen() {
  const router = useRouter();
  const {
    state, selectedCompanyId,
    handleAddFinancialCard, handleUpdateFinancialCard, handleDeleteFinancialCard,
    handleAddLoan, handleUpdateLoan, handleDeleteLoan,
    handleAddInstitution, handleUpdateInstitution, handleDeleteInstitution,
    handleAddSubscription, handleUpdateSubscription, handleDeleteSubscription,
    subMetrics,
  } = useAppContext();

  // ── Financial modals ──
  const [editingCard, setEditingCard] = useState<Partial<FinancialCard> | null>(null);
  const [editingLoan, setEditingLoan] = useState<Partial<Loan> | null>(null);
  const [editingInst, setEditingInst] = useState<Partial<Institution> | null>(null);

  // ── Subscription modal ──
  const [editingSub, setEditingSub] = useState<Partial<Subscription> | null>(null);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [expandedSecurity, setExpandedSecurity] = useState(false);
  const [expandedModalSubServices, setExpandedModalSubServices] = useState<Set<string>>(new Set());
  const [expandedModalEmails, setExpandedModalEmails] = useState<Set<string>>(new Set());
  const editScrollRef = useRef<ScrollView>(null);
  const subServicesSectionY = useRef<number>(0);
  const [focusSubServiceId, setFocusSubServiceId] = useState<string | null>(null);

  // Paid-From picker
  const [showPaidFromPicker, setShowPaidFromPicker] = useState(false);
  const [paidFromCurrentValue, setPaidFromCurrentValue] = useState('');
  const [paidFromCompanyId, setPaidFromCompanyId] = useState<string | null>(null);
  const paidFromCallback = useRef<((v: string) => void) | null>(null);

  const openPaidFromPicker = (companyId: string | null, currentValue: string, cb: (v: string) => void) => {
    setPaidFromCompanyId(companyId);
    setPaidFromCurrentValue(currentValue);
    paidFromCallback.current = cb;
    setShowPaidFromPicker(true);
  };

  if (!state) return null;

  const cards = state.financialCards.filter(c => c.companyId === selectedCompanyId);
  const loans = state.loans.filter(l => l.companyId === selectedCompanyId);

  // ── Subscription helpers ──
  const toggle = (set: Set<string>, id: string): Set<string> => {
    const n = new Set(set); n.has(id) ? n.delete(id) : n.add(id); return n;
  };

  const updateSub = (updates: Partial<Subscription>) => {
    setEditingSub(prev => prev ? { ...prev, ...updates } : null);
  };

  const updateSubService = (idx: number, updates: Partial<SubService>) => {
    const newSubs = [...(editingSub?.subServices || [])];
    newSubs[idx] = { ...newSubs[idx], ...updates };
    updateSub({ subServices: newSubs });
  };

  const addSubService = () => {
    const newId = genId();
    const newSub: SubService = { id: newId, name: '', cost: 0, billingCycle: 'Monthly', purpose: '', status: 'Active', autoPay: 'Auto' };
    updateSub({ subServices: [...(editingSub?.subServices || []), newSub] });
    setExpandedModalSubServices(prev => new Set(prev).add(newId));
  };

  const removeSubService = (idx: number) => {
    updateSub({ subServices: (editingSub?.subServices || []).filter((_, i) => i !== idx) });
  };

  const addLinkedEmail = () => {
    const newId = genId();
    const newEmail: LinkedEmail = { id: newId, email: '', forwarding: '', usedFor: '', usedIn: '', accessMethod: '', notes: [] };
    updateSub({ linkedEmails: [...(editingSub?.linkedEmails || []), newEmail] });
    setExpandedModalEmails(prev => new Set(prev).add(newId));
  };

  const updateLinkedEmail = (idx: number, updates: Partial<LinkedEmail>) => {
    const list = [...(editingSub?.linkedEmails || [])];
    list[idx] = { ...list[idx], ...updates };
    updateSub({ linkedEmails: list });
  };

  const removeLinkedEmail = (idx: number) => {
    updateSub({ linkedEmails: (editingSub?.linkedEmails || []).filter((_, i) => i !== idx) });
  };

  const handleSubSave = () => {
    if (!editingSub) return;
    if (!editingSub.name?.trim()) { Alert.alert('Missing Name', 'Please enter a name.'); return; }
    const updates = { ...editingSub, lastUpdated: Date.now() };
    if (editingSub.id) handleUpdateSubscription(editingSub.id, updates);
    else handleAddSubscription(updates);
    setEditingSub(null);
  };

  const handleSubDelete = () => {
    if (!editingSub?.id) return;
    handleDeleteSubscription(editingSub.id);
    setEditingSub(null);
  };

  const openNewSub = () => {
    setShowDeleteConfirm(false);
    setExpandedSecurity(false);
    setExpandedModalSubServices(new Set());
    setExpandedModalEmails(new Set());
    setEditingSub({
      companyId: selectedCompanyId || '', name: '', cost: 0, billingCycle: 'Monthly', status: 'Active',
      paymentMethod: '', nextRenewal: '', renew: 'Auto',
      subServices: [], linkedEmails: [],
      loginId: '', password: '', twoFactorAuth: 'None',
      recoveryMethod: '', website: '', pricingModel: 'paid', notes: ''
    });
  };

  const openEditSub = (sub: Subscription) => {
    setShowDeleteConfirm(false);
    setExpandedSecurity(false);
    setExpandedModalSubServices(new Set());
    setExpandedModalEmails(new Set());
    setEditingSub({ ...sub });
  };

  // Auto-scroll to sub-services
  useEffect(() => {
    if (editingSub && focusSubServiceId) {
      const timer = setTimeout(() => editScrollRef.current?.scrollTo({ y: subServicesSectionY.current, animated: true }), 250);
      return () => clearTimeout(timer);
    }
  }, [editingSub?.id, focusSubServiceId]);

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: '#000' }}>
      <ControlCenterView
        onEditInstitution={inst => setEditingInst(inst)}
        onEditCard={card => setEditingCard(card)}
        onEditLoan={loan => setEditingLoan(loan)}
        onEditSubscription={sub => openEditSub(sub)}
        onAddInstitution={() => setEditingInst({ name: '', loginUrl: '', email: '', username: '', password: '', accounts: [] })}
        onAddCard={() => setEditingCard({ name: '', cardHolder: '', last4: '', expiry: '', network: 'Visa', type: 'Credit', status: 'Active', limit: 0 })}
        onAddLoan={() => setEditingLoan({ role: 'Lendee', lender: '', name: '', principalAmount: 0, interestRate: 0, status: 'Active' })}
        onNewSubscription={openNewSub}
        onAddDocument={() => router.push('/document/new')}
        onOpenPaidFromPicker={openPaidFromPicker}
        onQuickGlanceCard={card => setEditingCard(card)}
        onQuickGlanceSub={sub => openEditSub(sub)}
      />

      {/* ── Financial Modals ── */}
      {editingInst && (
        <EditBankModal
          inst={editingInst} loans={loans} cards={cards}
          onSave={updated => { if (updated.id) handleUpdateInstitution(updated.id, updated); else handleAddInstitution({ ...updated, companyId: selectedCompanyId! }); setEditingInst(null); }}
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
        <EditCardModal card={editingCard}
          onSave={updated => { if (updated.id) handleUpdateFinancialCard(updated.id, updated); else handleAddFinancialCard({ ...updated, companyId: selectedCompanyId! }); setEditingCard(null); }}
          onDelete={() => { if (editingCard.id) handleDeleteFinancialCard(editingCard.id); setEditingCard(null); }}
          onClose={() => setEditingCard(null)} />
      )}
      {editingLoan && (
        <EditLoanModal loan={editingLoan}
          onSave={updated => { if ((updated as any).id) handleUpdateLoan((updated as any).id, updated); else handleAddLoan({ ...updated, companyId: selectedCompanyId! }); setEditingLoan(null); }}
          onDelete={() => { if ((editingLoan as any).id) handleDeleteLoan((editingLoan as any).id); setEditingLoan(null); }}
          onClose={() => setEditingLoan(null)} />
      )}

      {/* ── Subscription Edit Modal ── */}
      {/* This is the full subscription edit modal, copied from subscriptions.tsx */}
      <Modal visible={!!editingSub} animationType="slide" presentationStyle="pageSheet" onRequestClose={() => setEditingSub(null)}>
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={{ flex: 1 }}>
          <View style={{ flex: 1, backgroundColor: '#1C1C1E', borderWidth: 1, borderColor: 'rgba(255,255,255,0.1)' }}>
            <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 24, paddingVertical: 16, borderBottomWidth: 1, borderBottomColor: 'rgba(255,255,255,0.05)', paddingTop: 20 }}>
              <Text style={{ color: '#fff', fontWeight: '900', fontSize: 16, textTransform: 'uppercase', letterSpacing: 1 }}>
                {editingSub?.id ? 'Edit Service' : 'New Service'}
              </Text>
              <TouchableOpacity onPress={() => setEditingSub(null)}><Ionicons name="close" size={24} color="rgba(255,255,255,0.5)" /></TouchableOpacity>
            </View>
            <ScrollView ref={editScrollRef} style={{ flex: 1 }} contentContainerStyle={{ padding: 24, gap: 20 }} keyboardShouldPersistTaps="handled">
              {/* Free/Paid Toggle */}
              <View style={{ flexDirection: 'row', backgroundColor: 'rgba(0,0,0,0.4)', borderRadius: 100, padding: 4, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', alignSelf: 'center', minWidth: 200 }}>
                {(['free', 'paid'] as const).map(model => (
                  <TouchableOpacity key={model} onPress={() => updateSub({ pricingModel: model })}
                    style={{ flex: 1, paddingVertical: 8, paddingHorizontal: 24, borderRadius: 100, backgroundColor: editingSub?.pricingModel === model ? '#EBC351' : 'transparent', alignItems: 'center' }}>
                    <Text style={{ color: editingSub?.pricingModel === model ? '#000' : 'rgba(255,255,255,0.4)', fontWeight: '900', fontSize: 10, textTransform: 'uppercase', letterSpacing: 2 }}>{model === 'free' ? 'Free' : 'Paid'}</Text>
                  </TouchableOpacity>
                ))}
              </View>
              {/* Name + Website */}
              <View style={{ flexDirection: 'row', gap: 12 }}>
                <View style={{ flex: 1 }}><Text style={modalStyles.label}>Subscription</Text><TextInput style={modalStyles.input} value={editingSub?.name || ''} placeholder="Shopify" placeholderTextColor="rgba(255,255,255,0.2)" onChangeText={t => updateSub({ name: t })} /></View>
                <View style={{ flex: 1 }}><Text style={modalStyles.label}>Website</Text><TextInput style={modalStyles.input} value={editingSub?.website || ''} placeholder="shopify.com" placeholderTextColor="rgba(255,255,255,0.2)" autoCapitalize="none" onChangeText={t => updateSub({ website: t })} /></View>
              </View>
              {/* Cost + Due On + Cycle */}
              {editingSub?.pricingModel !== 'free' && (
                <View style={{ flexDirection: 'row', gap: 12 }}>
                  <View style={{ flex: 1 }}><Text style={modalStyles.label}>Cost</Text><View style={{ position: 'relative' }}><Text style={{ position: 'absolute', left: 12, top: 10, color: 'rgba(255,255,255,0.3)', fontSize: 13, zIndex: 1 }}>$</Text><TextInput style={[modalStyles.input, { paddingLeft: 24 }]} value={editingSub?.cost?.toString() || ''} placeholder="0.00" placeholderTextColor="rgba(255,255,255,0.2)" keyboardType="numeric" onChangeText={t => updateSub({ cost: parseFloat(t) || 0 })} /></View></View>
                  <View style={{ flex: 1 }}><Text style={modalStyles.label}>Due On</Text><TextInput style={modalStyles.input} value={editingSub?.nextRenewal || ''} placeholder="15th" placeholderTextColor="rgba(255,255,255,0.2)" onChangeText={t => updateSub({ nextRenewal: t })} /></View>
                  <View style={{ flex: 1 }}><Text style={modalStyles.label}>Cycle</Text>
                    <View style={{ flexDirection: 'row', backgroundColor: 'rgba(0,0,0,0.4)', borderRadius: 8, overflow: 'hidden', borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)' }}>
                      {(['Monthly', 'Yearly'] as const).map(c => (
                        <TouchableOpacity key={c} onPress={() => updateSub({ billingCycle: c, nextRenewal: '' })} style={{ flex: 1, padding: 8, backgroundColor: editingSub?.billingCycle === c ? 'rgba(235,195,81,0.1)' : 'transparent', alignItems: 'center' }}>
                          <Text style={{ color: editingSub?.billingCycle === c ? '#EBC351' : 'rgba(255,255,255,0.4)', fontSize: 10, fontWeight: '900', textTransform: 'uppercase', letterSpacing: 1 }}>{c.slice(0, 2)}</Text>
                        </TouchableOpacity>
                      ))}
                    </View>
                  </View>
                </View>
              )}
              {/* Login + Password */}
              <View style={{ flexDirection: 'row', gap: 12 }}>
                <View style={{ flex: 1 }}><Text style={modalStyles.label}>Login ID</Text><TextInput style={modalStyles.input} value={editingSub?.loginId || ''} placeholder="admin" placeholderTextColor="rgba(255,255,255,0.2)" autoCapitalize="none" onChangeText={t => updateSub({ loginId: t })} /></View>
                <View style={{ flex: 1 }}><Text style={modalStyles.label}>Password</Text><TextInput style={modalStyles.input} value={editingSub?.password || ''} placeholder="••••••••" placeholderTextColor="rgba(255,255,255,0.2)" secureTextEntry onChangeText={t => updateSub({ password: t })} /></View>
              </View>
              {/* Status Toggle */}
              <View style={{ alignItems: 'center' }}>
                <View style={{ backgroundColor: '#242426', borderRadius: 16, flexDirection: 'row', overflow: 'hidden', width: 256, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', position: 'relative' }}>
                  <View style={{ position: 'absolute', top: 4, bottom: 4, width: '50%', backgroundColor: editingSub?.status === 'Paused' ? '#ef4444' : '#EBC351', borderRadius: 12, left: editingSub?.status === 'Paused' ? '50%' : 4 }} />
                  {(['Active', 'Paused'] as const).map(s => (
                    <TouchableOpacity key={s} onPress={() => updateSub({ status: s })} style={{ flex: 1, paddingVertical: 10, alignItems: 'center', zIndex: 1 }}>
                      <Text style={{ color: editingSub?.status === s ? (s === 'Paused' ? '#fff' : '#000') : 'rgba(255,255,255,0.4)', fontWeight: '900', fontSize: 10, textTransform: 'uppercase', letterSpacing: 2 }}>{s}</Text>
                    </TouchableOpacity>
                  ))}
                </View>
              </View>
              {/* Paid From + Auto Pay */}
              {editingSub?.pricingModel !== 'free' && (
                <View style={{ flexDirection: 'row', gap: 12 }}>
                  <View style={{ flex: 1 }}><Text style={modalStyles.label}>Paid From</Text>
                    <TouchableOpacity style={[modalStyles.input, { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', minHeight: 38 }]}
                      onPress={() => openPaidFromPicker(editingSub?.companyId || selectedCompanyId, editingSub?.paymentMethod || '', v => updateSub({ paymentMethod: v }))}>
                      <Text style={{ color: editingSub?.paymentMethod ? '#fff' : 'rgba(255,255,255,0.2)', fontSize: 13, fontWeight: '500', flex: 1 }} numberOfLines={1}>{editingSub?.paymentMethod || "Linked card..."}</Text>
                      <Ionicons name="chevron-down" size={12} color="rgba(255,255,255,0.3)" />
                    </TouchableOpacity>
                  </View>
                  <View style={{ flex: 1 }}><Text style={modalStyles.label}>Auto Pay</Text>
                    <View style={{ flexDirection: 'row', backgroundColor: 'rgba(0,0,0,0.2)', borderRadius: 8, overflow: 'hidden', borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', height: 38, alignItems: 'center', position: 'relative' }}>
                      <View style={{ position: 'absolute', top: 4, bottom: 4, width: '50%', backgroundColor: editingSub?.renew === 'Manual' ? 'rgba(255,255,255,0.08)' : '#EBC351', borderRadius: 6, left: editingSub?.renew === 'Manual' ? '50%' : 4 }} />
                      {([['Auto', 'On'], ['Manual', 'Off']] as const).map(([val, label]) => (
                        <TouchableOpacity key={val} onPress={() => updateSub({ renew: val })} style={{ flex: 1, alignItems: 'center', zIndex: 1 }}>
                          <Text style={{ color: (val === 'Auto' && editingSub?.renew !== 'Manual') ? '#000' : val === 'Manual' && editingSub?.renew === 'Manual' ? '#fff' : 'rgba(255,255,255,0.3)', fontWeight: '900', fontSize: 9, textTransform: 'uppercase', letterSpacing: 2 }}>{label}</Text>
                        </TouchableOpacity>
                      ))}
                    </View>
                  </View>
                </View>
              )}
              {/* Notes */}
              <View><Text style={modalStyles.label}>Notes</Text><TextInput style={[modalStyles.input, { minHeight: 80, textAlignVertical: 'top' }]} value={editingSub?.notes || ''} placeholder="Add any specific notes..." placeholderTextColor="rgba(255,255,255,0.2)" multiline onChangeText={t => updateSub({ notes: t })} /></View>
              {/* Security */}
              <View style={{ borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.05)', paddingTop: 16 }}>
                <TouchableOpacity onPress={() => setExpandedSecurity(p => !p)} style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: expandedSecurity ? 16 : 0 }}>
                  <Text style={modalStyles.label}>Security & Recovery</Text>
                  <Ionicons name={expandedSecurity ? 'chevron-up' : 'chevron-down'} size={14} color="rgba(255,255,255,0.3)" />
                </TouchableOpacity>
                {expandedSecurity && (
                  <View style={{ flexDirection: 'row', gap: 12 }}>
                    <View style={{ flex: 1 }}><Text style={modalStyles.label}>2FA Method</Text>
                      <View style={{ backgroundColor: 'rgba(0,0,0,0.2)', borderRadius: 8, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', overflow: 'hidden' }}>
                        {['None', 'Authenticator', 'SMS', 'Email', 'Hardware Key', 'Backup Codes'].map(opt => (
                          <TouchableOpacity key={opt} onPress={() => updateSub({ twoFactorAuth: opt })}
                            style={{ paddingHorizontal: 12, paddingVertical: 10, backgroundColor: editingSub?.twoFactorAuth === opt ? 'rgba(235,195,81,0.1)' : 'transparent', flexDirection: 'row', alignItems: 'center', gap: 8 }}>
                            <View style={{ width: 8, height: 8, borderRadius: 4, backgroundColor: editingSub?.twoFactorAuth === opt ? '#EBC351' : 'rgba(255,255,255,0.1)' }} />
                            <Text style={{ color: editingSub?.twoFactorAuth === opt ? '#EBC351' : 'rgba(255,255,255,0.5)', fontSize: 13, fontWeight: '500' }}>{opt}</Text>
                          </TouchableOpacity>
                        ))}
                      </View>
                    </View>
                    <View style={{ flex: 1 }}><Text style={modalStyles.label}>Recovery</Text><TextInput style={modalStyles.input} value={editingSub?.recoveryMethod || ''} placeholder="Phone, email..." placeholderTextColor="rgba(255,255,255,0.2)" onChangeText={t => updateSub({ recoveryMethod: t })} /></View>
                  </View>
                )}
              </View>
              {/* Sub-Services */}
              <View onLayout={e => { subServicesSectionY.current = e.nativeEvent.layout.y; }} style={{ borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.05)', paddingTop: 24 }}>
                <TouchableOpacity onPress={addSubService} style={{ height: 60, backgroundColor: 'rgba(0,0,0,0.2)', borderRadius: 12, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 12, marginBottom: 12 }}>
                  <Text style={{ fontSize: 20 }}>💾</Text>
                  <Text style={{ color: 'rgba(255,255,255,0.6)', fontWeight: '700', fontSize: 11, textTransform: 'uppercase', letterSpacing: 2 }}>Add Supplemental Service</Text>
                </TouchableOpacity>
                {(editingSub?.subServices || []).map((child, idx) => {
                  const eid = child.id || String(idx);
                  const isOpen = expandedModalSubServices.has(eid);
                  return (
                    <View key={eid} style={{ backgroundColor: 'rgba(0,0,0,0.2)', borderRadius: 12, borderWidth: 1, borderColor: 'rgba(255,255,255,0.03)', marginBottom: 8, overflow: 'hidden' }}>
                      <TouchableOpacity onPress={() => setExpandedModalSubServices(prev => toggle(prev, eid))} style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 16, height: 47 }}>
                        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
                          <TouchableOpacity onPress={() => removeSubService(idx)}><Ionicons name="close" size={16} color="rgba(255,255,255,0.2)" /></TouchableOpacity>
                          <Text style={{ color: '#fff', fontSize: 13, fontWeight: '500' }}>{child.name || 'New Service'}</Text>
                          <Text style={{ color: 'rgba(255,255,255,0.2)', fontSize: 10 }}>|</Text>
                          <View style={{ width: 6, height: 6, borderRadius: 3, backgroundColor: child.status === 'Paused' ? '#ef4444' : '#1FE400' }} />
                          <Text style={{ color: child.status === 'Paused' ? '#ef4444' : '#1FE400', fontSize: 10, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 1 }}>{child.status}</Text>
                        </View>
                        <Ionicons name={isOpen ? 'chevron-up' : 'chevron-down'} size={14} color="rgba(255,255,255,0.3)" />
                      </TouchableOpacity>
                      {isOpen && (
                        <View style={{ padding: 16, borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.05)', gap: 12 }}>
                          <View style={{ flexDirection: 'row', gap: 12 }}>
                            <View style={{ flex: 1 }}><Text style={modalStyles.label}>Service Name</Text><TextInput style={modalStyles.input} value={child.name} placeholder="Storage, Analytics..." placeholderTextColor="rgba(255,255,255,0.2)" onChangeText={t => updateSubService(idx, { name: t })} /></View>
                            <View style={{ width: 120 }}><Text style={modalStyles.label}>Status</Text>
                              <View style={{ flexDirection: 'row', backgroundColor: 'rgba(0,0,0,0.4)', borderRadius: 8, overflow: 'hidden', borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', height: 38, alignItems: 'center' }}>
                                {(['Active', 'Paused'] as const).map(s => (
                                  <TouchableOpacity key={s} onPress={() => updateSubService(idx, { status: s })} style={{ flex: 1, alignItems: 'center', paddingVertical: 8, backgroundColor: child.status === s ? '#EBC351' : 'transparent' }}>
                                    <Text style={{ color: child.status === s ? '#000' : 'rgba(255,255,255,0.3)', fontWeight: '900', fontSize: 9, textTransform: 'uppercase', letterSpacing: 1 }}>{s}</Text>
                                  </TouchableOpacity>
                                ))}
                              </View>
                            </View>
                          </View>
                          <View style={{ flexDirection: 'row', gap: 12 }}>
                            <View style={{ flex: 1 }}><Text style={modalStyles.label}>Cost</Text><TextInput style={modalStyles.input} value={child.cost?.toString() || ''} placeholder="0.00" placeholderTextColor="rgba(255,255,255,0.2)" keyboardType="numeric" onChangeText={t => updateSubService(idx, { cost: parseFloat(t) || 0 })} /></View>
                            <View style={{ flex: 1 }}><Text style={modalStyles.label}>Cycle</Text>
                              <View style={{ flexDirection: 'row', backgroundColor: 'rgba(0,0,0,0.4)', borderRadius: 8, overflow: 'hidden', borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', height: 38, alignItems: 'center' }}>
                                {(['Monthly', 'Yearly'] as const).map(c => (
                                  <TouchableOpacity key={c} onPress={() => updateSubService(idx, { billingCycle: c })} style={{ flex: 1, alignItems: 'center', paddingVertical: 8, backgroundColor: child.billingCycle === c ? 'rgba(235,195,81,0.1)' : 'transparent' }}>
                                    <Text style={{ color: child.billingCycle === c ? '#EBC351' : 'rgba(255,255,255,0.4)', fontWeight: '900', fontSize: 9, textTransform: 'uppercase', letterSpacing: 1 }}>{c.slice(0, 2)}</Text>
                                  </TouchableOpacity>
                                ))}
                              </View>
                            </View>
                            <View style={{ flex: 1 }}><Text style={modalStyles.label}>Auto Pay</Text>
                              <View style={{ flexDirection: 'row', backgroundColor: 'rgba(0,0,0,0.2)', borderRadius: 8, overflow: 'hidden', borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', height: 38, alignItems: 'center' }}>
                                {([['Auto', 'On'], ['Manual', 'Off']] as const).map(([val, label]) => (
                                  <TouchableOpacity key={val} onPress={() => updateSubService(idx, { autoPay: val })} style={{ flex: 1, alignItems: 'center', backgroundColor: (val === 'Auto' && child.autoPay !== 'Manual') ? '#EBC351' : val === 'Manual' && child.autoPay === 'Manual' ? 'rgba(255,255,255,0.08)' : 'transparent' }}>
                                    <Text style={{ color: (val === 'Auto' && child.autoPay !== 'Manual') ? '#000' : 'rgba(255,255,255,0.3)', fontWeight: '900', fontSize: 9, textTransform: 'uppercase', letterSpacing: 2, paddingVertical: 12 }}>{label}</Text>
                                  </TouchableOpacity>
                                ))}
                              </View>
                            </View>
                          </View>
                          <View><Text style={modalStyles.label}>Purpose</Text><TextInput style={[modalStyles.input, { minHeight: 50, textAlignVertical: 'top' }]} value={child.purpose || ''} placeholder="Backup storage..." placeholderTextColor="rgba(255,255,255,0.2)" multiline onChangeText={t => updateSubService(idx, { purpose: t })} /></View>
                        </View>
                      )}
                    </View>
                  );
                })}
              </View>
              {/* Linked Emails */}
              <View style={{ borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.05)', paddingTop: 24, marginBottom: 8 }}>
                <TouchableOpacity onPress={addLinkedEmail} style={{ height: 60, backgroundColor: 'rgba(0,0,0,0.2)', borderRadius: 12, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 12, marginBottom: 12 }}>
                  <Text style={{ fontSize: 20 }}>📨</Text>
                  <Text style={{ color: 'rgba(255,255,255,0.6)', fontWeight: '700', fontSize: 11, textTransform: 'uppercase', letterSpacing: 2 }}>Add Linked Email</Text>
                </TouchableOpacity>
                {(editingSub?.linkedEmails || []).map((email, idx) => {
                  const eid = email.id || String(idx);
                  const isOpen = expandedModalEmails.has(eid);
                  return (
                    <View key={eid} style={{ backgroundColor: 'rgba(0,0,0,0.2)', borderRadius: 12, borderWidth: 1, borderColor: 'rgba(255,255,255,0.03)', marginBottom: 8, overflow: 'hidden' }}>
                      <TouchableOpacity onPress={() => setExpandedModalEmails(prev => toggle(prev, eid))} style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 16, height: 47 }}>
                        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
                          <TouchableOpacity onPress={() => removeLinkedEmail(idx)}><Ionicons name="close" size={16} color="rgba(255,255,255,0.2)" /></TouchableOpacity>
                          <Text style={{ color: '#fff', fontSize: 13, fontWeight: '500' }}>{email.email || 'New Email Address'}</Text>
                        </View>
                        <Ionicons name={isOpen ? 'chevron-up' : 'chevron-down'} size={14} color="rgba(255,255,255,0.3)" />
                      </TouchableOpacity>
                      {isOpen && (
                        <View style={{ padding: 16, borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.05)', gap: 12 }}>
                          <View style={{ flexDirection: 'row', gap: 12 }}>
                            <View style={{ flex: 1 }}><Text style={modalStyles.label}>Email Address</Text><TextInput style={modalStyles.input} value={email.email} placeholder="email@example.com" placeholderTextColor="rgba(255,255,255,0.2)" autoCapitalize="none" keyboardType="email-address" onChangeText={t => updateLinkedEmail(idx, { email: t })} /></View>
                            <View style={{ flex: 1 }}><Text style={modalStyles.label}>Used For</Text><TextInput style={modalStyles.input} value={email.usedFor} placeholder="Personal use" placeholderTextColor="rgba(255,255,255,0.2)" onChangeText={t => updateLinkedEmail(idx, { usedFor: t })} /></View>
                          </View>
                          <View style={{ flexDirection: 'row', gap: 12 }}>
                            <View style={{ flex: 1 }}><Text style={modalStyles.label}>Provider</Text><TextInput style={modalStyles.input} value={email.forwarding} placeholder="Google Workspace" placeholderTextColor="rgba(255,255,255,0.2)" onChangeText={t => updateLinkedEmail(idx, { forwarding: t })} /></View>
                            <View style={{ flex: 1 }}><Text style={modalStyles.label}>Access Method</Text><TextInput style={modalStyles.input} value={email.accessMethod} placeholder="Gmail, Apple Mail" placeholderTextColor="rgba(255,255,255,0.2)" onChangeText={t => updateLinkedEmail(idx, { accessMethod: t })} /></View>
                          </View>
                          <View><Text style={modalStyles.label}>Notes</Text><TextInput style={[modalStyles.input, { minHeight: 80, textAlignVertical: 'top' }]} value={(email.notes || []).join('\n')} placeholder="Main email used for..." placeholderTextColor="rgba(255,255,255,0.2)" multiline onChangeText={t => updateLinkedEmail(idx, { notes: t.split('\n') })} /></View>
                        </View>
                      )}
                    </View>
                  );
                })}
              </View>
            </ScrollView>
            {/* Modal Footer */}
            <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 24, paddingVertical: 16, borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.05)', backgroundColor: 'rgba(0,0,0,0.2)', paddingBottom: 36 }}>
              <View>
                {editingSub?.id && (
                  showDeleteConfirm ? (
                    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
                      <Text style={{ color: '#f97316', fontSize: 10, fontWeight: '900', textTransform: 'uppercase' }}>Confirm?</Text>
                      <TouchableOpacity onPress={handleSubDelete}><Text style={{ color: '#fff', fontSize: 10, fontWeight: '900', textTransform: 'uppercase' }}>Yes</Text></TouchableOpacity>
                      <TouchableOpacity onPress={() => setShowDeleteConfirm(false)}><Text style={{ color: 'rgba(255,255,255,0.3)', fontSize: 10, fontWeight: '900', textTransform: 'uppercase' }}>No</Text></TouchableOpacity>
                    </View>
                  ) : (
                    <TouchableOpacity onPress={() => setShowDeleteConfirm(true)}>
                      <Text style={{ color: 'rgba(255,255,255,0.25)', fontSize: 13, fontWeight: '500' }}>Delete</Text>
                    </TouchableOpacity>
                  )
                )}
              </View>
              <View style={{ flexDirection: 'row', gap: 16, alignItems: 'center' }}>
                <TouchableOpacity onPress={() => setEditingSub(null)}><Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 15, fontWeight: '500' }}>Cancel</Text></TouchableOpacity>
                <TouchableOpacity onPress={handleSubSave} style={{ backgroundColor: '#EBC351', borderRadius: 16, paddingHorizontal: 24, paddingVertical: 12 }}><Text style={{ color: '#000', fontSize: 15, fontWeight: '600' }}>Save</Text></TouchableOpacity>
              </View>
            </View>
          </View>
        </KeyboardAvoidingView>
        <PaidFromPicker visible={showPaidFromPicker} onClose={() => setShowPaidFromPicker(false)} onSelect={v => { paidFromCallback.current?.(v); }} currentValue={paidFromCurrentValue} state={state} companyId={paidFromCompanyId} />
      </Modal>

      <PaidFromPicker visible={showPaidFromPicker} onClose={() => setShowPaidFromPicker(false)} onSelect={v => { paidFromCallback.current?.(v); }} currentValue={paidFromCurrentValue} state={state} companyId={paidFromCompanyId} />
    </SafeAreaView>
  );
}

const modalStyles = {
  label: { color: 'rgba(255,255,255,0.4)', fontSize: 12, fontWeight: '500' as const, letterSpacing: 0, marginBottom: 6, marginLeft: 4 },
  input: { backgroundColor: 'rgba(0,0,0,0.3)', borderRadius: 8, paddingHorizontal: 12, paddingVertical: 10, borderWidth: 1, borderColor: 'rgba(255,255,255,0.06)', color: '#fff', fontSize: 13, fontWeight: '500' as const },
};
