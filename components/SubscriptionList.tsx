
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
      emailPurpose: ''
    });
  };

  const handleEditSubscription = (sub: Subscription) => {
    setShowDeleteConfirm(false);
    setEditingSubscription(sub);
  };

  const openEditWithNewSubService = (sub: Subscription) => {
    const newSubService: SubService = {
      id: Math.random().toString(36).substr(2, 9),
      name: '',
      cost: 0,
      status: 'Active'
    };
    setEditingSubscription({
      ...sub,
      subServices: [...(sub.subServices || []), newSubService]
    });
  };

  const handleSaveModal = () => {
    if (editingSubscription) {
      if (editingSubscription.id) {
        onUpdateSubscription(editingSubscription.id, editingSubscription);
      } else if (onAddSubscription) {
        onAddSubscription(editingSubscription);
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

  const handleUpdateSubService = (index: number, updates: Partial<SubService>) => {
    if (!editingSubscription || !editingSubscription.subServices) return;
    const newSubs = [...editingSubscription.subServices];
    newSubs[index] = { ...newSubs[index], ...updates };
    setEditingSubscription({ ...editingSubscription, subServices: newSubs });
  };

  const handleDeleteSubService = (index: number) => {
    if (!editingSubscription || !editingSubscription.subServices) return;
    const newSubs = editingSubscription.subServices.filter((_, i) => i !== index);
    setEditingSubscription({ ...editingSubscription, subServices: newSubs });
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

  const openDatePicker = () => {
    try {
      if (datePickerRef.current) {
        if (typeof datePickerRef.current.showPicker === 'function') {
          datePickerRef.current.showPicker();
        } else {
          datePickerRef.current.focus();
        }
      }
    } catch (e) {
      console.warn('Could not open date picker', e);
    }
  };

  // Stats Calculations
  const totalMonthlyBurn = subscriptions.reduce((acc, s) => {
    const parentCost = s.billingCycle === 'Monthly' ? s.cost : s.cost / 12;
    const subsCost = (s.subServices || []).reduce((sum, sub) => sum + sub.cost, 0);
    const subBurn = s.billingCycle === 'Monthly' ? subsCost : subsCost / 12;
    return acc + parentCost + subBurn;
  }, 0);

  const activeToolsCount = subscriptions.reduce((acc, s) => {
    let count = s.status === 'Active' ? 1 : 0;
    count += (s.subServices || []).filter(sub => sub.status === 'Active').length;
    return acc + count;
  }, 0);

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'Active': return 'bg-emerald-50 text-emerald-700 border-emerald-100';
      case 'Cancelled': return 'bg-rose-50 text-rose-700 border-rose-100';
      case 'Pending': return 'bg-amber-50 text-amber-700 border-amber-100';
      default: return 'bg-slate-50 text-slate-500 border-slate-100';
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center px-1">
        <h3 className="text-lg font-bold text-slate-800">Tech Stack & Subscriptions</h3>
        {onAddSubscription && (
          <button
            onClick={handleAddNew}
            className="bg-indigo-600 text-white px-4 py-2 rounded-lg text-sm font-semibold hover:bg-indigo-700 transition shadow-sm active:scale-95"
          >
            + Add Tool
          </button>
        )}
      </div>

      {/* Pop-up Edit/Add Modal */}
      {editingSubscription && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-fadeIn overflow-y-auto">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-2xl text-slate-900 my-auto">
            <div className="p-6 border-b border-slate-100 flex justify-between items-center bg-white z-10 rounded-t-2xl">
              <h3 className="text-xl font-bold text-slate-900">
                {editingSubscription.id ? `${editingSubscription.name} Details` : 'Add Tech Stack'}
              </h3>
              <button onClick={() => setEditingSubscription(null)} className="text-slate-400 hover:text-slate-600">
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" /></svg>
              </button>
            </div>

            <div className="p-6 space-y-6 max-h-[70vh] overflow-y-auto">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="md:col-span-2">
                  <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Service Name</label>
                  <input
                    className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                    value={editingSubscription.name || ''}
                    placeholder="e.g. Jira"
                    onChange={e => setEditingSubscription({ ...editingSubscription, name: e.target.value })}
                  />
                </div>

                <div className="md:col-span-2 grid grid-cols-1 md:grid-cols-2 gap-4 border-l-4 border-rose-800 bg-rose-50/30 p-4 rounded-r-lg">
                  <div>
                    <label className="block text-xs font-bold text-rose-800 uppercase mb-1">Associated Email</label>
                    <input
                      className="w-full px-3 py-2 border border-rose-200 rounded-lg focus:ring-2 focus:ring-rose-500 outline-none text-black bg-white"
                      value={editingSubscription.email || ''}
                      placeholder="e.g. founder@company.com"
                      onChange={e => setEditingSubscription({ ...editingSubscription, email: e.target.value })}
                    />
                  </div>
                  <div className="flex flex-col gap-1 flex-1">
                    <label className="block text-xs font-bold text-rose-800 uppercase mb-1 flex justify-between">
                      Email Purpose / Context
                      {editingSubscription.name && (
                        <button
                          type="button"
                          onClick={async () => {
                            const purpose = await generateSubscriptionEmailPurpose(editingSubscription.name);
                            if (purpose) setEditingSubscription({ ...editingSubscription, emailPurpose: purpose });
                          }}
                          className="text-[9px] text-indigo-600 hover:text-indigo-800 flex items-center gap-1 normal-case font-bold"
                        >
                          <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M13 10V3L4 14h7v7l9-11h-7z" /></svg>
                          AI Suggest
                        </button>
                      )}
                    </label>
                    <input
                      className="w-full px-3 py-2 border border-rose-200 rounded-lg focus:ring-2 focus:ring-rose-500 outline-none text-black bg-white"
                      value={editingSubscription.emailPurpose || ''}
                      placeholder="e.g. Primary Admin & Billing"
                      onChange={e => setEditingSubscription({ ...editingSubscription, emailPurpose: e.target.value })}
                    />
                  </div>
                </div>

                <div className="md:col-span-2 grid grid-cols-2 gap-4 bg-slate-50 p-4 rounded-lg border border-slate-100">
                  <div>
                    <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Cost</label>
                    <div className="relative">
                      <span className="absolute left-3 top-2 text-slate-400">$</span>
                      <input
                        type="number"
                        step="0.01"
                        className="w-full pl-6 pr-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                        value={editingSubscription.cost || ''}
                        onChange={e => setEditingSubscription({ ...editingSubscription, cost: parseFloat(e.target.value) })}
                      />
                    </div>
                  </div>
                  <div>
                    <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Billing Cycle</label>
                    <select
                      className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                      value={editingSubscription.billingCycle || 'Monthly'}
                      onChange={e => setEditingSubscription({ ...editingSubscription, billingCycle: e.target.value as any })}
                    >
                      <option value="Monthly">Monthly</option>
                      <option value="Yearly">Yearly</option>
                    </select>
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Paid From</label>
                  <input
                    className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                    value={editingSubscription.paymentMethod || ''}
                    placeholder="e.g. Visa 4242"
                    onChange={e => setEditingSubscription({ ...editingSubscription, paymentMethod: e.target.value })}
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Status</label>
                  <select
                    className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                    value={editingSubscription.status || 'Active'}
                    onChange={e => setEditingSubscription({ ...editingSubscription, status: e.target.value as any })}
                  >
                    <option value="Active">Active</option>
                    <option value="Cancelled">Cancelled</option>
                    <option value="Pending">Pending</option>
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Next Renewal</label>
                  <div className="relative">
                    <input
                      type="text"
                      className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white pr-10"
                      placeholder="e.g. 1st or YYYY-MM-DD"
                      value={editingSubscription.nextRenewal || ''}
                      onChange={e => setEditingSubscription({ ...editingSubscription, nextRenewal: e.target.value })}
                    />
                    <button
                      type="button"
                      onClick={openDatePicker}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-indigo-600 focus:outline-none"
                      title="Pick a date"
                    >
                      <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" /></svg>
                    </button>
                    <input
                      type="date"
                      ref={datePickerRef}
                      className="opacity-0 absolute bottom-0 left-0 w-1 h-1 pointer-events-none"
                      tabIndex={-1}
                      onChange={e => setEditingSubscription({ ...editingSubscription, nextRenewal: e.target.value })}
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Renew Type</label>
                  <select
                    className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                    value={editingSubscription.renew || 'Auto'}
                    onChange={e => setEditingSubscription({ ...editingSubscription, renew: e.target.value as any })}
                  >
                    <option value="Auto">Auto</option>
                    <option value="Manual">Manual</option>
                  </select>
                </div>

                <div className="md:col-span-2 border-t border-slate-100 pt-4 mt-2">
                  <div className="flex justify-between items-center mb-3">
                    <label className="block text-xs font-bold text-slate-500 uppercase tracking-wide">Add-ons / Affiliated Seats</label>
                    <button
                      type="button"
                      onClick={handleAddSubService}
                      className="text-xs font-bold text-indigo-600 hover:text-indigo-800"
                    >
                      + Add Line Item
                    </button>
                  </div>

                  <div className="space-y-3">
                    {(editingSubscription.subServices || []).map((sub, idx) => (
                      <div key={idx} className="flex gap-3 items-start bg-slate-50 p-3 rounded-lg border border-slate-100">
                        <div className="flex-1 space-y-2">
                          <input
                            className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white text-sm"
                            placeholder="Name (e.g. Extra Seat)"
                            value={sub.name}
                            onChange={e => handleUpdateSubService(idx, { name: e.target.value })}
                          />
                          <div className="flex gap-2">
                            <div className="relative w-32">
                              <span className="absolute left-3 top-2 text-slate-400 text-sm">$</span>
                              <input
                                type="number"
                                className="w-full pl-6 px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white text-sm"
                                placeholder="0.00"
                                value={sub.cost}
                                onChange={e => handleUpdateSubService(idx, { cost: parseFloat(e.target.value) })}
                              />
                            </div>
                            <select
                              className="px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white text-sm flex-1"
                              value={sub.status}
                              onChange={e => handleUpdateSubService(idx, { status: e.target.value as any })}
                            >
                              <option value="Active">Active</option>
                              <option value="Cancelled">Cancelled</option>
                              <option value="Pending">Pending</option>
                            </select>
                          </div>
                        </div>
                        <button
                          type="button"
                          onClick={() => handleDeleteSubService(idx)}
                          className="text-slate-300 hover:text-rose-500 p-2"
                        >
                          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" /></svg>
                        </button>
                      </div>
                    ))}
                    {(!editingSubscription.subServices || editingSubscription.subServices.length === 0) && (
                      <p className="text-sm text-slate-400 italic">No add-ons currently tracked.</p>
                    )}
                  </div>
                </div>
              </div>
            </div>

            <div className="p-6 border-t border-slate-100 bg-slate-50 rounded-b-2xl flex flex-col md:flex-row items-center justify-between gap-4">
              <div className="w-full md:w-auto">
                {editingSubscription.id && onDeleteSubscription && (
                  showDeleteConfirm ? (
                    <div className="flex items-center space-x-3 bg-rose-50 px-3 py-1.5 rounded-lg border border-rose-100 w-full justify-between md:justify-start">
                      <span className="text-xs font-bold text-rose-700 uppercase">Delete?</span>
                      <div className="flex gap-2">
                        <button
                          onClick={() => {
                            if (editingSubscription.id) onDeleteSubscription(editingSubscription.id);
                            setEditingSubscription(null);
                          }}
                          className="text-xs bg-rose-600 text-white px-3 py-1.5 rounded font-bold hover:bg-rose-700 shadow-sm"
                        >
                          Yes
                        </button>
                        <button
                          onClick={() => setShowDeleteConfirm(false)}
                          className="text-xs text-slate-500 hover:text-slate-800 font-bold underline px-1"
                        >
                          Cancel
                        </button>
                      </div>
                    </div>
                  ) : (
                    <button
                      onClick={() => setShowDeleteConfirm(true)}
                      className="text-rose-500 text-sm font-medium hover:text-rose-700 transition-colors flex items-center group"
                    >
                      <svg className="w-4 h-4 mr-1 group-hover:scale-110 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                      Remove Technology
                    </button>
                  )
                )}
              </div>
              <div className="flex space-x-3 w-full md:w-auto justify-end">
                <button
                  onClick={() => setEditingSubscription(null)}
                  className="px-4 py-2 text-slate-600 font-bold hover:text-slate-800"
                >
                  Cancel
                </button>
                <button
                  onClick={handleSaveModal}
                  className="px-6 py-2 bg-indigo-600 text-white rounded-lg font-bold shadow-sm hover:bg-indigo-700 transition"
                >
                  {editingSubscription.id ? 'Save Changes' : 'Add Tool'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Main Responsive Grid Layout for Subscriptions */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {subscriptions.length === 0 ? (
          <div className="md:col-span-2 py-16 text-center bg-white rounded-xl border border-slate-100 shadow-sm">
            <div className="w-16 h-16 bg-slate-50 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg className="w-8 h-8 text-slate-300" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z" /></svg>
            </div>
            <p className="text-slate-500 font-medium">No tech stack tracked. Start by adding one above.</p>
          </div>
        ) : (
          subscriptions.map(sub => {
            const totalCost = sub.cost + (sub.subServices || []).reduce((acc, item) => acc + item.cost, 0);
            const isEmailExpanded = expandedEmails.has(sub.id);

            return (
              <div
                key={sub.id}
                className="bg-white rounded-2xl border border-slate-100 shadow-sm hover:shadow-lg transition-all group overflow-hidden flex flex-col"
              >
                {/* Card Header */}
                <div className="p-4 border-b border-slate-50 flex justify-between items-start bg-gradient-to-r from-white to-slate-50/50">
                  <div className="flex items-center space-x-3 min-w-0">
                    <div className="w-10 h-10 bg-indigo-50 rounded-lg flex items-center justify-center font-bold text-indigo-600 uppercase text-sm flex-shrink-0">
                      {sub.name.charAt(0)}
                    </div>
                    <div className="min-w-0">
                      <button
                        onClick={() => handleEditSubscription(sub)}
                        className="text-base font-bold text-slate-900 hover:text-indigo-600 hover:underline text-left transition-colors truncate w-full block"
                      >
                        {sub.name}
                      </button>
                      <div className="flex items-center gap-1.5">
                        <span className={`text-[10px] font-bold uppercase tracking-widest px-1.5 py-0.5 rounded border ${getStatusColor(sub.status)}`}>
                          {sub.status}
                        </span>
                        {sub.renew === 'Auto' && (
                          <span className="text-[9px] font-bold text-emerald-600 bg-emerald-50 px-1 py-0.5 rounded uppercase tracking-tighter">Auto-Renew</span>
                        )}
                      </div>
                    </div>
                  </div>
                  <div className="flex flex-col items-end">
                    <p className="text-base font-black text-slate-900">${totalCost.toFixed(2)}</p>
                    <p className="text-[10px] text-slate-400 font-bold uppercase tracking-wider">{sub.billingCycle}</p>
                  </div>
                </div>

                {/* Card Body - Grid of Details */}
                <div className="p-4 grid grid-cols-2 gap-y-4 gap-x-6 border-b border-slate-50">
                  <div className="flex flex-col gap-1">
                    <span className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Paid From</span>
                    <span className="text-xs font-medium text-slate-700 truncate">{sub.paymentMethod || 'Not specified'}</span>
                  </div>
                  <div className="flex flex-col gap-1">
                    <span className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Next Renewal</span>
                    <span className="text-xs font-medium text-slate-700">{sub.nextRenewal || 'TBD'}</span>
                  </div>
                </div>

                {/* Card Footer - Sub-services Accordion */}
                <div className="bg-slate-50/50 p-2 border-b border-slate-100">
                  <div className="flex items-center justify-between px-2 py-1">
                    <button
                      onClick={() => toggleExpanded(sub.id)}
                      className="flex items-center space-x-2 text-[10px] font-bold text-slate-400 hover:text-indigo-600 transition-colors uppercase tracking-wider"
                    >
                      <span>Add-ons ({sub.subServices?.length || 0})</span>
                      <svg className={`w-3 h-3 transform transition-transform ${expandedSubs.has(sub.id) ? 'rotate-180' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 9l-7 7-7-7" /></svg>
                    </button>

                    <button
                      onClick={() => openEditWithNewSubService(sub)}
                      className="text-[9px] font-bold text-indigo-600 hover:text-indigo-800 uppercase bg-white border border-slate-200 px-2 py-0.5 rounded shadow-sm transition-all active:scale-95"
                    >
                      + Add Line
                    </button>
                  </div>

                  {expandedSubs.has(sub.id) && sub.subServices && sub.subServices.length > 0 && (
                    <div className="px-2 pb-2 mt-2 space-y-1.5 animate-fadeIn">
                      {sub.subServices.map((child, idx) => (
                        <div key={idx} className="flex items-center justify-between bg-white border border-slate-100 rounded-lg p-2 shadow-xs">
                          <div className="min-w-0 flex-1">
                            <p className="text-xs font-semibold text-slate-700 truncate">{child.name}</p>
                            <span className={`text-[8px] font-bold uppercase ${child.status === 'Active' ? 'text-emerald-500' : 'text-slate-400'}`}>
                              {child.status}
                            </span>
                          </div>
                          <div className="text-right ml-2">
                            <p className="text-xs font-bold text-slate-900">${child.cost.toFixed(2)}</p>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>

                {/* IDENTITY RECALL TAB - 40px Height, rose-800 Color */}
                <div className="flex flex-col">
                  <button
                    onClick={() => toggleEmailExpanded(sub.id)}
                    className="w-full h-[40px] bg-rose-800 hover:bg-rose-900 transition-colors flex items-center justify-between px-4 text-white group/tab"
                  >
                    <span className="text-[10px] font-black uppercase tracking-[0.2em] drop-shadow-sm">Email Logic</span>
                    <svg className={`w-4 h-4 transition-transform duration-300 ${isEmailExpanded ? 'rotate-180' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M19 9l-7 7-7-7" /></svg>
                  </button>

                  {isEmailExpanded && (
                    <div className="p-4 bg-rose-50 animate-fadeIn border-t border-rose-100">
                      <div className="flex flex-col space-y-3">
                        <div className="flex items-start gap-3">
                          <div className="w-8 h-8 rounded-lg bg-white shadow-sm flex items-center justify-center text-rose-800 flex-shrink-0">
                            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" /></svg>
                          </div>
                          <div className="min-w-0 flex-1">
                            <p className="text-[10px] font-black text-rose-800 uppercase tracking-widest mb-0.5">Account Email</p>
                            <p className="text-sm font-bold text-slate-800 truncate">{sub.email || 'No email specified'}</p>
                          </div>
                        </div>

                        <div className="pl-11 border-l-2 border-rose-200 py-1">
                          <p className="text-[10px] font-black text-rose-800 uppercase tracking-widest mb-1">Email Purpose</p>
                          <p className="text-xs text-slate-600 leading-relaxed font-medium italic">
                            "{sub.emailPurpose || 'Explain what this email is used for in the service settings...'}"
                          </p>
                        </div>

                        <div className="flex justify-end pt-1">
                          <button
                            onClick={() => handleEditSubscription(sub)}
                            className="text-[9px] font-black text-rose-800 uppercase tracking-tighter hover:underline"
                          >
                            Edit Email Context
                          </button>
                        </div>
                      </div>
                    </div>
                  )}
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* Stats Summary Section */}
      <div className="grid grid-cols-3 gap-3 md:gap-4 mt-8">
        <div className="bg-white p-3 md:p-4 rounded-xl shadow-sm border border-slate-100 flex flex-col justify-center items-center text-center">
          <p className="text-[10px] md:text-xs font-bold text-indigo-500 uppercase tracking-wider mb-1">Total Burn</p>
          <p className="text-lg md:text-2xl font-black text-slate-900">
            ${totalMonthlyBurn.toFixed(0)}
            <span className="text-[10px] md:text-xs font-normal text-slate-400 ml-0.5">/mo</span>
          </p>
        </div>
        <div className="bg-white p-3 md:p-4 rounded-xl shadow-sm border border-slate-100 flex flex-col justify-center items-center text-center">
          <p className="text-[10px] md:text-xs font-bold text-emerald-500 uppercase tracking-wider mb-1">Active Tools</p>
          <p className="text-lg md:text-2xl font-black text-slate-900">{activeToolsCount}</p>
        </div>
        <div className="bg-white p-3 md:p-4 rounded-xl shadow-sm border border-slate-100 flex flex-col justify-center items-center text-center">
          <p className="text-[10px] md:text-xs font-bold text-amber-500 uppercase tracking-wider mb-1">Auto-Renews</p>
          <p className="text-lg md:text-2xl font-black text-slate-900">
            {subscriptions.filter(s => s.status === 'Active' && s.renew === 'Auto').length}
          </p>
        </div>
      </div>
    </div>
  );
};

export default SubscriptionList;
