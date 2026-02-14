
import React, { useState, useRef } from 'react';
import { Subscription, SubService } from '../types';
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

  return (
    <div className="bg-black min-h-screen text-white p-4 space-y-8">
      {/* Action Bar */}
      <div className="flex justify-end pr-2">
        <button
          onClick={handleAddNew}
          className="bg-[#1C1C1E] text-white px-4 py-2.5 rounded-xl text-xs font-black uppercase tracking-widest hover:bg-[#2C2C2E] transition flex items-center space-x-2 border border-white/5"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M12 4v16m8-8H4" /></svg>
          <span>Account</span>
        </button>
      </div>

      {/* Subscription cards List */}
      <div className="space-y-4">
        {subscriptions.map(sub => (
          <div key={sub.id} className="bg-[#1C1C1E] rounded-[24px] overflow-hidden border border-white/5 shadow-2xl">
            {/* Main Info */}
            <div className="p-6 space-y-6">
              <div className="flex justify-between items-start">
                <div className="flex items-center space-x-4">
                  <div
                    className="w-14 h-14 bg-white/5 rounded-2xl flex items-center justify-center border border-white/10 cursor-pointer hover:bg-white/10 hover:border-[#1FE400]/30 transition-all duration-300 group/logo"
                    onClick={() => setEditingSubscription(sub)}
                    title="Edit Service"
                  >
                    <span className="text-white font-black text-xl opacity-80 group-hover/logo:text-[#1FE400] transition-colors">{sub.name.charAt(0)}</span>
                  </div>
                  <div>
                    <h3 className="text-lg font-black tracking-tight text-white uppercase">{sub.name}</h3>
                    <p className="text-[11px] text-white/40 font-bold tracking-wide">{sub.website || 'website.com'}</p>
                  </div>
                </div>
                <div className="text-right">
                  <p className="text-xl font-black text-white">
                    ${(sub.cost + (sub.subServices?.reduce((acc, s) => acc + s.cost, 0) || 0)).toFixed(2)}
                  </p>
                  <p className="text-[10px] text-white/40 font-black uppercase tracking-widest">{sub.billingCycle}</p>
                </div>
              </div>

              {/* Status Badge */}
              <div className="flex items-center space-x-2">
                <div className="h-2 w-2 rounded-full bg-[#1FE400] shadow-[0_0_8px_#1FE400]"></div>
                <span className="text-[#1FE400] text-[11px] font-black uppercase tracking-[0.1em]">Auto Renew</span>
              </div>

              {/* Info Grid */}
              <div className="grid grid-cols-2 gap-y-6 gap-x-8 pt-2">
                <div className="space-y-1">
                  <p className="text-[9px] font-black text-white/40 uppercase tracking-widest">Paid From</p>
                  <p className="text-xs font-black text-white">{sub.paymentMethod || 'Amex ••• 8474'}</p>
                </div>
                <div className="space-y-1">
                  <p className="text-[9px] font-black text-white/40 uppercase tracking-widest">Next Renewal</p>
                  <p className="text-xs font-black text-white">{sub.nextRenewal}</p>
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
                        <div className="h-1.5 w-1.5 rounded-full bg-[#1FE400] opacity-50"></div>
                        <span className="text-xs font-bold text-white/90">{child.name}</span>
                        <span className="text-[9px] font-black text-[#1FE400] uppercase tracking-tighter opacity-80">Active</span>
                      </div>
                      <span className="text-xs font-black text-white">${child.cost.toFixed(2)}</span>
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
                <div className="px-6 pb-8 space-y-8 animate-fadeIn">
                  {(sub.linkedEmails || []).map((email, idx) => (
                    <div key={email.id || idx} className="space-y-6 pt-4 first:pt-0 border-t border-white/5 first:border-0 relative group/email">
                      <div className="grid grid-cols-2 gap-x-8 gap-y-6">
                        {/* Row 1 */}
                        <div className="space-y-1">
                          <p className="text-[9px] font-black text-white/40 uppercase tracking-widest">Email</p>
                          <p className="text-xs font-black text-white">{email.email}</p>
                        </div>
                        <div className="space-y-1">
                          <p className="text-[9px] font-black text-white/40 uppercase tracking-widest">Forwarding</p>
                          <p className="text-xs font-black text-white">{email.forwarding || 'N/A'}</p>
                        </div>

                        {/* Row 2 */}
                        <div className="space-y-1">
                          <p className="text-[9px] font-black text-white/40 uppercase tracking-widest">Used For</p>
                          <p className="text-xs font-black text-white">{email.usedFor}</p>
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
                      </div>

                      <button
                        onClick={() => setEditingSubscription(sub)}
                        className="absolute bottom-0 right-0 text-[10px] font-black text-[#EBC351] uppercase tracking-widest hover:text-white transition-colors p-1"
                      >
                        + edit
                      </button>
                    </div>
                  ))}

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

      {/* Stats Summary Section */}
      <div className="grid grid-cols-2 gap-4 mt-4">
        <div className="bg-[#1C1C1E] p-6 rounded-[24px] border border-white/5">
          <p className="text-[10px] font-black text-white/40 uppercase tracking-widest mb-1">Monthly Burn</p>
          <p className="text-2xl font-black text-white tracking-tighter">
            ${subscriptions.reduce((acc, s) => {
              const baseMonthly = s.billingCycle === 'Monthly' ? s.cost : s.cost / 12;
              const subServicesMonthly = s.subServices?.reduce((sum, ss) => sum + ss.cost, 0) || 0;
              return acc + baseMonthly + subServicesMonthly;
            }, 0).toFixed(0)}
          </p>
        </div>
        <div className="bg-[#1C1C1E] p-6 rounded-[24px] border border-white/5">
          <p className="text-[10px] font-black text-white/40 uppercase tracking-widest mb-1">Active Stack</p>
          <p className="text-2xl font-black text-white tracking-tighter">
            {subscriptions.length}
          </p>
        </div>
      </div>

      {/* Editing Modal */}
      {editingSubscription && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/90 backdrop-blur-xl animate-fadeIn overflow-y-auto">
          <div className="bg-[#1C1C1E] rounded-[32px] shadow-2xl w-full max-w-xl border border-white/10 overflow-hidden">
            <div className="p-8 border-b border-white/5 flex justify-between items-center">
              <h3 className="text-xl font-black tracking-tight text-white uppercase">
                {editingSubscription.id ? 'Edit Service' : 'New Service'}
              </h3>
              <button onClick={() => setEditingSubscription(null)} className="text-white/40 hover:text-white transition">
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M6 18L18 6M6 6l12 12" /></svg>
              </button>
            </div>

            <div className="p-8 space-y-6 max-h-[60vh] overflow-y-auto custom-scrollbar">
              <div className="space-y-4">
                <div className="space-y-2">
                  <label className="text-[10px] font-black text-white/40 uppercase tracking-widest ml-1">Service Name</label>
                  <input
                    className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-3.5 text-white outline-none focus:border-[#EBC351]/50 transition font-bold"
                    value={editingSubscription.name || ''}
                    placeholder="e.g. Shopify"
                    onChange={e => setEditingSubscription({ ...editingSubscription, name: e.target.value })}
                  />
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <label className="text-[10px] font-black text-white/40 uppercase tracking-widest ml-1">Cost</label>
                    <input
                      type="number"
                      className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-3.5 text-white outline-none focus:border-[#EBC351]/50 transition font-bold"
                      value={editingSubscription.cost || ''}
                      onChange={e => setEditingSubscription({ ...editingSubscription, cost: parseFloat(e.target.value) || 0 })}
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
                <div className="space-y-2">
                  <label className="text-[10px] font-black text-white/40 uppercase tracking-widest ml-1">Website URL</label>
                  <input
                    className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-3.5 text-white outline-none focus:border-[#EBC351]/50 transition font-bold"
                    value={editingSubscription.website || ''}
                    placeholder="shopify.com"
                    onChange={e => setEditingSubscription({ ...editingSubscription, website: e.target.value })}
                  />
                </div>
                <div className="space-y-2">
                  <label className="text-[10px] font-black text-white/40 uppercase tracking-widest ml-1">2FA Status</label>
                  <input
                    className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-3.5 text-white outline-none focus:border-[#EBC351]/50 transition font-bold"
                    value={editingSubscription.twoFactorAuth || ''}
                    placeholder="Authenticator"
                    onChange={e => setEditingSubscription({ ...editingSubscription, twoFactorAuth: e.target.value })}
                  />
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
                      <div key={child.id} className="bg-white/2 p-4 rounded-2xl flex flex-col md:flex-row gap-4 items-end md:items-center border border-white/5 group/sub relative">
                        <div className="flex-1 grid grid-cols-2 md:grid-cols-3 gap-3 w-full">
                          <div className="md:col-span-2">
                            <input
                              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2 text-xs text-white outline-none focus:border-[#EBC351]/50 transition font-bold"
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
                            <span className="absolute left-3 top-2 text-white/30 text-xs">$</span>
                            <input
                              type="number"
                              className="w-full bg-white/5 border border-white/10 rounded-xl pl-6 pr-4 py-2 text-xs text-white outline-none focus:border-[#EBC351]/50 transition font-bold"
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
                          className="text-white/20 hover:text-orange-500 transition-colors p-1"
                        >
                          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M6 18L18 6M6 6l12 12" /></svg>
                        </button>
                      </div>
                    ))}
                    {(!editingSubscription.subServices || editingSubscription.subServices.length === 0) && (
                      <div className="text-center py-6 bg-white/2 border border-dashed border-white/10 rounded-2xl text-white/30 text-[10px] font-black uppercase tracking-widest">
                        No supplemental services added
                      </div>
                    )}
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
                            <label className="text-[9px] font-black text-white/40 uppercase tracking-widest ml-1">Used For</label>
                            <input
                              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-xs text-white outline-none focus:border-[#EBC351]/50 transition font-bold"
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
                            <label className="text-[9px] font-black text-white/40 uppercase tracking-widest ml-1">Used In</label>
                            <input
                              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-xs text-white outline-none focus:border-[#EBC351]/50 transition font-bold"
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
                            <label className="text-[9px] font-black text-white/40 uppercase tracking-widest ml-1">Access Method</label>
                            <input
                              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-xs text-white outline-none focus:border-[#EBC351]/50 transition font-bold"
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

            <div className="p-8 bg-black/20 border-t border-white/5 flex justify-end space-x-4">
              <button onClick={() => setEditingSubscription(null)} className="px-6 py-3 text-[11px] font-black text-white/40 uppercase tracking-widest hover:text-white transition">Cancel</button>
              <button onClick={handleSaveModal} className="px-8 py-3 bg-[#EBC351] rounded-2xl text-[11px] font-black text-black uppercase tracking-widest shadow-lg shadow-[#EBC351]/20 hover:scale-[1.02] active:scale-95 transition">Save Account</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default SubscriptionList;
