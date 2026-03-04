
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
  const datePickerRef = useRef<HTMLInputElement>(null);

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
      email: '',
      emailPurpose: '',
      twoFactorAuth: 'None',
      website: ''
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
    const subServicesMonthly = s.subServices?.reduce((sum, ss) => sum + ss.cost, 0) || 0;
    return acc + baseMonthly + subServicesMonthly;
  }, 0);

  const activeStack = subscriptions.length;

  return (
    <div className="bg-slate-50/50 min-h-screen text-slate-900 p-4 space-y-8 animate-fadeIn">
      {/* Action Bar */}
      <div className="flex items-center justify-between pr-2">
        <div className="flex items-center gap-3">
          <div className="bg-white h-[48px] px-5 rounded-xl border border-slate-200 flex items-center gap-4 shadow-sm shrink-0">
            <span className="text-[10px] font-black text-slate-400 uppercase tracking-widest text-nowrap">burn /mo</span>
            <span className="text-base font-black text-slate-900 tracking-tight">${monthlyBurn.toFixed(0)}</span>
          </div>

          <div className="bg-white h-[48px] px-5 rounded-xl border border-slate-200 flex items-center gap-4 shadow-sm shrink-0">
            <span className="text-[10px] font-black text-slate-400 uppercase tracking-widest text-nowrap">stacks</span>
            <span className="text-base font-black text-slate-900 tracking-tight">{activeStack}</span>
          </div>
        </div>

        <button
          onClick={handleAddNew}
          className="bg-indigo-600 text-white px-5 h-[48px] rounded-xl text-[10px] font-black uppercase tracking-widest hover:bg-indigo-700 transition flex items-center space-x-2 shadow-sm active:scale-95"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M12 4v16m8-8H4" /></svg>
          <span>Account</span>
        </button>
      </div>

      {/* Subscription cards List */}
      <div className="space-y-4">
        {subscriptions.map(sub => (
          <div key={sub.id} className="bg-white rounded-[24px] overflow-hidden border border-slate-100 shadow-sm hover:shadow-md transition-shadow">
            {/* Main Info */}
            <div className="p-6 space-y-6">
              <div className="flex justify-between items-start">
                <div className="flex items-center space-x-4">
                  <div
                    className="w-14 h-14 bg-slate-50 rounded-2xl flex items-center justify-center border border-slate-100 cursor-pointer hover:bg-slate-100 hover:border-indigo-500/30 transition-all duration-300 group/logo overflow-hidden"
                    onClick={() => setEditingSubscription(sub)}
                    title="Edit Service"
                  >
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
                      className="text-slate-400 font-black text-xl opacity-80 group-hover/logo:text-indigo-600 transition-colors"
                      style={{ display: sub.website ? 'none' : 'flex' }}
                    >
                      {sub.name.charAt(0)}
                    </span>
                  </div>
                  <div>
                    <h3 className="text-lg font-black tracking-tight text-slate-900 uppercase">{sub.name}</h3>
                    <p className="text-[11px] text-slate-400 font-bold tracking-wide">{sub.website || 'website.com'}</p>
                  </div>
                </div>
                <div className="text-right">
                  <p className="text-xl font-black text-slate-900">
                    ${(sub.cost + (sub.subServices?.reduce((acc, s) => acc + s.cost, 0) || 0)).toFixed(2)}
                  </p>
                  <p className="text-[10px] text-slate-400 font-bold uppercase tracking-widest">{sub.billingCycle}</p>
                </div>
              </div>

              {/* Status Badge */}
              <div className="flex items-center space-x-2">
                <div className="h-2 w-2 rounded-full bg-emerald-400 shadow-sm"></div>
                <span className="text-emerald-600 text-[11px] font-black uppercase tracking-[0.1em]">Auto Renew</span>
              </div>

              {/* Info Grid */}
              <div className="grid grid-cols-2 gap-y-6 gap-x-8 pt-2">
                <div className="space-y-1">
                  <p className="text-[9px] font-black text-slate-400 uppercase tracking-widest">Paid From</p>
                  <p className="text-xs font-bold text-slate-700">{sub.paymentMethod || 'Amex ••• 8474'}</p>
                </div>
                <div className="space-y-1">
                  <p className="text-[9px] font-black text-slate-400 uppercase tracking-widest">Next Renewal</p>
                  <p className="text-xs font-bold text-slate-700">{sub.nextRenewal}</p>
                </div>
              </div>
            </div>

            {/* Supplemental Services Accordion */}
            <div className="border-t border-slate-100">
              <button
                onClick={() => toggleExpanded(sub.id)}
                className="w-full h-14 px-6 flex items-center justify-between text-indigo-600 group hover:bg-slate-50/50 transition-colors"
              >
                <div className="flex items-center space-x-3">
                  <span className="text-[11px] font-black uppercase tracking-[0.15em]">Supplemental Services</span>
                  <div className="px-1.5 py-0.5 rounded bg-indigo-50 text-[9px] font-black text-indigo-600">
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
                        <div className="h-1.5 w-1.5 rounded-full bg-emerald-400"></div>
                        <span className="text-xs font-bold text-slate-700">{child.name}</span>
                        <span className="text-[9px] font-black text-emerald-600 uppercase tracking-tighter opacity-80">Active</span>
                      </div>
                      <span className="text-xs font-black text-slate-900">${child.cost.toFixed(2)}</span>
                    </div>
                  ))}
                  <button
                    onClick={() => addSubServiceToSubscription(sub)}
                    className="text-[10px] font-black text-slate-400 uppercase tracking-widest pt-2 hover:text-indigo-600 transition"
                  >
                    + add item
                  </button>
                </div>
              )}
            </div>

            {/* Linked Emails Accordion */}
            <div className="border-t border-slate-100">
              <button
                onClick={() => toggleEmailExpanded(sub.id)}
                className="w-full h-14 px-6 flex items-center justify-between text-indigo-600 group bg-slate-50/50 hover:bg-slate-100/50 transition-colors"
              >
                <div className="flex items-center space-x-3">
                  <span className="text-[11px] font-black uppercase tracking-[0.15em]">Linked Emails</span>
                  <div className="px-1.5 py-0.5 rounded bg-indigo-50 text-[9px] font-black text-indigo-600">
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
                      <div key={emailId} className="pt-2 first:pt-0 border-t border-slate-100 first:border-0 relative group/email">
                        {/* Header Toggle */}
                        <button
                          onClick={() => toggleDetailExpanded(emailId)}
                          className="w-full text-left grid grid-cols-[1fr,1fr,auto] gap-x-8 py-2 hover:bg-slate-50 transition-colors rounded-xl px-4 -mx-4 group/toggle"
                        >
                          <div className="space-y-1">
                            <p className="text-[9px] font-black text-slate-400 uppercase tracking-widest">Email</p>
                            <p className="text-xs font-bold text-slate-700 truncate">{email.email}</p>
                          </div>
                          <div className="space-y-1">
                            <p className="text-[9px] font-black text-slate-400 uppercase tracking-widest">Used For</p>
                            <p className="text-xs font-bold text-slate-700 truncate">{email.usedFor}</p>
                          </div>
                          <div className="flex items-center">
                            <svg
                              className={`w-3 h-3 text-slate-300 group-hover/toggle:text-indigo-600 transform transition-all duration-500 ease-[cubic-bezier(0.16,1,0.3,1)] ${isExpanded ? 'rotate-180 text-indigo-600' : ''}`}
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
                              <p className="text-[9px] font-black text-slate-400 uppercase tracking-widest">Forwarding</p>
                              <p className="text-xs font-bold text-slate-700">{email.forwarding || 'N/A'}</p>
                            </div>
                            <div className="space-y-1">
                              <p className="text-[9px] font-black text-slate-400 uppercase tracking-widest">Used In</p>
                              <p className="text-xs font-bold text-slate-700">{email.usedIn}</p>
                            </div>

                            {/* Row 3 */}
                            <div className="col-span-2 space-y-1">
                              <p className="text-[9px] font-black text-slate-400 uppercase tracking-widest">Access Method</p>
                              <p className="text-xs font-bold text-slate-700">{email.accessMethod}</p>
                            </div>

                            {/* Row 4: Notes */}
                            <div className="col-span-2 space-y-2">
                              <p className="text-[9px] font-black text-slate-400 uppercase tracking-widest">Notes</p>
                              <div className="space-y-1">
                                {email.notes.map((note, nIdx) => (
                                  <div key={nIdx} className="flex items-start space-x-2">
                                    <span className="text-indigo-500 mt-1">•</span>
                                    <p className="text-xs text-slate-600 leading-relaxed font-medium">{note}</p>
                                  </div>
                                ))}
                                <button className="text-[10px] font-black text-indigo-600 uppercase tracking-widest pt-1 hover:text-indigo-800 transition-colors">
                                  + add note
                                </button>
                              </div>
                            </div>

                            <div className="col-span-2 pt-2 flex justify-end">
                              <button
                                onClick={() => setEditingSubscription(sub)}
                                className="text-[10px] font-black text-indigo-600 uppercase tracking-widest hover:text-indigo-800 transition-colors py-1 flex items-center space-x-1"
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
                    className="text-[10px] font-black text-slate-400 uppercase tracking-widest pt-2 hover:text-indigo-600 transition"
                  >
                    + add email
                  </button>

                  {(!sub.linkedEmails || sub.linkedEmails.length === 0) && (
                    <div className="text-center py-4 text-[10px] font-black text-slate-300 uppercase tracking-widest">
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
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 animate-fadeIn overflow-y-auto">
          <div className="absolute inset-0 bg-black/50 backdrop-blur-sm" onClick={() => setEditingSubscription(null)} />
          <div className="relative bg-white rounded-[24px] shadow-2xl w-full max-w-xl border border-slate-100 overflow-hidden animate-scaleIn">
            <div className="p-8 border-b border-slate-100 flex justify-between items-center">
              <h3 className="text-xl font-black tracking-tight text-slate-900 uppercase">
                {editingSubscription.id ? 'Edit Service' : 'New Service'}
              </h3>
              <button
                onClick={() => setEditingSubscription(null)}
                className="text-slate-400 hover:text-slate-600 transition-colors p-2 -mr-2"
              >
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M6 18L18 6M6 6l12 12" /></svg>
              </button>
            </div>

            <div className="p-8 space-y-8 max-h-[65vh] overflow-y-auto custom-scrollbar">
              <div className="space-y-6">
                <div className="space-y-2">
                  <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest px-1">Service Name</label>
                  <input
                    className="w-full bg-white border border-slate-200 rounded-xl px-5 py-3.5 text-slate-900 outline-none focus:ring-2 focus:ring-indigo-500 transition-all font-bold placeholder:text-slate-300"
                    value={editingSubscription.name || ''}
                    placeholder="e.g. Shopify"
                    onChange={e => setEditingSubscription({ ...editingSubscription, name: e.target.value })}
                  />
                </div>
                <div className="grid grid-cols-2 gap-6">
                  <div className="space-y-2">
                    <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest px-1">Cost / mo</label>
                    <input
                      type="number"
                      className="w-full bg-white border border-slate-200 rounded-xl px-5 py-3.5 text-slate-900 outline-none focus:ring-2 focus:ring-indigo-500 transition-all font-bold"
                      value={editingSubscription.cost || ''}
                      onChange={e => setEditingSubscription({ ...editingSubscription, cost: parseFloat(e.target.value) || 0 })}
                    />
                  </div>
                  <div className="space-y-2">
                    <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest px-1">Billing Cycle</label>
                    <select
                      className="w-full bg-white border border-slate-200 rounded-xl px-5 py-3.5 text-slate-900 outline-none focus:ring-2 focus:ring-indigo-500 transition-all font-bold appearance-none cursor-pointer"
                      value={editingSubscription.billingCycle || 'Monthly'}
                      onChange={e => setEditingSubscription({ ...editingSubscription, billingCycle: e.target.value as any })}
                    >
                      <option value="Monthly">Monthly</option>
                      <option value="Yearly">Yearly</option>
                    </select>
                  </div>
                </div>
                <div className="space-y-2">
                  <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest px-1">Website URL</label>
                  <input
                    className="w-full bg-white border border-slate-200 rounded-xl px-5 py-3.5 text-slate-900 outline-none focus:ring-2 focus:ring-indigo-500 transition-all font-bold placeholder:text-slate-300"
                    value={editingSubscription.website || ''}
                    placeholder="shopify.com"
                    onChange={e => setEditingSubscription({ ...editingSubscription, website: e.target.value })}
                  />
                </div>
                <div className="space-y-2">
                  <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest px-1">2FA Status</label>
                  <input
                    className="w-full bg-white border border-slate-200 rounded-xl px-5 py-3.5 text-slate-900 outline-none focus:ring-2 focus:ring-indigo-500 transition-all font-bold placeholder:text-slate-300"
                    value={editingSubscription.twoFactorAuth || ''}
                    placeholder="Authenticator"
                    onChange={e => setEditingSubscription({ ...editingSubscription, twoFactorAuth: e.target.value })}
                  />
                </div>

                {/* Sub-services Management Section */}
                <div className="pt-8 border-t border-slate-100">
                  <div className="flex justify-between items-center mb-6">
                    <h4 className="text-[10px] font-black text-indigo-600 uppercase tracking-widest px-1">Supplemental Services</h4>
                    <button
                      onClick={handleAddSubService}
                      className="text-[10px] font-black text-indigo-600 bg-indigo-50 px-4 py-2 rounded-lg hover:bg-indigo-100 transition-colors uppercase tracking-widest"
                    >
                      + Add New
                    </button>
                  </div>

                  <div className="space-y-3">
                    {(editingSubscription.subServices || []).map((child, idx) => (
                      <div key={child.id} className="bg-slate-50 p-4 rounded-xl flex flex-col md:flex-row gap-4 items-end md:items-center border border-slate-100 group/sub relative transition-all hover:bg-slate-100/50">
                        <div className="flex-1 grid grid-cols-2 md:grid-cols-3 gap-3 w-full">
                          <div className="md:col-span-2">
                            <input
                              className="w-full bg-white border border-slate-200 rounded-lg px-4 py-2 text-xs text-slate-900 outline-none focus:ring-2 focus:ring-indigo-500 transition-all font-bold"
                              placeholder="Service Name (e.g. Storage)"
                              value={child.name}
                              onChange={e => {
                                const newSubs = [...(editingSubscription.subServices || [])];
                                newSubs[idx] = { ...newSubs[idx], name: e.target.value };
                                setEditingSubscription({ ...editingSubscription, subServices: newSubs });
                              }}
                            />
                          </div>
                          <div className="relative">
                            <span className="absolute left-3 top-2 text-slate-400 text-xs">$</span>
                            <input
                              type="number"
                              className="w-full bg-white border border-slate-200 rounded-lg pl-6 pr-4 py-2 text-xs text-slate-900 outline-none focus:ring-2 focus:ring-indigo-500 transition-all font-bold"
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
                        <button
                          onClick={() => {
                            const newSubs = editingSubscription.subServices?.filter((_, i) => i !== idx);
                            setEditingSubscription({ ...editingSubscription, subServices: newSubs });
                          }}
                          className="text-slate-400 hover:text-red-500 transition-colors p-2"
                        >
                          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M6 18L18 6M6 6l12 12" /></svg>
                        </button>
                      </div>
                    ))}
                    {(!editingSubscription.subServices || editingSubscription.subServices.length === 0) && (
                      <div className="text-center py-8 bg-slate-50 border border-dashed border-slate-200 rounded-xl text-slate-400 text-[10px] font-black uppercase tracking-widest">
                        No supplemental services added
                      </div>
                    )}
                  </div>
                </div>

                {/* Linked Emails Management Section */}
                <div className="pt-8 border-t border-slate-100">
                  <div className="flex justify-between items-center mb-6">
                    <h4 className="text-[10px] font-black text-indigo-600 uppercase tracking-widest px-1">Linked Emails</h4>
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
                      className="text-[10px] font-black text-indigo-600 bg-indigo-50 px-4 py-2 rounded-lg hover:bg-indigo-100 transition-colors uppercase tracking-widest"
                    >
                      + Add email
                    </button>
                  </div>

                  <div className="space-y-4">
                    {(editingSubscription.linkedEmails || []).map((email, idx) => (
                      <div key={email.id} className="bg-slate-50 p-6 rounded-2xl border border-slate-100 space-y-4 relative group/email-edit transition-all hover:bg-slate-100/50">
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                          <div className="space-y-2">
                            <label className="text-[9px] font-black text-slate-500 uppercase tracking-widest px-1">Email Address</label>
                            <input
                              className="w-full bg-white border border-slate-200 rounded-xl px-4 py-2.5 text-xs text-slate-900 outline-none focus:ring-2 focus:ring-indigo-500 transition-all font-bold"
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
                            <label className="text-[9px] font-black text-slate-500 uppercase tracking-widest px-1">Used For</label>
                            <input
                              className="w-full bg-white border border-slate-200 rounded-xl px-4 py-2.5 text-xs text-slate-900 outline-none focus:ring-2 focus:ring-indigo-500 transition-all font-bold"
                              placeholder="e.g. Personal use"
                              value={email.usedFor}
                              onChange={e => {
                                const newEmails = [...(editingSubscription.linkedEmails || [])];
                                newEmails[idx] = { ...newEmails[idx], usedFor: e.target.value };
                                setEditingSubscription({ ...editingSubscription, linkedEmails: newEmails });
                              }}
                            />
                          </div>
                          <div className="space-y-2">
                            <label className="text-[9px] font-black text-slate-500 uppercase tracking-widest px-1">Forwarding</label>
                            <input
                              className="w-full bg-white border border-slate-200 rounded-xl px-4 py-2.5 text-xs text-slate-900 outline-none focus:ring-2 focus:ring-indigo-500 transition-all font-bold"
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
                            <label className="text-[9px] font-black text-slate-500 uppercase tracking-widest px-1">Used In</label>
                            <input
                              className="w-full bg-white border border-slate-200 rounded-xl px-4 py-2.5 text-xs text-slate-900 outline-none focus:ring-2 focus:ring-indigo-500 transition-all font-bold"
                              placeholder="e.g. Shopify"
                              value={email.usedIn}
                              onChange={e => {
                                const newEmails = [...(editingSubscription.linkedEmails || [])];
                                newEmails[idx] = { ...newEmails[idx], usedIn: e.target.value };
                                setEditingSubscription({ ...editingSubscription, linkedEmails: newEmails });
                              }}
                            />
                          </div>
                          <div className="col-span-full space-y-2">
                            <label className="text-[9px] font-black text-slate-500 uppercase tracking-widest px-1">Access Method</label>
                            <input
                              className="w-full bg-white border border-slate-200 rounded-xl px-4 py-2.5 text-xs text-slate-900 outline-none focus:ring-2 focus:ring-indigo-500 transition-all font-bold"
                              placeholder="e.g. Gmail, Apple Mail"
                              value={email.accessMethod}
                              onChange={e => {
                                const newEmails = [...(editingSubscription.linkedEmails || [])];
                                newEmails[idx] = { ...newEmails[idx], accessMethod: e.target.value };
                                setEditingSubscription({ ...editingSubscription, linkedEmails: newEmails });
                              }}
                            />
                          </div>
                          <div className="col-span-full space-y-2">
                            <label className="text-[9px] font-black text-slate-500 uppercase tracking-widest px-1">Notes (one per line)</label>
                            <textarea
                              className="w-full bg-white border border-slate-200 rounded-xl px-4 py-3 text-xs text-slate-900 outline-none focus:ring-2 focus:ring-indigo-500 transition-all font-bold h-28 resize-none placeholder:text-slate-300"
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
                          className="absolute top-4 right-4 text-slate-300 hover:text-red-500 transition-colors p-2"
                        >
                          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M6 18L18 6M6 6l12 12" /></svg>
                        </button>
                      </div>
                    ))}
                    {(!editingSubscription.linkedEmails || editingSubscription.linkedEmails.length === 0) && (
                      <div className="text-center py-8 bg-slate-50 border border-dashed border-slate-200 rounded-xl text-slate-400 text-[10px] font-black uppercase tracking-widest">
                        No linked emails added
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </div>

            <div className="p-8 bg-slate-50 border-t border-slate-100 flex justify-end items-center space-x-4">
              <button
                onClick={() => setEditingSubscription(null)}
                className="px-6 py-3 text-[11px] font-black text-slate-500 uppercase tracking-widest hover:text-slate-700 hover:bg-slate-100 rounded-xl transition-all"
              >
                Cancel
              </button>
              <button
                onClick={handleSaveModal}
                className="px-8 py-3 bg-indigo-600 rounded-xl text-[11px] font-black text-white uppercase tracking-widest shadow-md hover:bg-indigo-700 active:scale-95 transition-all"
              >
                Save service
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default SubscriptionList;
