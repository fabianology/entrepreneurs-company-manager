
import React, { useState, useRef } from 'react';
import { Account, Subscription } from '../types';

interface AccountListProps {
  accounts: Account[];
  subscriptions: Subscription[];
  geminiInsights?: string;
  onAddAccount: (account: Partial<Account>) => void;
  onUpdateAccount: (id: string, updates: Partial<Account>) => void;
  onDeleteAccount: (id: string) => void;
}

const AccountList: React.FC<AccountListProps> = ({ 
  accounts, 
  onAddAccount, 
  onUpdateAccount,
  onDeleteAccount
}) => {
  const [editingAccount, setEditingAccount] = useState<Partial<Account> | null>(null);
  const [expandedNotes, setExpandedNotes] = useState<Set<string>>(new Set());
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [visiblePasswords, setVisiblePasswords] = useState<Set<string>>(new Set());
  const [showModalPassword, setShowModalPassword] = useState(false);
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const datePickerRef = useRef<HTMLInputElement>(null);
  
  const handleAddNew = () => {
    setShowDeleteConfirm(false);
    setShowModalPassword(false);
    setEditingAccount({
      platform: '',
      website: '',
      email: '',
      twoFactorAuth: 'None',
      recoveryMethod: '',
      pricingModel: 'free',
      notes: [],
      status: 'Active'
    });
  };

  const handleEditAccount = (acc: Account) => {
    setShowDeleteConfirm(false);
    setShowModalPassword(false);
    setEditingAccount(acc);
  };

  const handleSaveModal = () => {
    if (editingAccount) {
      if (editingAccount.id) {
         onUpdateAccount(editingAccount.id, editingAccount);
      } else {
         onAddAccount(editingAccount);
      }
      setEditingAccount(null);
    }
  };

  const handleEditNote = (index: number, value: string, account?: Partial<Account>) => {
    const targetAccount = account || editingAccount;
    if (!targetAccount) return;
    
    const updatedNotes = [...(targetAccount.notes || [])];
    updatedNotes[index] = value;
    
    if (account && account.id) {
       onUpdateAccount(account.id, { notes: updatedNotes });
    } else {
       setEditingAccount({ ...targetAccount, notes: updatedNotes });
    }
  };

  const addNote = (account?: Partial<Account>) => {
    const targetAccount = account || editingAccount;
    if (!targetAccount) return;
    
    const updatedNotes = [...(targetAccount.notes || []), ''];
    if (account && account.id) {
        onUpdateAccount(account.id, { notes: updatedNotes });
        if (!expandedNotes.has(account.id)) {
            toggleNote(account.id);
        }
    } else {
        setEditingAccount({ ...targetAccount, notes: updatedNotes });
    }
  };

  const removeNote = (index: number, account?: Partial<Account>) => {
    const targetAccount = account || editingAccount;
    if (!targetAccount) return;

    const updatedNotes = (targetAccount.notes || []).filter((_, i) => i !== index);
    if (account && account.id) {
        onUpdateAccount(account.id, { notes: updatedNotes });
    } else {
        setEditingAccount({ ...targetAccount, notes: updatedNotes });
    }
  };

  const toggleNote = (id: string) => {
    const newSet = new Set(expandedNotes);
    if (newSet.has(id)) newSet.delete(id);
    else newSet.add(id);
    setExpandedNotes(newSet);
  };

  const togglePasswordVisibility = (id: string) => {
    const newSet = new Set(visiblePasswords);
    if (newSet.has(id)) newSet.delete(id);
    else newSet.add(id);
    setVisiblePasswords(newSet);
  };

  const copyToClipboard = (text: string, id: string) => {
    if (!text) return;
    navigator.clipboard.writeText(text);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  const getPricingModelColor = (model: string | undefined) => {
    switch(model) {
        case 'paid': return 'bg-indigo-50 text-indigo-600 ring-1 ring-indigo-500/10';
        case 'free': return 'bg-emerald-50 text-emerald-600 ring-1 ring-emerald-500/10';
        default: return 'bg-slate-50 text-slate-500';
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center px-1">
        <h3 className="text-lg font-bold text-slate-800">Accounts & Logins</h3>
        <button 
          onClick={handleAddNew}
          className="bg-indigo-600 text-white px-4 py-2 rounded-lg text-sm font-semibold hover:bg-indigo-700 transition shadow-sm active:scale-95"
        >
          + Add Account
        </button>
      </div>

      {/* Pop-up Edit/Add Modal */}
      {editingAccount && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-fadeIn overflow-y-auto">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-2xl text-slate-900 my-auto">
            <div className="p-6 border-b border-slate-100 flex justify-between items-center bg-white z-10 rounded-t-2xl">
              <h3 className="text-xl font-bold text-slate-900">
                {editingAccount.id ? `${editingAccount.platform} Details` : 'Add New Account'}
              </h3>
              <button onClick={() => setEditingAccount(null)} className="text-slate-400 hover:text-slate-600">
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" /></svg>
              </button>
            </div>
            
            <form 
                id="account-form"
                onSubmit={(e) => { e.preventDefault(); handleSaveModal(); }}
                className="p-6 space-y-6 max-h-[70vh] overflow-y-auto"
            >
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <label htmlFor="platform" className="block text-xs font-bold text-slate-500 uppercase mb-1">Platform Name</label>
                  <input 
                    id="platform"
                    name="platform"
                    autoComplete="organization"
                    className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                    value={editingAccount.platform || ''}
                    placeholder="e.g. AWS"
                    onChange={e => setEditingAccount({...editingAccount, platform: e.target.value})}
                  />
                </div>
                <div>
                  <label htmlFor="website" className="block text-xs font-bold text-slate-500 uppercase mb-1">Website URL</label>
                  <input 
                    id="website"
                    name="website"
                    className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                    value={editingAccount.website || ''}
                    placeholder="https://app.example.com"
                    onChange={e => setEditingAccount({...editingAccount, website: e.target.value})}
                  />
                </div>
                
                <div>
                  <label htmlFor="email" className="block text-xs font-bold text-slate-500 uppercase mb-1">Email / Login ID</label>
                  <input 
                    id="email"
                    name="email"
                    type="text"
                    autoComplete="username"
                    className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                    value={editingAccount.email || ''}
                    placeholder="admin@example.com"
                    onChange={e => setEditingAccount({...editingAccount, email: e.target.value})}
                  />
                </div>
                <div>
                  <label htmlFor="password" className="block text-xs font-bold text-slate-500 uppercase mb-1">Password</label>
                  <div className="relative">
                    <input 
                        id="password"
                        name="password"
                        type={showModalPassword ? "text" : "password"}
                        autoComplete="new-password"
                        className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none font-mono text-sm text-black bg-white pr-10"
                        value={editingAccount.password || ''}
                        placeholder="••••••"
                        onChange={e => setEditingAccount({...editingAccount, password: e.target.value})}
                    />
                    <button
                        type="button"
                        onClick={() => setShowModalPassword(!showModalPassword)}
                        className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-indigo-600 focus:outline-none"
                        tabIndex={-1}
                    >
                        {showModalPassword ? (
                            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268-2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" /></svg>
                        ) : (
                            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268-2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" /></svg>
                        )}
                    </button>
                  </div>
                </div>

                <div>
                  <label htmlFor="pricingModel" className="block text-xs font-bold text-slate-500 uppercase mb-1">Pricing Model</label>
                  <select 
                    id="pricingModel"
                    name="pricingModel"
                    className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                    value={editingAccount.pricingModel || 'free'}
                    onChange={e => setEditingAccount({...editingAccount, pricingModel: e.target.value as any})}
                  >
                    <option value="free">free</option>
                    <option value="paid">paid</option>
                  </select>
                </div>
                <div>
                  <label htmlFor="status" className="block text-xs font-bold text-slate-500 uppercase mb-1">Status</label>
                  <select 
                    id="status"
                    name="status"
                    className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                    value={editingAccount.status || 'Active'}
                    onChange={e => setEditingAccount({...editingAccount, status: e.target.value as any})}
                  >
                    <option value="Active">Active</option>
                    <option value="Inactive">Inactive</option>
                    <option value="Trial">Trial</option>
                  </select>
                </div>
                
                <div>
                  <label htmlFor="twoFactorAuth" className="block text-xs font-bold text-slate-500 uppercase mb-1">2FA</label>
                  <select 
                    id="twoFactorAuth"
                    name="twoFactorAuth"
                    className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                    value={editingAccount.twoFactorAuth || 'None'}
                    onChange={e => setEditingAccount({...editingAccount, twoFactorAuth: e.target.value})}
                  >
                    <option value="Authenticator">Authenticator</option>
                    <option value="SMS">SMS</option>
                    <option value="None">None</option>
                  </select>
                </div>
                <div>
                  <label htmlFor="recoveryMethod" className="block text-xs font-bold text-slate-500 uppercase mb-1">Recovery Method</label>
                  <input 
                    id="recoveryMethod"
                    name="recoveryMethod"
                    className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                    value={editingAccount.recoveryMethod || ''}
                    placeholder="email, phone number"
                    onChange={e => setEditingAccount({...editingAccount, recoveryMethod: e.target.value})}
                  />
                </div>
                
                <div className="md:col-span-2">
                  <label className="block text-xs font-bold text-slate-500 uppercase mb-2">Notes</label>
                  <div className="space-y-2">
                    {(editingAccount.notes || []).map((note, idx) => (
                      <div key={idx} className="flex gap-2">
                        <input
                          className="flex-1 px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-sm text-black bg-white"
                          value={note}
                          onChange={e => handleEditNote(idx, e.target.value)}
                        />
                        <button onClick={() => removeNote(idx)} className="text-rose-400 hover:text-rose-600">
                          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                        </button>
                      </div>
                    ))}
                    <button 
                      type="button"
                      onClick={() => addNote()}
                      className="text-sm text-indigo-600 font-bold flex items-center hover:underline"
                    >
                      + Add Note
                    </button>
                  </div>
                </div>
              </div>
            </form>

            <div className="p-6 border-t border-slate-100 bg-slate-50 rounded-b-2xl flex flex-col md:flex-row items-center justify-between gap-4">
              <div className="w-full md:w-auto">
                {editingAccount.id && (
                  showDeleteConfirm ? (
                     <div className="flex items-center space-x-3 bg-rose-50 px-3 py-1.5 rounded-lg border border-rose-100 w-full justify-between md:justify-start">
                         <span className="text-xs font-bold text-rose-700 uppercase">Delete?</span>
                         <div className="flex gap-2">
                            <button
                                onClick={() => {
                                if (editingAccount.id) onDeleteAccount(editingAccount.id);
                                setEditingAccount(null);
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
                        Delete Service
                    </button>
                  )
                )}
              </div>
              <div className="flex space-x-3 w-full md:w-auto justify-end">
                <button 
                  onClick={() => setEditingAccount(null)}
                  className="px-4 py-2 text-slate-600 font-bold hover:text-slate-800"
                >
                  Cancel
                </button>
                <button 
                  type="submit"
                  form="account-form"
                  className="px-6 py-2 bg-indigo-600 text-white rounded-lg font-bold shadow-sm hover:bg-indigo-700 transition"
                >
                  {editingAccount.id ? 'Save' : 'Create'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Main Responsive Grid Layout */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {accounts.length === 0 ? (
          <div className="md:col-span-2 py-16 text-center bg-white rounded-xl border border-slate-100">
            <div className="w-16 h-16 bg-slate-50 rounded-full flex items-center justify-center mx-auto mb-4">
               <svg className="w-8 h-8 text-slate-300" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" /></svg>
            </div>
            <p className="text-slate-500 font-medium">No accounts found. Start by adding one above.</p>
          </div>
        ) : (
          accounts.map(acc => (
            <div 
              key={acc.id} 
              className="bg-white rounded-xl border border-slate-100 shadow-sm hover:shadow-md transition-all group overflow-hidden"
            >
              {/* Header */}
              <div className="p-4 border-b border-slate-50 flex justify-between items-start bg-gradient-to-r from-white to-slate-50/50">
                <div className="flex-1 min-w-0">
                  <button 
                    onClick={() => handleEditAccount(acc)}
                    className="text-base font-bold text-slate-900 hover:text-indigo-600 hover:underline text-left transition-colors truncate w-full"
                  >
                    {acc.platform}
                  </button>
                  {acc.website && (
                    <a 
                      href={acc.website.startsWith('http') ? acc.website : `https://${acc.website}`} 
                      target="_blank" 
                      rel="noreferrer" 
                      className="text-xs text-slate-400 hover:text-indigo-500 block truncate hover:underline"
                    >
                      {acc.website.replace(/^https?:\/\/(www\.)?/, '')}
                    </a>
                  )}
                </div>
                <div className="flex flex-col items-end gap-1.5 ml-2">
                   <span className={`px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wide ${getPricingModelColor(acc.pricingModel)}`}>
                      {acc.pricingModel}
                   </span>
                   <span className={`px-1.5 py-0.5 rounded text-[9px] font-bold uppercase tracking-tight ${
                      acc.status === 'Active' ? 'text-emerald-500' : 
                      acc.status === 'Trial' ? 'text-amber-500' : 'text-slate-400'
                    }`}>
                      {acc.status || 'Active'}
                   </span>
                </div>
              </div>

              {/* Account Data */}
              <div className="p-4 space-y-3">
                 <div className="flex flex-col gap-1">
                    <span className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Email / Identity</span>
                    <div className="flex items-center group/field">
                      <span className="text-sm text-slate-700 truncate flex-1">{acc.email}</span>
                      <button 
                        onClick={() => copyToClipboard(acc.email, `${acc.id}-email`)}
                        className="p-1 text-slate-300 hover:text-indigo-500 transition-colors opacity-0 group-hover/field:opacity-100"
                        title="Copy Email"
                      >
                         {copiedId === `${acc.id}-email` ? (
                           <svg className="w-3.5 h-3.5 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M5 13l4 4L19 7" /></svg>
                         ) : (
                           <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M8 5H6a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2v-1M8 5a2 2 0 002 2h2a2 2 0 002-2M8 5a2 2 0 012-2h2a2 2 0 012 2m0 0h2a2 2 0 012 2v3m2 4H10m0 0l3-3m-3 3l3 3" /></svg>
                         )}
                      </button>
                    </div>
                 </div>

                 <div className="grid grid-cols-2 gap-4">
                    <div className="flex flex-col gap-1">
                      <span className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">2FA / Recovery</span>
                      <div className="flex flex-col">
                         <span className="text-sm text-slate-700 font-medium">{acc.twoFactorAuth || 'None'}</span>
                         {acc.recoveryMethod && <span className="text-[10px] text-slate-400 truncate mt-0.5" title={acc.recoveryMethod}>{acc.recoveryMethod}</span>}
                      </div>
                    </div>
                    <div className="flex flex-col gap-1">
                      <span className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Password</span>
                      <div className="flex items-center space-x-2">
                        <span className="text-sm text-slate-700 font-mono tracking-wider">
                          {visiblePasswords.has(acc.id) ? acc.password : '••••••••'}
                        </span>
                        <div className="flex gap-1">
                          <button onClick={() => togglePasswordVisibility(acc.id)} className="text-slate-300 hover:text-indigo-500 p-0.5">
                            {visiblePasswords.has(acc.id) ? (
                              <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242" /></svg>
                            ) : (
                              <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268-2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" /></svg>
                            )}
                          </button>
                          <button onClick={() => copyToClipboard(acc.password || '', `${acc.id}-pass`)} className="text-slate-300 hover:text-indigo-500 p-0.5">
                            {copiedId === `${acc.id}-pass` ? (
                               <svg className="w-3.5 h-3.5 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M5 13l4 4L19 7" /></svg>
                            ) : (
                               <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M8 5H6a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2v-1M8 5a2 2 0 002 2h2a2 2 0 002-2M8 5a2 2 0 012-2h2a2 2 0 012 2m0 0h2a2 2 0 012 2v3m2 4H10m0 0l3-3m-3 3l3 3" /></svg>
                            )}
                          </button>
                        </div>
                      </div>
                    </div>
                 </div>
              </div>

              {/* Footer / Notes Accordion */}
              <div className="bg-slate-50/50 border-t border-slate-50 p-2">
                 <button 
                   onClick={() => toggleNote(acc.id)}
                   className="w-full flex items-center justify-between px-2 py-1.5 text-[10px] font-bold text-slate-400 hover:text-indigo-600 transition-colors uppercase tracking-wider"
                 >
                   <span>Notes ({acc.notes.length})</span>
                   <svg className={`w-3.5 h-3.5 transform transition-transform ${expandedNotes.has(acc.id) ? 'rotate-180' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 9l-7 7-7-7" /></svg>
                 </button>

                 {expandedNotes.has(acc.id) && (
                    <div className="px-2 pb-2 space-y-2 animate-fadeIn">
                       {acc.notes.map((note, idx) => (
                         <div key={idx} className="relative group/note">
                            <input
                              className="w-full text-xs text-slate-600 bg-white border border-slate-200 rounded-md px-2 py-1.5 pr-8 shadow-sm focus:ring-1 focus:ring-indigo-500 focus:border-transparent outline-none transition-all"
                              value={note}
                              onChange={(e) => handleEditNote(idx, e.target.value, acc)}
                              placeholder="Service details..."
                            />
                            <button 
                              onClick={() => removeNote(idx, acc)}
                              className="absolute right-1.5 top-1.5 text-slate-200 hover:text-rose-500 opacity-0 group-hover/note:opacity-100 transition-opacity"
                            >
                              <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" /></svg>
                            </button>
                         </div>
                       ))}
                       <button 
                         onClick={() => addNote(acc)}
                         className="w-full py-1.5 border border-dashed border-slate-200 rounded-md text-[10px] font-bold text-slate-400 hover:border-indigo-300 hover:text-indigo-500 transition-all bg-white/50"
                       >
                         + New Note
                       </button>
                    </div>
                 )}
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
};

export default AccountList;
