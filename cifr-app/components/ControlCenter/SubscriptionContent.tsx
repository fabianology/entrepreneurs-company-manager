import React, { useState } from 'react';
import { View, Text, TouchableOpacity, Image, TextInput, Clipboard } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useAppContext } from '../../context/AppContext';
import { Subscription } from '../../types';
import { getFaviconUrl } from '../../services/logoService';

interface SubscriptionContentProps {
  onEditSubscription: (sub: Subscription) => void;
  onNewSubscription: () => void;
  onOpenPaidFromPicker: (companyId: string | null, currentValue: string, cb: (v: string) => void) => void;
}

const toggle = (set: Set<string>, id: string): Set<string> => {
  const n = new Set(set);
  n.has(id) ? n.delete(id) : n.add(id);
  return n;
};

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

export default function SubscriptionContent({ onEditSubscription, onNewSubscription, onOpenPaidFromPicker }: SubscriptionContentProps) {
  const { state, selectedCompanyId, handleUpdateSubscription, subMetrics } = useAppContext();
  
  const [expandedSubs, setExpandedSubs] = useState<Set<string>>(new Set());
  const [expandedEmails, setExpandedEmails] = useState<Set<string>>(new Set());
  const [expandedCardDetails, setExpandedCardDetails] = useState<Set<string>>(new Set());
  const [visiblePasswords, setVisiblePasswords] = useState<Set<string>>(new Set());
  const [lastCopied, setLastCopied] = useState<{ id: string; field: string } | null>(null);

  if (!state) return null;

  const subscriptions = selectedCompanyId
    ? state.subscriptions.filter(s => s.companyId === selectedCompanyId)
    : state.subscriptions;

  const handleCopy = (id: string, text: string, field: string) => {
    if (!text) return;
    Clipboard.setString(text);
    setLastCopied({ id, field });
    setTimeout(() => setLastCopied(null), 2000);
  };
  
  if (subscriptions.length === 0) {
    return (
      <TouchableOpacity onPress={onNewSubscription} style={{ borderWidth: 1, borderStyle: 'dashed', borderColor: 'rgba(255,255,255,0.2)', padding: 40, borderRadius: 32, alignItems: 'center', backgroundColor: 'rgba(28,28,30,0.5)' }}>
        <Text style={{ fontSize: 28, marginBottom: 16 }}>🌐</Text>
        <Text style={{ color: 'rgba(255,255,255,0.4)', fontWeight: '900', fontSize: 10, letterSpacing: 3, textTransform: 'uppercase' }}>+ Add Your First Service</Text>
      </TouchableOpacity>
    );
  }

  return (
    <>
      {subscriptions.map(sub => {
        const isCardExpanded = expandedCardDetails.has(sub.id);
        const isSubsExpanded = expandedSubs.has(sub.id);
        const isEmailsExpanded = expandedEmails.has(sub.id);
        const totals = calcTotals(sub);

        return (
          <View key={sub.id} style={{ backgroundColor: '#1C1C1E', borderRadius: 24, borderWidth: 1, borderColor: 'rgba(255,255,255,0.05)', marginBottom: 16, overflow: 'hidden' }}>

            {/* ---- Card Top: tapping opens edit modal ---- */}
            <TouchableOpacity
              activeOpacity={0.85}
              onPress={() => onEditSubscription(sub)}
              style={{ padding: 24, paddingBottom: sub.pricingModel === 'free' ? 18 : 2 }}
            >
              <View style={{ flexDirection: 'row', alignItems: 'flex-start', marginBottom: 12 }}>
                {/* Logo */}
                <View style={{ width: 56, height: 56, backgroundColor: 'rgba(255,255,255,0.05)', borderRadius: 16, alignItems: 'center', justifyContent: 'center', marginRight: 16, overflow: 'hidden' }}>
                  {getFaviconUrl(sub.website) ? (
                    <Image
                      source={{ uri: getFaviconUrl(sub.website)! }}
                      style={{ width: 36, height: 36 }}
                      resizeMode="contain"
                    />
                  ) : (
                    <Text style={{ color: '#fff', fontWeight: '900', fontSize: 22, opacity: 0.8 }}>{sub.name.charAt(0)}</Text>
                  )}
                </View>

                {/* Name + Cost */}
                <View style={{ flex: 1 }}>
                  <Text style={{ color: '#fff', fontWeight: '600', fontSize: 17, letterSpacing: 0, marginBottom: 4 }}>{sub.name}</Text>
                  {sub.pricingModel !== 'free' && (
                    <View style={{ flexDirection: 'row', gap: 16, marginTop: 4 }}>
                      <View>
                        <Text style={{ color: '#fff', fontWeight: '700', fontSize: 15 }}>${totals.primary.toFixed(2)}</Text>
                        <Text style={{ color: 'rgba(255,255,255,0.4)', fontWeight: '500', fontSize: 11, letterSpacing: 0, marginTop: 1 }}>{totals.primaryLabel}</Text>
                      </View>
                      {totals.secondary > 0 && (
                        <>
                          <View style={{ width: 1, backgroundColor: 'rgba(255,255,255,0.05)', marginVertical: 2 }} />
                          <View>
                            <Text style={{ color: '#fff', fontWeight: '700', fontSize: 15 }}>${totals.secondary.toFixed(2)}</Text>
                            <Text style={{ color: 'rgba(255,255,255,0.4)', fontWeight: '500', fontSize: 11, letterSpacing: 0, marginTop: 1 }}>{totals.secondaryLabel}</Text>
                          </View>
                        </>
                      )}
                      <View style={{ width: 1, backgroundColor: 'rgba(255,255,255,0.05)', marginVertical: 2 }} />
                      <View>
                        <Text style={{ color: '#fff', fontWeight: '700', fontSize: 15 }}>${totals.totalAnnual.toFixed(2)}</Text>
                        <Text style={{ color: 'rgba(255,255,255,0.4)', fontWeight: '500', fontSize: 11, letterSpacing: 0, marginTop: 1 }}>est. yearly</Text>
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
                    <Text style={{ color: '#ef4444', fontSize: 11, fontWeight: '600', textTransform: 'uppercase', letterSpacing: 0.3 }}>Paused</Text>
                  </>
                ) : (
                  <>
                    <View style={{ width: 6, height: 6, borderRadius: 3, backgroundColor: sub.renew === 'Manual' ? '#ef4444' : '#1FE400' }} />
                    <Text style={{ color: sub.renew === 'Manual' ? '#ef4444' : '#1FE400', fontSize: 11, fontWeight: '600', textTransform: 'uppercase', letterSpacing: 0.3 }}>
                      {sub.pricingModel === 'free' ? 'Free' : sub.renew === 'Manual' ? 'Manual' : 'Auto Renew'}
                    </Text>
                    <Text style={{ color: 'rgba(255,255,255,0.2)', fontSize: 10 }}>|</Text>
                    <Text style={{ color: '#1FE400', fontSize: 11, fontWeight: '600', textTransform: 'uppercase', letterSpacing: 0.3 }}>
                      {sub.pricingModel === 'free' ? 'Active' : 'Paid'}
                    </Text>
                    <Text style={{ color: 'rgba(255,255,255,0.2)', fontSize: 10 }}>|</Text>
                    <Text style={{ color: '#1FE400', fontSize: 11, fontWeight: '600', textTransform: 'uppercase', letterSpacing: 0.3 }}>{sub.status}</Text>
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
                  <Text style={{ color: lastCopied?.id === sub.id && lastCopied.field === 'login' ? '#f97316' : 'rgba(255,255,255,0.4)', fontSize: 12, fontWeight: '500', letterSpacing: 0, marginBottom: 6 }}>
                    {lastCopied?.id === sub.id && lastCopied.field === 'login' ? 'Copied ✓' : 'Login ID'}
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
                    <Text style={{ color: lastCopied?.id === sub.id && lastCopied.field === 'password' ? '#f97316' : 'rgba(255,255,255,0.4)', fontSize: 12, fontWeight: '500', letterSpacing: 0 }}>
                      {lastCopied?.id === sub.id && lastCopied.field === 'password' ? 'Copied ✓' : 'Password'}
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
                  <Text style={{ color: 'rgba(255,255,255,0.5)', fontSize: 14, fontWeight: '600', letterSpacing: 0.2 }}>
                    {isCardExpanded ? 'Less Details' : 'More Details'}
                  </Text>
                  <Ionicons name={isCardExpanded ? 'chevron-up' : 'chevron-down'} size={16} color="rgba(255,255,255,0.4)" />
                </TouchableOpacity>

                {isCardExpanded && (
                  <View style={{ paddingHorizontal: 24, paddingBottom: 24, flexDirection: 'row', flexWrap: 'wrap', gap: 16 }}>
                    <View style={{ flex: 1, minWidth: '40%' }}>
                      <Text style={styles.fieldLabel}>Paid From</Text>
                      <TouchableOpacity
                        style={[styles.inlineInput, { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', minHeight: 34 }]}
                        onPress={() => onOpenPaidFromPicker(sub.companyId, sub.paymentMethod || '', text => handleUpdateSubscription(sub.id, { paymentMethod: text }))}
                      >
                        <Text style={{ color: sub.paymentMethod ? '#fff' : 'rgba(255,255,255,0.2)', fontSize: 13, fontWeight: '500', flex: 1 }} numberOfLines={1}>
                          {sub.paymentMethod || 'Linked card...'}
                        </Text>
                        <Ionicons name="chevron-down" size={12} color="rgba(255,255,255,0.3)" />
                      </TouchableOpacity>
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
                <Text style={{ color: 'rgba(255,255,255,0.5)', fontSize: 14, fontWeight: '600', letterSpacing: 0.2 }}>
                  Supplemental Services <Text style={{ color: 'rgba(255,255,255,0.2)', fontSize: 13 }}>({sub.subServices?.length || 0})</Text>
                </Text>
                <Ionicons name={isSubsExpanded ? 'chevron-up' : 'chevron-down'} size={16} color="rgba(255,255,255,0.4)" />
              </TouchableOpacity>

              {isSubsExpanded && (
                <View style={{ paddingHorizontal: 24, paddingBottom: 24, gap: 12 }}>
                  {(sub.subServices || []).map((child, idx) => (
                    <TouchableOpacity
                      key={child.id || idx}
                      activeOpacity={0.7}
                      onPress={() => onEditSubscription(sub)}
                      style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}
                    >
                      <View style={{ flex: 1, flexDirection: 'column' }}>
                        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
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
                    </TouchableOpacity>
                  ))}
                  <TouchableOpacity onPress={() => onEditSubscription(sub)}>
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
                <Text style={{ color: 'rgba(255,255,255,0.5)', fontSize: 14, fontWeight: '600', letterSpacing: 0.2 }}>
                  Linked Emails <Text style={{ color: 'rgba(255,255,255,0.2)', fontSize: 13 }}>({sub.linkedEmails?.length || 0})</Text>
                </Text>
                <Ionicons name={isEmailsExpanded ? 'chevron-up' : 'chevron-down'} size={16} color="rgba(255,255,255,0.4)" />
              </TouchableOpacity>

              {isEmailsExpanded && (
                <View style={{ paddingHorizontal: 24, paddingBottom: 24, gap: 8 }}>
                  {(sub.linkedEmails || []).map((email, idx) => (
                    <TouchableOpacity key={email.id || idx} onPress={() => onEditSubscription(sub)} style={{ flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 8, borderTopWidth: idx === 0 ? 0 : 1, borderTopColor: 'rgba(255,255,255,0.05)' }}>
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
                  <TouchableOpacity onPress={() => onEditSubscription(sub)}>
                    <Text style={{ color: 'rgba(255,255,255,0.3)', fontSize: 10, fontWeight: '900', textTransform: 'uppercase', letterSpacing: 2, marginTop: 8 }}>+ add email</Text>
                  </TouchableOpacity>
                </View>
              )}
            </View>
          </View>
        );
      })}
    </>
  );
}

const styles = {
  fieldLabel: { color: 'rgba(255,255,255,0.4)', fontSize: 12, fontWeight: '500' as const, letterSpacing: 0, marginBottom: 4, marginLeft: 2 },
  inlineInput: { backgroundColor: 'rgba(0,0,0,0.2)', borderRadius: 8, paddingHorizontal: 12, paddingVertical: 8, borderWidth: 1, borderColor: 'rgba(255,255,255,0.03)', color: '#fff', fontSize: 13, fontWeight: '500' as const },
};
