
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

      {/* Account Cards List */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {accounts.map(acc => (
          <div key={acc.id} className={`bg-[#1C1C1E] rounded-[24px] overflow-hidden border ${acc.status === 'Active' ? 'border-[#0091FF]' : 'border-white/5'} shadow-2xl flex flex-col`}>
            {/* Header / Main Info - Clickable */}
            <div className="p-6 space-y-6">
              <div
                className="flex justify-between items-start cursor-pointer hover:opacity-80 transition-opacity"
                onClick={() => setEditingAccount(acc)}
              >
                <div className="flex items-center space-x-4">
                  <div className="w-14 h-14 bg-white/5 rounded-2xl flex items-center justify-center border border-white/10 overflow-hidden">
                    {acc.platform.toLowerCase() === 'shopify' ? (
                      <img src="https://cdn.worldvectorlogo.com/logos/shopify.svg" className="w-8 h-8" alt="Shopify" />
                    ) : (
                      <span className="text-white font-black text-xl opacity-80">{acc.platform.charAt(0)}</span>
                    )}
                  </div>
                  <div>
                    <h3 className="text-lg font-black tracking-tight text-white uppercase">{acc.platform}</h3>
                    {acc.website && (
                      <p className="text-[11px] text-white/40 font-bold tracking-wide">{acc.website.replace(/^https?:\/\/(www\.)?/, '')}</p>
                    )}
                  </div>
                </div>
                <div className="flex items-center space-x-1.5 pt-1 uppercase font-black tracking-widest text-[10px]">
                  <span className="text-[#1FE400]">Active</span>
                  <span className="text-white/20">|</span>
                  <span className="text-[#1FE400]">{acc.pricingModel}</span>
                </div>
              </div>

              {/* Login Data Grid */}
              <div className="grid grid-cols-2 gap-y-6 gap-x-8">
                <div className="space-y-1 group/field">
                  <div className="flex justify-between items-center">
                    <p className="text-[9px] font-black text-white/40 uppercase tracking-widest">Email / Identity</p>
                  </div>
                  <p className="text-xs font-black text-white truncate">{acc.email}</p>
                </div>

                <div className="space-y-1 group/pass">
                  <div className="flex justify-between items-center">
                    <p className="text-[9px] font-black text-white/40 uppercase tracking-widest">Password</p>
                    <div className="flex space-x-2 opacity-0 group-hover/pass:opacity-100 transition-opacity">
                      <button onClick={(e) => { e.stopPropagation(); togglePasswordVisibility(acc.id); }} className="text-[9px] font-black text-[#EBC351] uppercase">
                        {visiblePasswords.has(acc.id) ? 'Hide' : 'Show'}
                      </button>
                    </div>
                  </div>
                  <p className="text-xs font-black text-white font-mono tracking-wider truncate">
                    {visiblePasswords.has(acc.id) ? acc.password : '••••••••••••••••'}
                  </p>
                </div>

                <div className="space-y-1">
                  <p className="text-[9px] font-black text-white/40 uppercase tracking-widest">2FA / Recovery</p>
                  <p className="text-xs font-black text-white">{acc.twoFactorAuth || 'none'}</p>
                </div>

                <div className="space-y-1">
                  <p className="text-[9px] font-black text-white/40 uppercase tracking-widest">Last Updated</p>
                  <p className="text-xs font-black text-white">{acc.lastUpdated ? new Date(acc.lastUpdated).toLocaleDateString() : '1/23/2022'}</p>
                </div>
              </div>
            </div>

            {/* Notes Accordion */}
            <div className={`mt-auto border-t border-white/5 ${expandedNotes.has(acc.id) ? 'bg-black/20' : ''}`}>
              <button
                onClick={(e) => { e.stopPropagation(); toggleNote(acc.id); }}
                className="w-full h-12 px-6 flex items-center justify-between text-[#EBC351] group"
              >
                <span className="text-[11px] font-black uppercase tracking-[0.15em]">NOTES ({acc.notes.length})</span>
                <svg className={`w-4 h-4 transform transition-transform duration-300 ${expandedNotes.has(acc.id) ? 'rotate-180' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M19 9l-7 7-7-7" /></svg>
              </button>

              {expandedNotes.has(acc.id) && (
                <div className="px-6 pb-4 space-y-2 animate-fadeIn">
                  <ul className="space-y-2">
                    {acc.notes.map((note, idx) => (
                      <li key={idx} className="flex items-start space-x-2 text-xs font-bold text-white/90">
                        <span className="mt-1.5 h-1 w-1 rounded-full bg-white/40 shrink-0"></span>
                        <div className="flex-1 group/note flex items-center justify-between">
                          <input
                            className="bg-transparent border-none outline-none w-full py-0.5 focus:text-white transition-colors"
                            value={note}
                            onChange={(e) => handleEditNote(idx, e.target.value, acc)}
                          />
                          <button
                            onClick={() => removeNote(idx, acc)}
                            className="text-white/20 hover:text-orange-500 opacity-0 group-hover/note:opacity-100 transition-opacity ml-2"
                          >
                            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M6 18L18 6M6 6l12 12" /></svg>
                          </button>
                        </div>
                      </li>
                    ))}
                  </ul>
                  <div className="flex justify-end pt-2">
                    <button
                      onClick={(e) => { e.stopPropagation(); addNote(acc); }}
                      className="text-[10px] font-black text-[#EBC351] uppercase tracking-widest hover:opacity-80 transition"
                    >
                      + new note
                    </button>
                  </div>
                </div>
              )}
            </div>
          </div>
        ))}

        {accounts.length === 0 && (
          <div className="md:col-span-2 py-16 text-center bg-[#1C1C1E] rounded-[32px] border border-white/5">
            <div className="w-16 h-16 bg-white/5 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg className="w-8 h-8 text-white/20" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" /></svg>
            </div>
            <p className="text-white/40 font-bold">No login accounts tracked.</p>
          </div>
        )}
      </div>

      {/* Editing Modal */}
      {editingAccount && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/90 backdrop-blur-xl animate-fadeIn overflow-y-auto">
          <div className="bg-[#1C1C1E] rounded-[32px] shadow-2xl w-full max-w-xl border border-white/10 overflow-hidden">
            <div className="p-8 border-b border-white/5 flex justify-between items-center">
              <h3 className="text-xl font-black tracking-tight text-white uppercase">
                {editingAccount.id ? 'Edit Account' : 'New Account'}
              </h3>
              <button onClick={() => setEditingAccount(null)} className="text-white/40 hover:text-white transition">
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M6 18L18 6M6 6l12 12" /></svg>
              </button>
            </div>

            <div className="p-8 space-y-6 max-h-[60vh] overflow-y-auto custom-scrollbar">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="space-y-2">
                  <label className="text-[10px] font-black text-white/40 uppercase tracking-widest ml-1">Platform</label>
                  <input
                    className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-3.5 text-white outline-none focus:border-orange-500/50 transition font-bold"
                    value={editingAccount.platform || ''}
                    placeholder="e.g. AWS"
                    onChange={e => setEditingAccount({ ...editingAccount, platform: e.target.value })}
                  />
                </div>
                <div className="space-y-2">
                  <label className="text-[10px] font-black text-white/40 uppercase tracking-widest ml-1">Website</label>
                  <input
                    className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-3.5 text-white outline-none focus:border-orange-500/50 transition font-bold"
                    value={editingAccount.website || ''}
                    placeholder="app.aws.com"
                    onChange={e => setEditingAccount({ ...editingAccount, website: e.target.value })}
                  />
                </div>
                <div className="space-y-2">
                  <label className="text-[10px] font-black text-white/40 uppercase tracking-widest ml-1">Login Email</label>
                  <input
                    className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-3.5 text-white outline-none focus:border-orange-500/50 transition font-bold"
                    value={editingAccount.email || ''}
                    placeholder="admin@cifr.io"
                    onChange={e => setEditingAccount({ ...editingAccount, email: e.target.value })}
                  />
                </div>
                <div className="space-y-2">
                  <label className="text-[10px] font-black text-white/40 uppercase tracking-widest ml-1">Password</label>
                  <div className="relative">
                    <input
                      type={showModalPassword ? "text" : "password"}
                      className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-3.5 text-white outline-none focus:border-orange-500/50 transition font-bold pr-10"
                      value={editingAccount.password || ''}
                      onChange={e => setEditingAccount({ ...editingAccount, password: e.target.value })}
                    />
                    <button onClick={() => setShowModalPassword(!showModalPassword)} className="absolute right-4 top-1/2 -translate-y-1/2 text-white/20">
                      {showModalPassword ? (
                        <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268-2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" /></svg>
                      ) : (
                        <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268-2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" /></svg>
                      )}
                    </button>
                  </div>
                </div>
                <div className="space-y-2">
                  <label className="text-[10px] font-black text-white/40 uppercase tracking-widest ml-1">Pricing</label>
                  <select
                    className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-3.5 text-white outline-none focus:border-orange-500/50 transition font-bold"
                    value={editingAccount.pricingModel || 'free'}
                    onChange={e => setEditingAccount({ ...editingAccount, pricingModel: e.target.value as any })}
                  >
                    <option value="free">free</option>
                    <option value="paid">paid</option>
                  </select>
                </div>
                <div className="space-y-2">
                  <label className="text-[10px] font-black text-white/40 uppercase tracking-widest ml-1">Status</label>
                  <select
                    className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-3.5 text-white outline-none focus:border-orange-500/50 transition font-bold"
                    value={editingAccount.status || 'Active'}
                    onChange={e => setEditingAccount({ ...editingAccount, status: e.target.value as any })}
                  >
                    <option value="Active">Active</option>
                    <option value="Inactive">Inactive</option>
                    <option value="Trial">Trial</option>
                  </select>
                </div>
              </div>

              <div className="space-y-4 pt-4">
                <p className="text-[10px] font-black text-white/40 uppercase tracking-widest ml-1">Security & Recovery</p>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div className="space-y-2">
                    <label className="text-[10px] font-black text-white/20 uppercase tracking-widest ml-1">2FA Method</label>
                    <select
                      className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-3.5 text-white outline-none focus:border-orange-500/50 transition font-bold"
                      value={editingAccount.twoFactorAuth || 'None'}
                      onChange={e => setEditingAccount({ ...editingAccount, twoFactorAuth: e.target.value })}
                    >
                      <option value="Authenticator">Authenticator</option>
                      <option value="SMS">SMS</option>
                      <option value="None">None</option>
                    </select>
                  </div>
                  <div className="space-y-2">
                    <label className="text-[10px] font-black text-white/20 uppercase tracking-widest ml-1">Last Updated</label>
                    <input
                      type="date"
                      className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-3.5 text-white outline-none focus:border-orange-500/50 transition font-bold"
                      value={editingAccount.lastUpdated ? new Date(editingAccount.lastUpdated).toISOString().split('T')[0] : ''}
                      onChange={e => setEditingAccount({ ...editingAccount, lastUpdated: new Date(e.target.value).getTime() })}
                    />
                  </div>
                  <div className="space-y-2">
                    <label className="text-[10px] font-black text-white/20 uppercase tracking-widest ml-1">Recovery</label>
                    <input
                      className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-3.5 text-white outline-none focus:border-orange-500/50 transition font-bold"
                      value={editingAccount.recoveryMethod || ''}
                      placeholder="email, phone number"
                      onChange={e => setEditingAccount({ ...editingAccount, recoveryMethod: e.target.value })}
                    />
                  </div>
                </div>
              </div>
            </div>

            <div className="p-8 bg-black/20 border-t border-white/5 flex justify-between items-center">
              <div className="flex-1">
                {editingAccount.id && (
                  showDeleteConfirm ? (
                    <div className="flex items-center space-x-3">
                      <span className="text-[10px] font-black text-orange-500 uppercase">Confirm?</span>
                      <button onClick={() => { onDeleteAccount(editingAccount.id!); setEditingAccount(null); }} className="text-[10px] font-black text-white hover:text-orange-500">YES</button>
                      <button onClick={() => setShowDeleteConfirm(false)} className="text-[10px] font-black text-white/20 hover:text-white">NO</button>
                    </div>
                  ) : (
                    <button onClick={() => setShowDeleteConfirm(true)} className="text-[10px] font-black text-white/20 hover:text-orange-500 uppercase tracking-widest">Delete</button>
                  )
                )}
              </div>
              <div className="flex space-x-4">
                <button onClick={() => setEditingAccount(null)} className="px-6 py-3 text-[11px] font-black text-white/40 uppercase tracking-widest hover:text-white transition">Cancel</button>
                <button onClick={handleSaveModal} className="px-8 py-3 bg-orange-500 rounded-2xl text-[11px] font-black text-white uppercase tracking-widest shadow-lg shadow-orange-500/20 hover:scale-[1.02] active:scale-95 transition">Save Account</button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default AccountList;
