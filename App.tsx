import React, { useState, useEffect, useCallback, useRef, useMemo } from 'react';
import Sidebar from './components/Sidebar';
import Dashboard from './components/Dashboard';
import AccountList from './components/AccountList';
import SubscriptionList from './components/SubscriptionList';
import FinancialList from './components/FinancialList';
import DocumentList from './components/DocumentList';
import { AppState, Company, Account, Subscription, FinancialCard, Loan, Institution, CompanyDocument } from './types';
import { analyzeSubscriptions, getEntrepreneurialQuote } from './services/geminiService';
import { db } from './services/dbService';

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
  const [activeTab, setActiveTab] = useState<'accounts' | 'subscriptions' | 'financial' | 'docs' | 'insights'>(() => {
    const stored = localStorage.getItem('fs_tab');
    if (stored === 'stack') return 'accounts';
    return (stored as any) || 'accounts';
  });

  const [geminiInsights, setGeminiInsights] = useState<string>('');
  const [isGeneratingInsights, setIsGeneratingInsights] = useState(false);
  const [isEditingCompanyName, setIsEditingCompanyName] = useState(false);
  const [isEditingDescription, setIsEditingDescription] = useState(false);
  const [showIconMenu, setShowIconMenu] = useState(false);
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

  const iconMenuRef = useRef<HTMLDivElement>(null);
  const searchInputRef = useRef<HTMLInputElement>(null);
  const searchContainerRef = useRef<HTMLDivElement>(null);
  const searchResultsRef = useRef<HTMLDivElement>(null);

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
    const base = state?.accounts.filter(a => a.companyId === selectedCompanyId) || [];
    if (!searchQuery) return base;
    const q = searchQuery.toLowerCase();
    return base.filter(a =>
      a.platform.toLowerCase().includes(q) ||
      a.email.toLowerCase().includes(q) ||
      a.twoFactorAuth.toLowerCase().includes(q) ||
      a.notes.some(note => note.toLowerCase().includes(q))
    );
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

    const accounts = state.accounts.filter(a =>
      a.platform.toLowerCase().includes(q) ||
      a.email.toLowerCase().includes(q) ||
      a.twoFactorAuth.toLowerCase().includes(q)
    ).map(a => ({ ...a, companyName: state.companies.find(c => c.id === a.companyId)?.name, companyColor: state.companies.find(c => c.id === a.companyId)?.color }));

    const subscriptions = state.subscriptions.filter(s =>
      s.name.toLowerCase().includes(q)
    ).map(s => ({ ...s, companyName: state.companies.find(c => c.id === s.companyId)?.name, companyColor: state.companies.find(c => c.id === s.companyId)?.color }));

    const hasResults = companies.length > 0 || accounts.length > 0 || subscriptions.length > 0;
    return { companies, accounts, subscriptions, hasResults };
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

  const handleGlobalResultClick = (type: 'company' | 'account' | 'sub', id: string, companyId: string) => {
    setSelectedCompanyId(companyId);
    setActiveView('company');
    setSearchQuery('');
    setShowSearchDropdown(false);

    if (type === 'account') setActiveTab('accounts');
    if (type === 'sub') setActiveTab('subscriptions');
    if (type === 'company') setActiveTab('accounts');

    handleUpdateCompany(companyId, { lastViewed: Date.now() });
  };


  // Close icon menu if clicked outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (iconMenuRef.current && !iconMenuRef.current.contains(event.target as Node)) {
        setShowIconMenu(false);
      }
    };
    document.addEventListener("mousedown", handleClickOutside);
    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
    };
  }, []);

  const handleUpdateCompany = (id: string, updates: Partial<Company>) => {
    if (!state) return;
    setState(prev => prev ? ({
      ...prev,
      companies: prev.companies.map(c => c.id === id ? { ...c, ...updates, lastModified: updates.lastModified || Date.now() } : c)
    }) : null);
  };

  const handleUpdateAccount = (id: string, updates: Partial<Account>) => {
    if (!state) return;
    setState(prev => {
      if (!prev) return null;
      const account = prev.accounts.find(a => a.id === id);
      if (!account) return prev;

      const updatedCompanies = prev.companies.map(c => c.id === account.companyId ? { ...c, lastModified: Date.now() } : c);

      const updatedSubscriptions = prev.subscriptions.map(s => {
        if (s.companyId === account.companyId && s.name === account.platform) {
          const newName = updates.platform || s.name;
          const newCost = updates.subscriptionCost !== undefined ? updates.subscriptionCost : s.cost;
          const newCycle = updates.subscriptionInterval === 'Yearly' ? 'Yearly' : 'Monthly';
          return { ...s, name: newName, cost: newCost, billingCycle: newCycle as any };
        }
        return s;
      });

      return {
        ...prev,
        companies: updatedCompanies,
        accounts: prev.accounts.map(a => a.id === id ? { ...a, ...updates } : a),
        subscriptions: updatedSubscriptions
      };
    });
  };

  const handleDeleteAccount = (id: string) => {
    if (!state) return;
    setState(prev => {
      if (!prev) return null;
      const accountToDelete = prev.accounts.find(a => a.id === id);
      if (!accountToDelete) return prev;

      return {
        ...prev,
        companies: prev.companies.map(c => c.id === accountToDelete.companyId ? { ...c, lastModified: Date.now() } : c),
        accounts: prev.accounts.filter(a => a.id !== id),
        subscriptions: prev.subscriptions.filter(s => !(s.companyId === accountToDelete.companyId && s.name === accountToDelete.platform))
      };
    });
  };

  const handleUpdateSubscription = (id: string, updates: Partial<Subscription>) => {
    if (!state) return;
    setState(prev => {
      if (!prev) return null;
      const sub = prev.subscriptions.find(s => s.id === id);
      return {
        ...prev,
        companies: prev.companies.map(c => c.id === sub?.companyId ? { ...c, lastModified: Date.now() } : c),
        subscriptions: prev.subscriptions.map(s => s.id === id ? { ...s, ...updates } : s)
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
      id: Math.random().toString(36).substr(2, 9),
      companyId: selectedCompanyId,
      name: card.name || 'New Card',
      cardHolder: card.cardHolder || '',
      last4: card.last4 || '0000',
      expiry: card.expiry || '12/99',
      network: card.network || 'Visa',
      type: card.type || 'Credit',
      status: card.status || 'Active',
      limit: card.limit || 0
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
      return {
        ...prev,
        companies: prev.companies.map(c => c.id === card?.companyId ? { ...c, lastModified: Date.now() } : c),
        financialCards: prev.financialCards.map(c => c.id === id ? { ...c, ...updates } : c)
      };
    });
  };

  const handleDeleteFinancialCard = (id: string) => {
    if (!state) return;
    setState(prev => {
      if (!prev) return null;
      const card = prev.financialCards.find(c => c.id === id);
      return {
        ...prev,
        companies: prev.companies.map(c => c.id === card?.companyId ? { ...c, lastModified: Date.now() } : c),
        financialCards: prev.financialCards.filter(c => c.id !== id)
      };
    });
  };

  const handleAddLoan = (loan: Partial<Loan>) => {
    if (!selectedCompanyId || !state) return;
    const newLoan: Loan = {
      id: Math.random().toString(36).substr(2, 9),
      companyId: selectedCompanyId,
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
      return {
        ...prev,
        companies: prev.companies.map(c => c.id === inst?.companyId ? { ...c, lastModified: Date.now() } : c),
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

  const handleDeleteCompany = () => {
    if (!selectedCompanyId || !state) return;

    setState(prev => prev ? ({
      companies: prev.companies.filter(c => c.id !== selectedCompanyId),
      accounts: prev.accounts.filter(a => a.companyId !== selectedCompanyId),
      subscriptions: prev.subscriptions.filter(s => s.companyId !== selectedCompanyId),
      financialCards: prev.financialCards.filter(c => c.companyId !== selectedCompanyId),
      loans: prev.loans.filter(l => l.companyId !== selectedCompanyId),
      institutions: (prev.institutions || []).filter(i => i.companyId !== selectedCompanyId),
      documents: (prev.documents || []).filter(d => d.companyId !== selectedCompanyId)
    }) : null);

    setSelectedCompanyId(null);
    setActiveView('dashboard');
    setShowDeleteCompanyConfirm(false);
  };

  const handleAddCompany = (newCompany: Omit<Company, 'id'>) => {
    const id = Math.random().toString(36).substr(2, 9);
    setState(prev => prev ? ({
      ...prev,
      companies: [...prev.companies, { ...newCompany, id, lastModified: Date.now(), lastViewed: Date.now() }]
    }) : null);
  };

  const handleAddAccount = (accountData: Partial<Account>) => {
    if (!selectedCompanyId || !state) return;
    const newAcc: Account = {
      id: Math.random().toString(36).substr(2, 9),
      companyId: selectedCompanyId,
      platform: accountData.platform || 'New Platform',
      website: accountData.website || '',
      email: accountData.email || 'N/A',
      twoFactorAuth: accountData.twoFactorAuth || 'None',
      recoveryMethod: accountData.recoveryMethod || '',
      password: '',
      pricingModel: accountData.pricingModel || 'paid',
      notes: accountData.notes || [],
      subscriptionCost: accountData.subscriptionCost || 0,
      subscriptionInterval: accountData.subscriptionInterval || 'Monthly',
      paymentMethod: accountData.paymentMethod || '',
      nextBillingDate: accountData.nextBillingDate || '',
      renew: accountData.renew || 'Auto',
      status: 'Active'
    };

    const newSub: Subscription = {
      id: Math.random().toString(36).substr(2, 9),
      companyId: selectedCompanyId,
      name: newAcc.platform,
      cost: newAcc.subscriptionCost || 0,
      currency: 'USD',
      billingCycle: newAcc.subscriptionInterval === 'Yearly' ? 'Yearly' : 'Monthly',
      paymentMethod: newAcc.paymentMethod,
      nextRenewal: newAcc.nextBillingDate || new Date().toISOString().split('T')[0],
      renew: newAcc.renew,
      status: newAcc.status === 'Inactive' ? 'Cancelled' : 'Active'
    };

    setState(prev => prev ? ({
      ...prev,
      companies: prev.companies.map(c => c.id === selectedCompanyId ? { ...c, lastModified: Date.now() } : c),
      accounts: [...prev.accounts, newAcc],
      subscriptions: [...prev.subscriptions, newSub]
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

  const generateInsights = useCallback(async () => {
    if (!selectedCompanyId) return;
    setIsGeneratingInsights(true);
    const insights = await analyzeSubscriptions(companySubscriptions);
    setGeminiInsights(insights || "No strategic insights available.");
    setIsGeneratingInsights(false);
  }, [selectedCompanyId, companySubscriptions]);

  useEffect(() => {
    if (activeTab === 'insights' && !geminiInsights && !isGeneratingInsights) {
      generateInsights();
    }
  }, [activeTab, geminiInsights, isGeneratingInsights, generateInsights]);

  const selectCompanyFromDashboard = (id: string) => {
    setSelectedCompanyId(id);
    setActiveView('company');
    setGeminiInsights('');
    setActiveTab('accounts');
    setIsEditingCompanyName(false);
    setIsEditingDescription(false);
    setShowIconMenu(false);
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
    <div className="flex bg-zinc-200 min-h-screen flex-col md:flex-row pb-24 md:pb-0 relative isolate">
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
        <div className="absolute top-0 left-0 right-0 h-[35vh] bg-stone-950 z-0"></div>

        <div className="relative z-10 p-4 md:p-8 max-w-6xl mx-auto space-y-6">

          {activeView === 'dashboard' && (
            <div className="pt-8 pb-4 text-center">
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
              className="fixed bottom-0 left-0 right-0 z-40 h-[60vh] bg-white/85 backdrop-blur-2xl border-t border-white/50 shadow-[0_-10px_40px_-15px_rgba(0,0,0,0.2)] rounded-t-[2.5rem] flex flex-col overflow-hidden animate-slideUp"
            >
              <div className="w-full flex justify-center pt-4 pb-2 pointer-events-none">
                <div className="w-12 h-1.5 bg-slate-300/50 rounded-full"></div>
              </div>

              <div className="flex-1 overflow-y-auto p-6 md:p-8 pb-32 max-w-3xl mx-auto w-full">
                {!globalSearchResults.hasResults ? (
                  <div className="flex flex-col items-center justify-center h-48 text-slate-400">
                    <svg className="w-12 h-12 mb-4 opacity-50" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" /></svg>
                    <p className="font-semibold text-lg">No results found</p>
                    <p className="text-sm opacity-70">Try searching for a company, service, or email.</p>
                  </div>
                ) : (
                  <div className="space-y-8">
                    {globalSearchResults.companies.length > 0 && (
                      <div className="space-y-3">
                        <h4 className="text-xs font-bold text-slate-400 uppercase tracking-widest pl-2">Companies</h4>
                        <div className="grid grid-cols-1 gap-2">
                          {globalSearchResults.companies.map(c => (
                            <div
                              key={c.id}
                              onClick={() => handleGlobalResultClick('company', c.id, c.id)}
                              className="group flex items-center p-3 rounded-2xl hover:bg-white/50 border border-transparent hover:border-slate-200/50 transition-all cursor-pointer"
                            >
                              <div className="w-10 h-10 rounded-xl flex items-center justify-center text-white font-bold shadow-sm mr-4" style={{ backgroundColor: c.color }}>
                                {c.name.charAt(0)}
                              </div>
                              <div>
                                <p className="font-bold text-slate-800 text-base">{c.name}</p>
                                <p className="text-xs text-slate-500 font-medium">{c.structure}</p>
                              </div>
                              <svg className="w-5 h-5 text-slate-300 ml-auto group-hover:text-indigo-500 transform group-hover:translate-x-1 transition-all" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 5l7 7-7 7" /></svg>
                            </div>
                          ))}
                        </div>
                      </div>
                    )}

                    {globalSearchResults.accounts.length > 0 && (
                      <div className="space-y-3">
                        <h4 className="text-xs font-bold text-slate-400 uppercase tracking-widest pl-2">Accounts & Logins</h4>
                        <div className="bg-white/40 rounded-2xl border border-white/50 divide-y divide-slate-100 overflow-hidden">
                          {globalSearchResults.accounts.map(a => (
                            <div
                              key={a.id}
                              onClick={() => handleGlobalResultClick('account', a.id, a.companyId)}
                              className="p-4 hover:bg-white/60 cursor-pointer flex items-center justify-between transition-colors group"
                            >
                              <div className="flex items-center space-x-4 min-w-0 flex-1">
                                <div className="bg-white p-2 rounded-xl shadow-sm text-indigo-600 flex-shrink-0">
                                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" /></svg>
                                </div>
                                <div className="min-w-0 flex-1">
                                  <div className="flex justify-between items-start">
                                    <div>
                                      <p className="font-bold text-slate-800 text-sm truncate">{a.platform}</p>
                                      <p className="text-xs text-slate-500 truncate font-medium">{a.email}</p>
                                    </div>
                                  </div>

                                  <div className="flex items-center gap-2 mt-1.5" onClick={(e) => e.stopPropagation()}>
                                    <div className="flex items-center bg-slate-100/80 rounded-md px-2 py-1 border border-slate-200/50">
                                      <span className="text-[10px] font-mono text-slate-600 w-16 truncate">
                                        {visibleSearchPasswords.has(a.id) ? (a.password || '-') : '••••••••'}
                                      </span>
                                    </div>
                                    <button
                                      onClick={(e) => toggleSearchPassword(a.id, e)}
                                      className="p-1 text-slate-400 hover:text-indigo-600 hover:bg-white rounded-md transition-colors"
                                    >
                                      {visibleSearchPasswords.has(a.id) ? (
                                        <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268-2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" /></svg>
                                      ) : (
                                        <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268-2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" /></svg>
                                      )}
                                    </button>
                                    <button
                                      onClick={(e) => copySearchPassword(a.password || '', a.id, e)}
                                      className="p-1 text-slate-400 hover:text-indigo-600 hover:bg-white rounded-md transition-colors"
                                    >
                                      {copiedSearchId === a.id ? (
                                        <svg className="w-3.5 h-3.5 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M5 13l4 4L19 7" /></svg>
                                      ) : (
                                        <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M8 5H6a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2v-1M8 5a2 2 0 002 2h2a2 2 0 002-2M8 5a2 2 0 012-2h2a2 2 0 012 2m0 0h2a2 2 0 012 2v3m2 4H10m0 0l3-3m-3 3l3 3" /></svg>
                                      )}
                                    </button>
                                  </div>
                                </div>
                              </div>
                              <div className="flex items-center flex-shrink-0 ml-4">
                                <span className="text-[10px] font-bold px-2 py-1 rounded-lg bg-slate-100 text-slate-500 mr-2 max-w-[100px] truncate">
                                  {a.companyName}
                                </span>
                                <svg className="w-4 h-4 text-slate-300 group-hover:text-indigo-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 5l7 7-7 7" /></svg>
                              </div>
                            </div>
                          ))}
                        </div>
                      </div>
                    )}

                    {globalSearchResults.subscriptions.length > 0 && (
                      <div className="space-y-3">
                        <h4 className="text-xs font-bold text-slate-400 uppercase tracking-widest pl-2">Subscriptions</h4>
                        <div className="bg-white/40 rounded-2xl border border-white/50 divide-y divide-slate-100 overflow-hidden">
                          {globalSearchResults.subscriptions.map(s => (
                            <div
                              key={s.id}
                              onClick={() => handleGlobalResultClick('sub', s.id, s.companyId)}
                              className="p-4 hover:bg-white/60 cursor-pointer flex items-center justify-between transition-colors group"
                            >
                              <div className="flex items-center space-x-4">
                                <div className="bg-white p-2 rounded-xl shadow-sm text-emerald-600">
                                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z" /></svg>
                                </div>
                                <div>
                                  <p className="font-bold text-slate-800 text-sm">{s.name}</p>
                                  <p className="text-xs text-slate-500 font-mono font-bold">${s.cost}/mo</p>
                                </div>
                              </div>
                              <div className="flex items-center">
                                <span className="text-[10px] font-bold px-2 py-1 rounded-lg bg-slate-100 text-slate-500 mr-2 max-w-[100px] truncate">
                                  {s.companyName}
                                </span>
                                <svg className="w-4 h-4 text-slate-300 group-hover:text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 5l7 7-7 7" /></svg>
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
            className="fixed bottom-8 left-0 right-0 mx-auto max-w-3xl px-4 z-50 flex items-end justify-center gap-3 pointer-events-none"
          >
            <div className="relative pointer-events-auto">
              {showQuickMenu && (
                <div className="absolute bottom-full left-0 mb-4 w-64 bg-white/60 backdrop-blur-xl border border-white/40 shadow-2xl rounded-2xl overflow-hidden p-2 animate-fadeIn flex flex-col gap-1">
                  <button
                    onClick={() => { setActiveView('dashboard'); setSelectedCompanyId(null); setShowQuickMenu(false); }}
                    className={`text-left px-4 py-3 rounded-xl text-sm font-semibold transition-colors flex items-center gap-3 ${activeView === 'dashboard' ? 'bg-indigo-600 text-white shadow-md' : 'hover:bg-white/40 text-slate-700'}`}
                  >
                    <svg className="w-5 h-5 opacity-70" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" /></svg>
                    Dashboard
                  </button>
                  <div className="px-2 py-1 text-[10px] font-bold text-slate-500 uppercase tracking-wider">Jump to Company</div>
                  {state.companies.map(c => (
                    <button
                      key={c.id}
                      onClick={() => { selectCompanyFromDashboard(c.id); setShowQuickMenu(false); }}
                      className={`text-left px-4 py-2.5 rounded-xl text-sm font-semibold transition-colors flex items-center gap-3 ${selectedCompanyId === c.id ? 'bg-indigo-600 text-white shadow-md' : 'hover:bg-white/40 text-slate-700'}`}
                    >
                      <div className="w-2 h-2 rounded-full ring-2 ring-white/50" style={{ backgroundColor: c.color }}></div>
                      {c.name}
                    </button>
                  ))}
                </div>
              )}
              <button
                onClick={() => setShowQuickMenu(!showQuickMenu)}
                className={`w-14 h-14 rounded-full backdrop-blur-xl border shadow-2xl flex items-center justify-center transition-all duration-300 hover:scale-105 active:scale-95 ${showQuickMenu ? 'bg-indigo-600 border-indigo-500 text-white' : 'bg-white/30 border-white/30 text-slate-700 hover:bg-white/50'}`}
              >
                {showQuickMenu ? (
                  <svg className="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" /></svg>
                ) : (
                  <svg className="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M4 6h16M4 12h16M4 18h16" /></svg>
                )}
              </button>
            </div>

            <div className="relative group flex-1 max-w-2xl pointer-events-auto" ref={searchContainerRef}>
              <div className="relative shadow-2xl rounded-full group transition-all duration-300 hover:scale-[1.01]">
                <div className="absolute inset-y-0 left-0 pl-6 flex items-center pointer-events-none z-10">
                  <svg className="h-6 w-6 text-stone-500 group-focus-within:text-white transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                  </svg>
                </div>

                {!searchQuery && (
                  <div
                    className={`absolute inset-y-0 left-16 flex items-center pointer-events-none transition-opacity duration-200 ${isInputFocused ? 'opacity-100' : 'opacity-0'}`}
                  >
                    <div className="h-5 w-[2.5px] bg-indigo-500 animate-blink"></div>
                  </div>
                )}

                <input
                  ref={searchInputRef}
                  type="text"
                  className="block w-full pl-16 pr-16 py-4 bg-stone-950 border border-white/5 rounded-full text-base font-medium text-white placeholder-stone-400 focus:outline-none focus:ring-4 focus:ring-indigo-500/20 transition-all shadow-2xl"
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

          {activeView === 'dashboard' ? (
            <Dashboard
              state={{ ...state, companies: filteredCompanies }}
              onSelectCompany={selectCompanyFromDashboard}
              onAddCompany={handleAddCompany}
              onUpdateCompany={handleUpdateCompany}
            />
          ) : (
            <div className="space-y-8 animate-fadeIn">
              {selectedCompany && (
                <>
                  <header className="flex flex-col md:flex-row md:items-start justify-between gap-4">
                    <div className="flex-1 w-full">
                      <div className="flex items-center space-x-3 mb-2">
                        <div className="relative" ref={iconMenuRef}>
                          <div
                            className="w-12 h-12 rounded-xl flex items-center justify-center text-white font-bold flex-shrink-0 cursor-pointer overflow-hidden ring-offset-2 hover:ring-2 ring-indigo-200 transition-all shadow-sm"
                            style={{ backgroundColor: selectedCompany.logoUrl ? 'transparent' : selectedCompany.color }}
                            onClick={() => setShowIconMenu(!showIconMenu)}
                            title="Change Icon or Color"
                          >
                            {selectedCompany.logoUrl ? (
                              <img src={selectedCompany.logoUrl} alt="Logo" className="w-full h-full object-cover" />
                            ) : (
                              <span className="text-xl">{selectedCompany.name.charAt(0)}</span>
                            )}
                          </div>

                          {showIconMenu && (
                            <div className="absolute top-14 left-0 bg-white border border-slate-200 rounded-xl shadow-xl p-4 w-64 z-50 animate-fadeIn">
                              <h4 className="text-xs font-bold text-slate-500 uppercase mb-3">Brand Color</h4>
                              <div className="grid grid-cols-5 gap-2 mb-4">
                                {BRAND_COLORS.map(color => (
                                  <button
                                    key={color}
                                    onClick={() => handleUpdateCompany(selectedCompany.id, { color, logoUrl: '' })}
                                    className={`w-8 h-8 rounded-full border border-slate-100 ${selectedCompany.color === color && !selectedCompany.logoUrl ? 'ring-2 ring-offset-1 ring-slate-800' : ''}`}
                                    style={{ backgroundColor: color }}
                                  />
                                ))}
                              </div>
                              <h4 className="text-xs font-bold text-slate-500 uppercase mb-2">Or Logo URL</h4>
                              <input
                                type="text"
                                className="w-full px-3 py-2 text-xs border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                                placeholder="https://example.com/logo.png"
                                value={selectedCompany.logoUrl || ''}
                                onChange={(e) => handleUpdateCompany(selectedCompany.id, { logoUrl: e.target.value })}
                              />
                            </div>
                          )}
                        </div>
                        {isEditingCompanyName ? (
                          <div className="flex items-center space-x-2 flex-1 w-full">
                            <input
                              autoFocus
                              type="text"
                              className="text-2xl md:text-3xl font-bold text-slate-900 bg-transparent border-b-2 border-indigo-600 outline-none w-full max-w-md px-1"
                              value={selectedCompany.name}
                              onChange={(e) => handleUpdateCompany(selectedCompany.id, { name: e.target.value })}
                              onBlur={() => setIsEditingCompanyName(false)}
                              onKeyDown={(e) => e.key === 'Enter' && setIsEditingCompanyName(false)}
                            />
                            <button
                              onClick={() => setIsEditingCompanyName(false)}
                              className="text-xs font-bold text-indigo-600 uppercase whitespace-nowrap"
                            >
                              Done
                            </button>
                          </div>
                        ) : (
                          <div className="flex items-center space-x-3 w-full overflow-hidden">
                            <h2 className={`text-2xl md:text-3xl font-bold truncate ${selectedCompanyId ? 'text-white drop-shadow-md' : 'text-slate-900'}`}>{selectedCompany.name}</h2>
                            <button
                              onClick={() => setIsEditingCompanyName(true)}
                              className="text-white/70 hover:text-white flex-shrink-0 transition-colors"
                            >
                              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                              </svg>
                            </button>

                            {showDeleteCompanyConfirm ? (
                              <div className="flex items-center space-x-2 animate-fadeIn bg-slate-50 p-1 rounded-lg border border-slate-100 ml-2">
                                <span className="text-xs font-bold text-slate-500 ml-1 whitespace-nowrap">Delete?</span>
                                <button
                                  onClick={handleDeleteCompany}
                                  className="bg-rose-600 text-white px-3 py-1 rounded-md text-xs font-bold hover:bg-rose-700 transition"
                                >
                                  Yes
                                </button>
                                <button
                                  onClick={() => setShowDeleteCompanyConfirm(false)}
                                  className="bg-white border border-slate-200 text-slate-600 px-3 py-1 rounded-md text-xs font-bold hover:bg-slate-50 transition"
                                >
                                  Cancel
                                </button>
                              </div>
                            ) : (
                              <button
                                onClick={() => setShowDeleteCompanyConfirm(true)}
                                className="text-white/70 hover:text-white transition-colors p-1"
                                title="Delete Company"
                              >
                                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                              </button>
                            )}
                          </div>
                        )}
                      </div>

                      {isEditingDescription ? (
                        <div className="flex flex-col space-y-2 w-full md:w-[60%]">
                          <textarea
                            autoFocus
                            className="w-full text-base text-slate-600 bg-white border border-slate-200 rounded-lg p-3 focus:ring-2 focus:ring-indigo-500 outline-none"
                            rows={2}
                            value={selectedCompany.description}
                            placeholder="Mission statement 🚀"
                            onChange={(e) => handleUpdateCompany(selectedCompany.id, { description: e.target.value })}
                            onBlur={() => setIsEditingDescription(false)}
                          />
                          <div className="flex justify-end">
                            <button
                              onClick={() => setIsEditingDescription(false)}
                              className="text-xs font-bold text-indigo-600 uppercase bg-indigo-50 px-3 py-1 rounded-md"
                            >
                              Save Mission
                            </button>
                          </div>
                        </div>
                      ) : (
                        <div className="group flex items-start space-x-2 w-full md:w-[60%] cursor-pointer" onClick={() => setIsEditingDescription(true)}>
                          <p className={`text-base leading-relaxed ${selectedCompany.description ? 'text-white/90' : 'text-white/60 italic'}`}>
                            {selectedCompany.description || "Mission statement 🚀"}
                          </p>
                          <button className="mt-1 text-white/50 opacity-0 group-hover:opacity-100 transition-opacity hover:text-white">
                            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" /></svg>
                          </button>
                        </div>
                      )}
                    </div>
                  </header>

                  <div className="sticky top-6 z-40 w-full max-w-xl mx-auto mb-10">
                    <div className="bg-stone-100 p-1.5 rounded-2xl shadow-xl border border-white/40 flex justify-between items-center ring-1 ring-black/5">
                      {[
                        { id: 'accounts', label: 'Logins' },
                        { id: 'subscriptions', label: 'Services' },
                        { id: 'financial', label: 'Financial' },
                        { id: 'docs', label: 'Docs' },
                        { id: 'insights', label: 'Insights' }
                      ].map(tab => (
                        <button
                          key={tab.id}
                          onClick={() => { setActiveTab(tab.id as any); setSearchQuery(''); }}
                          className={`relative z-10 flex-1 px-4 py-2 text-xs md:text-sm font-bold rounded-xl transition-all duration-300 ${activeTab === tab.id
                              ? 'bg-stone-200 text-stone-900 shadow-sm'
                              : 'text-stone-500 hover:text-stone-900 hover:bg-stone-200/50'
                            }`}
                        >
                          {tab.label}
                        </button>
                      ))}
                    </div>
                  </div>

                  <div className="mt-8">
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
                    {activeTab === 'accounts' && (
                      <div className="space-y-8 animate-fadeIn">
                        <AccountList
                          accounts={companyAccounts}
                          onAddAccount={handleAddAccount}
                          onUpdateAccount={handleUpdateAccount}
                          onDeleteAccount={handleDeleteAccount}
                          subscriptions={state.subscriptions}
                          geminiInsights={geminiInsights}
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