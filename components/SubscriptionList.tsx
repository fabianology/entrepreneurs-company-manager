
import React, { useState, useRef } from 'react';
import { Subscription, SubService, Institution } from '../types';
import { getFaviconUrl } from '../services/logoService';
import { generateSubscriptionEmailPurpose } from '../services/geminiService';

interface SubscriptionListProps {
  subscriptions: Subscription[];
  institutions?: Institution[];
  globalEmails?: string[];
  onUpdateSubscription: (id: string, updates: Partial<Subscription>) => void;
  onAddSubscription?: (sub: Partial<Subscription>) => void;
  onDeleteSubscription?: (id: string) => void;
}

const SubscriptionList: React.FC<SubscriptionListProps> = ({
  subscriptions,
  institutions = [],
  globalEmails = [],
  onUpdateSubscription,
  onAddSubscription,
  onDeleteSubscription
}) => {
  const [editingSubscription, setEditingSubscription] = useState<Partial<Subscription> | null>(null);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [expandedSubs, setExpandedSubs] = useState<Set<string>>(new Set());
  const [expandedEmails, setExpandedEmails] = useState<Set<string>>(new Set());
  const [expandedDetails, setExpandedDetails] = useState<Set<string>>(new Set());
  const [expandedCardDetails, setExpandedCardDetails] = useState<Set<string>>(new Set());
  const [expandedModalSubServices, setExpandedModalSubServices] = useState<Set<string>>(new Set());
  const [expandedModalEmails, setExpandedModalEmails] = useState<Set<string>>(new Set());
  
  const paymentOptions = institutions.flatMap(inst => inst.accounts.map(acc => ({
    id: acc.id,
    label: `${acc.name} ${acc.last4 ? `(x${acc.last4})` : ''}`,
    type: acc.type
  })));
  
  const uniqueLoginIds = Array.from(new Set(subscriptions.map(s => s.loginId).filter((id): id is string => Boolean(id) && id.trim() !== '')));
  
  const getUsedInServices = (emailStr: string) => {
    if (!emailStr) return [];
    const normalized = emailStr.toLowerCase().trim();
    
    const results: { name: string, role: 'primary' | 'linked' }[] = [];
    const seen = new Set<string>();

    subscriptions.forEach(s => {
      const isPrimary = s.loginId?.toLowerCase().trim() === normalized;
      const isLinked = s.linkedEmails?.some(e => e.email?.toLowerCase().trim() === normalized);
      
      const sName = s.name || 'Unnamed Service';
      
      if (isPrimary || isLinked) {
        if (!seen.has(sName)) {
           results.push({
             name: sName,
             role: isPrimary ? 'primary' : 'linked'
           });
           seen.add(sName);
        }
      }
    });

    return results;
  };

  const [modalCustomPaymentMode, setModalCustomPaymentMode] = useState(false);
  const [inlineCustomPaymentIds, setInlineCustomPaymentIds] = useState<Set<string>>(new Set());
  const [expandedSecurity, setExpandedSecurity] = useState(false);
  const [lastCopiedField, setLastCopiedField] = useState<{ id: string, field: string } | null>(null);
  const [visiblePasswords, setVisiblePasswords] = useState<Set<string>>(new Set());
  const datePickerRef = useRef<HTMLInputElement>(null);

  const handleFieldCopy = (id: string, text: string, field: string, e: React.MouseEvent) => {
    e.stopPropagation();
    if (!text) return;
    navigator.clipboard.writeText(text);
    setLastCopiedField({ id, field });
    setTimeout(() => setLastCopiedField(null), 2000);
    if ('vibrate' in navigator) navigator.vibrate(30);
  };

  const togglePasswordVisibility = (id: string) => {
    const newSet = new Set(visiblePasswords);
    if (newSet.has(id)) newSet.delete(id);
    else newSet.add(id);
    setVisiblePasswords(newSet);
  };

  const handleAddNew = () => {
    setShowDeleteConfirm(false);
    setModalCustomPaymentMode(false);
    setExpandedModalSubServices(new Set());
    setExpandedModalEmails(new Set());
    setEditingSubscription({
      name: '',
      cost: 0,
      billingCycle: 'Monthly',
      status: 'Active',
      paymentMethod: '',
      nextRenewal: '',
      renew: 'Auto',
      subServices: [],
      loginId: '',
      password: '',
      twoFactorAuth: 'None',
      recoveryMethod: '',
      website: '',
      pricingModel: 'paid'
    });
  };

  const handleEditSubscription = (sub: Subscription) => {
    setShowDeleteConfirm(false);
    setExpandedModalSubServices(new Set());
    setExpandedModalEmails(new Set());
    setEditingSubscription(sub);
  };

  const toggleExpanded = (id: string) => {
    const newSet = new Set(expandedSubs);
    if (newSet.has(id)) newSet.delete(id);
    else newSet.add(id);
    setExpandedSubs(newSet);
  };

  const toggleEmailExpanded = (id: string) => {
    const newSet = new Set(expandedEmails);
    if (newSet.has(id)) newSet.delete(id);
    else newSet.add(id);
    setExpandedEmails(newSet);
  };

  const toggleDetailExpanded = (emailId: string) => {
    const newSet = new Set(expandedDetails);
    if (newSet.has(emailId)) newSet.delete(emailId);
    else newSet.add(emailId);
    setExpandedDetails(newSet);
  };

  const toggleModalSubService = (id: string, e?: React.MouseEvent) => {
    if (e) e.stopPropagation();
    const newSet = new Set(expandedModalSubServices);
    if (newSet.has(id)) newSet.delete(id);
    else newSet.add(id);
    setExpandedModalSubServices(newSet);
  };

  const toggleModalEmail = (id: string, e?: React.MouseEvent) => {
    if (e) e.stopPropagation();
    const newSet = new Set(expandedModalEmails);
    if (newSet.has(id)) newSet.delete(id);
    else newSet.add(id);
    setExpandedModalEmails(newSet);
  };

  const toggleCardDetails = (id: string) => {
    const newSet = new Set(expandedCardDetails);
    if (newSet.has(id)) newSet.delete(id);
    else newSet.add(id);
    setExpandedCardDetails(newSet);
  };

  const handleSaveModal = () => {
    if (editingSubscription) {
      const updates = { ...editingSubscription, lastUpdated: Date.now() };
      if (editingSubscription.id) {
        onUpdateSubscription(editingSubscription.id, updates);
      } else if (onAddSubscription) {
        onAddSubscription(updates);
      }
      setEditingSubscription(null);
    }
  };

  const handleAddSubService = () => {
    if (!editingSubscription) return;
    const newId = Math.random().toString(36).substr(2, 9);
    const newSub: SubService = {
      id: newId,
      name: '',
      cost: 0,
      billingCycle: 'Monthly',
      purpose: '',
      status: 'Active'
    };
    setEditingSubscription({
      ...editingSubscription,
      subServices: [...(editingSubscription.subServices || []), newSub]
    });
    setExpandedModalSubServices(prev => new Set(prev).add(newId));

    // Auto-scroll to the new service section
    setTimeout(() => {
      const element = document.getElementById(`sub-service-${newId}`);
      if (element) {
        element.scrollIntoView({ behavior: 'smooth', block: 'center' });
        element.style.boxShadow = '0 0 0 2px #EBC351';
        setTimeout(() => {
          element.style.boxShadow = 'none';
        }, 2000);
      }
    }, 100);
  };

  const formatDate = (ts?: number) => {
    if (!ts) return 'Unknown';
    const date = new Date(ts);
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
  };

  const handleQuickAddSubService = (sub: Subscription, e: React.MouseEvent) => {
    e.stopPropagation();
    setEditingSubscription(sub);
    // Add a small delay to ensure editingSubscription is set before handleAddSubService runs logic
    // Actually, setting state and then calling a function that uses that state is tricky.
    // Let's modify handleAddSubService to accept an optional base subscription.
  };

  const addSubServiceToSubscription = (sub: Subscription) => {
    const newSub: SubService = {
      id: Math.random().toString(36).substr(2, 9),
      name: '',
      cost: 0,
      billingCycle: 'Monthly',
      purpose: '',
      status: 'Active'
    };
    const updatedSub = {
      ...sub,
      subServices: [...(sub.subServices || []), newSub]
    };
    setEditingSubscription(updatedSub);
    
    // Scroll to the section in the modal
    setTimeout(() => {
      const element = document.getElementById('modal-supplemental-section');
      if (element) {
        element.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    }, 100);
  };

  const addEmailToSubscription = (sub: Subscription) => {
    const newEmail = {
      id: Math.random().toString(36).substr(2, 9),
      email: '',
      forwarding: '',
      usedFor: '',
      usedIn: '',
      accessMethod: '',
      notes: []
    };
    const updatedSub = {
      ...sub,
      linkedEmails: [...(sub.linkedEmails || []), newEmail]
    };
    setEditingSubscription(updatedSub);

    // Scroll to the section in the modal
    setTimeout(() => {
      const element = document.getElementById('modal-emails-section');
      if (element) {
        element.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    }, 100);
  };
  const { cycleMonthly, cycleYearly, monthlyCount, yearlyCount } = subscriptions.reduce((acc, s) => {
    // Check main subscription
    if (s.billingCycle === 'Monthly') {
      acc.cycleMonthly += s.cost;
      acc.monthlyCount += 1;
    } else if (s.billingCycle === 'Yearly') {
      acc.cycleYearly += s.cost;
      acc.yearlyCount += 1;
    }
    
    // Check sub-services
    s.subServices?.forEach(ss => {
      if (ss.status !== 'Paused') {
        if (ss.billingCycle === 'Monthly') {
          acc.cycleMonthly += ss.cost;
          acc.monthlyCount += 1;
        } else if (ss.billingCycle === 'Yearly') {
          acc.cycleYearly += ss.cost;
          acc.yearlyCount += 1;
        }
      }
    });
    
    return acc;
  }, { cycleMonthly: 0, cycleYearly: 0, monthlyCount: 0, yearlyCount: 0 });

  const activeStack = subscriptions.length;

  return (
    <div className="bg-black min-h-screen text-white p-4 space-y-5">
      {/* Action Bar - Minimalist Floating Style */}
      <div className="w-full h-10 flex items-center justify-between overflow-x-auto no-scrollbar flex-nowrap pb-1">
        <div className="flex items-center gap-4 shrink-0">
          <div className="flex items-center">
            <div className="flex items-center gap-1 mr-1.5">
              <span className="text-[22px] leading-none">💵</span>
              <span className="text-[16px] leading-none">🔥</span>
            </div>
            <div className="flex items-center gap-1">
              <span className="text-[14px] font-medium text-white/40 lowercase tracking-normal">mo.</span>
              <div className="flex items-baseline gap-1.5">
                <span className="text-[16px] font-semibold text-white uppercase tracking-normal">${cycleMonthly.toFixed(0)}</span>
                <span className="text-[12px] font-medium text-white/40 uppercase tracking-normal">({monthlyCount})</span>
              </div>
            </div>
            
            <div className="w-[1px] h-4 bg-white/10 mx-4"></div>

            <div className="flex items-center gap-1">
              <span className="text-[14px] font-medium text-white/40 lowercase tracking-normal">yr.</span>
              <div className="flex items-baseline gap-1.5">
                <span className="text-[16px] font-semibold text-white uppercase tracking-normal">${cycleYearly.toLocaleString()}</span>
                <span className="text-[12px] font-medium text-white/40 uppercase tracking-normal">({yearlyCount})</span>
              </div>
            </div>
          </div>
        </div>

        <button
          onClick={handleAddNew}
          className="h-full bg-[#1C1C1E] text-white px-6 rounded-full text-[13px] font-medium uppercase tracking-normal transition-all flex items-center space-x-2 active:scale-95 shrink-0 group"
        >
          <svg className="w-3.5 h-3.5 text-white/40 group-hover:text-[#EBC351] transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M12 4v16m8-8H4" /></svg>
          <span>Service</span>
        </button>
      </div>

      {/* Subscription cards List */}
      <div className="space-y-4">
        {subscriptions.length === 0 && (
          <button
            onClick={handleAddNew}
            className="w-full max-w-[400px] mx-auto h-[216px] rounded-[32px] border border-dashed border-white/20 flex flex-col items-center justify-center bg-[#1C1C1E]/50 hover:bg-[#1C1C1E] hover:border-[#EBC351]/50 transition-all duration-300 group shadow-2xl mt-4"
          >
            <div className="w-16 h-16 bg-white/5 rounded-full flex items-center justify-center mx-auto mb-4 group-hover:scale-110 transition-transform duration-300">
              <span className="text-2xl">🌐</span>
            </div>
            <span className="text-[10px] font-black text-white/60 group-hover:text-white uppercase tracking-[0.2em] transition-colors">+ Add Your First Service</span>
          </button>
        )}
        {subscriptions.map(sub => (
           <div key={sub.id} className="bg-[#1C1C1E] rounded-[24px] overflow-hidden border border-white/5 shadow-2xl transition-all duration-300">
              {/* Main Info */}
              <div 
                className={`px-6 pt-6 ${sub.pricingModel === 'free' ? 'pb-[18px]' : 'pb-[2px]'} space-y-6 cursor-pointer group/card transition-colors`}
                onClick={() => {
                  setExpandedModalSubServices(new Set());
                  setExpandedModalEmails(new Set());
                  setEditingSubscription(sub);
                }}
              >
                <div className="flex justify-between items-start">
                  <div className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-3 items-center w-full">
                    {/* Row 1, Col 1: Logo */}
                    <div className="w-14 h-14 bg-white/5 rounded-2xl flex items-center justify-center transition-all duration-300 overflow-hidden shadow-sm hover:bg-white/[0.08] col-start-1 row-start-1">
                        {sub.website ? (
                          <img
                            src={getFaviconUrl(sub.website) || ''}
                            className="w-8 h-8 object-contain"
                            alt=""
                            onError={(e) => {
                              (e.target as HTMLImageElement).style.display = 'none';
                              const fallback = (e.target as HTMLImageElement).nextElementSibling as HTMLElement;
                              if (fallback) fallback.style.display = 'flex';
                            }}
                          />
                        ) : null}
                        <span
                          className="text-white font-black text-xl opacity-80 group-hover/card:text-[#EBC351] transition-colors"
                          style={{ display: sub.website ? 'none' : 'flex' }}
                        >
                          {sub.name.charAt(0)}
                        </span>
                      </div>

                      {/* Row 2, Col 1+2: Status Row */}
                      <div className="flex items-center whitespace-nowrap col-span-2 row-start-2 mt-[6px]">
                        {sub.status === 'Paused' ? (
                          <div className="flex items-center space-x-1.5">
                            <div className="h-1.5 w-1.5 rounded-full bg-red-500 shadow-[0_0_6px_rgba(239,68,68,0.6)]"></div>
                            <span className="text-red-500 text-[11px] font-medium uppercase tracking-widest">Paused</span>
                          </div>
                        ) : (
                          <div className="flex items-center space-x-2 text-[11px] font-medium uppercase tracking-widest">
                            {sub.pricingModel !== 'free' ? (
                              <>
                                <div className="flex items-center space-x-1.5">
                                  <div className={`h-1.5 w-1.5 rounded-full ${sub.renew === 'Manual' ? 'bg-red-500 shadow-[0_0_6px_rgba(239,68,68,0.6)]' : 'bg-[#1FE400] shadow-[0_0_6px_#1FE400]'}`}></div>
                                  <span className={sub.renew === 'Manual' ? 'text-red-500' : 'text-[#1FE400]'}>
                                    {sub.renew === 'Manual' ? 'Manual' : 'Auto Renew'}
                                  </span>
                                </div>
                                <span className="text-white/20 px-1 opacity-50">|</span>
                                <span className="text-[#1FE400]">Paid</span>
                                <span className="text-white/20 px-1 opacity-50">|</span>
                                <span className="text-[#1FE400]">{sub.status}</span>
                              </>
                            ) : (
                              <>
                                <div className="flex items-center space-x-1.5">
                                  <div className="h-1.5 w-1.5 rounded-full bg-[#1FE400] shadow-[0_0_6px_#1FE400]"></div>
                                  <span className="text-[#1FE400]">Free</span>
                                </div>
                                <span className="text-white/20 px-1 opacity-50">|</span>
                                <span className="text-[#1FE400]">{sub.status}</span>
                              </>
                            )}
                          </div>
                        )}
                      </div>
                    

                    {/* Row 1, Col 2: Name + Amounts */}
                    <div className="flex flex-col col-start-2 row-start-1">
                        <a 
                          href={sub.website ? (sub.website.startsWith('http') ? sub.website : `https://${sub.website}`) : '#'} 
                          target="_blank" 
                          rel="noreferrer"
                          className="flex items-center gap-2 group/name w-fit"
                          onClick={(e) => e.stopPropagation()}
                        >
                          <h3 className="text-base font-bold tracking-tight text-white uppercase group-hover/name:text-[#EBC351] transition-colors leading-none">{sub.name}</h3>
                          {sub.website && (
                            <svg className="w-3.5 h-3.5 text-white/20 group-hover/name:text-[#EBC351]/50 transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" /></svg>
                          )}
                        </a>
                        
                        {sub.pricingModel !== 'free' && (() => {
                          const monthlyTotal = (sub.billingCycle === 'Monthly' ? sub.cost : 0) + (sub.subServices?.reduce((sum, ss) => {
                            if (ss.status === 'Paused') return sum;
                            return ss.billingCycle === 'Monthly' ? sum + ss.cost : sum;
                          }, 0) || 0);

                          const yearlyTotal = (sub.billingCycle === 'Yearly' ? sub.cost : 0) + (sub.subServices?.reduce((sum, ss) => {
                            if (ss.status === 'Paused') return sum;
                            return ss.billingCycle === 'Yearly' ? sum + ss.cost : sum;
                          }, 0) || 0);

                          const primaryTotal = sub.billingCycle === 'Monthly' ? monthlyTotal : yearlyTotal;
                          const primaryLabel = sub.billingCycle === 'Monthly' ? 'recur/ mo.' : 'recur/ yr.';
                          const secondaryTotal = sub.billingCycle === 'Monthly' ? yearlyTotal : monthlyTotal;
                          const secondaryLabel = sub.billingCycle === 'Monthly' ? 'recur/ yr.' : 'recur/ mo.';

                          const totalAnnual = (monthlyTotal * 12) + yearlyTotal;

                          return (
                            <div className="mt-[5px] flex items-start gap-3">
                              <div className="flex flex-col">
                                <p className="text-base font-bold text-white leading-tight">
                                  ${primaryTotal.toFixed(2)}
                                </p>
                                <p className="text-[10px] text-white/40 font-black uppercase tracking-widest mt-0.5">{primaryLabel}</p>
                              </div>
                              
                              {secondaryTotal > 0 && (
                                <>
                                  <div className="h-8 w-[1px] bg-white/5 mt-1"></div>
                                  <div className="flex flex-col">
                                    <p className="text-base font-bold text-white leading-tight">${secondaryTotal.toFixed(2)}</p>
                                    <p className="text-[9px] text-white/40 font-black uppercase tracking-widest mt-0.5">{secondaryLabel}</p>
                                  </div>
                                </>
                              )}

                              <div className="h-8 w-[1px] bg-white/5 mt-1"></div>
                              <div className="flex flex-col">
                                <p className="text-base font-bold text-white leading-tight">${totalAnnual.toFixed(2)}</p>
                                <p className="text-[9px] text-white/40 font-black uppercase tracking-widest mt-0.5">est. yearly cost</p>
                              </div>
                            </div>
                          );
                        })()}
                    </div>
                  </div>
                  <div className="text-right flex flex-col items-end space-y-1">
                    {/* Placeholder for top-right space */}
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-y-6 gap-x-4 pt-2">
                  <div 
                    className="space-y-1 group/field cursor-pointer active:opacity-60 transition-opacity"
                    onClick={(e) => handleFieldCopy(sub.id, sub.loginId || '', 'login', e)}
                  >
                    <p className={`text-[12px] font-bold uppercase tracking-widest transition-colors duration-300 ${lastCopiedField?.id === sub.id && lastCopiedField.field === 'login' ? 'text-orange-500' : 'text-white/40'}`}>
                      {lastCopiedField?.id === sub.id && lastCopiedField.field === 'login' ? 'Copied' : 'Login ID'}
                    </p>
                    <div className="mt-1 bg-black/20 rounded-lg px-3 py-2 border border-white/[0.03]">
                      <p className="text-[13px] font-medium text-white truncate max-w-[140px]">{sub.loginId || '—'}</p>
                    </div>
                  </div>

                  <div 
                    className="space-y-1 group/pass cursor-pointer active:opacity-60 transition-opacity"
                    onClick={(e) => handleFieldCopy(sub.id, sub.password || '', 'password', e)}
                  >
                    <div className="flex items-center gap-2">
                      <p className={`text-[12px] font-bold uppercase tracking-widest transition-colors duration-300 ${lastCopiedField?.id === sub.id && lastCopiedField.field === 'password' ? 'text-orange-500' : 'text-white/40'}`}>
                        {lastCopiedField?.id === sub.id && lastCopiedField.field === 'password' ? 'Copied' : 'Password'}
                      </p>
                      <button 
                        onClick={(e) => { e.stopPropagation(); togglePasswordVisibility(sub.id); }} 
                        className="text-white/20 hover:text-[#EBC351] transition-colors"
                      >
                        {visiblePasswords.has(sub.id) ? (
                          <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268-2.943-9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" /></svg>
                        ) : (
                          <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268-2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542 7-4.477 0-8.268-2.943-9.542-7z" /></svg>
                        )}
                      </button>
                    </div>
                    <div className="mt-1 bg-black/20 rounded-lg px-3 py-2 border border-white/[0.03]">
                      <p className="text-[13px] font-medium text-white tracking-wider truncate">
                        {visiblePasswords.has(sub.id) ? (sub.password || '—') : '••••••••'}
                      </p>
                    </div>
                  </div>
                </div>
              </div>

            {/* Expand for Details - Full Width */}
            {sub.pricingModel !== 'free' && (
              <div>
                <button
                  onClick={(e) => { e.stopPropagation(); toggleCardDetails(sub.id); }}
                  className="w-full h-[47px] px-6 flex items-center justify-between text-white/40 group"
                >
                  <span className="text-[13px] font-medium uppercase tracking-[0.15em]">
                    {expandedCardDetails.has(sub.id) ? 'Collapse' : 'Expand for Details'}
                  </span>
                  <svg
                    className={`w-4 h-4 transform transition-transform duration-300 ${expandedCardDetails.has(sub.id) ? 'rotate-180' : ''}`}
                    fill="none" stroke="currentColor" viewBox="0 0 24 24"
                  >
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M19 9l-7 7-7-7" />
                  </svg>
                </button>

                {expandedCardDetails.has(sub.id) && (
                  <div className="px-6 pt-2 pb-6 grid grid-cols-2 gap-y-6 gap-x-4 animate-fadeIn">
                    <div className="space-y-1">
                      <p className="text-[12px] font-bold text-white/40 uppercase tracking-widest">Paid From</p>
                      {inlineCustomPaymentIds.has(sub.id) || (sub.paymentMethod && !paymentOptions.find(o => o.id === sub.paymentMethod)) ? (
                        <div className="relative">
                          <input
                            type="text"
                            defaultValue={sub.paymentMethod || ''}
                            onBlur={(e) => onUpdateSubscription(sub.id, { paymentMethod: e.target.value })}
                            placeholder="Partner's card..."
                            className="w-full bg-black/30 rounded-lg px-3 py-2 border border-white/[0.03] focus:border-[#EBC351]/30 focus:outline-none text-[13px] font-medium text-white placeholder-white/30 transition-all pr-8"
                          />
                          <button 
                            className="absolute right-2 top-2 w-5 h-5 flex items-center justify-center text-white/40 hover:text-white transition-colors"
                            onClick={() => {
                               const newSet = new Set(inlineCustomPaymentIds);
                               newSet.delete(sub.id);
                               setInlineCustomPaymentIds(newSet);
                               onUpdateSubscription(sub.id, { paymentMethod: '' });
                            }}
                          >
                            <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M6 18L18 6M6 6l12 12" /></svg>
                          </button>
                        </div>
                      ) : (
                        <select
                          value={sub.paymentMethod || ''}
                          onChange={(e) => {
                             if (e.target.value === '_custom_new') {
                               const newSet = new Set(inlineCustomPaymentIds);
                               newSet.add(sub.id);
                               setInlineCustomPaymentIds(newSet);
                             } else {
                               onUpdateSubscription(sub.id, { paymentMethod: e.target.value });
                             }
                          }}
                          className="w-full bg-black/30 rounded-lg px-3 py-2 border border-white/[0.03] focus:border-[#EBC351]/30 focus:outline-none text-[13px] font-medium text-white placeholder-white/10 transition-all appearance-none cursor-pointer"
                        >
                          <option value="">Linked cards</option>
                          {paymentOptions.map(o => (
                            <option key={o.id} value={o.id} className="bg-[#1C1C1E]">
                              {o.type === 'Credit' || o.type === 'Debit Card' ? '💳' : '🏦'} {o.label}
                            </option>
                          ))}
                          <option value="_custom_new" className="bg-[#1C1C1E] text-[#EBC351] font-bold">+ Enter Custom Card &hellip;</option>
                        </select>
                      )}
                    </div>
                    <div className="space-y-1">
                      <p className="text-[12px] font-bold text-white/40 uppercase tracking-widest">Due On</p>
                      <input
                        type="text"
                        defaultValue={sub.nextRenewal || ''}
                        onBlur={(e) => onUpdateSubscription(sub.id, { nextRenewal: e.target.value })}
                        placeholder="15th / EOM"
                        className="w-full bg-black/30 rounded-lg px-3 py-2 border border-white/[0.03] focus:border-[#EBC351]/30 focus:outline-none text-[13px] font-medium text-white placeholder-white/10 transition-all"
                      />
                    </div>
                    <div className="col-span-2 space-y-1">
                      <p className="text-[12px] font-bold text-white/40 uppercase tracking-widest">Notes</p>
                      <textarea
                        defaultValue={sub.notes || ''}
                        onBlur={(e) => onUpdateSubscription(sub.id, { notes: e.target.value })}
                        placeholder="Add critical notes here..."
                        rows={2}
                        className="w-full bg-black/30 rounded-lg px-3 py-2 border border-white/[0.03] focus:border-[#EBC351]/30 focus:outline-none text-[13px] font-medium text-white/80 placeholder-white/10 transition-all resize-none leading-relaxed"
                      />
                    </div>
                  </div>
                )}
              </div>
            )}

            {/* Supplemental Services Accordion */}
            <div className="border-t border-white/5">
              <button
                onClick={() => toggleExpanded(sub.id)}
                className="w-full h-[47px] px-6 flex items-center justify-between text-white/40 group"
              >
                <div className="flex items-center">
                  <span className="text-[13px] font-medium uppercase tracking-[0.15em]">Supplemental Services <span className="text-white/20">({sub.subServices?.length || 0})</span></span>
                </div>
                <svg className={`w-4 h-4 transform transition-transform duration-300 ${expandedSubs.has(sub.id) ? 'rotate-180' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M19 9l-7 7-7-7" />
                </svg>
              </button>

              {expandedSubs.has(sub.id) && sub.subServices && (
                <div className="px-6 pb-6 space-y-4 animate-fadeIn">
                  {sub.subServices.map((child, idx) => (
                    <div key={idx} className="flex justify-between items-center group/item">
                      <div className="flex items-center space-x-3">
                        <div className={`h-1.5 w-1.5 rounded-full ${child.status === 'Paused' ? 'bg-red-500 shadow-[0_0_4px_rgba(239,68,68,0.8)]' : 'bg-[#1FE400] shadow-[0_0_4px_#1FE400]'} transition-all duration-300`}></div>
                        <span
                          onClick={(e) => {
                            e.stopPropagation();
                            setExpandedModalSubServices(new Set([child.id || String(idx)]));
                            setExpandedModalEmails(new Set());
                            setEditingSubscription(sub);
                            setTimeout(() => {
                              const element = document.getElementById(`sub-service-${child.id}`);
                              if (element) {
                                element.scrollIntoView({ behavior: 'smooth', block: 'center' });
                                // Add a temporary highlight effect
                                element.style.boxShadow = '0 0 0 2px #EBC351';
                                setTimeout(() => {
                                  element.style.boxShadow = 'none';
                                }, 2000);
                              }
                            }, 100);
                          }}
                          className="text-[13px] font-medium uppercase cursor-pointer hover:text-[#EBC351] transition-colors text-white/90"
                        >
                          {child.name}
                        </span>
                        <div className="flex items-center space-x-2">
                          <span className={`text-[11px] font-medium uppercase tracking-tighter opacity-80 ${child.status === 'Paused' ? 'text-red-500' : 'text-[#1FE400]'}`}>
                            {child.status}
                          </span>
                          <span className="text-white/20 text-[10px]">|</span>
                          <span className={`text-[11px] font-medium uppercase tracking-tighter opacity-80 ${(child.autoPay === 'Manual') ? 'text-red-500' : 'text-[#1FE400]'}`}>
                            {(child.autoPay === 'Manual') ? 'Manual' : 'Auto Pay'}
                          </span>
                        </div>
                      </div>
                      <span className={`text-[13px] font-medium ${child.status === 'Paused' ? 'text-white/20' : 'text-white'}`}>
                        ${child.cost.toFixed(2)}
                        <span className="text-[12px] text-white/40 ml-1 font-bold uppercase tracking-widest lowercase">
                          /{child.billingCycle === 'Yearly' ? 'yr' : 'mo'}
                        </span>
                      </span>
                    </div>
                  ))}
                  <button
                    onClick={() => addSubServiceToSubscription(sub)}
                    className="text-[10px] font-black text-white/30 uppercase tracking-widest pt-2 hover:text-[#EBC351] transition"
                  >
                    + add item
                  </button>
                </div>
              )}
            </div>

            {/* Linked Emails Accordion */}
            <div className="border-t border-white/5">
              <button
                onClick={() => toggleEmailExpanded(sub.id)}
                className="w-full h-[47px] px-6 flex items-center justify-between text-white/40 group bg-white/2"
              >
                <div className="flex items-center">
                  <span className="text-[13px] font-medium uppercase tracking-[0.15em]">Linked Emails <span className="text-white/20">({sub.linkedEmails?.length || 0})</span></span>
                </div>
                <svg className={`w-4 h-4 transform transition-transform duration-300 ${expandedEmails.has(sub.id) ? 'rotate-180' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M19 9l-7 7-7-7" /></svg>
              </button>

              {expandedEmails.has(sub.id) && (
                <div className="px-6 pb-8 space-y-1 animate-fadeIn">
                  {(sub.linkedEmails || []).map((email, idx) => {
                    const emailId = email.id || String(idx);
                    return (
                      <div key={emailId} className="pt-2 first:pt-0 border-t border-white/5 first:border-0 relative group/email">
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            setExpandedModalSubServices(new Set());
                            setExpandedModalEmails(new Set([emailId]));
                            setEditingSubscription(sub);
                            setTimeout(() => {
                              const element = document.getElementById(`linked-email-${emailId}`);
                              if (element) {
                                element.scrollIntoView({ behavior: 'smooth', block: 'center' });
                                // Add a temporary highlight effect
                                element.style.boxShadow = '0 0 0 2px #EBC351';
                                setTimeout(() => {
                                  element.style.boxShadow = 'none';
                                }, 2000);
                              }
                            }, 100);
                          }}
                          className="w-full text-left grid grid-cols-2 gap-x-8 py-2 rounded-xl px-4 -mx-4 cursor-pointer"
                        >
                          <div className="space-y-1">
                            <p className="text-[9px] font-black text-white/40 uppercase tracking-widest">Email</p>
                            <p className="text-xs font-black text-white truncate">{email.email}</p>
                          </div>
                          <div className="space-y-1">
                            <p className="text-[9px] font-black text-white/40 uppercase tracking-widest">Used For</p>
                            <p className="text-xs font-black text-white truncate">{email.usedFor}</p>
                          </div>
                        </button>
                      </div>
                    );
                  })}

                  <button
                    onClick={() => addEmailToSubscription(sub)}
                    className="text-[10px] font-black text-white/30 uppercase tracking-widest pt-2 hover:text-[#EBC351] transition"
                  >
                    + add email
                  </button>


                </div>
              )}
            </div>
          </div>
        ))}
      </div>

      {/* Editing Modal */}
      <datalist id="login-sweeps">
        {uniqueLoginIds.map((id, i) => <option key={i} value={id} />)}
      </datalist>
      <datalist id="email-sweeps">
        {globalEmails.map((email, i) => <option key={i} value={email} />)}
      </datalist>
      
      {editingSubscription && (
        <div className="fixed inset-0 z-50 flex items-start justify-center p-4 pb-[160px] bg-black/90 backdrop-blur-xl animate-fadeIn overflow-y-auto">
          <div className="bg-[#1C1C1E] rounded-[32px] shadow-2xl w-full max-w-xl border border-white/10 overflow-hidden">
            <div className="px-6 py-3 border-b border-white/5 flex justify-between items-center">
              <h3 className="text-base font-black tracking-tight text-white uppercase">
                {editingSubscription.id ? 'Edit Service' : 'New Service'}
              </h3>
              <button onClick={() => setEditingSubscription(null)} className="text-white/40 hover:text-white transition">
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M6 18L18 6M6 6l12 12" /></svg>
              </button>
            </div>

            <div className="p-8 space-y-6 max-h-[60vh] overflow-y-auto custom-scrollbar">
              <div className="flex justify-center pb-2">
                <div className="flex bg-black/40 p-1 rounded-full border border-white/5 min-w-[200px]">
                  <button
                    onClick={() => setEditingSubscription({ ...editingSubscription, pricingModel: 'free' })}
                    className={`py-2 px-6 rounded-full text-[10px] font-black uppercase tracking-widest transition-all shadow-sm flex-1 text-center ${editingSubscription.pricingModel === 'free' ? 'bg-[#EBC351] text-black shadow-lg shadow-[#EBC351]/20' : 'text-white/40 hover:text-white'}`}
                  >
                    Free
                  </button>
                  <button
                    onClick={() => setEditingSubscription({ ...editingSubscription, pricingModel: 'paid' })}
                    className={`py-2 px-6 rounded-full text-[10px] font-black uppercase tracking-widest transition-all shadow-sm flex-1 text-center ${editingSubscription.pricingModel === 'paid' || !editingSubscription.pricingModel ? 'bg-[#EBC351] text-black shadow-lg shadow-[#EBC351]/20' : 'text-white/40 hover:text-white'}`}
                  >
                    Paid
                  </button>
                </div>
              </div>

              <div className="space-y-2.5">
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-0.5">
                    <label className="text-[12px] font-bold uppercase tracking-widest text-white/40 ml-1">Subscription</label>
                    <input
                      className="w-full bg-black/20 border border-white/[0.03] rounded-lg px-3 py-2 text-[13px] font-medium text-white outline-none focus:border-[#EBC351]/50 transition"
                      value={editingSubscription.name || ''}
                      placeholder="Shopify"
                      onChange={e => setEditingSubscription({ ...editingSubscription, name: e.target.value })}
                    />
                  </div>
                  <div className="space-y-0.5">
                    <label className="text-[12px] font-bold uppercase tracking-widest text-white/40 ml-1">Website</label>
                    <input
                      className="w-full bg-black/20 border border-white/[0.03] rounded-lg px-3 py-2 text-[13px] font-medium text-white outline-none focus:border-[#EBC351]/50 transition"
                      value={editingSubscription.website || ''}
                      placeholder="shopify.com"
                      onChange={e => setEditingSubscription({ ...editingSubscription, website: e.target.value })}
                    />
                  </div>
                </div>
                
                {editingSubscription.pricingModel !== 'free' && (
                  <div className="grid grid-cols-3 gap-4">
                    <div className="space-y-0.5">
                      <label className="text-[12px] font-bold uppercase tracking-widest text-white/40 ml-1">Cost</label>
                      <div className="relative">
                        <span className="absolute left-3 top-1/2 -translate-y-1/2 text-white/30 text-[13px] font-medium">$</span>
                        <input
                          type="text"
                          className="w-full bg-black/20 border border-white/[0.03] rounded-lg pl-8 pr-3 py-2 text-[13px] font-medium text-white outline-none focus:border-[#EBC351]/50 transition"
                          value={editingSubscription.cost || ''}
                          placeholder="0.00"
                          onChange={e => setEditingSubscription({ ...editingSubscription, cost: parseFloat(e.target.value) || 0 })}
                        />
                      </div>
                    </div>
                    <div className="space-y-0.5">
                      <label className="text-[12px] font-bold uppercase tracking-widest text-white/40 ml-1">Due On</label>
                      <input
                        className="w-full bg-black/20 border border-white/[0.03] rounded-lg px-3 py-2 text-[13px] font-medium text-white outline-none focus:border-[#EBC351]/50 transition"
                        value={editingSubscription.nextRenewal || ''}
                        placeholder={editingSubscription.billingCycle === 'Yearly' ? 'MM/DD/YY' : '15th'}
                        onChange={e => {
                          let val = e.target.value;
                          if (editingSubscription.billingCycle === 'Yearly') {
                            val = val.replace(/\D/g, '').slice(0, 6);
                            if (val.length > 2) val = val.slice(0, 2) + '/' + val.slice(2);
                            if (val.length > 5) val = val.slice(0, 5) + '/' + val.slice(5);
                          }
                          setEditingSubscription({ ...editingSubscription, nextRenewal: val });
                        }}
                      />
                    </div>
                    <div className="space-y-0.5">
                      <label className="text-[12px] font-bold uppercase tracking-widest text-white/40 ml-1">Cycle</label>
                      <select
                        className="w-full bg-black/20 border border-white/[0.03] rounded-lg px-3 py-2 text-[13px] font-medium text-white outline-none focus:border-[#EBC351]/50 transition appearance-none cursor-pointer"
                        value={editingSubscription.billingCycle || 'Monthly'}
                        onChange={e => {
                          const newCycle = e.target.value as any;
                          if (newCycle !== editingSubscription.billingCycle) {
                            // Clear out the Due On date when changing cycles, since the format completely changes
                            setEditingSubscription({ ...editingSubscription, billingCycle: newCycle, nextRenewal: '' });
                          } else {
                            setEditingSubscription({ ...editingSubscription, billingCycle: newCycle });
                          }
                        }}
                      >
                        <option value="Monthly">Monthly</option>
                        <option value="Yearly">Yearly</option>
                      </select>
                    </div>
                  </div>
                )}
                
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-0.5">
                    <label className="text-[12px] font-bold uppercase tracking-widest text-white/40 ml-1">Login ID</label>
                    <input
                      list="login-sweeps"
                      className="w-full bg-black/20 border border-white/[0.03] rounded-lg px-3 py-2 text-[13px] font-medium text-white outline-none focus:border-[#EBC351]/50 transition"
                      value={editingSubscription.loginId || ''}
                      placeholder="admin"
                      onChange={e => setEditingSubscription({ ...editingSubscription, loginId: e.target.value })}
                      onBlur={e => {
                        const val = e.target.value.trim();
                        if (val.includes('@')) {
                          const currentEmails = editingSubscription.linkedEmails || [];
                          if (!currentEmails.some(em => em.email?.toLowerCase().trim() === val.toLowerCase())) {
                            const newId = Date.now().toString();
                            const newEmail = {
                              id: newId,
                              email: val,
                              usedFor: '',
                              usedIn: '',
                              accessMethod: '',
                              forwarding: '',
                              notes: ['This is the primary Login ID.']
                            };
                            setEditingSubscription({
                              ...editingSubscription,
                              linkedEmails: [...currentEmails, newEmail]
                            });
                            setExpandedModalEmails(prev => new Set(prev).add(newId));
                          }
                        }
                      }}
                    />
                  </div>
                  <div className="space-y-0.5">
                    <label className="text-[12px] font-bold uppercase tracking-widest text-white/40 ml-1">Password</label>
                    <input
                      type="password"
                      className="w-full bg-black/20 border border-white/[0.03] rounded-lg px-3 py-2 text-[13px] font-medium text-white outline-none focus:border-[#EBC351]/50 transition"
                      value={editingSubscription.password || ''}
                      placeholder="••••••••"
                      onChange={e => setEditingSubscription({ ...editingSubscription, password: e.target.value })}
                    />
                  </div>
                </div>

                <div className="flex justify-center pt-2">
                  <div className="bg-[#242426] p-1 rounded-2xl flex w-64 border border-white/5 relative">
                    <div 
                      className="absolute inset-y-1 w-[calc(50%-4px)] rounded-xl transition-all duration-300 ease-[cubic-bezier(0.16,1,0.3,1)]"
                      style={{ 
                        left: editingSubscription.status === 'Paused' ? 'calc(50% + 2px)' : '4px',
                        backgroundColor: editingSubscription.status === 'Paused' ? '#ef4444' : '#EBC351'
                      }}
                    />
                    <button
                      className={`flex-1 py-2 text-[10px] font-black uppercase tracking-widest transition-colors duration-300 relative z-10 ${editingSubscription.status !== 'Paused' ? 'text-black' : 'text-white/40'}`}
                      type="button"
                      onClick={() => setEditingSubscription({...editingSubscription, status: 'Active'})}
                    >
                      Active
                    </button>
                    <button
                      className={`flex-1 py-2 text-[10px] font-black uppercase tracking-widest transition-colors duration-300 relative z-10 ${editingSubscription.status === 'Paused' ? 'text-white' : 'text-white/40'}`}
                      type="button"
                      onClick={() => setEditingSubscription({...editingSubscription, status: 'Paused'})}
                    >
                      Paused
                    </button>
                  </div>
                </div>
                {editingSubscription.pricingModel !== 'free' && (
                  <div className="grid grid-cols-2 gap-4 items-end pb-2">
                    <div className="space-y-0.5">
                      <label className="text-[12px] font-bold uppercase tracking-widest text-white/40 ml-1">Paid From</label>
                      {modalCustomPaymentMode || (editingSubscription.paymentMethod && !paymentOptions.find(o => o.id === editingSubscription.paymentMethod)) ? (
                        <div className="relative">
                          <input
                            className="w-full bg-black/20 border border-white/[0.03] rounded-lg px-3 py-2 text-[13px] font-medium text-white outline-none focus:border-[#EBC351]/50 transition pr-8"
                            value={editingSubscription.paymentMethod || ''}
                            placeholder="e.g. Partner's external card"
                            onChange={e => setEditingSubscription({ ...editingSubscription, paymentMethod: e.target.value })}
                          />
                          <button 
                            className="absolute right-2 top-2 w-5 h-5 flex items-center justify-center text-white/40 hover:text-white transition-colors"
                            onClick={() => {
                               setModalCustomPaymentMode(false);
                               setEditingSubscription({ ...editingSubscription, paymentMethod: '' });
                            }}
                          >
                            <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M6 18L18 6M6 6l12 12" /></svg>
                          </button>
                        </div>
                      ) : (
                        <select
                          className="w-full bg-black/20 border border-white/[0.03] rounded-lg px-3 py-2 text-[13px] font-medium text-white outline-none focus:border-[#EBC351]/50 transition appearance-none cursor-pointer"
                          value={editingSubscription.paymentMethod || ''}
                          onChange={e => {
                             if (e.target.value === '_custom_new') setModalCustomPaymentMode(true);
                             else setEditingSubscription({ ...editingSubscription, paymentMethod: e.target.value });
                          }}
                        >
                          <option value="">Linked cards</option>
                          {paymentOptions.map(o => (
                            <option key={o.id} value={o.id} className="bg-[#1C1C1E]">
                              {o.type === 'Credit' || o.type === 'Debit Card' ? '💳' : '🏦'} {o.label}
                            </option>
                          ))}
                          <option value="_custom_new" className="bg-[#1C1C1E] text-[#EBC351] font-bold">+ Enter Custom Card &hellip;</option>
                        </select>
                      )}
                    </div>
                    <div className="space-y-0.5">
                      <label className="text-[12px] font-bold uppercase tracking-widest text-white/40 ml-1">Auto Pay</label>
                      <div className="flex items-center h-[36px]">
                        <div
                          className="relative flex items-center w-full bg-black/20 border border-white/[0.03] rounded-lg p-1 cursor-pointer select-none h-full"
                          onClick={() => setEditingSubscription({ ...editingSubscription, renew: editingSubscription.renew === 'Manual' ? 'Auto' : 'Manual' })}
                        >
                          <div
                            className="absolute top-1 bottom-1 w-[calc(50%-4px)] rounded-md transition-all duration-300 ease-[cubic-bezier(0.16,1,0.3,1)]"
                            style={{
                              left: editingSubscription.renew === 'Manual' ? 'calc(50% + 2px)' : '4px',
                              background: editingSubscription.renew === 'Manual' ? 'rgba(255,255,255,0.08)' : '#EBC351'
                            }}
                          />
                          <span className={`relative z-10 flex-1 text-center text-[10px] font-bold uppercase tracking-widest transition-colors duration-200 py-1 ${editingSubscription.renew !== 'Manual' ? 'text-black' : 'text-white/30'}`}>On</span>
                          <span className={`relative z-10 flex-1 text-center text-[10px] font-bold uppercase tracking-widest transition-colors duration-200 py-1 ${editingSubscription.renew === 'Manual' ? 'text-white' : 'text-white/30'}`}>Off</span>
                        </div>
                      </div>
                    </div>
                  </div>
                )}

                <div className="space-y-1 pt-2">
                  <label className="text-[12px] font-bold uppercase tracking-widest text-white/40 ml-1">Notes</label>
                  <div className="bg-black/20 border border-white/[0.03] rounded-lg px-4 py-1">
                    <textarea
                      rows={3}
                      style={{
                        backgroundImage: 'linear-gradient(to bottom, transparent 31px, rgba(255,255,255,0.1) 31px, rgba(255,255,255,0.1) 32px, transparent 32px, transparent 51px, rgba(255,255,255,0.1) 51px, rgba(255,255,255,0.1) 52px, transparent 52px, transparent 71px, rgba(255,255,255,0.1) 71px, rgba(255,255,255,0.1) 72px, transparent 72px)',
                        backgroundAttachment: 'local',
                        lineHeight: '20px'
                      }}
                      className="w-full py-3 bg-transparent border-none outline-none focus:ring-0 text-white text-[13px] font-medium transition-colors resize-none custom-scrollbar"
                      placeholder="Add any specific notes about this service..."
                      value={editingSubscription.notes || ''}
                      onChange={e => {
                        const val = e.target.value;
                        const lines = val.split('\n');
                        if (lines.length <= 3) {
                          setEditingSubscription({ ...editingSubscription, notes: val });
                        }
                      }}
                    />
                  </div>
                </div>

                {/* Security & Recovery Accordion */}
                <div className="pt-4 border-t border-white/5">
                  <button
                    type="button"
                    onClick={() => setExpandedSecurity(prev => !prev)}
                    className="w-full flex justify-between items-center mb-1 group"
                  >
                    <h4 className="text-[12px] font-bold text-white/40 uppercase tracking-widest ml-1 group-hover:text-white/60 transition-colors">
                      Security &amp; Recovery
                    </h4>
                    <svg
                      className={`w-3.5 h-3.5 text-white/30 transition-transform duration-300 ${expandedSecurity ? 'rotate-180' : ''}`}
                      fill="none" stroke="currentColor" viewBox="0 0 24 24"
                    >
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M19 9l-7 7-7-7" />
                    </svg>
                  </button>

                  {expandedSecurity && (
                    <div className="grid grid-cols-2 gap-4 mt-4 animate-fadeIn">
                      <div className="space-y-1">
                        <label className="text-[12px] font-bold uppercase tracking-widest text-white/40 ml-1">2FA</label>
                        <select
                          className="w-full bg-black/20 border border-white/[0.03] rounded-lg px-3 py-2 text-[13px] font-medium text-white outline-none focus:border-[#EBC351]/50 transition appearance-none cursor-pointer"
                          value={editingSubscription.twoFactorAuth || 'None'}
                          onChange={e => setEditingSubscription({ ...editingSubscription, twoFactorAuth: e.target.value })}
                        >
                          <option value="None">None</option>
                          <option value="Authenticator">Authenticator App</option>
                          <option value="SMS">SMS</option>
                          <option value="Email">Email</option>
                          <option value="Hardware Key">Hardware Key</option>
                          <option value="Backup Codes">Backup Codes</option>
                        </select>
                      </div>
                      <div className="space-y-1">
                        <label className="text-[12px] font-bold uppercase tracking-widest text-white/40 ml-1">Recovery</label>
                        <input
                          className="w-full bg-black/20 border border-white/[0.03] rounded-lg px-3 py-2 text-[13px] font-medium text-white outline-none focus:border-[#EBC351]/50 transition"
                          value={editingSubscription.recoveryMethod || ''}
                          placeholder="Phone, email, backup code..."
                          onChange={e => setEditingSubscription({ ...editingSubscription, recoveryMethod: e.target.value })}
                        />
                      </div>
                    </div>
                  )}
                </div>

                {/* Sub-services Management Section */}
                <div className="pt-8 border-t border-white/5" id="modal-supplemental-section">
                  <div className="flex justify-between items-center mb-6">
                    <h4 className="text-[12px] font-bold text-[#EBC351] uppercase tracking-widest ml-1">Supplemental Services</h4>
                    <button
                      type="button"
                      onClick={handleAddSubService}
                      className="text-[10px] font-bold text-[#EBC351] bg-[#EBC351]/10 px-3 py-1.5 rounded-lg hover:bg-[#EBC351]/20 transition"
                    >
                      + ADD SERVICE
                    </button>
                  </div>

                  <div className="space-y-1">
                    {(editingSubscription.subServices || []).map((child, idx) => {
                      const expandedId = child.id || String(idx);
                      const isExpanded = expandedModalSubServices.has(expandedId);
                      return (
                        <div key={expandedId} id={`sub-service-${expandedId}`} className="bg-black/20 rounded-lg flex flex-col group/sub relative transition-all duration-300 border border-white/[0.03]">
                          <div 
                            className="flex items-center justify-between px-4 h-[47px] cursor-pointer hover:bg-white/5 transition-colors"
                            onClick={(e) => toggleModalSubService(expandedId, e)}
                          >
                            <div className="flex items-center gap-4">
                              <button
                                type="button"
                                onClick={(e) => {
                                  e.stopPropagation();
                                  const newSubs = editingSubscription.subServices?.filter((_, i) => i !== idx);
                                  setEditingSubscription({ ...editingSubscription, subServices: newSubs });
                                }}
                                className="text-white/20 hover:text-orange-500 transition-colors p-1"
                              >
                                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M6 18L18 6M6 6l12 12" /></svg>
                              </button>
                              
                              <div className="flex items-center space-x-2.5">
                                <span className="text-[13px] font-medium text-white">{child.name || 'New Service'}</span>
                                <span className="text-white/20 text-[10px]">|</span>
                                <div className="flex items-center space-x-1.5">
                                  <div className={`h-1.5 w-1.5 rounded-full ${child.status === 'Paused' ? 'bg-red-500 shadow-[0_0_4px_rgba(239,68,68,0.8)]' : 'bg-[#1FE400] shadow-[0_0_4px_#1FE400]'} transition-colors`}></div>
                                  <span className={`text-[10px] font-bold uppercase tracking-widest ${child.status === 'Paused' ? 'text-red-500' : 'text-[#1FE400]'}`}>{child.status || 'Active'}</span>
                                </div>
                              </div>
                            </div>

                            <button
                              type="button"
                              className="text-white/30 p-1"
                            >
                              <svg className={`w-4 h-4 transform transition-transform duration-300 ${isExpanded ? 'rotate-180' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M19 9l-7 7-7-7" />
                              </svg>
                            </button>
                          </div>

                          {isExpanded && (
                            <div className="p-4 pt-0 animate-fadeIn border-t border-white/5 mt-1">
                              <div className="flex-1 space-y-4">
                                <div className="flex gap-4 items-start pt-4">
                                  <div className="flex-1 space-y-1">
                                    <label className="text-[12px] font-bold text-white/40 uppercase tracking-widest ml-1">Service Name</label>
                                    <input
                                      className="w-full bg-black/20 border border-white/[0.03] rounded-lg px-3 py-2 text-[13px] font-medium text-white outline-none focus:border-[#EBC351]/50 transition"
                                      placeholder="Service Name (Storage)"
                                      value={child.name}
                                      onChange={e => {
                                        const newSubs = [...(editingSubscription.subServices || [])];
                                        newSubs[idx] = { ...newSubs[idx], name: e.target.value };
                                        setEditingSubscription({ ...editingSubscription, subServices: newSubs });
                                      }}
                                    />
                                  </div>
                                  
                                  <div className="w-[124px] shrink-0 space-y-1">
                                    <label className="text-[12px] font-bold text-white/40 uppercase tracking-widest ml-1">Status</label>
                                    <div className="flex bg-black/40 p-1 rounded-lg border border-white/5 h-[37px] items-center">
                                      <button
                                        type="button"
                                        onClick={() => {
                                          const newSubs = [...(editingSubscription.subServices || [])];
                                          newSubs[idx] = { ...newSubs[idx], status: 'Active' };
                                          setEditingSubscription({ ...editingSubscription, subServices: newSubs });
                                        }}
                                        className={`flex-1 h-full rounded-md text-[9px] font-bold uppercase tracking-widest transition-all ${child.status === 'Active' ? 'bg-[#EBC351] text-black shadow-lg shadow-[#EBC351]/20' : 'text-white/30 hover:text-white'}`}
                                      >
                                        Active
                                      </button>
                                      <button
                                        type="button"
                                        onClick={() => {
                                          const newSubs = [...(editingSubscription.subServices || [])];
                                          newSubs[idx] = { ...newSubs[idx], status: 'Paused' };
                                          setEditingSubscription({ ...editingSubscription, subServices: newSubs });
                                        }}
                                        className={`flex-1 h-full rounded-md text-[9px] font-bold uppercase tracking-widest transition-all ${child.status === 'Paused' ? 'bg-[#EBC351] text-black shadow-lg shadow-[#EBC351]/20' : 'text-white/30 hover:text-white'}`}
                                      >
                                        Paused
                                      </button>
                                    </div>
                                  </div>
                                </div>

                                <div className="grid grid-cols-[1fr_1fr_124px] lg:grid-cols-[110px_120px_1fr_124px] gap-4 items-end pb-1">
                                  <div className="space-y-1">
                                    <label className="text-[12px] font-bold text-white/40 uppercase tracking-widest ml-1">Cost</label>
                                    <div className="relative">
                                      <span className="absolute left-3 top-1/2 -translate-y-1/2 text-white/30 text-[13px] font-medium">$</span>
                                      <input
                                        type="text"
                                        className="w-full bg-black/20 border border-white/[0.03] rounded-lg pl-7 pr-3 py-2 text-[13px] font-medium text-white outline-none focus:border-[#EBC351]/50 transition"
                                        placeholder="0.00"
                                        value={child.cost || ''}
                                        onChange={e => {
                                          const newSubs = [...(editingSubscription.subServices || [])];
                                          newSubs[idx] = { ...newSubs[idx], cost: parseFloat(e.target.value) || 0 };
                                          setEditingSubscription({ ...editingSubscription, subServices: newSubs });
                                        }}
                                      />
                                    </div>
                                  </div>
                                  <div className="space-y-1">
                                    <label className="text-[12px] font-bold text-white/40 uppercase tracking-widest ml-1">Cycle</label>
                                    <select
                                      className="w-full bg-black/20 border border-white/[0.03] rounded-lg px-3 py-2 text-[13px] font-medium text-white outline-none focus:border-[#EBC351]/50 transition appearance-none cursor-pointer"
                                      value={child.billingCycle || 'Monthly'}
                                      onChange={e => {
                                        const newSubs = [...(editingSubscription.subServices || [])];
                                        newSubs[idx] = { ...newSubs[idx], billingCycle: e.target.value as any };
                                        setEditingSubscription({ ...editingSubscription, subServices: newSubs });
                                      }}
                                    >
                                      <option value="Monthly">Monthly</option>
                                      <option value="Yearly">Yearly</option>
                                    </select>
                                  </div>
                                  <div className="col-span-3 lg:col-span-1 space-y-1 order-last lg:order-none min-h-[60px]">
                                    <label className="text-[12px] font-bold text-white/40 uppercase tracking-widest ml-1">Purpose</label>
                                    <textarea
                                      rows={2}
                                      style={{
                                        backgroundImage: 'linear-gradient(to bottom, transparent 31px, rgba(255,255,255,0.1) 31px, rgba(255,255,255,0.1) 32px, transparent 32px, transparent 51px, rgba(255,255,255,0.1) 51px, rgba(255,255,255,0.1) 52px, transparent 52px)',
                                        backgroundAttachment: 'local',
                                        lineHeight: '20px'
                                      }}
                                      className="w-full py-2.5 bg-transparent border-none outline-none focus:ring-0 text-white text-[13px] font-medium transition-colors resize-none overflow-hidden custom-scrollbar"
                                      placeholder="Backup storage, processing..."
                                      value={child.purpose || ''}
                                      onChange={e => {
                                        const val = e.target.value;
                                        const lines = val.split('\n');
                                        if (lines.length <= 2) {
                                          const newSubs = [...(editingSubscription.subServices || [])];
                                          newSubs[idx] = { ...newSubs[idx], purpose: val };
                                          setEditingSubscription({ ...editingSubscription, subServices: newSubs });
                                        }
                                      }}
                                    />
                                  </div>
                                  <div className="space-y-1">
                                    <label className="text-[12px] font-bold text-white/40 uppercase tracking-widest ml-1">Auto Pay</label>
                                    <div 
                                      className="bg-black/20 border border-white/[0.03] rounded-lg p-1 flex relative cursor-pointer group h-[36px] items-center"
                                      onClick={() => {
                                        const newSubs = [...(editingSubscription.subServices || [])];
                                        newSubs[idx] = { ...newSubs[idx], autoPay: child.autoPay === 'Manual' ? 'Auto' : 'Manual' };
                                        setEditingSubscription({ ...editingSubscription, subServices: newSubs });
                                      }}
                                    >
                                      <div 
                                        className="absolute top-1 bottom-1 w-[calc(50%-4px)] rounded-md transition-all duration-300 ease-[cubic-bezier(0.16,1,0.3,1)]"
                                        style={{ 
                                          left: child.autoPay === 'Manual' ? 'calc(50% + 2px)' : '4px',
                                          background: child.autoPay === 'Manual' ? 'rgba(255,255,255,0.08)' : '#EBC351'
                                        }}
                                      />
                                      <span className={`relative z-10 flex-1 text-center text-[9px] font-bold uppercase tracking-widest transition-colors duration-200 ${child.autoPay !== 'Manual' ? 'text-black' : 'text-white/30'}`}>On</span>
                                      <span className={`relative z-10 flex-1 text-center text-[9px] font-bold uppercase tracking-widest transition-colors duration-200 ${child.autoPay === 'Manual' ? 'text-white' : 'text-white/30'}`}>Off</span>
                                    </div>
                                  </div>
                                </div>
                              </div>
                            </div>
                          )}
                        </div>
                      );
                    })}
                  </div>
                </div>

                {/* Linked Emails Management Section */}
                <div className="pt-8 border-t border-white/5" id="modal-emails-section">
                  <div className="flex justify-between items-center mb-6">
                    <h4 className="text-[12px] font-bold text-[#EBC351] uppercase tracking-widest ml-1">Linked Emails</h4>
                    <button
                      type="button"
                      onClick={() => {
                        const newId = Math.random().toString(36).substr(2, 9);
                        const newEmail = {
                          id: newId,
                          email: '',
                          forwarding: '',
                          usedFor: '',
                          usedIn: '',
                          accessMethod: '',
                          notes: []
                        };
                        setEditingSubscription({
                          ...editingSubscription,
                          linkedEmails: [...(editingSubscription.linkedEmails || []), newEmail]
                        });
                        setExpandedModalEmails(prev => new Set(prev).add(newId));

                        // Auto-scroll to the new email section
                        setTimeout(() => {
                          const element = document.getElementById(`linked-email-${newId}`);
                          if (element) {
                            element.scrollIntoView({ behavior: 'smooth', block: 'center' });
                            element.style.boxShadow = '0 0 0 2px #EBC351';
                            setTimeout(() => {
                              element.style.boxShadow = 'none';
                            }, 2000);
                          }
                        }, 100);
                      }}
                      className="text-[10px] font-bold text-[#EBC351] bg-[#EBC351]/10 px-3 py-1.5 rounded-lg hover:bg-[#EBC351]/20 transition"
                    >
                      + ADD EMAIL
                    </button>
                  </div>

                  <div className="space-y-1">
                    {(editingSubscription.linkedEmails || []).map((email, idx) => {
                      const expandedId = email.id || String(idx);
                      const isExpanded = expandedModalEmails.has(expandedId);
                      return (
                        <div key={expandedId} id={`linked-email-${expandedId}`} className="bg-black/20 rounded-lg flex flex-col group/sub relative transition-all duration-300 border border-white/[0.03]">
                          <div 
                            className="flex items-center justify-between px-4 h-[47px] cursor-pointer hover:bg-white/5 transition-colors"
                            onClick={(e) => toggleModalEmail(expandedId, e)}
                          >
                            <div className="flex items-center gap-4">
                              <button
                                type="button"
                                onClick={(e) => {
                                  e.stopPropagation();
                                  const newEmails = editingSubscription.linkedEmails?.filter((_, i) => i !== idx);
                                  setEditingSubscription({ ...editingSubscription, linkedEmails: newEmails });
                                }}
                                className="text-white/20 hover:text-orange-500 transition-colors p-1"
                              >
                                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M6 18L18 6M6 6l12 12" /></svg>
                              </button>
                              
                              <div className="flex items-center space-x-2.5">
                                <span className="text-[13px] font-medium text-white">{email.email || 'New Email Address'}</span>
                              </div>
                            </div>

                            <button
                              type="button"
                              className="text-white/30 p-1"
                            >
                              <svg className={`w-4 h-4 transform transition-transform duration-300 ${isExpanded ? 'rotate-180' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M19 9l-7 7-7-7" />
                              </svg>
                            </button>
                          </div>

                          {isExpanded && (
                            <div className="p-4 pt-0 animate-fadeIn border-t border-white/5 mt-1">
                              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 pt-4">
                                <div className="space-y-1">
                                  <label className="text-[12px] font-bold text-white/40 uppercase tracking-widest ml-1">Email Address</label>
                                  <input
                                    list="email-sweeps"
                                    className="w-full bg-black/20 border border-white/[0.03] rounded-lg px-3 py-2 text-[13px] font-medium text-white outline-none focus:border-[#EBC351]/50 transition"
                                    placeholder="email@example.com"
                                    value={email.email}
                                    onChange={e => {
                                      const newEmails = [...(editingSubscription.linkedEmails || [])];
                                      newEmails[idx] = { ...newEmails[idx], email: e.target.value };
                                      setEditingSubscription({ ...editingSubscription, linkedEmails: newEmails });
                                    }}
                                  />
                                </div>
                                <div className="space-y-1">
                                  <label className="text-[12px] font-bold text-white/40 uppercase tracking-widest ml-1">Used For</label>
                                  <input
                                    className="w-full bg-black/20 border border-white/[0.03] rounded-lg px-3 py-2 text-[13px] font-medium text-white outline-none focus:border-[#EBC351]/50 transition"
                                    placeholder="Personal use"
                                    value={email.usedFor}
                                    onChange={e => {
                                      const newEmails = [...(editingSubscription.linkedEmails || [])];
                                      newEmails[idx] = { ...newEmails[idx], usedFor: e.target.value };
                                      setEditingSubscription({ ...editingSubscription, linkedEmails: newEmails });
                                    }}
                                  />
                                </div>
                                <div className="space-y-1">
                                  <label className="text-[12px] font-bold text-white/40 uppercase tracking-widest ml-1">Provider</label>
                                  <input
                                    className="w-full bg-black/20 border border-white/[0.03] rounded-lg px-3 py-2 text-[13px] font-medium text-white outline-none focus:border-[#EBC351]/50 transition"
                                    placeholder="e.g. Google Workspace"
                                    value={email.forwarding}
                                    onChange={e => {
                                      const newEmails = [...(editingSubscription.linkedEmails || [])];
                                      newEmails[idx] = { ...newEmails[idx], forwarding: e.target.value };
                                      setEditingSubscription({ ...editingSubscription, linkedEmails: newEmails });
                                    }}
                                  />
                                </div>
                                <div className="space-y-2">
                                  <label className="text-[12px] font-bold text-white/40 uppercase tracking-widest ml-1">Used In</label>
                                  {(() => {
                                    const computedServices = getUsedInServices(email.email);
                                    const legacyTags = email.usedIn ? email.usedIn.split(',').map(s => s.trim()).filter(s => s && !computedServices.find(cs => cs.name.toLowerCase() === s.toLowerCase())) : [];
                                    
                                    return (
                                      <div className="flex flex-wrap gap-2 px-3 py-2 bg-black/20 border border-white/[0.03] rounded-lg min-h-[38px] items-center">
                                        {computedServices.length === 0 && legacyTags.length === 0 && (
                                          <span className="text-white/20 text-[11px] italic">Auto-generates when linked to services...</span>
                                        )}
                                        {computedServices.map((svc, i) => (
                                          <span key={`svc-${i}`} className={`px-2 py-1 text-[10px] uppercase tracking-widest font-bold rounded-md border ${svc.role === 'primary' ? 'bg-[#EBC351]/10 text-[#EBC351] border-[#EBC351]/20 shadow-[0_0_8px_rgba(235,195,81,0.1)]' : 'bg-white/5 text-white/50 border-white/10'}`}>
                                            {svc.role === 'primary' ? '🔑 ' : '🔗 '} {svc.name} {svc.role === 'primary' ? '(Login)' : ''}
                                          </span>
                                        ))}
                                        {legacyTags.map((tag, i) => (
                                          <div key={`legacy-${i}`} className="flex items-center bg-black/40 text-white/50 text-[10px] uppercase tracking-widest font-bold rounded-md border border-white/5 px-2 py-1">
                                             {tag}
                                          </div>
                                        ))}
                                      </div>
                                    );
                                  })()}
                                </div>
                                <div className="col-span-full space-y-1">
                                  <label className="text-[12px] font-bold text-white/40 uppercase tracking-widest ml-1">Access Method</label>
                                  <input
                                    className="w-full bg-black/20 border border-white/[0.03] rounded-lg px-3 py-2 text-[13px] font-medium text-white outline-none focus:border-[#EBC351]/50 transition"
                                    placeholder="Gmail, Apple Mail"
                                    value={email.accessMethod}
                                    onChange={e => {
                                      const newEmails = [...(editingSubscription.linkedEmails || [])];
                                      newEmails[idx] = { ...newEmails[idx], accessMethod: e.target.value };
                                      setEditingSubscription({ ...editingSubscription, linkedEmails: newEmails });
                                    }}
                                  />
                                </div>
                                <div className="col-span-full space-y-1">
                                  <label className="text-[12px] font-bold text-white/40 uppercase tracking-widest ml-1">Notes</label>
                                  <textarea
                                    className="w-full bg-black/20 border border-white/[0.03] rounded-lg px-3 py-2 text-[13px] font-medium text-white outline-none focus:border-[#EBC351]/50 transition h-24 resize-none"
                                    placeholder="Main email used for...&#10;Secondary contact..."
                                    value={email.notes.join('\n')}
                                    onChange={e => {
                                      const newEmails = [...(editingSubscription.linkedEmails || [])];
                                      newEmails[idx] = { ...newEmails[idx], notes: e.target.value.split('\n') };
                                      setEditingSubscription({ ...editingSubscription, linkedEmails: newEmails });
                                    }}
                                  />
                                </div>
                              </div>
                            </div>
                          )}
                        </div>
                      );
                    })}
                  </div>
                </div>
              </div>
            </div>

            <div className="px-6 py-3 bg-black/20 border-t border-white/5 flex justify-between items-center">
              <div className="flex-1">
                {editingSubscription.id && onDeleteSubscription && (
                  showDeleteConfirm ? (
                    <div className="flex items-center space-x-3">
                      <span className="text-[10px] font-black text-orange-500 uppercase">Confirm?</span>
                      <button type="button" onClick={() => { onDeleteSubscription(editingSubscription.id!); setEditingSubscription(null); }} className="text-[10px] font-black text-white hover:text-orange-500">YES</button>
                      <button type="button" onClick={() => setShowDeleteConfirm(false)} className="text-[10px] font-black text-white/20 hover:text-white">NO</button>
                    </div>
                  ) : (
                    <button type="button" onClick={() => setShowDeleteConfirm(true)} className="text-[10px] font-black text-white/20 hover:text-orange-500 uppercase tracking-widest">Delete</button>
                  )
                )}
              </div>
              <div className="flex space-x-4">
                <button type="button" onClick={() => setEditingSubscription(null)} className="px-6 py-3 text-[11px] font-black text-white/40 uppercase tracking-widest hover:text-white transition">Cancel</button>
                <button type="button" onClick={handleSaveModal} className="px-8 py-3 bg-[#EBC351] rounded-2xl text-[11px] font-black text-black uppercase tracking-widest shadow-lg shadow-[#EBC351]/20 hover:scale-[1.02] active:scale-95 transition">Save Account</button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default SubscriptionList;
