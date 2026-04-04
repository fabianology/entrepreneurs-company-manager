
import React, { useState, useRef } from 'react';
import { Subscription, SubService } from '../types';
import { getFaviconUrl } from '../services/logoService';
import { generateSubscriptionEmailPurpose } from '../services/geminiService';

interface SubscriptionListProps {
  subscriptions: Subscription[];
  onUpdateSubscription: (id: string, updates: Partial<Subscription>) => void;
  onAddSubscription?: (sub: Partial<Subscription>) => void;
  onDeleteSubscription?: (id: string) => void;
}

const SubscriptionList: React.FC<SubscriptionListProps> = ({
  subscriptions,
  onUpdateSubscription,
  onAddSubscription,
  onDeleteSubscription
}) => {
  const [editingSubscription, setEditingSubscription] = useState<Partial<Subscription> | null>(null);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [expandedSubs, setExpandedSubs] = useState<Set<string>>(new Set());
  const [expandedEmails, setExpandedEmails] = useState<Set<string>>(new Set());
  const [expandedDetails, setExpandedDetails] = useState<Set<string>>(new Set());
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
    const newSub: SubService = {
      id: Math.random().toString(36).substr(2, 9),
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
  };
  const monthlyBurn = subscriptions.reduce((acc, s) => {
    const baseMonthly = s.billingCycle === 'Monthly' ? s.cost : s.cost / 12;
    const subServicesMonthly = s.subServices?.reduce((sum, ss) => {
      if (ss.status === 'Paused') return sum;
      const ssMonthly = (ss.billingCycle === 'Yearly') ? (ss.cost / 12) : ss.cost;
      return sum + ssMonthly;
    }, 0) || 0;
    return acc + baseMonthly + subServicesMonthly;
  }, 0);

  const activeStack = subscriptions.length;

  return (
    <div className="bg-black min-h-screen text-white p-4 space-y-8">
      {/* Action Bar */}
      <div className="flex items-center justify-between pr-2">
        <div className="flex items-center gap-3">
          <div className="bg-[#1C1C1E] px-4 py-3.5 rounded-xl border border-white/5 flex items-center gap-3 shrink-0">
            <span className="text-xs font-black text-white/40 uppercase tracking-widest text-nowrap">burn /mo</span>
            <span className="text-xs font-black text-white tracking-widest">${monthlyBurn.toFixed(0)}</span>
          </div>
          <div className="bg-[#1C1C1E] px-4 py-3.5 rounded-xl border border-white/5 flex items-center gap-3 shrink-0">
            <span className="text-xs font-black text-white/40 uppercase tracking-widest text-nowrap">stacks</span>
            <span className="text-xs font-black text-white tracking-widest">{activeStack}</span>
          </div>
        </div>

        <button
          onClick={handleAddNew}
          className="bg-[#1C1C1E] text-white px-4 py-3.5 rounded-xl text-xs font-black uppercase tracking-widest hover:bg-[#2C2C2E] transition flex items-center space-x-2 border border-white/5"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M12 4v16m8-8H4" /></svg>
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
           <div key={sub.id} className="bg-[#1C1C1E] rounded-[24px] overflow-hidden border border-white/5 shadow-2xl transition-all duration-300 hover:border-white/10">
              {/* Main Info */}
              <div 
                className="p-6 space-y-6 cursor-pointer group/card hover:bg-white/[0.02] transition-colors"
                onClick={() => setEditingSubscription(sub)}
              >
                <div className="flex justify-between items-start">
                  <div className="flex items-center space-x-4">
                    <div className="w-14 h-14 bg-white/5 rounded-2xl flex items-center justify-center border border-white/10 group-hover/card:border-[#EBC351]/30 transition-all duration-300 overflow-hidden">
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
                    <div>
                      <a 
                        href={sub.website ? (sub.website.startsWith('http') ? sub.website : `https://${sub.website}`) : '#'} 
                        target="_blank" 
                        rel="noreferrer"
                        className="flex items-center gap-2 group/name"
                        onClick={(e) => e.stopPropagation()}
                      >
                        <h3 className="text-lg font-black tracking-tight text-white uppercase group-hover/name:text-[#EBC351] transition-colors">{sub.name}</h3>
                        {sub.website && (
                          <svg className="w-3.5 h-3.5 text-white/20 group-hover/name:text-[#EBC351]/50 transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" /></svg>
                        )}
                      </a>
                      <div className="flex items-center space-x-2 mt-1.5 transition-all duration-300">
                        {sub.renew === 'Manual' ? (
                          <>
                            <div className="h-1.5 w-1.5 rounded-full bg-red-500 shadow-[0_0_6px_rgba(239,68,68,0.6)]"></div>
                            <span className="text-red-500 text-[9px] font-black uppercase tracking-widest">Manual Renew</span>
                          </>
                        ) : (
                          <>
                            <div className="h-1.5 w-1.5 rounded-full bg-[#1FE400] shadow-[0_0_6px_#1FE400]"></div>
                            <span className="text-[#1FE400] text-[9px] font-black uppercase tracking-widest">Auto Renew</span>
                          </>
                        )}
                      </div>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="text-xl font-black text-white">
                      ${(sub.cost + (sub.subServices?.reduce((sum, ss) => {
                        if (ss.status === 'Paused') return sum;
                        if (sub.billingCycle === ss.billingCycle) return sum + ss.cost;
                        if (sub.billingCycle === 'Monthly' && ss.billingCycle === 'Yearly') return sum + (ss.cost / 12);
                        if (sub.billingCycle === 'Yearly' && ss.billingCycle === 'Monthly') return sum + (ss.cost * 12);
                        return sum + ss.cost;
                      }, 0) || 0)).toFixed(2)}
                    </p>
                    <p className="text-[10px] text-white/40 font-black uppercase tracking-widest">{sub.billingCycle}</p>
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-y-6 gap-x-4 pt-2">
                  <div 
                    className="space-y-1 group/field cursor-pointer active:opacity-60 transition-opacity"
                    onClick={(e) => handleFieldCopy(sub.id, sub.loginId || '', 'login', e)}
                  >
                    <p className={`text-[9px] font-black uppercase tracking-widest transition-colors duration-300 ${lastCopiedField?.id === sub.id && lastCopiedField.field === 'login' ? 'text-orange-500' : 'text-white/40'}`}>
                      {lastCopiedField?.id === sub.id && lastCopiedField.field === 'login' ? 'Copied!' : 'Login ID'}
                    </p>
                    <p className="text-xs font-black text-white truncate max-w-[140px]">{sub.loginId || '—'}</p>
                  </div>

                  <div 
                    className="space-y-1 group/pass cursor-pointer active:opacity-60 transition-opacity"
                    onClick={(e) => handleFieldCopy(sub.id, sub.password || '', 'password', e)}
                  >
                    <div className="flex items-center gap-2">
                      <p className={`text-[9px] font-black uppercase tracking-widest transition-colors duration-300 ${lastCopiedField?.id === sub.id && lastCopiedField.field === 'password' ? 'text-orange-500' : 'text-white/40'}`}>
                        {lastCopiedField?.id === sub.id && lastCopiedField.field === 'password' ? 'Copied!' : 'Password'}
                      </p>
                      <button 
                        onClick={(e) => { e.stopPropagation(); togglePasswordVisibility(sub.id); }} 
                        className="text-white/20 hover:text-[#EBC351] transition-colors"
                      >
                        {visiblePasswords.has(sub.id) ? (
                          <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268-2.943-9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" /></svg>
                        ) : (
                          <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268-2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" /></svg>
                        )}
                      </button>
                    </div>
                    <p className="text-xs font-black text-white tracking-wider truncate">
                      {visiblePasswords.has(sub.id) ? (sub.password || '—') : '••••••••'}
                    </p>
                  </div>

                  <div className="space-y-1">
                    <p className="text-[9px] font-black text-white/40 uppercase tracking-widest">Paid From</p>
                    <p className="text-xs font-black text-white truncate max-w-[100px]">{sub.paymentMethod || '—'}</p>
                  </div>
                  <div className="space-y-1">
                    <p className="text-[9px] font-black text-white/40 uppercase tracking-widest">Due On</p>
                    <p className="text-xs font-black text-white">{sub.nextRenewal || '—'}</p>
                  </div>
                </div>
            </div>

            {/* Supplemental Services Accordion */}
            <div className="border-t border-white/5">
              <button
                onClick={() => toggleExpanded(sub.id)}
                className="w-full h-14 px-6 flex items-center justify-between text-[#EBC351] group"
              >
                <div className="flex items-center space-x-3">
                  <span className="text-[11px] font-black uppercase tracking-[0.15em]">Supplemental Services</span>
                  <div className="px-1.5 py-0.5 rounded bg-[#EBC351]/10 text-[9px] font-black">
                    {sub.subServices?.length || 0}
                  </div>
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
                          className="text-xs font-bold cursor-pointer hover:text-[#EBC351] transition-colors text-white/90"
                        >
                          {child.name}
                        </span>
                        <span className={`text-[9px] font-black uppercase tracking-tighter opacity-80 ${child.status === 'Paused' ? 'text-red-500' : 'text-[#1FE400]'}`}>
                          {child.status}
                        </span>
                      </div>
                      <span className={`text-xs font-black ${child.status === 'Paused' ? 'text-white/20' : 'text-white'}`}>
                        ${child.cost.toFixed(2)}
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
                className="w-full h-14 px-6 flex items-center justify-between text-[#EBC351] group bg-white/2"
              >
                <div className="flex items-center space-x-3">
                  <span className="text-[11px] font-black uppercase tracking-[0.15em]">Linked Emails</span>
                  <div className="px-1.5 py-0.5 rounded bg-[#EBC351]/10 text-[9px] font-black">
                    {sub.linkedEmails?.length || 0}
                  </div>
                </div>
                <svg className={`w-4 h-4 transform transition-transform duration-300 ${expandedEmails.has(sub.id) ? 'rotate-180' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M19 9l-7 7-7-7" /></svg>
              </button>

              {expandedEmails.has(sub.id) && (
                <div className="px-6 pb-8 space-y-1 animate-fadeIn">
                  {(sub.linkedEmails || []).map((email, idx) => {
                    const emailId = email.id || String(idx);
                    const isExpanded = expandedDetails.has(emailId);
                    return (
                      <div key={emailId} className="pt-2 first:pt-0 border-t border-white/5 first:border-0 relative group/email">
                        {/* Header Toggle */}
                        <button
                          onClick={() => toggleDetailExpanded(emailId)}
                          className="w-full text-left grid grid-cols-[1fr,1fr,auto] gap-x-8 py-2 hover:bg-white/5 transition-colors rounded-xl px-4 -mx-4 group/toggle"
                        >
                          <div className="space-y-1">
                            <p className="text-[9px] font-black text-white/40 uppercase tracking-widest">Email</p>
                            <p className="text-xs font-black text-white truncate">{email.email}</p>
                          </div>
                          <div className="space-y-1">
                            <p className="text-[9px] font-black text-white/40 uppercase tracking-widest">Used For</p>
                            <p className="text-xs font-black text-white truncate">{email.usedFor}</p>
                          </div>
                          <div className="flex items-center">
                            <svg
                              className={`w-3 h-3 text-white/20 group-hover/toggle:text-[#EBC351] transform transition-all duration-500 ease-[cubic-bezier(0.16,1,0.3,1)] ${isExpanded ? 'rotate-180 text-[#EBC351]' : ''}`}
                              fill="none"
                              stroke="currentColor"
                              viewBox="0 0 24 24"
                            >
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="4" d="M19 9l-7 7-7-7" />
                            </svg>
                          </div>
                        </button>

                        {/* Collapsible Drawer */}
                        <div className={`overflow-hidden transition-all duration-500 ease-[cubic-bezier(0.16,1,0.3,1)] ${isExpanded ? 'max-h-[500px] opacity-100 mt-4 pb-2' : 'max-h-0 opacity-0 mt-0 pointer-events-none'}`}>
                          <div className="grid grid-cols-2 gap-x-8 gap-y-6 px-4 -mx-4">
                            {/* Row 2 */}
                            <div className="space-y-1">
                              <p className="text-[9px] font-black text-white/40 uppercase tracking-widest">Forwarding</p>
                              <p className="text-xs font-black text-white">{email.forwarding || 'N/A'}</p>
                            </div>
                            <div className="space-y-1">
                              <p className="text-[9px] font-black text-white/40 uppercase tracking-widest">Used In</p>
                              <p className="text-xs font-black text-white">{email.usedIn}</p>
                            </div>

                            {/* Row 3 */}
                            <div className="col-span-2 space-y-1">
                              <p className="text-[9px] font-black text-white/40 uppercase tracking-widest">Access Method</p>
                              <p className="text-xs font-black text-white">{email.accessMethod}</p>
                            </div>

                            {/* Row 4: Notes */}
                            <div className="col-span-2 space-y-2">
                              <p className="text-[9px] font-black text-white/40 uppercase tracking-widest">Notes</p>
                              <div className="space-y-1">
                                {email.notes.map((note, nIdx) => (
                                  <div key={nIdx} className="flex items-start space-x-2">
                                    <span className="text-[#EBC351] mt-1">•</span>
                                    <p className="text-xs text-white/80 leading-relaxed font-medium">{note}</p>
                                  </div>
                                ))}
                                <button className="text-[10px] font-black text-[#EBC351] uppercase tracking-widest pt-1 hover:text-white transition-colors">
                                  + add note
                                </button>
                              </div>
                            </div>

                            <div className="col-span-2 pt-2 flex justify-end">
                              <button
                                onClick={() => setEditingSubscription(sub)}
                                className="text-[10px] font-black text-[#EBC351] uppercase tracking-widest hover:text-white transition-colors py-1 flex items-center space-x-1"
                              >
                                <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" /></svg>
                                <span>Edit Account</span>
                              </button>
                            </div>
                          </div>
                        </div>
                      </div>
                    );
                  })}

                  <button
                    onClick={() => addEmailToSubscription(sub)}
                    className="text-[10px] font-black text-white/30 uppercase tracking-widest pt-2 hover:text-[#EBC351] transition"
                  >
                    + add email
                  </button>

                  {(!sub.linkedEmails || sub.linkedEmails.length === 0) && (
                    <div className="text-center py-4 text-[10px] font-black text-white/20 uppercase tracking-widest">
                      No linked emails found
                    </div>
                  )}
                </div>
              )}
            </div>
          </div>
        ))}
      </div>

      {/* Editing Modal */}
      {editingSubscription && (
        <div className="fixed inset-x-0 z-50 flex items-start justify-center p-4 bg-black/90 backdrop-blur-xl animate-fadeIn overflow-y-auto" style={{ top: '20px', bottom: '160px' }}>
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

              <div className="space-y-4">
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <label className="text-[10px] font-black text-white/40 uppercase tracking-widest ml-1">Subscription</label>
                    <input
                      className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-3.5 text-white outline-none focus:border-[#EBC351]/50 transition font-bold"
                      value={editingSubscription.name || ''}
                      placeholder="Shopify"
                      onChange={e => setEditingSubscription({ ...editingSubscription, name: e.target.value })}
                    />
                  </div>
                  <div className="space-y-2">
                    <label className="text-[10px] font-black text-white/40 uppercase tracking-widest ml-1">Website</label>
                    <input
                      className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-3.5 text-white outline-none focus:border-[#EBC351]/50 transition font-bold"
                      value={editingSubscription.website || ''}
                      placeholder="shopify.com"
                      onChange={e => setEditingSubscription({ ...editingSubscription, website: e.target.value })}
                    />
                  </div>
                </div>
                {editingSubscription.pricingModel !== 'free' && (
                  <div className="grid grid-cols-3 gap-4">
                    <div className="space-y-2">
                      <label className="text-[10px] font-black text-white/40 uppercase tracking-widest ml-1">Cost</label>
                      <div className="relative">
                        <span className="absolute left-5 top-1/2 -translate-y-1/2 text-white/30 font-bold">$</span>
                        <input
                          type="text"
                          className="w-full bg-white/5 border border-white/10 rounded-2xl pl-10 pr-5 py-3.5 text-white outline-none focus:border-[#EBC351]/50 transition font-bold"
                          value={editingSubscription.cost || ''}
                          placeholder="0.00"
                          onChange={e => setEditingSubscription({ ...editingSubscription, cost: parseFloat(e.target.value) || 0 })}
                        />
                      </div>
                    </div>
                    <div className="space-y-2">
                      <label className="text-[10px] font-black text-white/40 uppercase tracking-widest ml-1">Due On</label>
                      <input
                        className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-3.5 text-white outline-none focus:border-[#EBC351]/50 transition font-bold"
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
                    <div className="space-y-2">
                      <label className="text-[10px] font-black text-white/40 uppercase tracking-widest ml-1">Cycle</label>
                      <select
                        className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-3.5 text-white outline-none focus:border-[#EBC351]/50 transition font-bold"
                        value={editingSubscription.billingCycle || 'Monthly'}
                        onChange={e => setEditingSubscription({ ...editingSubscription, billingCycle: e.target.value as any })}
                      >
                        <option value="Monthly">Monthly</option>
                        <option value="Yearly">Yearly</option>
                      </select>
                    </div>
                  </div>
                )}
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <label className="text-[10px] font-black text-white/40 uppercase tracking-widest ml-1">Login ID</label>
                    <input
                      className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-3.5 text-white outline-none focus:border-[#EBC351]/50 transition font-bold"
                      value={editingSubscription.loginId || ''}
                      placeholder="admin"
                      onChange={e => setEditingSubscription({ ...editingSubscription, loginId: e.target.value })}
                    />
                  </div>
                  <div className="space-y-2">
                    <label className="text-[10px] font-black text-white/40 uppercase tracking-widest ml-1">Password</label>
                    <input
                      type="password"
                      className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-3.5 text-white outline-none focus:border-[#EBC351]/50 transition font-bold"
                      value={editingSubscription.password || ''}
                      placeholder="••••••••"
                      onChange={e => setEditingSubscription({ ...editingSubscription, password: e.target.value })}
                    />
                  </div>
                </div>
                {editingSubscription.pricingModel !== 'free' && (
                  <div className="grid grid-cols-2 gap-4 items-end">
                    <div className="space-y-2">
                      <label className="text-[10px] font-black text-white/40 uppercase tracking-widest ml-1">Paid From</label>
                      <input
                        className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-3.5 text-white outline-none focus:border-[#EBC351]/50 transition font-bold"
                        value={editingSubscription.paymentMethod || ''}
                        placeholder="Amex Gold"
                        onChange={e => setEditingSubscription({ ...editingSubscription, paymentMethod: e.target.value })}
                      />
                    </div>
                    <div className="space-y-2">
                      <label className="text-[10px] font-black text-white/40 uppercase tracking-widest ml-1">Auto Renew</label>
                      <div className="flex items-center h-[52px] px-2">
                        <div
                          className="relative flex items-center w-full bg-white/5 border border-white/10 rounded-2xl p-1 cursor-pointer select-none"
                          onClick={() => setEditingSubscription({ ...editingSubscription, renew: editingSubscription.renew === 'Manual' ? 'Auto' : 'Manual' })}
                        >
                          {/* Sliding pill */}
                          <div
                            className="absolute top-1 bottom-1 w-[calc(50%-4px)] rounded-xl transition-all duration-300 ease-[cubic-bezier(0.16,1,0.3,1)]"
                            style={{
                              left: editingSubscription.renew === 'Manual' ? 'calc(50% + 2px)' : '4px',
                              background: editingSubscription.renew === 'Manual' ? 'rgba(255,255,255,0.08)' : '#EBC351'
                            }}
                          />
                          <span className={`relative z-10 flex-1 text-center text-[11px] font-black uppercase tracking-widest transition-colors duration-200 py-2 ${editingSubscription.renew !== 'Manual' ? 'text-black' : 'text-white/30'
                            }`}>Auto</span>
                          <span className={`relative z-10 flex-1 text-center text-[11px] font-black uppercase tracking-widest transition-colors duration-200 py-2 ${editingSubscription.renew === 'Manual' ? 'text-white' : 'text-white/30'
                            }`}>Manual</span>
                        </div>
                      </div>
                    </div>
                  </div>
                )}

                {/* Security & Recovery Accordion */}
                <div className="pt-4 border-t border-white/5">
                  <button
                    type="button"
                    onClick={() => setExpandedSecurity(prev => !prev)}
                    className="w-full flex justify-between items-center mb-1 group"
                  >
                    <h4 className="text-[10px] font-black text-white/40 uppercase tracking-widest ml-1 group-hover:text-white/60 transition-colors">
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
                    <div className="grid grid-cols-2 gap-4 mt-4">
                      <div className="space-y-2">
                        <label className="text-[10px] font-black text-white/40 uppercase tracking-widest ml-1">2FA</label>
                        <select
                          className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-3.5 text-white outline-none focus:border-[#EBC351]/50 transition font-bold"
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
                      <div className="space-y-2">
                        <label className="text-[10px] font-black text-white/40 uppercase tracking-widest ml-1">Recovery</label>
                        <input
                          className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-3.5 text-white outline-none focus:border-[#EBC351]/50 transition font-bold"
                          value={editingSubscription.recoveryMethod || ''}
                          placeholder="Phone, email, backup code..."
                          onChange={e => setEditingSubscription({ ...editingSubscription, recoveryMethod: e.target.value })}
                        />
                      </div>
                    </div>
                  )}
                </div>

                {/* Sub-services Management Section */}
                <div className="pt-8 border-t border-white/5">
                  <div className="flex justify-between items-center mb-6">
                    <h4 className="text-[10px] font-black text-[#EBC351] uppercase tracking-widest ml-1">Supplemental Services</h4>
                    <button
                      onClick={handleAddSubService}
                      className="text-[10px] font-black text-[#EBC351] bg-[#EBC351]/10 px-3 py-1.5 rounded-lg hover:bg-[#EBC351]/20 transition"
                    >
                      + ADD SERVICE
                    </button>
                  </div>

                  <div className="space-y-4">
                    {(editingSubscription.subServices || []).map((child, idx) => (
                      <div key={child.id} id={`sub-service-${child.id}`} className="bg-white/2 p-5 rounded-2xl flex flex-col gap-4 group/sub relative transition-all duration-300 border border-[#EBC351]/20">
                        <div className="flex-1 space-y-4">
                          <div className="flex gap-4 items-start">
                            <div className="flex-1 space-y-2">
                              <label className="text-[9px] font-black text-white/40 uppercase tracking-widest ml-1">Service Name</label>
                              <input
                                className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-xs text-white outline-none focus:border-[#EBC351]/50 transition font-bold"
                                placeholder="Service Name (Storage)"
                                value={child.name}
                                onChange={e => {
                                  const newSubs = [...(editingSubscription.subServices || [])];
                                  newSubs[idx] = { ...newSubs[idx], name: e.target.value };
                                  setEditingSubscription({ ...editingSubscription, subServices: newSubs });
                                }}
                              />
                            </div>
                            <button
                              onClick={() => {
                                const newSubs = editingSubscription.subServices?.filter((_, i) => i !== idx);
                                setEditingSubscription({ ...editingSubscription, subServices: newSubs });
                              }}
                              className="text-white/10 hover:text-orange-500 transition-colors p-1 mt-7"
                            >
                              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M6 18L18 6M6 6l12 12" /></svg>
                            </button>
                          </div>

                          <div className="grid grid-cols-3 md:grid-cols-6 gap-4 items-end">
                            <div className="space-y-2">
                              <label className="text-[9px] font-black text-white/40 uppercase tracking-widest ml-1">Cost</label>
                              <div className="relative">
                                <span className="absolute left-4 top-1/2 -translate-y-1/2 text-white/30 text-xs font-bold">$</span>
                                <input
                                  type="text"
                                  className="w-full bg-white/5 border border-white/10 rounded-xl pl-8 pr-4 py-2.5 text-xs text-white outline-none focus:border-[#EBC351]/50 transition font-bold"
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
                            <div className="space-y-2">
                              <label className="text-[9px] font-black text-white/40 uppercase tracking-widest ml-1">Billing Cycle</label>
                              <select
                                className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-xs text-white outline-none focus:border-[#EBC351]/50 transition font-bold"
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
                            <div className="col-span-3 md:col-span-3 lg:col-span-3 space-y-2 order-last md:order-none min-h-[64px]">
                              <label className="text-[9px] font-black text-white/40 uppercase tracking-widest ml-1">What it's used for</label>
                              <textarea
                                rows={2}
                                style={{
                                  backgroundImage: 'linear-gradient(to bottom, transparent 31px, rgba(255,255,255,0.1) 31px, rgba(255,255,255,0.1) 32px, transparent 32px, transparent 51px, rgba(255,255,255,0.1) 51px, rgba(255,255,255,0.1) 52px, transparent 52px)',
                                  backgroundAttachment: 'local',
                                  lineHeight: '20px'
                                }}
                                className="w-full py-3 bg-transparent border-none outline-none focus:ring-0 text-white text-xs font-bold transition-colors resize-none overflow-hidden custom-scrollbar"
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
                            <div className="space-y-2">
                              <label className="text-[9px] font-black text-white/40 uppercase tracking-widest ml-1">Status</label>
                              <div className="flex bg-black/40 p-1 rounded-full border border-white/5 h-[38px] items-center">
                                <button
                                  type="button"
                                  onClick={() => {
                                    const newSubs = [...(editingSubscription.subServices || [])];
                                    newSubs[idx] = { ...newSubs[idx], status: 'Active' };
                                    setEditingSubscription({ ...editingSubscription, subServices: newSubs });
                                  }}
                                  className={`flex-1 h-full rounded-full text-[8px] font-black uppercase tracking-widest transition-all ${child.status === 'Active' ? 'bg-[#EBC351] text-black shadow-lg shadow-[#EBC351]/20' : 'text-white/30 hover:text-white'}`}
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
                                  className={`flex-1 h-full rounded-full text-[8px] font-black uppercase tracking-widest transition-all ${child.status === 'Paused' ? 'bg-[#EBC351] text-black shadow-lg shadow-[#EBC351]/20' : 'text-white/30 hover:text-white'}`}
                                >
                                  Paused
                                </button>
                              </div>
                            </div>
                          </div>
                        </div>
                      </div>
                    ))}

                  </div>
                </div>

                {/* Linked Emails Management Section */}
                <div className="pt-8 border-t border-white/5">
                  <div className="flex justify-between items-center mb-6">
                    <h4 className="text-[10px] font-black text-[#EBC351] uppercase tracking-widest ml-1">Linked Emails</h4>
                    <button
                      onClick={() => {
                        const newEmail = {
                          id: Math.random().toString(36).substr(2, 9),
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
                      }}
                      className="text-[10px] font-black text-[#EBC351] bg-[#EBC351]/10 px-3 py-1.5 rounded-lg hover:bg-[#EBC351]/20 transition"
                    >
                      + ADD EMAIL
                    </button>
                  </div>

                  <div className="space-y-6">
                    {(editingSubscription.linkedEmails || []).map((email, idx) => (
                      <div key={email.id} className="bg-white/2 p-6 rounded-3xl border border-white/5 space-y-4 relative group/email-edit">
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                          <div className="space-y-2">
                            <label className="text-[9px] font-black text-white/40 uppercase tracking-widest ml-1">Email Address</label>
                            <input
                              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-xs text-white outline-none focus:border-[#EBC351]/50 transition font-bold"
                              placeholder="email@example.com"
                              value={email.email}
                              onChange={e => {
                                const newEmails = [...(editingSubscription.linkedEmails || [])];
                                newEmails[idx] = { ...newEmails[idx], email: e.target.value };
                                setEditingSubscription({ ...editingSubscription, linkedEmails: newEmails });
                              }}
                            />
                          </div>
                          <div className="space-y-2">
                            <label className="text-[9px] font-black text-white/40 uppercase tracking-widest ml-1">Used For</label>
                            <input
                              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-xs text-white outline-none focus:border-[#EBC351]/50 transition font-bold"
                              placeholder="Personal use"
                              value={email.usedFor}
                              onChange={e => {
                                const newEmails = [...(editingSubscription.linkedEmails || [])];
                                newEmails[idx] = { ...newEmails[idx], usedFor: e.target.value };
                                setEditingSubscription({ ...editingSubscription, linkedEmails: newEmails });
                              }}
                            />
                          </div>
                          <div className="space-y-2">
                            <label className="text-[9px] font-black text-white/40 uppercase tracking-widest ml-1">Forwarding</label>
                            <input
                              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-xs text-white outline-none focus:border-[#EBC351]/50 transition font-bold"
                              placeholder="N/A or Destination"
                              value={email.forwarding}
                              onChange={e => {
                                const newEmails = [...(editingSubscription.linkedEmails || [])];
                                newEmails[idx] = { ...newEmails[idx], forwarding: e.target.value };
                                setEditingSubscription({ ...editingSubscription, linkedEmails: newEmails });
                              }}
                            />
                          </div>
                          <div className="space-y-2">
                            <label className="text-[9px] font-black text-white/40 uppercase tracking-widest ml-1">Used In</label>
                            <input
                              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-xs text-white outline-none focus:border-[#EBC351]/50 transition font-bold"
                              placeholder="Shopify"
                              value={email.usedIn}
                              onChange={e => {
                                const newEmails = [...(editingSubscription.linkedEmails || [])];
                                newEmails[idx] = { ...newEmails[idx], usedIn: e.target.value };
                                setEditingSubscription({ ...editingSubscription, linkedEmails: newEmails });
                              }}
                            />
                          </div>
                          <div className="col-span-full space-y-2">
                            <label className="text-[9px] font-black text-white/40 uppercase tracking-widest ml-1">Access Method</label>
                            <input
                              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-xs text-white outline-none focus:border-[#EBC351]/50 transition font-bold"
                              placeholder="Gmail, Apple Mail"
                              value={email.accessMethod}
                              onChange={e => {
                                const newEmails = [...(editingSubscription.linkedEmails || [])];
                                newEmails[idx] = { ...newEmails[idx], accessMethod: e.target.value };
                                setEditingSubscription({ ...editingSubscription, linkedEmails: newEmails });
                              }}
                            />
                          </div>
                          <div className="col-span-full space-y-2">
                            <label className="text-[9px] font-black text-white/40 uppercase tracking-widest ml-1">Notes (one per line)</label>
                            <textarea
                              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2 text-xs text-white outline-none focus:border-[#EBC351]/50 transition font-bold h-24 resize-none"
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
                        <button
                          onClick={() => {
                            const newEmails = editingSubscription.linkedEmails?.filter((_, i) => i !== idx);
                            setEditingSubscription({ ...editingSubscription, linkedEmails: newEmails });
                          }}
                          className="absolute top-4 right-4 text-white/20 hover:text-orange-500 transition-colors p-1"
                        >
                          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M6 18L18 6M6 6l12 12" /></svg>
                        </button>
                      </div>
                    ))}
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
                      <button onClick={() => { onDeleteSubscription(editingSubscription.id!); setEditingSubscription(null); }} className="text-[10px] font-black text-white hover:text-orange-500">YES</button>
                      <button onClick={() => setShowDeleteConfirm(false)} className="text-[10px] font-black text-white/20 hover:text-white">NO</button>
                    </div>
                  ) : (
                    <button onClick={() => setShowDeleteConfirm(true)} className="text-[10px] font-black text-white/20 hover:text-orange-500 uppercase tracking-widest">Delete</button>
                  )
                )}
              </div>
              <div className="flex space-x-4">
                <button onClick={() => setEditingSubscription(null)} className="px-6 py-3 text-[11px] font-black text-white/40 uppercase tracking-widest hover:text-white transition">Cancel</button>
                <button onClick={handleSaveModal} className="px-8 py-3 bg-[#EBC351] rounded-2xl text-[11px] font-black text-black uppercase tracking-widest shadow-lg shadow-[#EBC351]/20 hover:scale-[1.02] active:scale-95 transition">Save Account</button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default SubscriptionList;
