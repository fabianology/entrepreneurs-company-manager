
import React, { useState, useRef, useEffect } from 'react';
import { FinancialCard, Loan, Institution, InstitutionAccount } from '../types';

interface FinancialListProps {
  cards: FinancialCard[];
  loans: Loan[];
  institutions: Institution[];
  onAddCard: (card: Partial<FinancialCard>) => void;
  onUpdateCard: (id: string, updates: Partial<FinancialCard>) => void;
  onDeleteCard: (id: string) => void;
  onAddLoan: (loan: Partial<Loan>) => void;
  onUpdateLoan: (id: string, updates: Partial<Loan>) => void;
  onDeleteLoan: (id: string) => void;
  onAddInstitution: (inst: Partial<Institution>) => void;
  onUpdateInstitution: (id: string, updates: Partial<Institution>) => void;
  onDeleteInstitution: (id: string) => void;
}

const FinancialList: React.FC<FinancialListProps> = ({ 
  cards, 
  loans,
  institutions,
  onAddCard, 
  onUpdateCard,
  onDeleteCard,
  onAddLoan,
  onUpdateLoan,
  onDeleteLoan,
  onAddInstitution,
  onUpdateInstitution,
  onDeleteInstitution
}) => {
  const [editingCard, setEditingCard] = useState<Partial<FinancialCard> | null>(null);
  const [editingLoan, setEditingLoan] = useState<Partial<Loan> | null>(null);
  const [editingInstitution, setEditingInstitution] = useState<Partial<Institution> | null>(null);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [isWalletExpanded, setIsWalletExpanded] = useState(false);
  const [showPasswords, setShowPasswords] = useState<Set<string>>(new Set());
  
  // Drag states
  const [dragY, setDragY] = useState(0);
  const [isDragging, setIsDragging] = useState(false);
  const dragStartY = useRef(0);
  const walletContainerRef = useRef<HTMLDivElement>(null);

  // --- DRAG HANDLERS ---
  const handlePointerDown = (e: React.PointerEvent) => {
    if (!isWalletExpanded) return;
    if ((e.target as HTMLElement).closest('button')) return;
    
    setIsDragging(true);
    dragStartY.current = e.clientY;
    (e.target as HTMLElement).setPointerCapture(e.pointerId);
  };

  const handlePointerMove = (e: React.PointerEvent) => {
    if (!isDragging) return;
    const deltaY = e.clientY - dragStartY.current;
    if (deltaY > 0) {
      setDragY(deltaY);
    } else {
      setDragY(0);
    }
  };

  const handlePointerUp = (e: React.PointerEvent) => {
    if (!isDragging) return;
    setIsDragging(false);
    
    if (dragY > 100) {
      setIsWalletExpanded(false);
    }
    
    setDragY(0);
    (e.target as HTMLElement).releasePointerCapture(e.pointerId);
  };

  // --- INSTITUTION HANDLERS ---
  const togglePassword = (id: string) => {
    const newSet = new Set(showPasswords);
    if (newSet.has(id)) newSet.delete(id);
    else newSet.add(id);
    setShowPasswords(newSet);
  };

  const handleAddNewInstitution = () => {
    setShowDeleteConfirm(false);
    setEditingInstitution({
      name: '',
      loginUrl: '',
      email: '',
      username: '',
      password: '',
      accounts: []
    });
  };

  const handleSaveInstitution = () => {
    if (editingInstitution) {
      if (editingInstitution.id) {
        onUpdateInstitution(editingInstitution.id, editingInstitution);
      } else {
        onAddInstitution(editingInstitution);
      }
      setEditingInstitution(null);
    }
  };

  const handleAddInstAccount = () => {
    if (!editingInstitution) return;
    const newAcc: InstitutionAccount = {
      id: Math.random().toString(36).substr(2, 9),
      name: '',
      type: 'Checking',
      last4: '',
      balance: 0
    };
    setEditingInstitution({
      ...editingInstitution,
      accounts: [...(editingInstitution.accounts || []), newAcc]
    });
  };

  const handleUpdateInstAccount = (index: number, updates: Partial<InstitutionAccount>) => {
    if (!editingInstitution || !editingInstitution.accounts) return;
    const newAccounts = [...editingInstitution.accounts];
    newAccounts[index] = { ...newAccounts[index], ...updates };
    setEditingInstitution({ ...editingInstitution, accounts: newAccounts });
  };

  const handleDeleteInstAccount = (index: number) => {
    if (!editingInstitution || !editingInstitution.accounts) return;
    const newAccounts = editingInstitution.accounts.filter((_, i) => i !== index);
    setEditingInstitution({ ...editingInstitution, accounts: newAccounts });
  };

  // --- CARD HANDLERS ---
  const handleAddNewCard = (e: React.MouseEvent) => {
    e.stopPropagation();
    setShowDeleteConfirm(false);
    setEditingCard({
      name: '',
      cardHolder: '',
      last4: '',
      expiry: '',
      network: 'Visa',
      type: 'Credit',
      status: 'Active',
      limit: 0
    });
  };

  const handleSaveCardModal = () => {
    if (editingCard) {
      if (editingCard.id) {
         onUpdateCard(editingCard.id, editingCard);
      } else {
         onAddCard(editingCard);
      }
      setEditingCard(null);
    }
  };

  const handleCardClick = (card: FinancialCard, e: React.MouseEvent) => {
    e.stopPropagation();
    if (Math.abs(dragY) > 5) return;

    if (!isWalletExpanded) {
      setIsWalletExpanded(true);
    } else {
      setShowDeleteConfirm(false);
      setEditingCard(card);
    }
  };

  // --- LOAN HANDLERS ---
  const handleAddNewLoan = () => {
    setShowDeleteConfirm(false);
    setEditingLoan({
      lender: '',
      name: '',
      principalAmount: 0,
      remainingBalance: 0,
      interestRate: 0,
      term: '',
      monthlyPayment: 0,
      startDate: '',
      status: 'Active'
    });
  };

  const handleSaveLoanModal = () => {
    if (editingLoan) {
      if (editingLoan.id) {
        onUpdateLoan(editingLoan.id, editingLoan);
      } else {
        onAddLoan(editingLoan);
      }
      setEditingLoan(null);
    }
  };

  const getCardGradient = (network: string | undefined) => {
    switch(network) {
      case 'Amex': return 'from-blue-600 to-cyan-500';
      case 'Mastercard': return 'from-slate-800 to-orange-900';
      case 'Visa': return 'from-indigo-700 to-purple-800';
      case 'Discover': return 'from-orange-500 to-amber-600';
      default: return 'from-slate-700 to-slate-900';
    }
  };

  return (
    <div className="space-y-12 animate-fadeIn">
      {/* --- PAYMENT METHODS --- */}
      <section className="space-y-6">
        <div className="flex justify-between items-center px-1">
          <div className="flex flex-col">
            <h3 className="text-lg font-bold text-slate-800">Payment Methods</h3>
            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">
              {isWalletExpanded ? 'Drag down to collapse' : 'Click stack to expand'}
            </p>
          </div>
          <div className="flex items-center gap-3">
            {isWalletExpanded && (
              <button 
                onClick={() => setIsWalletExpanded(false)}
                className="text-indigo-600 text-sm font-bold hover:underline"
              >
                Collapse
              </button>
            )}
            <button 
              onClick={handleAddNewCard}
              className="bg-indigo-600 text-white px-4 py-2 rounded-lg text-sm font-semibold hover:bg-indigo-700 transition shadow-sm active:scale-95"
            >
              + Add Card
            </button>
          </div>
        </div>
        <div 
          ref={walletContainerRef}
          className={`relative transition-all duration-700 ease-[cubic-bezier(0.16,1,0.3,1)] ${isWalletExpanded ? 'space-y-4' : 'h-[300px]'} ${isDragging ? 'cursor-grabbing touch-none' : ''}`}
          onClick={() => !isWalletExpanded && setIsWalletExpanded(true)}
          onPointerDown={handlePointerDown}
          onPointerMove={handlePointerMove}
          onPointerUp={handlePointerUp}
          onPointerCancel={handlePointerUp}
          style={{
            transform: isWalletExpanded ? `translateY(${dragY}px)` : 'none',
            transition: isDragging ? 'none' : 'all 0.6s cubic-bezier(0.16, 1, 0.3, 1)'
          }}
        >
          {cards.length === 0 ? (
            <button 
              onClick={handleAddNewCard}
              className="w-full h-56 rounded-2xl border-2 border-dashed border-slate-200 flex flex-col items-center justify-center text-slate-400 hover:border-indigo-300 hover:text-indigo-500 transition-colors bg-white/50"
            >
              <svg className="w-10 h-10 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 4v16m8-8H4" /></svg>
              <span className="font-bold text-sm">Add Your First Card</span>
            </button>
          ) : (
            <div className={`relative ${isWalletExpanded ? 'flex flex-col gap-4' : ''}`}>
              {cards.map((card, index) => {
                const stackOffset = index * 45; 
                const stackScale = 1 - (cards.length - 1 - index) * 0.02;
                const stackZ = index;
                return (
                  <div 
                    key={card.id}
                    onClick={(e) => handleCardClick(card, e)}
                    className={`
                      w-full h-56 rounded-2xl p-6 text-white shadow-2xl cursor-pointer bg-gradient-to-br 
                      ${getCardGradient(card.network)}
                      transition-all duration-500 ease-[cubic-bezier(0.16,1,0.3,1)]
                      ${!isWalletExpanded ? 'absolute left-0 right-0 hover:-translate-y-4' : 'relative hover:scale-[1.01]'}
                    `}
                    style={{
                      top: !isWalletExpanded ? `${stackOffset}px` : '0',
                      zIndex: stackZ,
                      transform: !isWalletExpanded ? `scale(${stackScale})` : 'scale(1)',
                      boxShadow: !isWalletExpanded ? '0 -10px 20px -5px rgba(0,0,0,0.3)' : '0 10px 30px -10px rgba(0,0,0,0.2)'
                    }}
                  >
                    <div className="flex justify-between items-start mb-8">
                      <div className="flex flex-col">
                        <span className="text-[10px] font-bold opacity-70 uppercase tracking-widest">{card.type}</span>
                        <span className="font-bold text-lg tracking-tight truncate max-w-[200px]">{card.name}</span>
                      </div>
                      <span className="font-black text-xl italic tracking-tighter opacity-90">{card.network}</span>
                    </div>
                    <div className="flex items-center space-x-3 mb-8">
                       <div className="w-11 h-8 bg-yellow-200/20 rounded-md border border-yellow-100/30 flex items-center justify-center">
                          <div className="w-6 h-4 border border-yellow-100/40 rounded-sm"></div>
                       </div>
                       <div className="text-xl font-mono tracking-[0.2em] opacity-90">
                          •••• •••• •••• {card.last4}
                       </div>
                    </div>
                    <div className="flex justify-between items-end">
                      <div>
                        <p className="text-[9px] uppercase font-bold tracking-widest opacity-60 mb-1">Card Holder</p>
                        <p className="font-bold tracking-wide uppercase text-xs truncate max-w-[150px]">{card.cardHolder}</p>
                      </div>
                      <div className="text-right">
                        <p className="text-[9px] uppercase font-bold tracking-widest opacity-60 mb-1">Expires</p>
                        <p className="font-mono font-bold text-sm">{card.expiry}</p>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </section>

      {/* --- BANKING INSTITUTIONS --- */}
      <section className="space-y-6">
        <div className="flex justify-between items-center px-1 border-t border-slate-200 pt-8">
          <div className="flex flex-col">
            <h3 className="text-lg font-bold text-slate-800">Banking Institutions</h3>
            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Login & Linked Accounts</p>
          </div>
          <button 
            onClick={handleAddNewInstitution}
            className="bg-indigo-600 text-white px-4 py-2 rounded-lg text-sm font-semibold hover:bg-indigo-700 transition"
          >
            + Add Institution
          </button>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {institutions.map(inst => {
            const totalBalance = inst.accounts.reduce((sum, acc) => sum + acc.balance, 0);
            return (
              <div 
                key={inst.id}
                className="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden flex flex-col hover:shadow-md transition-shadow"
              >
                <div className="p-5 border-b border-slate-50 bg-gradient-to-br from-slate-50/50 to-white">
                  <div className="flex justify-between items-start mb-4">
                    <div className="flex items-center space-x-3">
                      <div className="w-10 h-10 bg-indigo-600 rounded-lg flex items-center justify-center text-white">
                        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" /></svg>
                      </div>
                      <div>
                        <h4 className="font-bold text-slate-900">{inst.name}</h4>
                        {inst.loginUrl && (
                          <a href={inst.loginUrl} target="_blank" rel="noreferrer" className="text-[10px] text-indigo-500 hover:underline flex items-center gap-1">
                             Launch Portal
                             <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" /></svg>
                          </a>
                        )}
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="text-lg font-black text-slate-900">${totalBalance.toLocaleString()}</p>
                      <p className="text-[9px] font-bold text-slate-400 uppercase tracking-wider">Total Liquidity</p>
                    </div>
                  </div>

                  <div className="bg-slate-50 rounded-xl p-3 space-y-2 border border-slate-100">
                    <div className="flex justify-between items-center text-xs">
                      <span className="text-slate-400 font-medium uppercase tracking-wide">Username / Email</span>
                      <span className="text-slate-700 font-bold">{inst.username || inst.email || '-'}</span>
                    </div>
                    <div className="flex justify-between items-center text-xs">
                      <span className="text-slate-400 font-medium uppercase tracking-wide">Password</span>
                      <div className="flex items-center space-x-2">
                        <span className="text-slate-700 font-mono tracking-wider">{showPasswords.has(inst.id) ? (inst.password || '-') : '••••••••'}</span>
                        <button onClick={() => togglePassword(inst.id)} className="text-slate-300 hover:text-indigo-500">
                          {showPasswords.has(inst.id) ? (
                            <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242" /></svg>
                          ) : (
                            <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268-2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" /></svg>
                          )}
                        </button>
                      </div>
                    </div>
                  </div>
                </div>

                <div className="p-4 space-y-3">
                  <div className="flex justify-between items-center">
                    <span className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Linked Accounts</span>
                    <button onClick={() => setEditingInstitution(inst)} className="text-[10px] font-bold text-indigo-600 uppercase hover:text-indigo-800">Manage</button>
                  </div>
                  <div className="space-y-2">
                    {inst.accounts.map(acc => (
                      <div key={acc.id} className="flex justify-between items-center bg-slate-50/50 border border-slate-100 p-2.5 rounded-lg hover:bg-slate-50 transition">
                        <div className="flex items-center space-x-3">
                          <span className={`w-2 h-2 rounded-full ${acc.type === 'Checking' ? 'bg-emerald-400' : acc.type === 'Credit Card' ? 'bg-rose-400' : 'bg-blue-400'}`}></span>
                          <div>
                            <p className="text-xs font-bold text-slate-800">{acc.name}</p>
                            <div className="flex items-center gap-1.5">
                               <span className="text-[9px] text-slate-400 font-mono">••{acc.last4}</span>
                               <span className="text-[9px] text-slate-400 uppercase">• {acc.type}</span>
                            </div>
                          </div>
                        </div>
                        <div className="text-right">
                          <p className="text-xs font-black text-slate-700">${acc.balance.toLocaleString()}</p>
                        </div>
                      </div>
                    ))}
                    {inst.accounts.length === 0 && <p className="text-xs text-slate-400 italic text-center py-2">No linked accounts.</p>}
                  </div>
                </div>
              </div>
            )
          })}
        </div>
      </section>

      {/* --- LOANS SECTION --- */}
      <section className="space-y-6">
        <div className="flex justify-between items-center border-t border-slate-200 pt-8">
          <div className="flex flex-col">
            <h3 className="text-lg font-bold text-slate-800">Loans & Debt</h3>
            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Amortization</p>
          </div>
          <button 
            onClick={() => onAddLoan({ lender: 'New Lender', principalAmount: 0, remainingBalance: 0 })}
            className="bg-emerald-600 text-white px-4 py-2 rounded-lg text-sm font-semibold hover:bg-emerald-700 transition"
          >
            + Add Loan
          </button>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {loans.map(loan => (
            <div key={loan.id} onClick={() => setEditingLoan(loan)} className="bg-white rounded-2xl p-6 shadow-sm border border-slate-100 flex flex-col cursor-pointer hover:shadow-lg transition">
              <div className="flex justify-between mb-4">
                <h4 className="font-bold text-slate-800">{loan.name}</h4>
                <span className="text-[10px] font-bold text-emerald-600 uppercase tracking-tighter bg-emerald-50 px-2 py-0.5 rounded-full">{loan.status}</span>
              </div>
              <p className="text-xs text-slate-400 font-medium mb-1 uppercase tracking-widest">{loan.lender}</p>
              <p className="text-xl font-black text-slate-900 mb-6">${loan.remainingBalance.toLocaleString()}</p>
              <div className="mt-auto flex justify-between pt-4 border-t border-slate-50 text-[10px] font-bold uppercase tracking-widest text-slate-400">
                <span>{loan.interestRate}% Rate</span>
                <span>${loan.monthlyPayment}/mo</span>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* --- EDIT INSTITUTION MODAL --- */}
      {editingInstitution && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-fadeIn overflow-y-auto">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-2xl overflow-hidden my-auto">
            <div className="p-6 border-b border-slate-100 flex justify-between items-center">
              <h3 className="text-xl font-bold text-slate-900">{editingInstitution.id ? 'Edit Bank' : 'Add Bank'}</h3>
              <button onClick={() => setEditingInstitution(null)} className="text-slate-400 hover:text-slate-600">
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" /></svg>
              </button>
            </div>
            <div className="p-6 space-y-6 max-h-[70vh] overflow-y-auto">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div className="md:col-span-2">
                  <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Bank / Institution Name</label>
                  <input className="w-full px-3 py-2 border rounded-lg outline-none focus:ring-2 focus:ring-indigo-500" value={editingInstitution.name || ''} placeholder="e.g. Mercury" onChange={e => setEditingInstitution({...editingInstitution, name: e.target.value})} />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Login Email/User</label>
                  <input className="w-full px-3 py-2 border rounded-lg outline-none focus:ring-2 focus:ring-indigo-500" value={editingInstitution.username || ''} placeholder="user@example.com" onChange={e => setEditingInstitution({...editingInstitution, username: e.target.value})} />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Password</label>
                  <input className="w-full px-3 py-2 border rounded-lg outline-none focus:ring-2 focus:ring-indigo-500" type="text" value={editingInstitution.password || ''} placeholder="••••••" onChange={e => setEditingInstitution({...editingInstitution, password: e.target.value})} />
                </div>
                <div className="md:col-span-2">
                  <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Login Portal URL</label>
                  <input className="w-full px-3 py-2 border rounded-lg outline-none focus:ring-2 focus:ring-indigo-500" value={editingInstitution.loginUrl || ''} placeholder="https://bank.com/login" onChange={e => setEditingInstitution({...editingInstitution, loginUrl: e.target.value})} />
                </div>
              </div>

              <div className="border-t pt-4">
                <div className="flex justify-between items-center mb-4">
                  <h4 className="text-xs font-bold text-slate-500 uppercase tracking-widest">Linked Accounts</h4>
                  <button onClick={handleAddInstAccount} className="text-xs font-bold text-indigo-600 bg-indigo-50 px-2 py-1 rounded hover:bg-indigo-100">+ Add Account</button>
                </div>
                <div className="space-y-3">
                  {(editingInstitution.accounts || []).map((acc, idx) => (
                    <div key={idx} className="bg-slate-50 p-3 rounded-lg flex flex-col md:flex-row gap-3 items-end md:items-center border border-slate-100">
                      <div className="flex-1 grid grid-cols-2 md:grid-cols-4 gap-2 w-full">
                        <div className="md:col-span-1">
                             <input className="w-full px-2 py-1.5 text-xs border rounded outline-none focus:border-indigo-500" placeholder="Name" value={acc.name} onChange={e => handleUpdateInstAccount(idx, {name: e.target.value})} />
                        </div>
                        <div className="md:col-span-1">
                             <select className="w-full px-2 py-1.5 text-xs border rounded outline-none focus:border-indigo-500 bg-white" value={acc.type} onChange={e => handleUpdateInstAccount(idx, {type: e.target.value as any})}>
                                <option value="Checking">Checking</option>
                                <option value="Savings">Savings</option>
                                <option value="Investing">Investing</option>
                                <option value="Credit Card">Credit Card</option>
                                <option value="Debit Card">Debit Card</option>
                                <option value="CD">CD</option>
                                <option value="Other">Other</option>
                              </select>
                        </div>
                        <div className="md:col-span-1">
                             <input className="w-full px-2 py-1.5 text-xs border rounded outline-none focus:border-indigo-500" placeholder="Last 4" value={acc.last4} maxLength={4} onChange={e => handleUpdateInstAccount(idx, {last4: e.target.value})} />
                        </div>
                        <div className="md:col-span-1 relative">
                             <span className="absolute left-2 top-1.5 text-slate-400 text-xs">$</span>
                             <input className="w-full pl-5 px-2 py-1.5 text-xs border rounded outline-none focus:border-indigo-500" type="number" placeholder="Balance" value={acc.balance} onChange={e => handleUpdateInstAccount(idx, {balance: parseFloat(e.target.value)})} />
                        </div>
                      </div>
                      <button onClick={() => handleDeleteInstAccount(idx)} className="text-slate-400 hover:text-rose-600 p-1">
                        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                      </button>
                    </div>
                  ))}
                  {(!editingInstitution.accounts || editingInstitution.accounts.length === 0) && (
                     <div className="text-center py-4 bg-slate-50 border border-dashed border-slate-200 rounded-lg text-slate-400 text-xs">
                        No accounts linked yet. Add Checking, Savings, etc.
                     </div>
                  )}
                </div>
              </div>
            </div>
            <div className="p-6 bg-slate-50 border-t flex justify-between items-center">
              {editingInstitution.id && (
                <button onClick={() => { onDeleteInstitution(editingInstitution.id!); setEditingInstitution(null); }} className="text-rose-500 text-sm font-bold hover:text-rose-700">Delete Bank</button>
              )}
              <div className="flex space-x-3 ml-auto">
                <button onClick={() => setEditingInstitution(null)} className="px-4 py-2 text-slate-500 font-bold hover:text-slate-700">Cancel</button>
                <button onClick={handleSaveInstitution} className="px-6 py-2 bg-indigo-600 text-white rounded-lg font-bold shadow-sm hover:bg-indigo-700">Save Bank</button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* --- EDIT CARD MODAL --- */}
      {editingCard && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-fadeIn overflow-y-auto">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg overflow-hidden my-auto">
            <div className="p-6 border-b border-slate-100 flex justify-between items-center bg-white">
              <h3 className="text-xl font-bold text-slate-900">
                {editingCard.id ? 'Edit Card Details' : 'Add New Card'}
              </h3>
              <button onClick={() => setEditingCard(null)} className="text-slate-400 hover:text-slate-600">
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" /></svg>
              </button>
            </div>
            
            <div className="p-6 space-y-4 overflow-y-auto max-h-[70vh]">
               <div>
                  <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Card Nickname</label>
                  <input 
                    className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                    placeholder="e.g. Amex Gold - Advertising"
                    value={editingCard.name || ''}
                    onChange={e => setEditingCard({...editingCard, name: e.target.value})}
                  />
               </div>
               
               <div className="grid grid-cols-2 gap-4">
                 <div>
                    <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Card Network</label>
                    <select
                      className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                      value={editingCard.network || 'Visa'}
                      onChange={e => setEditingCard({...editingCard, network: e.target.value as any})}
                    >
                      <option value="Visa">Visa</option>
                      <option value="Mastercard">Mastercard</option>
                      <option value="Amex">Amex</option>
                      <option value="Discover">Discover</option>
                      <option value="Other">Other</option>
                    </select>
                 </div>
                 <div>
                    <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Type</label>
                    <select
                      className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                      value={editingCard.type || 'Credit'}
                      onChange={e => setEditingCard({...editingCard, type: e.target.value as any})}
                    >
                      <option value="Credit">Credit</option>
                      <option value="Debit">Debit</option>
                    </select>
                 </div>
               </div>

               <div>
                  <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Card Holder Name</label>
                  <input 
                    className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                    placeholder="NAME ON CARD"
                    value={editingCard.cardHolder || ''}
                    onChange={e => setEditingCard({...editingCard, cardHolder: e.target.value})}
                  />
               </div>

               <div className="grid grid-cols-3 gap-4">
                  <div className="col-span-2">
                     <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Card Number (Last 4)</label>
                     <div className="relative">
                        <span className="absolute left-3 top-2 text-slate-400 font-mono text-sm">•••• •••• ••••</span>
                        <input 
                          maxLength={4}
                          className="w-full pl-36 px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white font-mono"
                          placeholder="1234"
                          value={editingCard.last4 || ''}
                          onChange={e => setEditingCard({...editingCard, last4: e.target.value.replace(/\D/g,'')})}
                        />
                     </div>
                  </div>
                  <div>
                     <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Expiry</label>
                     <input 
                       className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white text-center font-mono"
                       placeholder="MM/YY"
                       maxLength={5}
                       value={editingCard.expiry || ''}
                       onChange={e => setEditingCard({...editingCard, expiry: e.target.value})}
                     />
                  </div>
               </div>

               <div className="grid grid-cols-2 gap-4">
                  <div>
                     <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Credit Limit / Balance</label>
                     <div className="relative">
                        <span className="absolute left-3 top-2 text-slate-400">$</span>
                        <input 
                          type="number"
                          className="w-full pl-6 px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                          value={editingCard.limit || ''}
                          onChange={e => setEditingCard({...editingCard, limit: parseFloat(e.target.value)})}
                        />
                     </div>
                  </div>
                  <div>
                     <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Status</label>
                     <select
                        className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                        value={editingCard.status || 'Active'}
                        onChange={e => setEditingCard({...editingCard, status: e.target.value as any})}
                     >
                        <option value="Active">Active</option>
                        <option value="Frozen">Frozen</option>
                        <option value="Expired">Expired</option>
                     </select>
                  </div>
               </div>
            </div>

            <div className="p-6 border-t border-slate-100 bg-slate-50 flex items-center justify-between">
               <div>
                  {editingCard.id && (
                     showDeleteConfirm ? (
                        <div className="flex items-center space-x-2">
                           <button 
                              onClick={() => { onDeleteCard(editingCard.id!); setEditingCard(null); }}
                              className="bg-rose-600 text-white px-3 py-1.5 rounded text-xs font-bold"
                           >
                              Confirm
                           </button>
                           <button 
                              onClick={() => setShowDeleteConfirm(false)}
                              className="text-slate-500 text-xs font-bold underline"
                           >
                              Cancel
                           </button>
                        </div>
                     ) : (
                        <button 
                           onClick={() => setShowDeleteConfirm(true)}
                           className="text-rose-500 text-sm font-bold hover:text-rose-700"
                        >
                           Remove Card
                        </button>
                     )
                  )}
               </div>
               <div className="flex space-x-3">
                  <button 
                     onClick={() => setEditingCard(null)}
                     className="px-4 py-2 text-slate-600 font-bold hover:text-slate-800"
                  >
                     Cancel
                  </button>
                  <button 
                     onClick={handleSaveCardModal}
                     className="px-6 py-2 bg-indigo-600 text-white rounded-lg font-bold shadow-sm hover:bg-indigo-700 transition"
                  >
                     Save Card
                  </button>
               </div>
            </div>
          </div>
        </div>
      )}

      {/* --- EDIT LOAN MODAL --- */}
      {editingLoan && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-fadeIn overflow-y-auto">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg overflow-hidden my-auto">
            <div className="p-6 border-b border-slate-100 flex justify-between items-center bg-white">
              <h3 className="text-xl font-bold text-slate-900">
                {editingLoan.id ? 'Edit Loan Details' : 'Add New Financing'}
              </h3>
              <button onClick={() => setEditingLoan(null)} className="text-slate-400 hover:text-slate-600">
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" /></svg>
              </button>
            </div>
            
            <div className="p-6 space-y-4 overflow-y-auto max-h-[70vh]">
               <div>
                  <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Lender / Institution</label>
                  <input 
                    className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                    placeholder="e.g. Silicon Valley Bank"
                    value={editingLoan.lender || ''}
                    onChange={e => setEditingLoan({...editingLoan, lender: e.target.value})}
                  />
               </div>
               <div>
                  <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Loan Nickname</label>
                  <input 
                    className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                    placeholder="e.g. Series A Venture Debt"
                    value={editingLoan.name || ''}
                    onChange={e => setEditingLoan({...editingLoan, name: e.target.value})}
                  />
               </div>
               
               <div className="grid grid-cols-2 gap-4">
                 <div>
                    <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Original Principal</label>
                    <div className="relative">
                        <span className="absolute left-3 top-2 text-slate-400">$</span>
                        <input 
                          type="number"
                          className="w-full pl-6 px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                          value={editingLoan.principalAmount || ''}
                          onChange={e => setEditingLoan({...editingLoan, principalAmount: parseFloat(e.target.value)})}
                        />
                    </div>
                 </div>
                 <div>
                    <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Current Balance</label>
                    <div className="relative">
                        <span className="absolute left-3 top-2 text-slate-400">$</span>
                        <input 
                          type="number"
                          className="w-full pl-6 px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                          value={editingLoan.remainingBalance || ''}
                          onChange={e => setEditingLoan({...editingLoan, remainingBalance: parseFloat(e.target.value)})}
                        />
                    </div>
                 </div>
               </div>

               <div className="grid grid-cols-2 gap-4">
                  <div>
                     <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Monthly Payment</label>
                     <div className="relative">
                        <span className="absolute left-3 top-2 text-slate-400">$</span>
                        <input 
                          type="number"
                          className="w-full pl-6 px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                          value={editingLoan.monthlyPayment || ''}
                          onChange={e => setEditingLoan({...editingLoan, monthlyPayment: parseFloat(e.target.value)})}
                        />
                     </div>
                  </div>
                  <div>
                     <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Interest Rate (%)</label>
                     <input 
                       type="number"
                       step="0.1"
                       className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                       placeholder="5.5"
                       value={editingLoan.interestRate || ''}
                       onChange={e => setEditingLoan({...editingLoan, interestRate: parseFloat(e.target.value)})}
                     />
                  </div>
               </div>

               <div className="grid grid-cols-2 gap-4">
                   <div>
                       <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Term Length</label>
                       <input 
                         className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                         placeholder="e.g. 36 Months"
                         value={editingLoan.term || ''}
                         onChange={e => setEditingLoan({...editingLoan, term: e.target.value})}
                       />
                   </div>
                   <div>
                       <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Status</label>
                       <select
                          className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                          value={editingLoan.status || 'Active'}
                          onChange={e => setEditingLoan({...editingLoan, status: e.target.value as any})}
                       >
                          <option value="Active">Active</option>
                          <option value="Paid Off">Paid Off</option>
                          <option value="Default">Default</option>
                       </select>
                   </div>
               </div>
            </div>

            <div className="p-6 border-t border-slate-100 bg-slate-50 flex items-center justify-between">
               <div>
                  {editingLoan.id && (
                     showDeleteConfirm ? (
                        <div className="flex items-center space-x-2">
                           <button 
                              onClick={() => { onDeleteLoan(editingLoan.id!); setEditingLoan(null); }}
                              className="bg-rose-600 text-white px-3 py-1.5 rounded text-xs font-bold"
                           >
                              Confirm
                           </button>
                           <button 
                              onClick={() => setShowDeleteConfirm(false)}
                              className="text-slate-500 text-xs font-bold underline"
                           >
                              Cancel
                           </button>
                        </div>
                     ) : (
                        <button 
                           onClick={() => setShowDeleteConfirm(true)}
                           className="text-rose-500 text-sm font-bold hover:text-rose-700"
                        >
                           Remove Loan
                        </button>
                     )
                  )}
               </div>
               <div className="flex space-x-3">
                  <button 
                     onClick={() => setEditingLoan(null)}
                     className="px-4 py-2 text-slate-600 font-bold hover:text-slate-800"
                  >
                     Cancel
                  </button>
                  <button 
                     onClick={handleSaveLoanModal}
                     className="px-6 py-2 bg-emerald-600 text-white rounded-lg font-bold shadow-sm hover:bg-emerald-700 transition"
                  >
                     Save Loan
                  </button>
               </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default FinancialList;
