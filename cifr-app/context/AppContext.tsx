import React, { createContext, useContext, useState, useEffect, useMemo } from 'react';
import { db } from '../services/dbService';
import { AppState, Company, Account, Subscription, FinancialCard, Loan, Institution, CompanyDocument } from '../types';

// ─── Exported Types ───────────────────────────────────────────────────────────

export interface SubMetrics {
  cycleMonthly: number;
  cycleYearly: number;
  monthlyCount: number;
  yearlyCount: number;
}

export interface GlobalSearchResults {
  companies: (Company & { companyName?: string; companyColor?: string })[];
  subscriptions: (Subscription & { companyName?: string; companyColor?: string })[];
  financials: { id: string; companyId: string; name: string; subtext: string; icon: string; companyName?: string; companyColor?: string }[];
  hasResults: boolean;
}

interface AppContextType {
  state: AppState | null;
  activeView: 'dashboard' | 'company';
  setActiveView: (view: 'dashboard' | 'company') => void;
  selectedCompanyId: string | null;
  setSelectedCompanyId: (id: string | null) => void;
  searchQuery: string;
  setSearchQuery: (q: string) => void;

  // Company
  handleAddCompany: (newCompany: Omit<Company, 'id'>) => string | void;
  handleUpdateCompany: (id: string, updates: Partial<Company>) => void;
  handleDeleteCompany: (id?: string) => void;

  // Subscriptions
  handleAddSubscription: (sub: Partial<Subscription>) => void;
  handleUpdateSubscription: (id: string, updates: Partial<Subscription>) => void;
  handleDeleteSubscription: (id: string) => void;

  // Financial Cards
  handleAddFinancialCard: (card: Partial<FinancialCard>) => void;
  handleUpdateFinancialCard: (id: string, updates: Partial<FinancialCard>) => void;
  handleDeleteFinancialCard: (id: string) => void;

  // Institutions
  handleAddInstitution: (inst: Partial<Institution>) => void;
  handleUpdateInstitution: (id: string, updates: Partial<Institution>) => void;
  handleDeleteInstitution: (id: string) => void;

  // Loans
  handleAddLoan: (loan: Partial<Loan>) => void;
  handleUpdateLoan: (id: string, updates: Partial<Loan>) => void;
  handleDeleteLoan: (id: string) => void;

  // Documents
  handleAddCompanyDocument: (doc: Partial<CompanyDocument>) => void;
  handleUpdateCompanyDocument: (id: string, updates: Partial<CompanyDocument>) => void;
  handleDeleteCompanyDocument: (id: string) => void;

  // Computed
  totalMonthlyBurn: number;
  subMetrics: SubMetrics;
  globalEmails: string[];
  globalSearchResults: GlobalSearchResults | null;
  filteredCompanies: Company[];
  selectedCompany: Company | undefined;
}

const AppContext = createContext<AppContextType | undefined>(undefined);

