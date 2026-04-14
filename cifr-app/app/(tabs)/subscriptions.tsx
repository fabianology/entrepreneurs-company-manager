import React, { useState } from 'react';
import {
  View, Text, ScrollView, TouchableOpacity, TextInput,
  Modal, Alert, Pressable, KeyboardAvoidingView, Platform, Clipboard
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useAppContext } from '../../context/AppContext';
import { Subscription, SubService, LinkedEmail } from '../../types';
import CompanyHeader from '../../components/CompanyHeader';

const genId = () => Math.random().toString(36).substr(2, 9);

export default function SubscriptionsScreen() {
  const { state, selectedCompanyId, handleUpdateSubscription, handleAddSubscription, handleDeleteSubscription, subMetrics } = useAppContext();

  const [editingSub, setEditingSub] = useState<Partial<Subscription> | null>(null);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [expandedSubs, setExpandedSubs] = useState<Set<string>>(new Set());
  const [expandedEmails, setExpandedEmails] = useState<Set<string>>(new Set());
  const [expandedCardDetails, setExpandedCardDetails] = useState<Set<string>>(new Set());
  const [expandedModalSubServices, setExpandedModalSubServices] = useState<Set<string>>(new Set());
  const [expandedModalEmails, setExpandedModalEmails] = useState<Set<string>>(new Set());
  const [expandedSecurity, setExpandedSecurity] = useState(false);
  const [visiblePasswords, setVisiblePasswords] = useState<Set<string>>(new Set());
  const [lastCopied, setLastCopied] = useState<{ id: string; field: string } | null>(null);

  if (!state) return null;

  const subscriptions = selectedCompanyId
    ? state.subscriptions.filter(s => s.companyId === selectedCompanyId)
    : state.subscriptions;

  const toggle = (set: Set<string>, id: string): Set<string> => {
    const n = new Set(set);
    n.has(id) ? n.delete(id) : n.add(id);
    return n;
  };

  const handleCopy = (id: string, text: string, field: string) => {
    if (!text) return;
    Clipboard.setString(text);
    setLastCopied({ id, field });
    setTimeout(() => setLastCopied(null), 2000);
  };

  const openNew = () => {
    setShowDeleteConfirm(false);
    setExpandedSecurity(false);
    setExpandedModalSubServices(new Set());
    setExpandedModalEmails(new Set());
    setEditingSub({
      companyId: selectedCompanyId || '',
      name: '', cost: 0, billingCycle: 'Monthly', status: 'Active',
      paymentMethod: '', nextRenewal: '', renew: 'Auto',
      subServices: [], linkedEmails: [],
      loginId: '', password: '', twoFactorAuth: 'None',
      recoveryMethod: '', website: '', pricingModel: 'paid', notes: ''
    });
  };

  const openEdit = (sub: Subscription) => {
    setShowDeleteConfirm(false);
    setExpandedSecurity(false);
    setExpandedModalSubServices(new Set());
    setExpandedModalEmails(new Set());
    setEditingSub({ ...sub });
  };

  const handleSave = () => {
    if (!editingSub) return;
    if (!editingSub.name?.trim()) {
      Alert.alert('Missing Name', 'Please enter a name for this service.');
      return;
    }
    const updates = { ...editingSub, lastUpdated: Date.now() };
    if (editingSub.id) {
      handleUpdateSubscription(editingSub.id, updates);
    } else {
      handleAddSubscription(updates);
    }
    setEditingSub(null);
  };

  const handleDelete = () => {
    if (!editingSub?.id) return;
    handleDeleteSubscription(editingSub.id);
    setEditingSub(null);
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
    const newSubs = (editingSub?.subServices || []).filter((_, i) => i !== idx);
    updateSub({ subServices: newSubs });
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
    const list = (editingSub?.linkedEmails || []).filter((_, i) => i !== idx);
    updateSub({ linkedEmails: list });
  };

  // Calculate billing totals — same logic as web
  const calcTotals = (sub: Subscription) => {
    const monthlyTotal = (sub.billingCycle === 'Monthly' ? sub.cost : 0) +
      (sub.subServices?.reduce((s, ss) => ss.status === 'Paused' ? s : ss.billingCycle === 'Monthly' ? s + ss.cost : s, 0) || 0);
    const yearlyTotal = (sub.billingCycle === 'Yearly' ? sub.cost : 0) +
      (sub.subServices?.reduce((s, ss) => ss.status === 'Paused' ? s : ss.billingCycle === 'Yearly' ? s + ss.cost : s, 0) || 0);
    const totalAnnual = (monthlyTotal * 12) + yearlyTotal;
    const primary = sub.billingCycle === 'Monthly' ? monthlyTotal : yearlyTotal;
    const secondary = sub.billingCycle === 'Monthly' ? yearlyTotal : monthlyTotal;
    const primaryLabel = sub.billingCycle === 'Monthly' ? 'recur/mo.' : 'recur/yr.';
    const secondaryLabel = sub.billingCycle === 'Monthly' ? 'recur/yr.' : 'recur/mo.';
    return { primary, secondary, primaryLabel, secondaryLabel, totalAnnual };
  };

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: '#000' }}>
      <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 16, paddingBottom: 120 }}>
        <CompanyHeader activeTab="subscriptions" />

        {/* Add Button Row */}
        <View style={{ flexDirection: 'row', justifyContent: 'flex-end', marginBottom: 20 }}>
          {selectedCompanyId && (
            <TouchableOpacity onPress={openNew} style={{ backgroundColor: '#fff', paddingHorizontal: 16, height: 32, borderRadius: 100, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 6 }}>
              <Ionicons name="add" size={14} color="#000" />
              <Text style={{ color: '#000', fontWeight: '700', fontSize: 10, textTransform: 'uppercase', letterSpacing: 1 }}>Service</Text>
            </TouchableOpacity>
          )}
        </View>

        {subscriptions.length === 0 ? (
          <TouchableOpacity onPress={openNew} style={{ borderWidth: 1, borderStyle: 'dashed', borderColor: 'rgba(255,255,255,0.2)', padding: 40, borderRadius: 32, alignItems: 'center', backgroundColor: 'rgba(28,28,30,0.5)' }}>
            <Text style={{ fontSize: 28, marginBottom: 16 }}>🌐</Text>
            <Text style={{ color: 'rgba(255,255,255,0.4)', fontWeight: '900', fontSize: 10, letterSpacing: 3, textTransform: 'uppercase' }}>+ Add Your First Service</Text>
          </TouchableOpacity>
        ) : (
          subscriptions.map(sub => {
            const isCardExpanded = expandedCardDetails.has(sub.id);
            const isSubsExpanded = expandedSubs.has(sub.id);
            const isEmailsExpanded = expandedEmails.has(sub.id);
            const totals = calcTotals(sub);

            return (
              <View key={sub.id} style={{ backgroundColor: '#1C1C1E', borderRadius: 24, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', marginBottom: 16, overflow: 'hidden' }}>

                {/* ---- Card Top: tapping opens edit modal ---- */}
                <TouchableOpacity
                  activeOpacity={0.85}
                  onPress={() => openEdit(sub)}
                  style={{ padding: 24, paddingBottom: sub.pricingModel === 'free' ? 18 : 2 }}
                >
                  <View style={{ flexDirection: 'row', alignItems: 'flex-start', marginBottom: 12 }}>
                    {/* Logo */}
                    <View style={{ width: 56, height: 56, backgroundColor: 'rgba(255,255,255,0.05)', borderRadius: 16, alignItems: 'center', justifyContent: 'center', marginRight: 16 }}>
                      <Text style={{ color: '#fff', fontWeight: '900', fontSize: 22, opacity: 0.8 }}>{sub.name.charAt(0)}</Text>
                    </View>

                    {/* Name + Cost */}
                    <View style={{ flex: 1 }}>
                      <Text style={{ color: '#fff', fontWeight: '700', fontSize: 14, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 4 }}>{sub.name}</Text>
                      {sub.pricingModel !== 'free' && (
                        <View style={{ flexDirection: 'row', gap: 16, marginTop: 4 }}>
                          <View>
                            <Text style={{ color: '#fff', fontWeight: '700', fontSize: 15 }}>${totals.primary.toFixed(2)}</Text>
                            <Text style={{ color: 'rgba(255,255,255,0.4)', fontWeight: '900', fontSize: 9, textTransform: 'uppercase', letterSpacing: 2, marginTop: 1 }}>{totals.primaryLabel}</Text>
                          </View>
                          {totals.secondary > 0 && (
                            <>
                              <View style={{ width: 1, backgroundColor: 'rgba(255,255,255,0.05)', marginVertical: 2 }} />
                              <View>
                                <Text style={{ color: '#fff', fontWeight: '700', fontSize: 15 }}>${totals.secondary.toFixed(2)}</Text>
                                <Text style={{ color: 'rgba(255,255,255,0.4)', fontWeight: '900', fontSize: 9, textTransform: 'uppercase', letterSpacing: 2, marginTop: 1 }}>{totals.secondaryLabel}</Text>
                              </View>
                            </>
                          )}
                          <View style={{ width: 1, backgroundColor: 'rgba(255,255,255,0.05)', marginVertical: 2 }} />
                          <View>
                            <Text style={{ color: '#fff', fontWeight: '700', fontSize: 15 }}>${totals.totalAnnual.toFixed(2)}</Text>
                            <Text style={{ color: 'rgba(255,255,255,0.4)', fontWeight: '900', fontSize: 9, textTransform: 'uppercase', letterSpacing: 2, marginTop: 1 }}>est. yearly</Text>
                          </View>
                        </View>
                      )}
                    </View>
                  </View>

                  {/* Status Row */}
                  <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 12 }}>
                    {sub.status === 'Paused' ? (
                      <>
                        <View style={{ width: 6, height: 6, borderRadius: 3, backgroundColor: '#ef4444' }} />
                        <Text style={{ color: '#ef4444', fontSize: 11, fontWeight: '500', textTransform: 'uppercase', letterSpacing: 2 }}>Paused</Text>
                      </>
                    ) : (
                      <>
                        <View style={{ width: 6, height: 6, borderRadius: 3, backgroundColor: sub.renew === 'Manual' ? '#ef4444' : '#1FE400' }} />
                        <Text style={{ color: sub.renew === 'Manual' ? '#ef4444' : '#1FE400', fontSize: 11, fontWeight: '500', textTransform: 'uppercase', letterSpacing: 2 }}>
                          {sub.pricingModel === 'free' ? 'Free' : sub.renew === 'Manual' ? 'Manual' : 'Auto Renew'}
                        </Text>
                        <Text style={{ color: 'rgba(255,255,255,0.2)', fontSize: 10 }}>|</Text>
                        <Text style={{ color: '#1FE400', fontSize: 11, fontWeight: '500', textTransform: 'uppercase', letterSpacing: 2 }}>
                          {sub.pricingModel === 'free' ? 'Active' : 'Paid'}
                        </Text>
                        <Text style={{ color: 'rgba(255,255,255,0.2)', fontSize: 10 }}>|</Text>
                        <Text style={{ color: '#1FE400', fontSize: 11, fontWeight: '500', textTransform: 'uppercase', letterSpacing: 2 }}>{sub.status}</Text>
                      </>
                    )}
                  </View>

                  {/* Credentials Row */}
                  <View style={{ flexDirection: 'row', gap: 12 }}>
                    <TouchableOpacity
                      activeOpacity={0.7}
                      onPress={() => handleCopy(sub.id, sub.loginId || '', 'login')}
                      style={{ flex: 1 }}
                    >
                      <Text style={{ color: lastCopied?.id === sub.id && lastCopied.field === 'login' ? '#f97316' : 'rgba(255,255,255,0.4)', fontSize: 11, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 2, marginBottom: 6 }}>
                        {lastCopied?.id === sub.id && lastCopied.field === 'login' ? 'Copied' : 'Login ID'}
                      </Text>
                      <View style={{ backgroundColor: 'rgba(0,0,0,0.2)', borderRadius: 8, paddingHorizontal: 12, paddingVertical: 8, borderWidth: 1, borderColor: 'rgba(255,255,255,0.03)' }}>
                        <Text style={{ color: '#fff', fontSize: 13, fontWeight: '500' }} numberOfLines={1}>{sub.loginId || '—'}</Text>
                      </View>
                    </TouchableOpacity>

                    <TouchableOpacity
                      activeOpacity={0.7}
                      onPress={() => handleCopy(sub.id, sub.password || '', 'password')}
                      style={{ flex: 1 }}
                    >
                      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6, marginBottom: 6 }}>
                        <Text style={{ color: lastCopied?.id === sub.id && lastCopied.field === 'password' ? '#f97316' : 'rgba(255,255,255,0.4)', fontSize: 11, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 2 }}>
                          {lastCopied?.id === sub.id && lastCopied.field === 'password' ? 'Copied' : 'Password'}
                        </Text>
                        <TouchableOpacity onPress={() => setVisiblePasswords(prev => toggle(prev, sub.id))}>
                          <Ionicons name={visiblePasswords.has(sub.id) ? 'eye-off' : 'eye'} size={14} color="rgba(255,255,255,0.3)" />
                        </TouchableOpacity>
                      </View>
                      <View style={{ backgroundColor: 'rgba(0,0,0,0.2)', borderRadius: 8, paddingHorizontal: 12, paddingVertical: 8, borderWidth: 1, borderColor: 'rgba(255,255,255,0.03)' }}>
                        <Text style={{ color: '#fff', fontSize: 13, fontWeight: '500', letterSpacing: visiblePasswords.has(sub.id) ? 0 : 2 }} numberOfLines={1}>
                          {visiblePasswords.has(sub.id) ? (sub.password || '—') : '••••••••'}
                        </Text>
                      </View>
                    </TouchableOpacity>
                  </View>
                </TouchableOpacity>

                {/* ---- More Details Accordion ---- */}
                {sub.pricingModel !== 'free' && (
                  <>
                    <TouchableOpacity
                      onPress={() => setExpandedCardDetails(prev => toggle(prev, sub.id))}
                      style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 24, height: 47 }}
                    >
                      <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 13, fontWeight: '500', textTransform: 'uppercase', letterSpacing: 2 }}>
                        {isCardExpanded ? 'Less Details' : 'More Details'}
                      </Text>
                      <Ionicons name={isCardExpanded ? 'chevron-up' : 'chevron-down'} size={16} color="rgba(255,255,255,0.4)" />
                    </TouchableOpacity>

                    {isCardExpanded && (
                      <View style={{ paddingHorizontal: 24, paddingBottom: 24, flexDirection: 'row', flexWrap: 'wrap', gap: 16 }}>
                        <View style={{ flex: 1, minWidth: '40%' }}>
                          <Text style={styles.fieldLabel}>Paid From</Text>
                          <TextInput
                            style={styles.inlineInput}
                            value={sub.paymentMethod || ''}
                            placeholder="Linked card..."
                            placeholderTextColor="rgba(255,255,255,0.2)"
                            onChangeText={text => handleUpdateSubscription(sub.id, { paymentMethod: text })}
                          />
                        </View>
                        <View style={{ flex: 1, minWidth: '40%' }}>
                          <Text style={styles.fieldLabel}>Due On</Text>
                          <TextInput
                            style={styles.inlineInput}
                            value={sub.nextRenewal || ''}
                            placeholder="15th / EOM"
                            placeholderTextColor="rgba(255,255,255,0.2)"
                            onChangeText={text => handleUpdateSubscription(sub.id, { nextRenewal: text })}
                          />
                        </View>
                        <View style={{ width: '100%' }}>
                          <Text style={styles.fieldLabel}>Notes</Text>
                          <TextInput
                            style={[styles.inlineInput, { minHeight: 60, textAlignVertical: 'top' }]}
                            value={sub.notes || ''}
                            placeholder="Add notes..."
                            placeholderTextColor="rgba(255,255,255,0.2)"
                            multiline
                            onChangeText={text => handleUpdateSubscription(sub.id, { notes: text })}
                          />
                        </View>
                      </View>
                    )}
                  </>
                )}

                {/* ---- Supplemental Services Accordion ---- */}
                <View style={{ borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.05)' }}>
                  <TouchableOpacity
                    onPress={() => setExpandedSubs(prev => toggle(prev, sub.id))}
                    style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 24, height: 47 }}
                  >
                    <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 13, fontWeight: '500', textTransform: 'uppercase', letterSpacing: 2 }}>
                      Supplemental Services <Text style={{ color: 'rgba(255,255,255,0.2)' }}>({sub.subServices?.length || 0})</Text>
                    </Text>
                    <Ionicons name={isSubsExpanded ? 'chevron-up' : 'chevron-down'} size={16} color="rgba(255,255,255,0.4)" />
                  </TouchableOpacity>

                  {isSubsExpanded && (
                    <View style={{ paddingHorizontal: 24, paddingBottom: 24, gap: 12 }}>
                      {(sub.subServices || []).map((child, idx) => (
                        <View key={child.id || idx} style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
                          <View style={{ flex: 1, flexDirection: 'column' }}>
                            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
                              <View style={{ width: 6, height: 6, borderRadius: 3, backgroundColor: child.status === 'Paused' ? '#ef4444' : '#1FE400' }} />
                              <Text style={{ color: '#fff', fontSize: 13, fontWeight: '500', textTransform: 'uppercase' }}>{child.name}</Text>
                            </View>
                            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, marginTop: 4, marginLeft: 16 }}>
                              <Text style={{ color: child.status === 'Paused' ? '#ef4444' : '#1FE400', fontSize: 10, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 1 }}>{child.status}</Text>
                              <Text style={{ color: 'rgba(255,255,255,0.2)', fontSize: 10 }}>|</Text>
                              <Text style={{ color: child.autoPay === 'Manual' ? '#ef4444' : '#1FE400', fontSize: 10, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 1 }}>
                                {child.autoPay === 'Manual' ? 'Manual' : 'Auto Pay'}
                              </Text>
                            </View>
                          </View>
                          <Text style={{ color: child.status === 'Paused' ? 'rgba(255,255,255,0.2)' : '#fff', fontSize: 13, fontWeight: '500' }}>
                            ${child.cost.toFixed(2)}<Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 11, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 1 }}>/{child.billingCycle === 'Yearly' ? 'yr' : 'mo'}</Text>
                          </Text>
                        </View>
                      ))}
                      <TouchableOpacity onPress={() => { openEdit(sub); setTimeout(addSubService, 100); }}>
                        <Text style={{ color: 'rgba(255,255,255,0.3)', fontSize: 10, fontWeight: '900', textTransform: 'uppercase', letterSpacing: 2, marginTop: 8 }}>+ add item</Text>
                      </TouchableOpacity>
                    </View>
                  )}
                </View>

                {/* ---- Linked Emails Accordion ---- */}
                <View style={{ borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.05)' }}>
                  <TouchableOpacity
                    onPress={() => setExpandedEmails(prev => toggle(prev, sub.id))}
                    style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 24, height: 47 }}
                  >
                    <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 13, fontWeight: '500', textTransform: 'uppercase', letterSpacing: 2 }}>
                      Linked Emails <Text style={{ color: 'rgba(255,255,255,0.2)' }}>({sub.linkedEmails?.length || 0})</Text>
                    </Text>
                    <Ionicons name={isEmailsExpanded ? 'chevron-up' : 'chevron-down'} size={16} color="rgba(255,255,255,0.4)" />
                  </TouchableOpacity>

                  {isEmailsExpanded && (
                    <View style={{ paddingHorizontal: 24, paddingBottom: 24, gap: 8 }}>
                      {(sub.linkedEmails || []).map((email, idx) => (
                        <TouchableOpacity key={email.id || idx} onPress={() => openEdit(sub)} style={{ flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 8, borderTopWidth: idx === 0 ? 0 : 1, borderTopColor: 'rgba(255,255,255,0.05)' }}>
                          <View style={{ flex: 1 }}>
                            <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 9, fontWeight: '900', textTransform: 'uppercase', letterSpacing: 2, marginBottom: 2 }}>Email</Text>
                            <Text style={{ color: '#fff', fontSize: 12, fontWeight: '900' }} numberOfLines={1}>{email.email}</Text>
                          </View>
                          <View style={{ flex: 1, paddingLeft: 24 }}>
                            <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 9, fontWeight: '900', textTransform: 'uppercase', letterSpacing: 2, marginBottom: 2 }}>Used For</Text>
                            <Text style={{ color: '#fff', fontSize: 12, fontWeight: '900' }} numberOfLines={1}>{email.usedFor}</Text>
                          </View>
                        </TouchableOpacity>
                      ))}
                      <TouchableOpacity onPress={() => { openEdit(sub); setTimeout(addLinkedEmail, 100); }}>
                        <Text style={{ color: 'rgba(255,255,255,0.3)', fontSize: 10, fontWeight: '900', textTransform: 'uppercase', letterSpacing: 2, marginTop: 8 }}>+ add email</Text>
                      </TouchableOpacity>
                    </View>
                  )}
                </View>
              </View>
            );
          })
        )}
      </ScrollView>

      {/* ======== EDIT / CREATE MODAL ======== */}
      <Modal
        visible={!!editingSub}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setEditingSub(null)}
      >
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={{ flex: 1 }}>
          <View style={{ flex: 1, backgroundColor: '#1C1C1E' }}>

            {/* Modal Header */}
            <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 24, paddingVertical: 16, borderBottomWidth: 1, borderBottomColor: 'rgba(255,255,255,0.05)', paddingTop: 20 }}>
              <Text style={{ color: '#fff', fontWeight: '900', fontSize: 16, textTransform: 'uppercase', letterSpacing: 1 }}>
                {editingSub?.id ? 'Edit Service' : 'New Service'}
              </Text>
              <TouchableOpacity onPress={() => setEditingSub(null)}>
                <Ionicons name="close" size={24} color="rgba(255,255,255,0.5)" />
              </TouchableOpacity>
            </View>

            <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 24, gap: 20 }} keyboardShouldPersistTaps="handled">

              {/* Free/Paid Toggle */}
              <View style={{ flexDirection: 'row', backgroundColor: 'rgba(0,0,0,0.4)', borderRadius: 100, padding: 4, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', alignSelf: 'center', minWidth: 200 }}>
                {(['free', 'paid'] as const).map(model => (
                  <TouchableOpacity
                    key={model}
                    onPress={() => updateSub({ pricingModel: model })}
                    style={{ flex: 1, paddingVertical: 8, paddingHorizontal: 24, borderRadius: 100, backgroundColor: editingSub?.pricingModel === model ? '#EBC351' : 'transparent', alignItems: 'center' }}
                  >
                    <Text style={{ color: editingSub?.pricingModel === model ? '#000' : 'rgba(255,255,255,0.4)', fontWeight: '900', fontSize: 10, textTransform: 'uppercase', letterSpacing: 2 }}>
                      {model === 'free' ? 'Free' : 'Paid'}
                    </Text>
                  </TouchableOpacity>
                ))}
              </View>

              {/* Name + Website */}
              <View style={{ flexDirection: 'row', gap: 12 }}>
                <View style={{ flex: 1 }}>
                  <Text style={styles.modalLabel}>Subscription</Text>
                  <TextInput style={styles.modalInput} value={editingSub?.name || ''} placeholder="Shopify" placeholderTextColor="rgba(255,255,255,0.2)" onChangeText={t => updateSub({ name: t })} />
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={styles.modalLabel}>Website</Text>
                  <TextInput style={styles.modalInput} value={editingSub?.website || ''} placeholder="shopify.com" placeholderTextColor="rgba(255,255,255,0.2)" autoCapitalize="none" onChangeText={t => updateSub({ website: t })} />
                </View>
              </View>

              {/* Cost + Due On + Cycle (paid only) */}
              {editingSub?.pricingModel !== 'free' && (
                <View style={{ flexDirection: 'row', gap: 12 }}>
                  <View style={{ flex: 1 }}>
                    <Text style={styles.modalLabel}>Cost</Text>
                    <View style={{ position: 'relative' }}>
                      <Text style={{ position: 'absolute', left: 12, top: 10, color: 'rgba(255,255,255,0.3)', fontSize: 13, zIndex: 1 }}>$</Text>
                      <TextInput style={[styles.modalInput, { paddingLeft: 24 }]} value={editingSub?.cost?.toString() || ''} placeholder="0.00" placeholderTextColor="rgba(255,255,255,0.2)" keyboardType="numeric" onChangeText={t => updateSub({ cost: parseFloat(t) || 0 })} />
                    </View>
                  </View>
                  <View style={{ flex: 1 }}>
                    <Text style={styles.modalLabel}>Due On</Text>
                    <TextInput style={styles.modalInput} value={editingSub?.nextRenewal || ''} placeholder="15th" placeholderTextColor="rgba(255,255,255,0.2)" onChangeText={t => updateSub({ nextRenewal: t })} />
                  </View>
                  <View style={{ flex: 1 }}>
                    <Text style={styles.modalLabel}>Cycle</Text>
                    <View style={{ flexDirection: 'row', backgroundColor: 'rgba(0,0,0,0.4)', borderRadius: 8, overflow: 'hidden', borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)' }}>
                      {(['Monthly', 'Yearly'] as const).map(c => (
                        <TouchableOpacity key={c} onPress={() => updateSub({ billingCycle: c, nextRenewal: '' })}
                          style={{ flex: 1, padding: 8, backgroundColor: editingSub?.billingCycle === c ? 'rgba(235,195,81,0.1)' : 'transparent', alignItems: 'center' }}>
                          <Text style={{ color: editingSub?.billingCycle === c ? '#EBC351' : 'rgba(255,255,255,0.4)', fontSize: 10, fontWeight: '900', textTransform: 'uppercase', letterSpacing: 1 }}>{c.slice(0, 2)}</Text>
                        </TouchableOpacity>
                      ))}
                    </View>
                  </View>
                </View>
              )}

              {/* Login ID + Password */}
              <View style={{ flexDirection: 'row', gap: 12 }}>
                <View style={{ flex: 1 }}>
                  <Text style={styles.modalLabel}>Login ID</Text>
                  <TextInput style={styles.modalInput} value={editingSub?.loginId || ''} placeholder="admin" placeholderTextColor="rgba(255,255,255,0.2)" autoCapitalize="none" onChangeText={t => updateSub({ loginId: t })} />
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={styles.modalLabel}>Password</Text>
                  <TextInput style={styles.modalInput} value={editingSub?.password || ''} placeholder="••••••••" placeholderTextColor="rgba(255,255,255,0.2)" secureTextEntry onChangeText={t => updateSub({ password: t })} />
                </View>
              </View>

              {/* Active / Paused Toggle */}
              <View style={{ alignItems: 'center' }}>
                <View style={{ backgroundColor: '#242426', borderRadius: 16, flexDirection: 'row', overflow: 'hidden', width: 256, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', position: 'relative' }}>
                  <View style={{
                    position: 'absolute', top: 4, bottom: 4, width: '50%',
                    backgroundColor: editingSub?.status === 'Paused' ? '#ef4444' : '#EBC351',
                    borderRadius: 12, left: editingSub?.status === 'Paused' ? '50%' : 4, transition: 'left 0.3s'
                  }} />
                  {(['Active', 'Paused'] as const).map(s => (
                    <TouchableOpacity key={s} onPress={() => updateSub({ status: s })} style={{ flex: 1, paddingVertical: 10, alignItems: 'center', zIndex: 1 }}>
                      <Text style={{ color: editingSub?.status === s ? (s === 'Paused' ? '#fff' : '#000') : 'rgba(255,255,255,0.4)', fontWeight: '900', fontSize: 10, textTransform: 'uppercase', letterSpacing: 2 }}>{s}</Text>
                    </TouchableOpacity>
                  ))}
                </View>
              </View>

              {/* Paid From + Auto Pay (paid only) */}
              {editingSub?.pricingModel !== 'free' && (
                <View style={{ flexDirection: 'row', gap: 12 }}>
                  <View style={{ flex: 1 }}>
                    <Text style={styles.modalLabel}>Paid From</Text>
                    <TextInput style={styles.modalInput} value={editingSub?.paymentMethod || ''} placeholder="Partner's card..." placeholderTextColor="rgba(255,255,255,0.2)" onChangeText={t => updateSub({ paymentMethod: t })} />
                  </View>
                  <View style={{ flex: 1 }}>
                    <Text style={styles.modalLabel}>Auto Pay</Text>
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
              <View>
                <Text style={styles.modalLabel}>Notes</Text>
                <TextInput
                  style={[styles.modalInput, { minHeight: 80, textAlignVertical: 'top' }]}
                  value={editingSub?.notes || ''} placeholder="Add any specific notes..."
                  placeholderTextColor="rgba(255,255,255,0.2)" multiline
                  onChangeText={t => updateSub({ notes: t })}
                />
              </View>

              {/* Security & Recovery */}
              <View style={{ borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.05)', paddingTop: 16 }}>
                <TouchableOpacity onPress={() => setExpandedSecurity(p => !p)} style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: expandedSecurity ? 16 : 0 }}>
                  <Text style={styles.modalLabel}>Security & Recovery</Text>
                  <Ionicons name={expandedSecurity ? 'chevron-up' : 'chevron-down'} size={14} color="rgba(255,255,255,0.3)" />
                </TouchableOpacity>
                {expandedSecurity && (
                  <View style={{ flexDirection: 'row', gap: 12 }}>
                    <View style={{ flex: 1 }}>
                      <Text style={styles.modalLabel}>2FA Method</Text>
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
                    <View style={{ flex: 1 }}>
                      <Text style={styles.modalLabel}>Recovery</Text>
                      <TextInput style={styles.modalInput} value={editingSub?.recoveryMethod || ''} placeholder="Phone, email, backup codes..." placeholderTextColor="rgba(255,255,255,0.2)" onChangeText={t => updateSub({ recoveryMethod: t })} />
                    </View>
                  </View>
                )}
              </View>

              {/* Sub-Services Manager */}
              <View style={{ borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.05)', paddingTop: 24 }}>
                <TouchableOpacity onPress={addSubService} style={{ height: 60, backgroundColor: 'rgba(0,0,0,0.2)', borderRadius: 12, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 12, marginBottom: 12 }}>
                  <Text style={{ fontSize: 20 }}>💾</Text>
                  <Text style={{ color: 'rgba(255,255,255,0.6)', fontWeight: '700', fontSize: 11, textTransform: 'uppercase', letterSpacing: 2 }}>Add Supplemental Service</Text>
                </TouchableOpacity>

                {(editingSub?.subServices || []).map((child, idx) => {
                  const eid = child.id || String(idx);
                  const isOpen = expandedModalSubServices.has(eid);
                  return (
                    <View key={eid} style={{ backgroundColor: 'rgba(0,0,0,0.2)', borderRadius: 12, borderWidth: 1, borderColor: 'rgba(255,255,255,0.03)', marginBottom: 8, overflow: 'hidden' }}>
                      <TouchableOpacity onPress={() => setExpandedModalSubServices(prev => toggle(prev, eid))}
                        style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 16, height: 47 }}>
                        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
                          <TouchableOpacity onPress={() => removeSubService(idx)}>
                            <Ionicons name="close" size={16} color="rgba(255,255,255,0.2)" />
                          </TouchableOpacity>
                          <Text style={{ color: '#fff', fontSize: 13, fontWeight: '500' }}>{child.name || 'New Service'}</Text>
                          <Text style={{ color: 'rgba(255,255,255,0.2)', fontSize: 10 }}>|</Text>
                          <View style={{ width: 6, height: 6, borderRadius: 3, backgroundColor: child.status === 'Paused' ? '#ef4444' : '#1FE400' }} />
                          <Text style={{ color: child.status === 'Paused' ? '#ef4444' : '#1FE400', fontSize: 10, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 1 }}>{child.status}</Text>
                        </View>
                        <Ionicons name={isOpen ? 'chevron-up' : 'chevron-down'} size={14} color="rgba(255,255,255,0.3)" />
                      </TouchableOpacity>

                      {isOpen && (
                        <View style={{ padding: 16, borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.05)', gap: 12 }}>
                          {/* Name + Status */}
                          <View style={{ flexDirection: 'row', gap: 12 }}>
                            <View style={{ flex: 1 }}>
                              <Text style={styles.modalLabel}>Service Name</Text>
                              <TextInput style={styles.modalInput} value={child.name} placeholder="Storage, Analytics..." placeholderTextColor="rgba(255,255,255,0.2)" onChangeText={t => updateSubService(idx, { name: t })} />
                            </View>
                            <View style={{ width: 120 }}>
                              <Text style={styles.modalLabel}>Status</Text>
                              <View style={{ flexDirection: 'row', backgroundColor: 'rgba(0,0,0,0.4)', borderRadius: 8, overflow: 'hidden', borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', height: 38, alignItems: 'center' }}>
                                {(['Active', 'Paused'] as const).map(s => (
                                  <TouchableOpacity key={s} onPress={() => updateSubService(idx, { status: s })}
                                    style={{ flex: 1, alignItems: 'center', paddingVertical: 8, backgroundColor: child.status === s ? '#EBC351' : 'transparent' }}>
                                    <Text style={{ color: child.status === s ? '#000' : 'rgba(255,255,255,0.3)', fontWeight: '900', fontSize: 9, textTransform: 'uppercase', letterSpacing: 1 }}>{s}</Text>
                                  </TouchableOpacity>
                                ))}
                              </View>
                            </View>
                          </View>
                          {/* Cost + Cycle + Auto Pay */}
                          <View style={{ flexDirection: 'row', gap: 12 }}>
                            <View style={{ flex: 1 }}>
                              <Text style={styles.modalLabel}>Cost</Text>
                              <TextInput style={styles.modalInput} value={child.cost?.toString() || ''} placeholder="0.00" placeholderTextColor="rgba(255,255,255,0.2)" keyboardType="numeric" onChangeText={t => updateSubService(idx, { cost: parseFloat(t) || 0 })} />
                            </View>
                            <View style={{ flex: 1 }}>
                              <Text style={styles.modalLabel}>Cycle</Text>
                              <View style={{ flexDirection: 'row', backgroundColor: 'rgba(0,0,0,0.4)', borderRadius: 8, overflow: 'hidden', borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', height: 38, alignItems: 'center' }}>
                                {(['Monthly', 'Yearly'] as const).map(c => (
                                  <TouchableOpacity key={c} onPress={() => updateSubService(idx, { billingCycle: c })}
                                    style={{ flex: 1, alignItems: 'center', paddingVertical: 8, backgroundColor: child.billingCycle === c ? 'rgba(235,195,81,0.1)' : 'transparent' }}>
                                    <Text style={{ color: child.billingCycle === c ? '#EBC351' : 'rgba(255,255,255,0.4)', fontWeight: '900', fontSize: 9, textTransform: 'uppercase', letterSpacing: 1 }}>{c.slice(0, 2)}</Text>
                                  </TouchableOpacity>
                                ))}
                              </View>
                            </View>
                            <View style={{ flex: 1 }}>
                              <Text style={styles.modalLabel}>Auto Pay</Text>
                              <View style={{ flexDirection: 'row', backgroundColor: 'rgba(0,0,0,0.2)', borderRadius: 8, overflow: 'hidden', borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', height: 38, alignItems: 'center' }}>
                                {([['Auto', 'On'], ['Manual', 'Off']] as const).map(([val, label]) => (
                                  <TouchableOpacity key={val} onPress={() => updateSubService(idx, { autoPay: val })}
                                    style={{ flex: 1, alignItems: 'center', backgroundColor: (val === 'Auto' && child.autoPay !== 'Manual') ? '#EBC351' : val === 'Manual' && child.autoPay === 'Manual' ? 'rgba(255,255,255,0.08)' : 'transparent' }}>
                                    <Text style={{ color: (val === 'Auto' && child.autoPay !== 'Manual') ? '#000' : 'rgba(255,255,255,0.3)', fontWeight: '900', fontSize: 9, textTransform: 'uppercase', letterSpacing: 2, paddingVertical: 12 }}>{label}</Text>
                                  </TouchableOpacity>
                                ))}
                              </View>
                            </View>
                          </View>
                          {/* Purpose */}
                          <View>
                            <Text style={styles.modalLabel}>Purpose</Text>
                            <TextInput style={[styles.modalInput, { minHeight: 50, textAlignVertical: 'top' }]} value={child.purpose || ''} placeholder="Backup storage, processing..." placeholderTextColor="rgba(255,255,255,0.2)" multiline onChangeText={t => updateSubService(idx, { purpose: t })} />
                          </View>
                        </View>
                      )}
                    </View>
                  );
                })}
              </View>

              {/* Linked Emails Manager */}
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
                      <TouchableOpacity onPress={() => setExpandedModalEmails(prev => toggle(prev, eid))}
                        style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 16, height: 47 }}>
                        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
                          <TouchableOpacity onPress={() => removeLinkedEmail(idx)}>
                            <Ionicons name="close" size={16} color="rgba(255,255,255,0.2)" />
                          </TouchableOpacity>
                          <Text style={{ color: '#fff', fontSize: 13, fontWeight: '500' }}>{email.email || 'New Email Address'}</Text>
                        </View>
                        <Ionicons name={isOpen ? 'chevron-up' : 'chevron-down'} size={14} color="rgba(255,255,255,0.3)" />
                      </TouchableOpacity>

                      {isOpen && (
                        <View style={{ padding: 16, borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.05)', gap: 12 }}>
                          <View style={{ flexDirection: 'row', gap: 12 }}>
                            <View style={{ flex: 1 }}>
                              <Text style={styles.modalLabel}>Email Address</Text>
                              <TextInput style={styles.modalInput} value={email.email} placeholder="email@example.com" placeholderTextColor="rgba(255,255,255,0.2)" autoCapitalize="none" keyboardType="email-address" onChangeText={t => updateLinkedEmail(idx, { email: t })} />
                            </View>
                            <View style={{ flex: 1 }}>
                              <Text style={styles.modalLabel}>Used For</Text>
                              <TextInput style={styles.modalInput} value={email.usedFor} placeholder="Personal use" placeholderTextColor="rgba(255,255,255,0.2)" onChangeText={t => updateLinkedEmail(idx, { usedFor: t })} />
                            </View>
                          </View>
                          <View style={{ flexDirection: 'row', gap: 12 }}>
                            <View style={{ flex: 1 }}>
                              <Text style={styles.modalLabel}>Provider</Text>
                              <TextInput style={styles.modalInput} value={email.forwarding} placeholder="Google Workspace" placeholderTextColor="rgba(255,255,255,0.2)" onChangeText={t => updateLinkedEmail(idx, { forwarding: t })} />
                            </View>
                            <View style={{ flex: 1 }}>
                              <Text style={styles.modalLabel}>Access Method</Text>
                              <TextInput style={styles.modalInput} value={email.accessMethod} placeholder="Gmail, Apple Mail" placeholderTextColor="rgba(255,255,255,0.2)" onChangeText={t => updateLinkedEmail(idx, { accessMethod: t })} />
                            </View>
                          </View>
                          <View>
                            <Text style={styles.modalLabel}>Notes</Text>
                            <TextInput
                              style={[styles.modalInput, { minHeight: 80, textAlignVertical: 'top' }]}
                              value={(email.notes || []).join('\n')}
                              placeholder="Main email used for..."
                              placeholderTextColor="rgba(255,255,255,0.2)"
                              multiline
                              onChangeText={t => updateLinkedEmail(idx, { notes: t.split('\n') })}
                            />
                          </View>
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
                      <TouchableOpacity onPress={handleDelete}><Text style={{ color: '#fff', fontSize: 10, fontWeight: '900', textTransform: 'uppercase' }}>Yes</Text></TouchableOpacity>
                      <TouchableOpacity onPress={() => setShowDeleteConfirm(false)}><Text style={{ color: 'rgba(255,255,255,0.3)', fontSize: 10, fontWeight: '900', textTransform: 'uppercase' }}>No</Text></TouchableOpacity>
                    </View>
                  ) : (
                    <TouchableOpacity onPress={() => setShowDeleteConfirm(true)}>
                      <Text style={{ color: 'rgba(255,255,255,0.2)', fontSize: 10, fontWeight: '900', textTransform: 'uppercase', letterSpacing: 2 }}>Delete</Text>
                    </TouchableOpacity>
                  )
                )}
              </View>
              <View style={{ flexDirection: 'row', gap: 16, alignItems: 'center' }}>
                <TouchableOpacity onPress={() => setEditingSub(null)}>
                  <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 11, fontWeight: '900', textTransform: 'uppercase', letterSpacing: 2 }}>Cancel</Text>
                </TouchableOpacity>
                <TouchableOpacity onPress={handleSave} style={{ backgroundColor: '#EBC351', borderRadius: 16, paddingHorizontal: 24, paddingVertical: 12 }}>
                  <Text style={{ color: '#000', fontSize: 11, fontWeight: '900', textTransform: 'uppercase', letterSpacing: 2 }}>Save Account</Text>
                </TouchableOpacity>
              </View>
            </View>
          </View>
        </KeyboardAvoidingView>
      </Modal>
    </SafeAreaView>
  );
}

const styles = {
  fieldLabel: {
    color: 'rgba(255,255,255,0.4)', fontSize: 11, fontWeight: '700' as const,
    textTransform: 'uppercase' as const, letterSpacing: 2, marginBottom: 6
  },
  inlineInput: {
    backgroundColor: 'rgba(0,0,0,0.3)', borderRadius: 8, paddingHorizontal: 12, paddingVertical: 8,
    borderWidth: 1, borderColor: 'rgba(255,255,255,0.03)', color: '#fff', fontSize: 13, fontWeight: '500' as const
  },
  modalLabel: {
    color: 'rgba(255,255,255,0.4)', fontSize: 11, fontWeight: '700' as const,
    textTransform: 'uppercase' as const, letterSpacing: 2, marginBottom: 6, marginLeft: 4
  },
  modalInput: {
    backgroundColor: 'rgba(0,0,0,0.2)', borderRadius: 8, paddingHorizontal: 12, paddingVertical: 10,
    borderWidth: 1, borderColor: 'rgba(255,255,255,0.03)', color: '#fff', fontSize: 13, fontWeight: '500' as const
  }
};
