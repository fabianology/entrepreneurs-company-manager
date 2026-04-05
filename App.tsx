import React, { useState, useEffect, useCallback, useRef, useMemo } from 'react';
import Sidebar from './components/Sidebar';
import Dashboard from './components/Dashboard';

import SubscriptionList from './components/SubscriptionList';
import FinancialList from './components/FinancialList';
import DocumentList from './components/DocumentList';
import { AppState, Company, Account, Subscription, FinancialCard, Loan, Institution, CompanyDocument } from './types';
import { getEntrepreneurialQuote } from './services/geminiService';
import { db } from './services/dbService';
import { getFaviconUrl } from './services/logoService';

const BRAND_COLORS = [
  '#4f46e5', // Indigo
  '#10b981', // Emerald
  '#f59e0b', // Amber
  '#ef4444', // Red
  '#3b82f6', // Blue
  '#8b5cf6', // Violet
  '#ec4899', // Pink
  '#64748b', // Slate
  '#000000', // Black
];

const App: React.FC = () => {
  const [state, setState] = useState<AppState | null>(null);
  const [activeView, setActiveView] = useState<'dashboard' | 'company'>(() => (localStorage.getItem('fs_view') as any) || 'dashboard');
  const [selectedCompanyId, setSelectedCompanyId] = useState<string | null>(() => localStorage.getItem('fs_selected_company'));

  // Initialize tab state, migrating old 'stack' value to 'accounts'
  const [activeTab, setActiveTab] = useState<'subscriptions' | 'financial' | 'docs'>(() => {
    const stored = localStorage.getItem('fs_tab');
    if (stored === 'stack' || stored === 'accounts') return 'subscriptions';
    return (stored as any) || 'subscriptions';
  });

  const [isEditingCompanyName, setIsEditingCompanyName] = useState(false);
  const [isEditingDescription, setIsEditingDescription] = useState(false);
  const [showDeleteCompanyConfirm, setShowDeleteCompanyConfirm] = useState(false);
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const [quote, setQuote] = useState<string>('');

  // Search & Menu States
  const [searchQuery, setSearchQuery] = useState('');
  const [showSearchDropdown, setShowSearchDropdown] = useState(false);
  const [showQuickMenu, setShowQuickMenu] = useState(false);
  const [isInputFocused, setIsInputFocused] = useState(false);

  // Search Results Password State
  const [visibleSearchPasswords, setVisibleSearchPasswords] = useState<Set<string>>(new Set());
  const [copiedSearchId, setCopiedSearchId] = useState<string | null>(null);

  const [lastSaved, setLastSaved] = useState<number>(Date.now());
  const [isSaving, setIsSaving] = useState(false);
  const [saveError, setSaveError] = useState(false);

  const searchInputRef = useRef<HTMLInputElement>(null);
  const searchContainerRef = useRef<HTMLDivElement>(null);
  const searchResultsRef = useRef<HTMLDivElement>(null);
  const quickMenuRef = useRef<HTMLDivElement>(null);

  // Keyboard shortcut for search
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault();
        searchInputRef.current?.focus();
      }
      if (e.key === '/') {
        if (document.activeElement?.tagName !== 'INPUT' && document.activeElement?.tagName !== 'TEXTAREA') {
          e.preventDefault();
          searchInputRef.current?.focus();
        }
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  // Fetch entrepreneurial quote
  useEffect(() => {
    const fetchQuote = async () => {
      const q = await getEntrepreneurialQuote();
      setQuote(q);
    };
    fetchQuote();
  }, []);

  // Close search dropdown on outside click
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as Node;
      if (
        searchContainerRef.current && !searchContainerRef.current.contains(target) &&
        searchResultsRef.current && !searchResultsRef.current.contains(target)
      ) {
        setShowSearchDropdown(false);
      }
      if (
        quickMenuRef.current && !quickMenuRef.current.contains(target)
      ) {
        setShowQuickMenu(false);
      }
    };
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  // --- PERSISTENCE ---

  useEffect(() => {
    const initData = async () => {
      const data = await db.load();
      setState(data);
    };
    initData();
  }, []);

  useEffect(() => {
    if (state) {
      setIsSaving(true);
      setSaveError(false);
      db.save(state).then((success) => {
        if (success) {
          setLastSaved(Date.now());
          setTimeout(() => setIsSaving(false), 500);
        } else {
          setSaveError(true);
          setIsSaving(false);
        }
      });
    }
  }, [state]);

  // Persist UI State
  useEffect(() => {
    localStorage.setItem('fs_view', activeView);
    if (selectedCompanyId) localStorage.setItem('fs_selected_company', selectedCompanyId);
    else localStorage.removeItem('fs_selected_company');
    localStorage.setItem('fs_tab', activeTab);
  }, [activeView, selectedCompanyId, activeTab]);

  // --- CALCULATIONS ---
  const totalMonthlyBurn = useMemo(() => {
    if (!state) return 0;
    return state.subscriptions.reduce((sum, sub) => {
      const subServiceCost = (sub.subServices || []).reduce((acc, s) => acc + s.cost, 0);
      const monthlyFactor = sub.billingCycle === 'Monthly' ? 1 : 1 / 12;
      return sum + (sub.cost + subServiceCost) * monthlyFactor;
    }, 0);
  }, [state]);

  // --- FILTERING LOGIC ---
  const filteredCompanies = useMemo(() => {
    if (!state) return [];
    if (!searchQuery) return state.companies;
    const q = searchQuery.toLowerCase();
    return state.companies.filter(c =>
      c.name.toLowerCase().includes(q) ||
      c.structure.toLowerCase().includes(q) ||
      c.description.toLowerCase().includes(q)
    );
  }, [state, searchQuery]);

  const selectedCompany = state?.companies.find(c => c.id === selectedCompanyId);

  const companyAccounts = useMemo(() => {
    return state?.accounts.filter(a => a.companyId === selectedCompanyId) || [];
  }, [state?.accounts, selectedCompanyId, searchQuery]);

  const companySubscriptions = useMemo(() => {
    const base = state?.subscriptions.filter(s => s.companyId === selectedCompanyId) || [];
    if (!searchQuery) return base;
    const q = searchQuery.toLowerCase();
    return base.filter(s =>
      s.name.toLowerCase().includes(q) ||
      s.paymentMethod?.toLowerCase().includes(q)
    );
  }, [state?.subscriptions, selectedCompanyId, searchQuery]);

  const companyCards = state?.financialCards.filter(c => c.companyId === selectedCompanyId) || [];
  const companyLoans = state?.loans.filter(l => l.companyId === selectedCompanyId) || [];
  const companyInstitutions = state?.institutions?.filter(i => i.companyId === selectedCompanyId) || [];
  const companyDocuments = state?.documents?.filter(d => d.companyId === selectedCompanyId) || [];

  // --- GLOBAL SEARCH LOGIC ---
  const globalSearchResults = useMemo(() => {
    if (!searchQuery || !state) return null;
    const q = searchQuery.toLowerCase();

    const companies = state.companies.filter(c => c.name.toLowerCase().includes(q));

    const subscriptions = state.subscriptions.filter(s =>
      s.name.toLowerCase().includes(q)
    ).map(s => ({ ...s, companyName: state.companies.find(c => c.id === s.companyId)?.name, companyColor: state.companies.find(c => c.id === s.companyId)?.color }));

    const hasResults = companies.length > 0 || subscriptions.length > 0;
    return { companies, subscriptions, hasResults };
  }, [searchQuery, state]);

  const toggleSearchPassword = (id: string, e: React.MouseEvent) => {
    e.stopPropagation();
    const newSet = new Set(visibleSearchPasswords);
    if (newSet.has(id)) newSet.delete(id);
    else newSet.add(id);
    setVisibleSearchPasswords(newSet);
  };

  const copySearchPassword = (text: string, id: string, e: React.MouseEvent) => {
    e.stopPropagation();
    if (!text) return;
    // Fix: correct camelCase for writeText
    navigator.clipboard.writeText(text);
    setCopiedSearchId(id);
    setTimeout(() => setCopiedSearchId(null), 2000);
  };

  const handleGlobalResultClick = (type: 'company' | 'sub', id: string, companyId: string) => {
    setSelectedCompanyId(companyId);
    setActiveView('company');
    setSearchQuery('');
    setShowSearchDropdown(false);

    if (type === 'sub') setActiveTab('subscriptions');
    if (type === 'company') setActiveTab('subscriptions');

    handleUpdateCompany(companyId, { lastViewed: Date.now() });
  };



  const handleUpdateCompany = (id: string, updates: Partial<Company>) => {
    if (!state) return;
    setState(prev => prev ? ({
      ...prev,
      companies: prev.companies.map(c => c.id === id ? { ...c, ...updates, lastModified: updates.lastModified || Date.now() } : c)
    }) : null);
  };



  const handleUpdateSubscription = (id: string, updates: Partial<Subscription>) => {
    if (!state) return;
    setState(prev => {
      if (!prev) return null;
      const sub = prev.subscriptions.find(s => s.id === id);
      return {
        ...prev,
        companies: prev.companies.map(c => c.id === sub?.companyId ? { ...c, lastModified: Date.now() } : c),
        subscriptions: prev.subscriptions.map(s => s.id === id ? { ...s, ...updates, lastUpdated: Date.now() } : s)
      };
    });
  };

  const handleDeleteSubscription = (id: string) => {
    if (!state) return;
    setState(prev => {
      if (!prev) return null;
      const sub = prev.subscriptions.find(s => s.id === id);
      return {
        ...prev,
        companies: prev.companies.map(c => c.id === sub?.companyId ? { ...c, lastModified: Date.now() } : c),
        subscriptions: prev.subscriptions.filter(s => s.id !== id)
      };
    });
  };

  const handleAddFinancialCard = (card: Partial<FinancialCard>) => {
    if (!selectedCompanyId || !state) return;
    const newCard: FinancialCard = {
      id: card.id || Math.random().toString(36).substr(2, 9),
      companyId: selectedCompanyId,
      name: card.name || 'New Card',
      cardHolder: card.cardHolder || '',
      last4: card.last4 || '0000',
      expiry: card.expiry || '12/99',
      network: card.network || 'Visa',
      type: card.type || 'Credit',
      status: card.status || 'Active',
      limit: card.limit || 0,
      paidFrom: card.paidFrom || '',
      paidOn: card.paidOn || '',
      autopay: card.autopay || 'N/A'
    };
    setState(prev => prev ? ({
      ...prev,
      companies: prev.companies.map(c => c.id === selectedCompanyId ? { ...c, lastModified: Date.now() } : c),
      financialCards: [...prev.financialCards, newCard]
    }) : null);
  };

  const handleUpdateFinancialCard = (id: string, updates: Partial<FinancialCard>) => {
    if (!state) return;
    setState(prev => {
      if (!prev) return null;
      const card = prev.financialCards.find(c => c.id === id);

      // Inverse sync: Update the card inside any linked institution
      const updatedInstitutions = (prev.institutions || []).map(inst => {
        if (inst.accounts.some(a => a.id === id)) {
          return {
            ...inst,
            accounts: inst.accounts.map(a => a.id === id ? { 
              ...a, 
              name: updates.name !== undefined ? updates.name : a.name,
              last4: updates.last4 !== undefined ? updates.last4 : a.last4,
              expiry: updates.expiry !== undefined ? updates.expiry : a.expiry,
              cardHolder: updates.cardHolder !== undefined ? updates.cardHolder : a.cardHolder,
              network: updates.network !== undefined ? updates.network : a.network,
              type: updates.type === 'Credit' ? 'Credit Card' : updates.type === 'Debit' ? (a.type === 'Debit (Linked)' || a.type === 'FSA' || a.type === 'HSA' ? a.type : 'Debit Card') : a.type,
              status: updates.status !== undefined ? updates.status : a.status,
              limit: updates.limit !== undefined ? updates.limit : a.limit,
              paidFrom: updates.paidFrom !== undefined ? updates.paidFrom : a.paidFrom,
              paidOn: updates.paidOn !== undefined ? updates.paidOn : a.paidOn,
              autopay: updates.autopay !== undefined ? updates.autopay : a.autopay
            } : a)
          };
        }
        return inst;
      });

      return {
        ...prev,
        companies: prev.companies.map(c => c.id === card?.companyId ? { ...c, lastModified: Date.now() } : c),
        financialCards: prev.financialCards.map(c => c.id === id ? { ...c, ...updates } : c),
        institutions: updatedInstitutions
      };
    });
  };

  const handleDeleteFinancialCard = (id: string) => {
    if (!state) return;
    setState(prev => {
      if (!prev) return null;
      const card = prev.financialCards.find(c => c.id === id);
      
      const updatedInstitutions = (prev.institutions || []).map(inst => ({
        ...inst,
        accounts: inst.accounts.filter(a => a.id !== id)
      }));

      return {
        ...prev,
        companies: prev.companies.map(c => c.id === card?.companyId ? { ...c, lastModified: Date.now() } : c),
        financialCards: prev.financialCards.filter(c => c.id !== id),
        institutions: updatedInstitutions
      };
    });
  };

  const handleAddLoan = (loan: Partial<Loan>) => {
    if (!selectedCompanyId || !state) return;
    const newLoan: Loan = {
      id: Math.random().toString(36).substr(2, 9),
      companyId: selectedCompanyId,
      role: loan.role || 'Lendee',
      lender: loan.lender || 'Bank',
      name: loan.name || 'New Loan',
      principalAmount: loan.principalAmount || 0,
      remainingBalance: loan.remainingBalance || 0,
      interestRate: loan.interestRate || 0,
      term: loan.term || 'Unknown',
      monthlyPayment: loan.monthlyPayment || 0,
      startDate: loan.startDate || new Date().toISOString().split('T')[0],
      status: loan.status || 'Active'
    };
    setState(prev => prev ? ({
      ...prev,
      companies: prev.companies.map(c => c.id === selectedCompanyId ? { ...c, lastModified: Date.now() } : c),
      loans: [...prev.loans, newLoan]
    }) : null);
  };

  const handleUpdateLoan = (id: string, updates: Partial<Loan>) => {
    if (!state) return;
    setState(prev => {
      if (!prev) return null;
      const loan = prev.loans.find(l => l.id === id);
      return {
        ...prev,
        companies: prev.companies.map(c => c.id === loan?.companyId ? { ...c, lastModified: Date.now() } : c),
        loans: prev.loans.map(l => l.id === id ? { ...l, ...updates } : l)
      };
    });
  };

  const handleDeleteLoan = (id: string) => {
    if (!state) return;
    setState(prev => {
      if (!prev) return null;
      const loan = prev.loans.find(l => l.id === id);
      return {
        ...prev,
        companies: prev.companies.map(c => c.id === loan?.companyId ? { ...c, lastModified: Date.now() } : c),
        loans: prev.loans.filter(l => l.id !== id)
      };
    });
  };

  const handleAddInstitution = (inst: Partial<Institution>) => {
    if (!selectedCompanyId || !state) return;
    const newInst: Institution = {
      id: Math.random().toString(36).substr(2, 9),
      companyId: selectedCompanyId,
      name: inst.name || 'New Bank',
      loginUrl: inst.loginUrl || '',
      email: inst.email || '',
      username: inst.username || '',
      password: inst.password || '',
      accounts: inst.accounts || []
    };
    setState(prev => prev ? ({
      ...prev,
      companies: prev.companies.map(c => c.id === selectedCompanyId ? { ...c, lastModified: Date.now() } : c),
      institutions: [...(prev.institutions || []), newInst]
    }) : null);
  };

  const handleUpdateInstitution = (id: string, updates: Partial<Institution>) => {
    if (!state) return;
    setState(prev => {
      if (!prev) return null;
      const inst = prev.institutions.find(i => i.id === id);
      return {
        ...prev,
        companies: prev.companies.map(c => c.id === inst?.companyId ? { ...c, lastModified: Date.now() } : c),
        institutions: prev.institutions.map(i => i.id === id ? { ...i, ...updates } : i)
      };
    });
  };

  const handleDeleteInstitution = (id: string) => {
    if (!state) return;
    setState(prev => {
      if (!prev) return null;
      const inst = prev.institutions.find(i => i.id === id);
      if (!inst) return prev;
      
      const accountIds = inst.accounts.map(a => a.id);

      return {
        ...prev,
        companies: prev.companies.map(c => c.id === inst.companyId ? { ...c, lastModified: Date.now() } : c),
        financialCards: prev.financialCards.filter(c => !accountIds.includes(c.id)),
        institutions: prev.institutions.filter(i => i.id !== id)
      };
    });
  };

  const handleAddDocument = (doc: Partial<CompanyDocument>) => {
    if (!selectedCompanyId || !state) return;
    const newDoc: CompanyDocument = {
      id: Math.random().toString(36).substr(2, 9),
      companyId: selectedCompanyId,
      name: doc.name || 'New Document',
      type: doc.type || 'Other',
      url: doc.url || '',
      uploadDate: doc.uploadDate || new Date().toISOString().split('T')[0],
      notes: doc.notes || ''
    };
    setState(prev => prev ? ({
      ...prev,
      companies: prev.companies.map(c => c.id === selectedCompanyId ? { ...c, lastModified: Date.now() } : c),
      documents: [...(prev.documents || []), newDoc]
    }) : null);
  };

  const handleUpdateDocument = (id: string, updates: Partial<CompanyDocument>) => {
    if (!state) return;
    setState(prev => {
      if (!prev) return null;
      const doc = prev.documents.find(d => d.id === id);
      return {
        ...prev,
        companies: prev.companies.map(c => c.id === doc?.companyId ? { ...c, lastModified: Date.now() } : c),
        documents: (prev.documents || []).map(d => d.id === id ? { ...d, ...updates } : d)
      };
    });
  };

  const handleDeleteDocument = (id: string) => {
    if (!state) return;
    setState(prev => {
      if (!prev) return null;
      const doc = prev.documents.find(d => d.id === id);
      return {
        ...prev,
        companies: prev.companies.map(c => c.id === doc?.companyId ? { ...c, lastModified: Date.now() } : c),
        documents: (prev.documents || []).filter(d => d.id !== id)
      };
    });
  };

  const handleDeleteCompany = (id?: string) => {
    const targetId = id || selectedCompanyId;
    if (!targetId || !state) return;

    setState(prev => prev ? ({
      companies: prev.companies.filter(c => c.id !== targetId),
      accounts: prev.accounts.filter(a => a.companyId !== targetId),
      subscriptions: prev.subscriptions.filter(s => s.companyId !== targetId),
      financialCards: prev.financialCards.filter(c => c.companyId !== targetId),
      loans: prev.loans.filter(l => l.companyId !== targetId),
      institutions: (prev.institutions || []).filter(i => i.companyId !== targetId),
      documents: (prev.documents || []).filter(d => d.companyId !== targetId)
    }) : null);

    if (targetId === selectedCompanyId) {
      setSelectedCompanyId(null);
      setActiveView('dashboard');
    }
    setShowDeleteCompanyConfirm(false);
  };

  const handleAddCompany = (newCompany: Omit<Company, 'id'>) => {
    const id = Math.random().toString(36).substr(2, 9);
    setState(prev => prev ? ({
      ...prev,
      companies: [...prev.companies, { ...newCompany, id, lastModified: Date.now(), lastViewed: Date.now() }]
    }) : null);
  };



  const handleAddSubscription = (subData: Partial<Subscription>) => {
    if (!selectedCompanyId || !state) return;
    const newSub: Subscription = {
      id: Math.random().toString(36).substr(2, 9),
      companyId: selectedCompanyId,
      name: subData.name || 'New Tech Stack',
      cost: subData.cost || 0,
      currency: subData.currency || 'USD',
      billingCycle: subData.billingCycle || 'Monthly',
      paymentMethod: subData.paymentMethod || '',
      nextRenewal: subData.nextRenewal || new Date().toISOString().split('T')[0],
      renew: subData.renew || 'Auto',
      status: subData.status || 'Active',
      subServices: []
    };
    setState(prev => prev ? ({
      ...prev,
      companies: prev.companies.map(c => c.id === selectedCompanyId ? { ...c, lastModified: Date.now() } : c),
      subscriptions: [...prev.subscriptions, newSub]
    }) : null);
  };


  const selectCompanyFromDashboard = (id: string) => {
    setSelectedCompanyId(id);
    setActiveView('company');
    setActiveTab('subscriptions');
    setIsEditingCompanyName(false);
    setIsEditingDescription(false);
    setShowDeleteCompanyConfirm(false);
    setSearchQuery('');

    handleUpdateCompany(id, { lastViewed: Date.now() });
  };

  const clearSearch = () => {
    setSearchQuery('');
    setShowSearchDropdown(false);
    searchInputRef.current?.focus();
  };

  if (!state) {
    return (
      <div className="min-h-screen bg-stone-100 flex flex-col items-center justify-center">
        <div className="w-12 h-12 border-4 border-stone-300 border-t-stone-800 rounded-full animate-spin mb-4"></div>
        <h2 className="text-stone-500 font-semibold animate-pulse">Loading CiFr...</h2>
      </div>
    );
  }

  return (
    <div className="flex bg-black min-h-screen flex-col md:flex-row pb-64 md:pb-64 relative isolate text-white">
      <style>{`
        @keyframes blink {
          0%, 100% { opacity: 1; }
          50% { opacity: 0; }
        }
        .animate-blink {
          animation: blink 1s step-end infinite;
        }
        @keyframes slideUp {
          from { transform: translateY(100%); opacity: 0; }
          to { transform: translateY(0); opacity: 1; }
        }
        .animate-slideUp {
          animation: slideUp 0.5s cubic-bezier(0.16, 1, 0.3, 1) forwards;
        }
      `}</style>

      <Sidebar
        companies={state.companies}
        activeView={activeView}
        setActiveView={(v) => { setActiveView(v as any); setSearchQuery(''); }}
        selectedCompanyId={selectedCompanyId}
        setSelectedCompanyId={setSelectedCompanyId}
        isOpen={isSidebarOpen}
        onClose={() => setIsSidebarOpen(false)}
        totalMonthlyBurn={totalMonthlyBurn}
      />

      <main className="flex-1 md:ml-64 relative transition-all duration-300">
        <div className="absolute top-0 left-0 right-0 h-[35vh] bg-[#000000] z-0"></div>

        <div className="relative z-10 p-4 md:p-8 max-w-6xl mx-auto space-y-6">

          {activeView === 'dashboard' && (
            <div className="pt-2 pb-4 text-center">
              <button
                onClick={() => { setActiveView('dashboard'); setSelectedCompanyId(null); }}
                className="text-3xl md:text-5xl font-black tracking-tighter text-white drop-shadow-sm hover:opacity-80 transition-opacity focus:outline-none"
              >
                CiFr
              </button>
              {quote && (
                <p className="mt-3 text-sm italic font-light text-stone-400 animate-fadeIn px-8">
                  "{quote.split(' - ')[0]}" — <span className="font-medium not-italic">{quote.split(' - ')[1]}</span>
                </p>
              )}
            </div>
          )}

          {showSearchDropdown && globalSearchResults && (
            <div
              ref={searchResultsRef}
              className="fixed bottom-0 left-0 right-0 z-40 h-[60vh] bg-[#111111]/95 backdrop-blur-2xl border-t border-white/10 shadow-[0_-10px_40px_-15px_rgba(0,0,0,0.6)] rounded-t-[2.5rem] flex flex-col overflow-hidden animate-slideUp"
            >
              <div className="w-full flex justify-center pt-4 pb-2 pointer-events-none">
                <div className="w-12 h-1.5 bg-white/20 rounded-full"></div>
              </div>

              <div className="flex-1 overflow-y-auto p-6 md:p-8 pb-32 max-w-3xl mx-auto w-full">
                {!globalSearchResults.hasResults ? (
                  <div className="flex flex-col items-center justify-center h-48 text-white/40">
                    <svg className="w-12 h-12 mb-4 opacity-50" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" /></svg>
                    <p className="font-semibold text-lg">No results found</p>
                    <p className="text-sm opacity-70">Try searching for a company, service, or email.</p>
                  </div>
                ) : (
                  <div className="space-y-8">
                    {globalSearchResults.companies.length > 0 && (
                      <div className="space-y-3">
                        <h4 className="text-xs font-bold text-white/40 uppercase tracking-widest pl-2">Companies</h4>
                        <div className="grid grid-cols-1 gap-2">
                          {globalSearchResults.companies.map(c => (
                            <div
                              key={c.id}
                              onClick={() => handleGlobalResultClick('company', c.id, c.id)}
                              className="group flex items-center p-3 rounded-2xl hover:bg-white/5 border border-transparent hover:border-white/10 transition-all cursor-pointer"
                            >
                              <div className="w-10 h-10 rounded-xl flex items-center justify-center text-white font-bold shadow-sm mr-4" style={{ backgroundColor: c.color }}>
                                {c.name.charAt(0)}
                              </div>
                              <div>
                                <p className="font-bold text-white text-base">{c.name}</p>
                                <p className="text-xs text-white/40 font-medium">{c.structure}</p>
                              </div>
                              <svg className="w-5 h-5 text-white/20 ml-auto group-hover:text-[#EBC351] transform group-hover:translate-x-1 transition-all" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 5l7 7-7 7" /></svg>
                            </div>
                          ))}
                        </div>
                      </div>
                    )}



                    {globalSearchResults.subscriptions.length > 0 && (
                      <div className="space-y-3">
                        <h4 className="text-xs font-bold text-white/40 uppercase tracking-widest pl-2">Subscriptions</h4>
                        <div className="bg-white/5 rounded-2xl border border-white/10 divide-y divide-white/5 overflow-hidden">
                          {globalSearchResults.subscriptions.map(s => (
                            <div
                              key={s.id}
                              onClick={() => handleGlobalResultClick('sub', s.id, s.companyId)}
                              className="p-4 hover:bg-white/10 cursor-pointer flex items-center justify-between transition-colors group"
                            >
                              <div className="flex items-center space-x-4">
                                <div className="bg-white/10 p-2 rounded-xl text-[#1FE400]">
                                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z" /></svg>
                                </div>
                                <div>
                                  <p className="font-bold text-white text-sm">{s.name}</p>
                                  <p className="text-xs text-white/40 font-mono font-bold">${s.cost}/mo</p>
                                </div>
                              </div>
                              <div className="flex items-center">
                                <span className="text-[10px] font-bold px-2 py-1 rounded-lg bg-white/10 text-white/40 mr-2 max-w-[100px] truncate">
                                  {s.companyName}
                                </span>
                                <svg className="w-4 h-4 text-white/20 group-hover:text-[#1FE400]" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 5l7 7-7 7" /></svg>
                              </div>
                            </div>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                )}
              </div>
            </div>
          )}


          <div
            className="fixed bottom-8 left-0 right-0 mx-auto max-w-3xl px-4 z-50 flex flex-col items-center gap-4 pointer-events-none"
          >
            <div className="flex items-end justify-center gap-3 w-full">
              <div className="relative pointer-events-auto" ref={quickMenuRef}>
                {showQuickMenu && (
                  <div className="absolute bottom-full left-0 mb-4 w-64 bg-[#111111]/95 backdrop-blur-xl border border-white/10 shadow-2xl rounded-2xl overflow-hidden p-2 animate-fadeIn flex flex-col gap-1">
                    <button
                      onClick={() => { setActiveView('dashboard'); setSelectedCompanyId(null); setShowQuickMenu(false); }}
                      className={`text-left px-4 py-3 rounded-xl text-sm font-semibold transition-colors flex items-center gap-3 ${activeView === 'dashboard' ? 'bg-[#EBC351] text-black shadow-md' : 'hover:bg-white/5 text-white/70'}`}
                    >
                      <svg className="w-5 h-5 opacity-70" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" /></svg>
                      Dashboard
                    </button>
                    <div className="px-2 py-1 text-[10px] font-bold text-white/30 uppercase tracking-wider">Jump to Company</div>
                    {state.companies.map(c => (
                      <button
                        key={c.id}
                        onClick={() => { selectCompanyFromDashboard(c.id); setShowQuickMenu(false); }}
                        className={`text-left px-4 py-2.5 rounded-xl text-sm font-semibold transition-colors flex items-center gap-3 ${selectedCompanyId === c.id ? 'bg-[#EBC351] text-black shadow-md' : 'hover:bg-white/5 text-white/70'}`}
                      >
                        <div className="w-2 h-2 rounded-full ring-2 ring-white/10" style={{ backgroundColor: c.color }}></div>
                        {c.name}
                      </button>
                    ))}
                  </div>
                )}
                <button
                  onClick={() => setShowQuickMenu(!showQuickMenu)}
                  className={`w-11 h-11 rounded-xl backdrop-blur-xl border shadow-2xl flex items-center justify-center transition-all duration-300 hover:scale-105 active:scale-95 ${showQuickMenu ? 'bg-[#EBC351] border-[#EBC351]/50 text-black' : 'bg-stone-900/60 border-white/10 text-white/40 hover:text-white hover:bg-stone-800'}`}
                >
                  {showQuickMenu ? (
                    <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M6 18L18 6M6 6l12 12" /></svg>
                  ) : (
                    <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M4 6h16M4 12h16M4 18h16" /></svg>
                  )}
                </button>
              </div>

              <div className="relative group flex-1 max-w-2xl pointer-events-auto" ref={searchContainerRef}>
                <div className="relative shadow-2xl rounded-full group transition-all duration-300 hover:scale-[1.01]">
                  <div className="absolute inset-y-0 left-0 pl-5 flex items-center pointer-events-none z-10">
                    <svg className="h-5 w-5 text-white/20 group-focus-within:text-[#EBC351] transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                    </svg>
                  </div>

                  {!searchQuery && (
                    <div
                      className={`absolute inset-y-0 left-14 flex items-center pointer-events-none transition-opacity duration-200 ${isInputFocused ? 'opacity-100' : 'opacity-0'}`}
                    >
                      <div className="h-4 w-[2px] bg-[#EBC351] animate-blink"></div>
                    </div>
                  )}

                  <input
                    ref={searchInputRef}
                    type="text"
                    className="block w-full pl-14 pr-12 py-2.5 bg-stone-900/60 backdrop-blur-xl border border-white/10 rounded-xl text-base font-medium text-white placeholder-white/20 focus:outline-none focus:ring-2 focus:ring-[#EBC351]/20 transition-all shadow-2xl"
                    placeholder="Search"
                    value={searchQuery}
                    onFocus={() => {
                      setIsInputFocused(true);
                      if (searchQuery) setShowSearchDropdown(true);
                    }}
                    onBlur={() => setIsInputFocused(false)}
                    onChange={(e) => {
                      setSearchQuery(e.target.value);
                      setShowSearchDropdown(!!e.target.value);
                    }}
                  />
                  <div className="absolute inset-y-0 right-0 pr-4 flex items-center space-x-3 z-10">
                    {searchQuery && (
                      <button
                        onClick={clearSearch}
                        className="text-stone-500 hover:text-white transition-colors p-1"
                      >
                        <svg className="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M6 18L18 6M6 6l12 12" /></svg>
                      </button>
                    )}
                  </div>
                </div>
              </div>
            </div>

            {selectedCompanyId && activeView === 'company' && (
              <div className="w-full max-w-xl mx-auto pointer-events-auto">
                <div className="bg-stone-900/60 backdrop-blur-xl p-1.5 rounded-2xl shadow-2xl border border-white/10 flex justify-between items-center ring-1 ring-black/5">
                  {[

                    { id: 'subscriptions', label: 'Services', activeClass: 'bg-blue-400/7 border-blue-300/20 shadow-[0_2px_16px_0_rgba(96,165,250,0.06)]' },
                    { id: 'financial', label: 'Financial', activeClass: 'bg-green-400/7 border-green-300/20 shadow-[0_2px_16px_0_rgba(74,222,128,0.06)]' },
                    { id: 'docs', label: 'Docs', activeClass: 'bg-white/7 border-white/20 shadow-[0_2px_16px_0_rgba(255,255,255,0.06)]' },
                  ].map(tab => (
                    <button
                      key={tab.id}
                      onClick={() => { setActiveTab(tab.id as any); setSearchQuery(''); }}
                      className={`relative z-10 flex-1 px-4 py-3.5 text-xs font-black uppercase tracking-widest rounded-xl transition-all duration-300 ${activeTab === tab.id
                        ? `backdrop-blur-xl text-white scale-[1.02] border ${tab.activeClass}`
                        : 'text-white/40 hover:text-white hover:bg-white/5'
                        }`}
                    >
                      {tab.label}
                    </button>
                  ))}
                </div>
              </div>
            )}
          </div>

          {activeView === 'dashboard' ? (
            <Dashboard
              state={{ ...state, companies: filteredCompanies }}
              onSelectCompany={selectCompanyFromDashboard}
              onAddCompany={handleAddCompany}
              onUpdateCompany={handleUpdateCompany}
              onDeleteCompany={handleDeleteCompany}
            />
          ) : (
            <div className="space-y-8 animate-fadeIn">
              {selectedCompany && (
                <>
                  <header className="flex flex-col md:flex-row md:items-start justify-between gap-4">
                    <div className="flex-1 w-full">
                      <div className="flex items-center space-x-3 mb-2">
                        <div className="relative">
                          <div
                            className="w-12 h-12 rounded-xl flex items-center justify-center text-white font-bold flex-shrink-0 overflow-hidden ring-offset-2 transition-all shadow-sm"
                            style={{
                              backgroundColor: selectedCompany.logoUrl ? 'white' : (selectedCompany.website ? 'white' : selectedCompany.color)
                            }}
                          >
                            {selectedCompany.logoUrl ? (
                              <img src={selectedCompany.logoUrl} alt="Logo" className="w-full h-full object-cover" />
                            ) : selectedCompany.website ? (
                              <img
                                src={getFaviconUrl(selectedCompany.website) || ''}
                                className="w-8 h-8 object-contain"
                                alt=""
                                onError={(e) => {
                                  (e.target as HTMLImageElement).style.display = 'none';
                                  (e.target as HTMLImageElement).nextElementSibling!.setAttribute('style', 'display: block');
                                }}
                              />
                            ) : null}
                            <span
                              className="text-xl"
                              style={{ display: !selectedCompany.logoUrl && selectedCompany.website ? 'none' : 'block' }}
                            >
                              {selectedCompany.name.charAt(0)}
                            </span>
                          </div>
                        </div>
                        <div className="flex items-center space-x-3 w-full overflow-hidden">
                          <h2 className={`text-2xl md:text-3xl font-bold truncate ${selectedCompanyId ? 'text-white' : 'text-slate-900'}`}>{selectedCompany.name}</h2>
                        </div>
                      </div>
                    </div>
                  </header>


                  <div className="mt-2">
                    {activeTab === 'subscriptions' && (
                      <div className="space-y-8 animate-fadeIn">
                        <SubscriptionList
                          subscriptions={companySubscriptions}
                          onUpdateSubscription={handleUpdateSubscription}
                          onAddSubscription={handleAddSubscription}
                          onDeleteSubscription={handleDeleteSubscription}
                        />
                      </div>
                    )}

                    {activeTab === 'financial' && (
                      <FinancialList
                        cards={companyCards}
                        loans={companyLoans}
                        institutions={companyInstitutions}
                        onAddCard={handleAddFinancialCard}
                        onUpdateCard={handleUpdateFinancialCard}
                        onDeleteCard={handleDeleteFinancialCard}
                        onAddLoan={handleAddLoan}
                        onUpdateLoan={handleUpdateLoan}
                        onDeleteLoan={handleDeleteLoan}
                        onAddInstitution={handleAddInstitution}
                        onUpdateInstitution={handleUpdateInstitution}
                        onDeleteInstitution={handleDeleteInstitution}
                      />
                    )}
                    {activeTab === 'docs' && (
                      <DocumentList
                        documents={companyDocuments}
                        onAddDocument={handleAddDocument}
                        onUpdateDocument={handleUpdateDocument}
                        onDeleteDocument={handleDeleteDocument}
                      />
                    )}
                  </div>
                </>
              )}
            </div>
          )}
        </div>
      </main>
    </div>
  );
};

export default App;