export const AppProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [state, setState] = useState<AppState | null>(null);
  const [activeView, setActiveView] = useState<'dashboard' | 'company'>('dashboard');
  const [selectedCompanyId, setSelectedCompanyId] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');

  // ─── Initial Data Load ──────────────────────────────────────────────────────
  useEffect(() => {
    const initData = async () => {
      const data = await db.load();
      setState(data);
    };
    initData();
  }, []);

  // ─── Auto-save ──────────────────────────────────────────────────────────────
  useEffect(() => {
    if (state) {
      db.save(state);
    }
  }, [state]);

  // ─── Computed Values ────────────────────────────────────────────────────────

  const totalMonthlyBurn = useMemo(() => {
    if (!state) return 0;
    return state.subscriptions.reduce((sum, sub) => {
      const subServiceCost = (sub.subServices || []).reduce((acc: number, s: any) => acc + s.cost, 0);
      const monthlyFactor = sub.billingCycle === 'Monthly' ? 1 : 1 / 12;
      return sum + (sub.cost + subServiceCost) * monthlyFactor;
    }, 0);
  }, [state]);

  const subMetrics = useMemo((): SubMetrics => {
    if (!state || !selectedCompanyId) return { cycleMonthly: 0, cycleYearly: 0, monthlyCount: 0, yearlyCount: 0 };
    const companySubs = state.subscriptions.filter(s => s.companyId === selectedCompanyId);
    return companySubs.reduce((acc, s) => {
      if (s.billingCycle === 'Monthly') { acc.cycleMonthly += s.cost; acc.monthlyCount += 1; }
      else if (s.billingCycle === 'Yearly') { acc.cycleYearly += s.cost; acc.yearlyCount += 1; }
      s.subServices?.forEach(ss => {
        if (ss.status !== 'Paused') {
          if (ss.billingCycle === 'Monthly') { acc.cycleMonthly += ss.cost; acc.monthlyCount += 1; }
          else if (ss.billingCycle === 'Yearly') { acc.cycleYearly += ss.cost; acc.yearlyCount += 1; }
        }
      });
      return acc;
    }, { cycleMonthly: 0, cycleYearly: 0, monthlyCount: 0, yearlyCount: 0 });
  }, [state, selectedCompanyId]);

  const globalEmails = useMemo(() => {
    if (!state) return [];
    const emails = new Set<string>();
    state.accounts.forEach(a => { if (a.email?.trim()) emails.add(a.email.trim().toLowerCase()); });
    state.subscriptions.forEach(s => {
      s.linkedEmails?.forEach(e => { if (e.email?.trim()) emails.add(e.email.trim().toLowerCase()); });
    });
    (state.institutions || []).forEach(i => { if (i.email?.trim()) emails.add(i.email.trim().toLowerCase()); });
    return Array.from(emails);
  }, [state]);

  const globalSearchResults = useMemo((): GlobalSearchResults | null => {
    if (!searchQuery || !state) return null;
    const q = searchQuery.toLowerCase();
    const companies = state.companies.filter(c => c.name?.toLowerCase().includes(q));
    const subscriptions = state.subscriptions
      .filter(s => s.name?.toLowerCase().includes(q))
      .map(s => ({
        ...s,
        companyName: state.companies.find(c => c.id === s.companyId)?.name,
        companyColor: state.companies.find(c => c.id === s.companyId)?.color,
      }));
    const financials = [
      ...(state.institutions || []).filter(i => i.name?.toLowerCase().includes(q)).map(i => ({ id: i.id, companyId: i.companyId, name: i.name, subtext: 'Institution', icon: '🏦' })),
      ...state.financialCards.filter(c => c.name?.toLowerCase().includes(q) || c.institutionName?.toLowerCase().includes(q) || c.network?.toLowerCase().includes(q)).map(c => ({ id: c.id, companyId: c.companyId, name: c.name, subtext: `Card •••• ${c.last4}`, icon: '💳' })),
      ...state.loans.filter(l => l.name?.toLowerCase().includes(q) || l.lender?.toLowerCase().includes(q)).map(l => ({ id: l.id, companyId: l.companyId, name: l.name, subtext: `Loan • ${l.lender}`, icon: '📑' })),
    ].map(f => ({
      ...f,
      companyName: state.companies.find(c => c.id === f.companyId)?.name,
      companyColor: state.companies.find(c => c.id === f.companyId)?.color,
    }));
    return { companies, subscriptions, financials, hasResults: companies.length > 0 || subscriptions.length > 0 || financials.length > 0 };
  }, [searchQuery, state]);

  const filteredCompanies = useMemo(() => {
    if (!state) return [];
    if (!searchQuery) return state.companies;
    const q = searchQuery.toLowerCase();
    return state.companies.filter(c =>
      c.name?.toLowerCase().includes(q) ||
      c.structure?.toLowerCase().includes(q) ||
      c.description?.toLowerCase().includes(q)
    );
  }, [state, searchQuery]);

  const selectedCompany = state?.companies.find(c => c.id === selectedCompanyId);

  // ─── Company ────────────────────────────────────────────────────────────────

  const handleAddCompany = (newCompany: Omit<Company, 'id'>) => {
    const id = Math.random().toString(36).substr(2, 9);
    setState(prev => prev ? ({
      ...prev,
      companies: [...prev.companies, { ...newCompany, id, lastModified: Date.now(), lastViewed: Date.now() }]
    }) : null);
    return id;
  };

  const handleUpdateCompany = (id: string, updates: Partial<Company>) => {
    if (!state) return;
    setState(prev => prev ? ({
      ...prev,
      companies: prev.companies.map(c => c.id === id ? { ...c, ...updates, lastModified: updates.lastModified || Date.now() } : c)
    }) : null);
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
  };

  // ─── Subscriptions ──────────────────────────────────────────────────────────

  const handleAddSubscription = (subData: Partial<Subscription>) => {
    const companyId = subData.companyId || selectedCompanyId;
    if (!companyId || !state) return;
    const newSub: Subscription = {
      id: Math.random().toString(36).substr(2, 9),
      companyId,
      name: subData.name || 'New Tech Stack',
      cost: subData.cost || 0,
      currency: subData.currency || 'USD',
      billingCycle: subData.billingCycle || 'Monthly',
      paymentMethod: subData.paymentMethod || '',
      nextRenewal: subData.nextRenewal || new Date().toISOString().split('T')[0],
      renew: subData.renew || 'Auto',
      status: subData.status || 'Active',
      pricingModel: subData.pricingModel,
      website: subData.website || '',
      loginId: subData.loginId || '',
      password: subData.password || '',
      twoFactorAuth: subData.twoFactorAuth,
      recoveryMethod: subData.recoveryMethod || '',
      notes: subData.notes || '',
      linkedEmails: subData.linkedEmails || [],
      subServices: subData.subServices || [],
    };
    setState(prev => prev ? ({
      ...prev,
      companies: prev.companies.map(c => c.id === companyId ? { ...c, lastModified: Date.now() } : c),
      subscriptions: [...prev.subscriptions, newSub]
    }) : null);
  };

  const handleUpdateSubscription = (id: string, updates: Partial<Subscription>) => {
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

  // ─── Financial Cards (with bi-directional institution sync) ─────────────────

  const handleAddFinancialCard = (card: Partial<FinancialCard>) => {
    const companyId = card.companyId || selectedCompanyId;
    if (!companyId) return;
    const newCard: FinancialCard = {
      id: card.id || Math.random().toString(36).substr(2, 9),
      companyId,
      name: card.name || 'New Card',
      institutionName: card.institutionName,
      login: card.login || '',
      password: card.password || '',
      cardHolder: card.cardHolder || '',
      last4: card.last4 || '0000',
      expiry: card.expiry || '12/99',
      network: card.network || 'Visa',
      type: card.type || 'Credit',
      status: card.status || 'Active',
      limit: card.limit || 0,
      paidFrom: card.paidFrom || '',
      paidOn: card.paidOn || '',
      autopay: card.autopay || 'N/A',
    };
    setState(prev => prev ? ({
      ...prev,
      companies: prev.companies.map(c => c.id === companyId ? { ...c, lastModified: Date.now() } : c),
      financialCards: [...prev.financialCards, newCard]
    }) : null);
  };

  const handleUpdateFinancialCard = (id: string, updates: Partial<FinancialCard>) => {
    setState(prev => {
      if (!prev) return null;
      const card = prev.financialCards.find(c => c.id === id);

      // Bi-directional sync: update matching InstitutionAccount inside linked institutions
      const updatedInstitutions = (prev.institutions || []).map(inst => {
        if (!inst.accounts.some(a => a.id === id)) return inst;
        return {
          ...inst,
          accounts: inst.accounts.map(a => {
            if (a.id !== id) return a;
            return {
              ...a,
              name: updates.name !== undefined ? updates.name : a.name,
              last4: updates.last4 !== undefined ? updates.last4 : a.last4,
              expiry: updates.expiry !== undefined ? updates.expiry : a.expiry,
              cardHolder: updates.cardHolder !== undefined ? updates.cardHolder : a.cardHolder,
              network: updates.network !== undefined ? updates.network : a.network,
              // Map Credit/Debit back to institution account type
              type: updates.type === 'Credit'
                ? 'Credit Card'
                : updates.type === 'Debit'
                  ? (a.type === 'Debit (Linked)' || a.type === 'FSA' || a.type === 'HSA' ? a.type : 'Debit Card')
                  : a.type,
              status: updates.status !== undefined ? updates.status : a.status,
              limit: updates.limit !== undefined ? updates.limit : a.limit,
              paidFrom: updates.paidFrom !== undefined ? updates.paidFrom : (a as any).paidFrom,
              paidOn: updates.paidOn !== undefined ? updates.paidOn : (a as any).paidOn,
              autopay: updates.autopay !== undefined ? updates.autopay : (a as any).autopay,
            };
          })
        };
      });

      return {
        ...prev,
        companies: prev.companies.map(c => c.id === card?.companyId ? { ...c, lastModified: Date.now() } : c),
        financialCards: prev.financialCards.map(c => c.id === id ? { ...c, ...updates } : c),
        institutions: updatedInstitutions,
      };
    });
  };

  const handleDeleteFinancialCard = (id: string) => {
    setState(prev => {
      if (!prev) return null;
      const card = prev.financialCards.find(c => c.id === id);
      // Also remove from any institution's accounts array
      const updatedInstitutions = (prev.institutions || []).map(inst => ({
        ...inst,
        accounts: inst.accounts.filter(a => a.id !== id)
      }));
      return {
        ...prev,
        companies: prev.companies.map(c => c.id === card?.companyId ? { ...c, lastModified: Date.now() } : c),
        financialCards: prev.financialCards.filter(c => c.id !== id),
        institutions: updatedInstitutions,
      };
    });
  };

  // ─── Institutions ───────────────────────────────────────────────────────────

  const handleAddInstitution = (inst: Partial<Institution>) => {
    const companyId = inst.companyId || selectedCompanyId;
    if (!companyId) return;
    const newInst: Institution = {
      id: Math.random().toString(36).substr(2, 9),
      companyId,
      name: inst.name || 'New Bank',
      loginUrl: inst.loginUrl || '',
      email: inst.email || '',
      username: inst.username || '',
      password: inst.password || '',
      accounts: inst.accounts || [],
    };
    setState(prev => prev ? ({
      ...prev,
      companies: prev.companies.map(c => c.id === companyId ? { ...c, lastModified: Date.now() } : c),
      institutions: [...(prev.institutions || []), newInst]
    }) : null);
  };

  const handleUpdateInstitution = (id: string, updates: Partial<Institution>) => {
    setState(prev => {
      if (!prev) return null;
      const inst = (prev.institutions || []).find(i => i.id === id);
      return {
        ...prev,
        companies: prev.companies.map(c => c.id === inst?.companyId ? { ...c, lastModified: Date.now() } : c),
        institutions: (prev.institutions || []).map(i => i.id === id ? { ...i, ...updates } : i)
      };
    });
  };

  const handleDeleteInstitution = (id: string) => {
    setState(prev => {
      if (!prev) return null;
      const inst = (prev.institutions || []).find(i => i.id === id);
      if (!inst) return prev;
      // Cascade: delete all financial cards that were linked institution accounts
      const accountIds = inst.accounts.map(a => a.id);
      return {
        ...prev,
        companies: prev.companies.map(c => c.id === inst.companyId ? { ...c, lastModified: Date.now() } : c),
        financialCards: prev.financialCards.filter(c => !accountIds.includes(c.id)),
        institutions: (prev.institutions || []).filter(i => i.id !== id)
      };
    });
  };

  // ─── Loans ──────────────────────────────────────────────────────────────────

  const handleAddLoan = (loan: Partial<Loan>) => {
    const companyId = loan.companyId || selectedCompanyId;
    if (!companyId) return;
    const newLoan: Loan = {
      id: loan.id || Math.random().toString(36).substr(2, 9),
      companyId,
      role: loan.role || 'Lendee',
      lender: loan.lender || 'Bank',
      name: loan.name || 'New Loan',
      principalAmount: loan.principalAmount || 0,
      remainingBalance: loan.remainingBalance || 0,
      interestType: (loan as any).interestType || 'Percentage',
      interestRate: loan.interestRate || 0,
      term: loan.term || '',
      termYears: loan.termYears || 0,
      termMonths: loan.termMonths || 0,
      scheduleFrequency: loan.scheduleFrequency || 'Monthly',
      monthlyPayment: loan.monthlyPayment || 0,
      startDate: loan.startDate || new Date().toISOString().split('T')[0],
      maturityDate: loan.maturityDate,
      paidOffDate: loan.paidOffDate,
      status: loan.status || 'Active',
    };
    setState(prev => prev ? ({
      ...prev,
      companies: prev.companies.map(c => c.id === companyId ? { ...c, lastModified: Date.now() } : c),
      loans: [...prev.loans, newLoan]
    }) : null);
  };

  const handleUpdateLoan = (id: string, updates: Partial<Loan>) => {
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

  // ─── Documents ──────────────────────────────────────────────────────────────

  const handleAddCompanyDocument = (doc: Partial<CompanyDocument>) => {
    const companyId = doc.companyId || selectedCompanyId;
    if (!companyId) return;
    const newDoc: CompanyDocument = {
      id: Math.random().toString(36).substr(2, 9),
      companyId,
      name: doc.name || 'New Document',
      type: doc.type || 'Other',
      url: doc.url || '',
      uploadDate: doc.uploadDate || new Date().toISOString().split('T')[0],
      notes: doc.notes || '',
    };
    setState(prev => prev ? ({
      ...prev,
      companies: prev.companies.map(c => c.id === companyId ? { ...c, lastModified: Date.now() } : c),
      documents: [...(prev.documents || []), newDoc]
    }) : null);
  };

  const handleUpdateCompanyDocument = (id: string, updates: Partial<CompanyDocument>) => {
    setState(prev => {
      if (!prev) return null;
      const doc = (prev.documents || []).find(d => d.id === id);
      return {
        ...prev,
        companies: prev.companies.map(c => c.id === doc?.companyId ? { ...c, lastModified: Date.now() } : c),
        documents: (prev.documents || []).map(d => d.id === id ? { ...d, ...updates } : d)
      };
    });
  };

  const handleDeleteCompanyDocument = (id: string) => {
    setState(prev => {
      if (!prev) return null;
      const doc = (prev.documents || []).find(d => d.id === id);
      return {
        ...prev,
        companies: prev.companies.map(c => c.id === doc?.companyId ? { ...c, lastModified: Date.now() } : c),
        documents: (prev.documents || []).filter(d => d.id !== id)
      };
    });
  };

  // ─── Context Value ───────────────────────────────────────────────────────────

  const value: AppContextType = {
    state,
    activeView,
    setActiveView,
    selectedCompanyId,
    setSelectedCompanyId,
    searchQuery,
    setSearchQuery,
    handleAddCompany,
    handleUpdateCompany,
    handleDeleteCompany,
    handleAddSubscription,
    handleUpdateSubscription,
    handleDeleteSubscription,
    handleAddFinancialCard,
    handleUpdateFinancialCard,
    handleDeleteFinancialCard,
    handleAddInstitution,
    handleUpdateInstitution,
    handleDeleteInstitution,
    handleAddLoan,
    handleUpdateLoan,
    handleDeleteLoan,
    handleAddCompanyDocument,
    handleUpdateCompanyDocument,
    handleDeleteCompanyDocument,
    totalMonthlyBurn,
    subMetrics,
    globalEmails,
    globalSearchResults,
    filteredCompanies,
    selectedCompany,
  };

  return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
};

export const useAppContext = () => {
  const context = useContext(AppContext);
  if (context === undefined) {
    throw new Error('useAppContext must be used within an AppProvider');
  }
  return context;
};
