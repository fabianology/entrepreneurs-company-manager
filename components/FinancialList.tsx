
import React, { useState, useRef, useEffect } from 'react';
import { FinancialCard, Loan, Institution, InstitutionAccount } from '../types';
import { getFaviconUrl } from '../services/logoService';
import { jsPDF } from 'jspdf';

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
  const [expandedInstitutions, setExpandedInstitutions] = useState<Set<string>>(new Set());
  const [lastCopiedField, setLastCopiedField] = useState<{ id: string, field: 'username' | 'password' } | null>(null);
  const [confirmDeleteAccount, setConfirmDeleteAccount] = useState<number | null>(null);
  const [expandedAccounts, setExpandedAccounts] = useState<Set<number>>(new Set());
  const [showAmortizationTable, setShowAmortizationTable] = useState(false);
  const [expandedSchedules, setExpandedSchedules] = useState<Set<string>>(new Set());

  const toggleSchedule = (loanId: string, e: React.MouseEvent) => {
    e.stopPropagation();
    const newSet = new Set(expandedSchedules);
    if (newSet.has(loanId)) newSet.delete(loanId);
    else newSet.add(loanId);
    setExpandedSchedules(newSet);
  };

  const toggleAccountExpanded = (idx: number) => {
    const newSet = new Set(expandedAccounts);
    if (newSet.has(idx)) newSet.delete(idx);
    else newSet.add(idx);
    setExpandedAccounts(newSet);
  };

  const handleFieldCopy = (id: string, text: string, field: 'username' | 'password') => {
    if (!text || text === '-') return;
    navigator.clipboard.writeText(text);
    setLastCopiedField({ id, field });
    setTimeout(() => setLastCopiedField(null), 2000);
    if ('vibrate' in navigator) navigator.vibrate(30);
  };
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

  const toggleInstitutionExpanded = (id: string) => {
    const newSet = new Set(expandedInstitutions);
    if (newSet.has(id)) newSet.delete(id);
    else newSet.add(id);
    setExpandedInstitutions(newSet);
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
      // Clean up globally synced cards that were removed from the modal
      const originalInst = institutions.find(i => i.id === editingInstitution.id);
      if (originalInst) {
        const originalCardIds = originalInst.accounts
          .filter(a => ['Credit Card', 'Debit Card', 'Debit (Linked)', 'FSA', 'HSA'].includes(a.type))
          .map(a => a.id);
        const newCardIds = editingInstitution.accounts?.map(a => a.id) || [];
        
        const deletedCardIds = originalCardIds.filter(id => !newCardIds.includes(id));
        deletedCardIds.forEach(id => onDeleteCard(id));
      }

      // Auto-sync bank cards to global payment methods
      const instCards = editingInstitution.accounts?.filter(a => ['Credit Card', 'Debit Card', 'Debit (Linked)', 'FSA', 'HSA'].includes(a.type)) || [];
      instCards.forEach(acc => {
        const cardData: Partial<FinancialCard> = {
          id: acc.id,
          name: acc.name || `${editingInstitution.name} Card`,
          institutionName: editingInstitution.name || '',
          last4: acc.last4 || '',
          expiry: acc.expiry || '',
          type: acc.type === 'Credit Card' ? 'Credit' : 'Debit',
          status: (acc.status as any) || 'Active',
          limit: acc.limit || 0,
          paidFrom: acc.paidFrom || '',
          paidOn: acc.paidOn || '',
          autopay: acc.autopay || 'N/A'
        };
        const exists = cards.find(c => c.id === acc.id);
        if (exists) {
          onUpdateCard(acc.id, cardData);
        } else {
          onAddCard(cardData);
        }
      });

      if (editingInstitution.id) {
        onUpdateInstitution(editingInstitution.id, editingInstitution);
      } else {
        onAddInstitution(editingInstitution);
      }
      setEditingInstitution(null);
    }
  };

  const handleAddInstAccount = (defaultType: string = 'Checking') => {
    if (!editingInstitution) return;
    const newAcc: InstitutionAccount = {
      id: Math.random().toString(36).substr(2, 9),
      name: '',
      type: defaultType as any,
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
      role: 'Lendee',
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
    switch (network) {
      case 'Amex': return 'from-blue-600 to-cyan-500';
      case 'Mastercard': return 'from-slate-800 to-orange-900';
      case 'Visa': return 'from-indigo-700 to-purple-800';
      case 'Discover': return 'from-orange-500 to-amber-600';
      default: return 'from-slate-700 to-slate-900';
    }
  };

  const calcAmortization = (loan: Partial<Loan> | null = editingLoan) => {
    if (!loan) return null;
    const principal = loan.principalAmount || 0;
    const rate = loan.interestRate || 0;
    const isFixed = loan.interestType === 'Fixed';
    const totalMonths = (loan.termYears || 0) * 12 + (loan.termMonths || 0);
    const scheduleFrequency = loan.scheduleFrequency || 'Monthly';

    if (principal <= 0) return null;

    if (isFixed) {
      const totalCost = principal + rate;
      const principalPct = totalCost > 0 ? (principal / totalCost) * 100 : 0;
      const interestPct = totalCost > 0 ? (rate / totalCost) * 100 : 0;
      return { 
        monthlyPayment: 0, 
        totalInterest: rate, 
        totalCost, 
        totalPrincipal: principal, 
        principalPct, 
        interestPct, 
        schedule: [], 
        scheduleFrequency 
      };
    }

    if (totalMonths <= 0) return null;

    let schedule = [];
    let payment = 0;
    let totalInterest = 0;

    let totalPeriods = totalMonths; // Monthly default
    let periodsPerYear = 12;
    if (scheduleFrequency === 'Weekly') {
       totalPeriods = Math.round((totalMonths / 12) * 52);
       periodsPerYear = 52;
    } else if (scheduleFrequency === 'Yearly') {
       totalPeriods = Math.ceil(totalMonths / 12);
       periodsPerYear = 1;
    }

    if (totalPeriods <= 0) return null;

    const perPeriodRate = (rate / 100) / periodsPerYear;
    if (perPeriodRate <= 0) {
      payment = principal / totalPeriods;
      let balance = principal;
      for (let i = 1; i <= totalPeriods; i++) {
        balance -= payment;
        schedule.push({ month: i, payment: payment, principal: payment, interest: 0, balance: Math.max(0, balance) });
      }
    } else {
      payment = principal * (perPeriodRate * Math.pow(1 + perPeriodRate, totalPeriods)) / (Math.pow(1 + perPeriodRate, totalPeriods) - 1);
      let balance = principal;
      for (let i = 1; i <= totalPeriods; i++) {
        const interest = balance * perPeriodRate;
        const principalPayment = payment - interest;
        balance -= principalPayment;
        totalInterest += interest;
        schedule.push({ month: i, payment: payment, principal: principalPayment, interest: interest, balance: Math.max(0, balance) });
      }
    }

    if (schedule.length > 5000) {
      // Prevent browser freeze for very long daily scheduled loans
      schedule = schedule.slice(0, 5000);
    }

    const totalCost = principal + totalInterest;
    const principalPct = totalCost > 0 ? (principal / totalCost) * 100 : 0;
    const interestPct = totalCost > 0 ? (totalInterest / totalCost) * 100 : 0;

    return { monthlyPayment: payment, totalInterest, totalCost, totalPrincipal: principal, principalPct, interestPct, schedule, scheduleFrequency };
  };

  const generatePromissoryNote = (loan: Partial<Loan>) => {
    try {
    const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'letter' });
    const W = doc.internal.pageSize.getWidth();
    const margin = 20;
    const contentW = W - margin * 2;
    let y = margin;

    const fmt = (n: number) => '$' + n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    const amort = calcAmortization(loan);
    const totalMonths = (loan.termYears || 0) * 12 + (loan.termMonths || 0);
    let maturityDisplay = loan.maturityDate || '';
    if (!maturityDisplay && loan.startDate && totalMonths > 0) {
      const d = new Date(loan.startDate);
      d.setMonth(d.getMonth() + totalMonths);
      maturityDisplay = d.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });
    }

    // ── Header Bar ──
    doc.setFillColor(28, 28, 30);
    doc.rect(0, 0, W, 22, 'F');
    doc.setFontSize(7);
    doc.setTextColor(180, 180, 180);
    doc.setFont('helvetica', 'bold');
    doc.text('PROMISSORY NOTE', margin, 10);
    doc.setTextColor(235, 195, 81);
    doc.text('CONFIDENTIAL', W - margin, 10, { align: 'right' });
    doc.setTextColor(255, 255, 255);
    doc.setFontSize(14);
    doc.text(loan.name || 'Loan Agreement', W / 2, 16, { align: 'center' });
    y = 32;

    // ── Date line ──
    doc.setFontSize(8);
    doc.setTextColor(80, 80, 80);
    doc.setFont('helvetica', 'normal');
    doc.text(`Date: ${loan.startDate || new Date().toLocaleDateString()}`, margin, y);
    y += 10;

    // ── Parties section ──
    doc.setFillColor(245, 245, 247);
    doc.roundedRect(margin, y, contentW, 22, 3, 3, 'F');
    doc.setFontSize(7);
    doc.setTextColor(120, 120, 120);
    doc.setFont('helvetica', 'bold');
    doc.text('LENDER (Creditor)', margin + 4, y + 6);
    doc.text('BORROWER (Debtor)', W / 2 + 4, y + 6);
    doc.setFontSize(10);
    doc.setTextColor(20, 20, 20);
    doc.text('Lender / Creditor', margin + 4, y + 14);
    doc.text(loan.lender || '___________________', W / 2 + 4, y + 14);
    doc.setLineWidth(0.2);
    doc.setDrawColor(200, 200, 200);
    doc.line(W / 2, y + 2, W / 2, y + 20);
    y += 30;

    // ── Key Terms ──
    const drawRow = (label: string, value: string, xOffset = 0, yPos = y) => {
      doc.setFontSize(7);
      doc.setFont('helvetica', 'bold');
      doc.setTextColor(120, 120, 120);
      doc.text(label.toUpperCase(), margin + xOffset, yPos);
      doc.setFontSize(10);
      doc.setFont('helvetica', 'normal');
      doc.setTextColor(20, 20, 20);
      doc.text(value, margin + xOffset, yPos + 5);
    };

    // Row 1: Principal | Interest | Total
    drawRow('Principal Amount', fmt(loan.principalAmount || 0), 0, y);
    drawRow(loan.interestType === 'Fixed' ? 'Fixed Fee' : 'Interest Rate', loan.interestType === 'Fixed' ? fmt(loan.interestRate || 0) : `${loan.interestRate || 0}% APR`, contentW / 3, y);
    drawRow('Total Cost of Loan', fmt((loan.principalAmount || 0) + (amort?.totalInterest || 0)), (contentW / 3) * 2, y);
    y += 16;

    // Row 2: Term | Loan Date | Maturity
    const termStr = [loan.termYears ? `${loan.termYears} yr` : '', loan.termMonths ? `${loan.termMonths} mo` : ''].filter(Boolean).join(' ') || 'N/A';
    drawRow('Loan Term', termStr, 0, y);
    drawRow('Loan Date', loan.startDate || 'N/A', contentW / 3, y);
    drawRow('Maturity Date', maturityDisplay || 'N/A', (contentW / 3) * 2, y);
    y += 16;

    // Payment
    if (amort && amort.monthlyPayment > 0) {
      const freq = amort.scheduleFrequency || 'Monthly';
      drawRow(`${freq} Payment`, fmt(amort.monthlyPayment), 0, y);
      y += 16;
    }

    // Divider
    doc.setDrawColor(220, 220, 220);
    doc.setLineWidth(0.3);
    doc.line(margin, y, W - margin, y);
    y += 8;

    // ── Loan Summary ──
    if (loan.term) {
      doc.setFontSize(7);
      doc.setFont('helvetica', 'bold');
      doc.setTextColor(120, 120, 120);
      doc.text('LOAN SUMMARY / TERMS', margin, y);
      y += 5;
      doc.setFontSize(9);
      doc.setFont('helvetica', 'normal');
      doc.setTextColor(40, 40, 40);
      const lines = doc.splitTextToSize(loan.term, contentW);
      doc.text(lines, margin, y);
      y += lines.length * 5 + 6;
      doc.setDrawColor(220, 220, 220);
      doc.line(margin, y, W - margin, y);
      y += 8;
    }

    // ── Promise language ──
    doc.setFontSize(8.5);
    doc.setFont('helvetica', 'normal');
    doc.setTextColor(50, 50, 50);
    const promise = `FOR VALUE RECEIVED, the Borrower named above, promises to pay to the order of the Lender named above the principal sum of ${fmt(loan.principalAmount || 0)}${ loan.interestType === 'Fixed' ? `, plus a fixed fee of ${fmt(loan.interestRate || 0)}` : `, together with interest at the rate of ${loan.interestRate || 0}% per annum`}, in accordance with the terms set forth herein. This note shall be governed by the laws of the applicable jurisdiction. In the event of default, the entire remaining balance shall become immediately due and payable. The Borrower waives presentment, demand, protest, and notice of dishonor.`;
    const promiseLines = doc.splitTextToSize(promise, contentW);
    doc.text(promiseLines, margin, y);
    y += promiseLines.length * 5 + 10;

    // ── Amortization Schedule ──
    if (amort && amort.schedule.length > 0) {
      if (y > 200) { doc.addPage(); y = margin; }
      doc.setFontSize(7);
      doc.setFont('helvetica', 'bold');
      doc.setTextColor(120, 120, 120);
      doc.text('AMORTIZATION SCHEDULE', margin, y);
      y += 5;

      const colW = contentW / 5;
      const headers = ['Period', 'Payment', 'Principal', 'Interest', 'Balance'];
      doc.setFillColor(28, 28, 30);
      doc.rect(margin, y, contentW, 6, 'F');
      doc.setFontSize(6.5);
      doc.setTextColor(200, 200, 200);
      headers.forEach((h, i) => {
        const align = i === 0 ? 'left' : 'right';
        const x = i === 0 ? margin + 2 : margin + colW * i + colW - 2;
        doc.text(h, x, y + 4, { align });
      });
      y += 7;

      const rowsToShow = Math.min(amort.schedule.length, 120);
      amort.schedule.slice(0, rowsToShow).forEach((row, idx) => {
        if (y > 265) { doc.addPage(); y = margin; }
        if (idx % 2 === 0) {
          doc.setFillColor(248, 248, 250);
          doc.rect(margin, y - 1, contentW, 5.5, 'F');
        }
        doc.setFontSize(7);
        doc.setFont('helvetica', 'normal');
        doc.setTextColor(40, 40, 40);
        doc.text(String(row.month), margin + 2, y + 3);
        doc.text(fmt(row.payment), margin + colW * 2 - 2, y + 3, { align: 'right' });
        doc.text(fmt(row.principal), margin + colW * 3 - 2, y + 3, { align: 'right' });
        doc.text(fmt(row.interest), margin + colW * 4 - 2, y + 3, { align: 'right' });
        doc.text(fmt(row.balance), margin + contentW - 2, y + 3, { align: 'right' });
        y += 5.5;
      });
      if (amort.schedule.length > rowsToShow) {
        doc.setFontSize(7);
        doc.setTextColor(120, 120, 120);
        doc.text(`... ${amort.schedule.length - rowsToShow} more periods omitted`, margin, y + 4);
        y += 8;
      }
    }

    // ── Signature Block ──
    const sigY = Math.max(y + 10, 230);
    if (sigY > 250) { doc.addPage(); }
    const finalSigY = sigY > 250 ? margin + 20 : sigY;
    doc.setDrawColor(180, 180, 180);
    doc.setLineWidth(0.3);
    // Lender sig
    doc.line(margin, finalSigY + 14, margin + 70, finalSigY + 14);
    doc.setFontSize(7);
    doc.setFont('helvetica', 'bold');
    doc.setTextColor(100, 100, 100);
    doc.text('LENDER SIGNATURE', margin, finalSigY + 19);
    doc.text('Date: _______________', margin, finalSigY + 24);
    // Borrower sig
    doc.line(W - margin - 70, finalSigY + 14, W - margin, finalSigY + 14);
    doc.text('BORROWER SIGNATURE', W - margin - 70, finalSigY + 19);
    doc.text('Date: _______________', W - margin - 70, finalSigY + 24);

    // ── Footer ──
    doc.setFontSize(6.5);
    doc.setFont('helvetica', 'normal');
    doc.setTextColor(160, 160, 160);
    doc.text('This document is generated for informational purposes. Consult a legal professional before signing.', W / 2, 275, { align: 'center' });

    const filename = `Promissory_Note_${(loan.name || 'Loan').replace(/\s+/g, '_')}_${new Date().toISOString().slice(0,10)}.pdf`;
    doc.save(filename);
    } catch (err) {
      console.error('Promissory note generation failed:', err);
      alert('PDF generation failed: ' + (err instanceof Error ? err.message : String(err)));
    }
  };

  const amortizationData = editingLoan ? calcAmortization() : null;

  return (
    <div className="bg-black min-h-screen text-white p-4 space-y-12 animate-fadeIn">
      {/* Action Bar */}
      <div className="grid grid-cols-3 gap-3 pr-2">
        <button
          onClick={handleAddNewInstitution}
          className="bg-[#1C1C1E] text-white px-4 py-3.5 rounded-xl text-xs font-black uppercase tracking-widest hover:bg-[#2C2C2E] transition flex items-center justify-center space-x-2 border border-white/5 active:scale-95"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M12 4v16m8-8H4" /></svg>
          <span>Institution</span>
        </button>

        <button
          onClick={handleAddNewCard}
          className="bg-[#1C1C1E] text-white px-4 py-3.5 rounded-xl text-xs font-black uppercase tracking-widest hover:bg-[#2C2C2E] transition flex items-center justify-center space-x-2 border border-white/5 active:scale-95"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M12 4v16m8-8H4" /></svg>
          <span>Cards</span>
        </button>

        <button
          onClick={handleAddNewLoan}
          className="bg-[#1C1C1E] text-white px-4 py-3.5 rounded-xl text-xs font-black uppercase tracking-widest hover:bg-[#2C2C2E] transition flex items-center justify-center space-x-2 border border-white/5 active:scale-95"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M12 4v16m8-8H4" /></svg>
          <span>Loan</span>
        </button>
      </div>

      {/* --- PAYMENT METHODS --- */}
      <section className="space-y-6">
        <div className="flex justify-between items-center px-1">
          <div className="flex flex-col">
            <h3 className="text-lg font-black text-white/40">Payment Methods</h3>
          </div>
          {isWalletExpanded && (
            <button
              onClick={() => setIsWalletExpanded(false)}
              className="text-orange-500 text-[10px] font-black uppercase tracking-widest hover:text-orange-400 transition"
            >
              Collapse
            </button>
          )}
        </div>
        <div
          ref={walletContainerRef}
          className={`relative transition-all duration-700 ease-[cubic-bezier(0.16,1,0.3,1)] ${isWalletExpanded ? 'space-y-4' : 'h-[300px] overflow-hidden'} ${isDragging ? 'cursor-grabbing touch-none' : ''}`}
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
              className="w-full max-w-[400px] mx-auto h-[216px] rounded-[32px] border border-dashed border-white/20 flex flex-col items-center justify-center bg-[#1C1C1E]/50 hover:bg-[#1C1C1E] hover:border-[#EBC351]/50 transition-all duration-300 group shadow-2xl"
            >
              <div className="w-16 h-16 bg-white/5 rounded-full flex items-center justify-center mx-auto mb-4 group-hover:scale-110 transition-transform duration-300">
                <span className="text-2xl">💳</span>
              </div>
              <span className="text-[10px] font-black text-white/60 group-hover:text-white uppercase tracking-[0.2em] transition-colors">+ Add Your First Card</span>
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
                      w-full max-w-[400px] mx-auto h-56 rounded-2xl p-6 text-white shadow-2xl cursor-pointer bg-gradient-to-br 
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
        <div className="flex justify-between items-center px-1 border-t border-white/10 pt-8">
          <div className="flex flex-col">
            <h3 className="text-lg font-black text-white/40">Financial Institutions</h3>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {institutions.map(inst => {
            const totalBalance = inst.accounts.reduce((sum, acc) => sum + acc.balance, 0);
            return (
              <div
                key={inst.id}
                className="bg-[#1C1C1E] rounded-[24px] border border-white/5 shadow-2xl overflow-hidden flex flex-col hover:border-white/10 transition-colors"
              >
                <div className="p-6 border-b border-white/5">
                  <div className="flex justify-between items-start mb-6">
                    <div className="flex items-center space-x-3">
                      <div 
                        className="w-14 h-14 bg-white/5 flex items-center justify-center text-white overflow-hidden cursor-pointer p-1 -ml-1 rounded-2xl border border-white/10 hover:bg-white/10 hover:border-[#1FE400]/30 transition-all duration-300"
                        onClick={(e) => {
                          e.stopPropagation();
                          setEditingInstitution(inst);
                        }}
                      >
                        {inst.loginUrl ? (
                          <img
                            src={getFaviconUrl(inst.loginUrl) || ''}
                            className="w-8 h-8 object-contain"
                            alt=""
                            onError={(e) => {
                              (e.target as HTMLImageElement).style.display = 'none';
                              const fallback = (e.target as HTMLImageElement).nextElementSibling as HTMLElement;
                              if (fallback) fallback.style.display = 'flex';
                            }}
                          />
                        ) : null}
                        <svg
                          className="w-8 h-8 opacity-40 shrink-0"
                          fill="none"
                          stroke="currentColor"
                          viewBox="0 0 24 24"
                          style={{ display: inst.loginUrl ? 'none' : 'flex' }}
                        >
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                        </svg>
                      </div>
                      <div>
                        <h4 className="font-black text-white text-base">{inst.name}</h4>
                        {inst.loginUrl && (
                          <a href={inst.loginUrl} target="_blank" rel="noreferrer" className="text-[10px] text-white/40 hover:text-white/80 hover:underline flex items-center gap-1 font-black uppercase tracking-widest mt-1">
                            Launch Portal
                            <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" /></svg>
                          </a>
                        )}
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="text-xl font-black text-white">${totalBalance.toLocaleString()}</p>
                      <p className="text-[9px] font-black text-white/40 uppercase tracking-widest mt-1">Total Liquidity</p>
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-y-6 gap-x-8 pt-4 px-1">
                    <div
                      className="space-y-1 group/field cursor-pointer active:opacity-60 transition-opacity"
                      onClick={() => handleFieldCopy(inst.id, inst.username || inst.email || '', 'username')}
                    >
                      <div className="flex justify-between items-center">
                        <p className={`text-[9px] font-black uppercase tracking-widest transition-colors duration-300 ${lastCopiedField?.id === inst.id && lastCopiedField.field === 'username' ? 'text-orange-500' : 'text-white/40'}`}>
                          {lastCopiedField?.id === inst.id && lastCopiedField.field === 'username' ? 'Copied!' : 'Username / Email'}
                        </p>
                      </div>
                      <p className="text-xs font-black text-white truncate">{inst.username || inst.email || '-'}</p>
                    </div>

                    <div
                      className="space-y-1 group/pass cursor-pointer active:opacity-60 transition-opacity"
                      onClick={() => handleFieldCopy(inst.id, inst.password || '', 'password')}
                    >
                      <div className="flex justify-between items-center">
                        <p className={`text-[9px] font-black uppercase tracking-widest transition-colors duration-300 ${lastCopiedField?.id === inst.id && lastCopiedField.field === 'password' ? 'text-orange-500' : 'text-white/40'}`}>
                          {lastCopiedField?.id === inst.id && lastCopiedField.field === 'password' ? 'Copied!' : 'Password'}
                        </p>
                        <div className="flex space-x-2 opacity-0 group-hover/pass:opacity-100 transition-opacity">
                          <button onClick={(e) => { e.stopPropagation(); togglePassword(inst.id); }} className="text-[9px] font-black text-[#EBC351] uppercase">
                            {showPasswords.has(inst.id) ? 'Hide' : 'Show'}
                          </button>
                        </div>
                      </div>
                      <p className="text-xs font-black text-white font-mono tracking-wider truncate">
                        {showPasswords.has(inst.id) ? (inst.password || '-') : '••••••••'}
                      </p>
                    </div>
                  </div>
                </div>

                <div className="border-t border-white/5">
                  <button
                    onClick={() => toggleInstitutionExpanded(inst.id)}
                    className="w-full h-14 px-6 flex items-center justify-between text-[#EBC351] group hover:bg-white/[0.02] transition-colors"
                  >
                    <div className="flex items-center space-x-3">
                      <span className="text-[11px] font-black uppercase tracking-[0.15em]">Linked Accounts</span>
                      <div className="px-1.5 py-0.5 rounded bg-[#EBC351]/10 text-[9px] font-black">
                        {inst.accounts.length}
                      </div>
                    </div>
                    <div className="flex items-center space-x-4">
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          setEditingInstitution(inst);
                        }}
                        className="text-[9px] font-black text-[#EBC351] uppercase hover:text-white transition"
                      >
                        Manage
                      </button>
                      <svg
                        className={`w-4 h-4 transform transition-transform duration-500 ease-[cubic-bezier(0.16,1,0.3,1)] ${expandedInstitutions.has(inst.id) ? 'rotate-180' : ''}`}
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M19 9l-7 7-7-7" />
                      </svg>
                    </div>
                  </button>

                  <div className={`grid transition-all duration-500 ease-[cubic-bezier(0.16,1,0.3,1)] ${expandedInstitutions.has(inst.id) ? 'grid-rows-[1fr] opacity-100' : 'grid-rows-[0fr] opacity-0'}`}>
                    <div className="overflow-hidden">
                      <div className="p-6 pt-0 space-y-2">
                        {inst.accounts.map((acc, aIdx) => (
                          <div key={acc.id || aIdx} className="flex justify-between items-center py-3 px-1 border-b border-white/5 last:border-0 hover:bg-white/[0.02] transition cursor-default">
                            <div className="flex items-center space-x-3">
                              <span className={`w-2 h-2 rounded-full ${acc.type === 'Checking' ? 'bg-[#EBC351]' : acc.type === 'Credit Card' ? 'bg-orange-500' : 'bg-blue-400'}`}></span>
                              <div>
                                <p className="text-xs font-black text-white truncate max-w-[120px]">{acc.name}</p>
                                <div className="flex items-center gap-1.5 mt-0.5">
                                  <span className="text-[9px] font-black text-white/40 font-mono tracking-widest">••{acc.last4}</span>
                                  <span className="text-[9px] font-black text-white/40 uppercase tracking-widest">• {acc.type}</span>
                                </div>
                              </div>
                            </div>
                            <div className="text-right">
                              <p className="text-xs font-black text-white tracking-widest">${acc.balance.toLocaleString()}</p>
                            </div>
                          </div>
                        ))}
                        {inst.accounts.length === 0 && <p className="text-[9px] font-black text-white/40 uppercase tracking-widest text-center py-4">No linked accounts</p>}
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            )
          })}
        </div>
      </section>

      {/* --- LOANS SECTION --- */}
      <section className="space-y-6">
        <div className="flex justify-between items-center border-t border-white/10 pt-8 px-1">
          <div className="flex flex-col">
            <h3 className="text-lg font-black text-white/40">Loans & Debt</h3>
          </div>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {loans.map(loan => {
            const amort = calcAmortization(loan);
            return (
            <div key={loan.id} onClick={() => setEditingLoan(loan)} className="bg-[#1C1C1E] rounded-[24px] border border-white/5 shadow-2xl flex flex-col overflow-hidden cursor-pointer hover:border-white/10 transition-colors">
              <div className="p-6 border-b border-white/5 flex-1">
                <div className="flex justify-between items-start mb-6">
                  <div className="flex items-center space-x-3">
                    <div>
                      <div className="flex items-center space-x-2 mb-1">
                        <h4 className="font-black text-white text-base">{loan.name}</h4>
                        {loan.role && (
                          <span className="text-[8px] font-black text-white/40 uppercase tracking-[0.2em] border border-white/10 px-2 py-0.5 rounded-full">{loan.role}</span>
                        )}
                      </div>
                      
                      <div className="flex items-center space-x-1.5 pt-1 uppercase font-black tracking-widest text-[10px]">
                        <span className="text-white/40">
                          {loan.role === 'Lender' ? 'Lent To: ' : ''}{loan.lender || 'Unknown'}
                        </span>
                        <span className="text-white/20">|</span>
                        <span className={(loan.paidOffDate || loan.status === 'Paid Off') ? 'text-emerald-500' : 'text-[#EBC351]'}>
                          {loan.paidOffDate ? 'Paid Off' : loan.status}
                        </span>
                      </div>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="text-xl font-black text-white">${(loan.principalAmount || 0).toLocaleString()}</p>
                    <p className="text-[9px] font-black text-white/40 uppercase tracking-widest mt-1">Loan Amount</p>
                  </div>
                </div>
                
                <div className="grid grid-cols-3 gap-y-6 gap-x-2 pt-2 px-1 mb-6">
                  <div>
                    <p className="text-[9px] font-black text-white/40 mb-1 uppercase tracking-widest">Loan Date</p>
                    <p className="text-[13px] font-black text-white">{loan.startDate || '—'}</p>
                  </div>
                  <div>
                    <p className="text-[9px] font-black text-white/40 mb-1 uppercase tracking-widest">{loan.interestType === 'Fixed' ? 'Fixed Fee' : 'Interest Paid'}</p>
                    <p className="text-sm font-black text-white">${(amort?.totalInterest || 0).toLocaleString(undefined, { maximumFractionDigits: 0 })}</p>
                  </div>
                  <div>
                    <p className="text-[9px] font-black text-white/40 mb-1 uppercase tracking-widest">Total Amount</p>
                    <p className="text-sm font-black text-white">${((loan.principalAmount || 0) + (amort?.totalInterest || 0)).toLocaleString(undefined, { maximumFractionDigits: 0 })}</p>
                  </div>
                </div>

                {amort && (
                  <div className="space-y-2">
                    <div className="flex justify-between text-[8px] font-black uppercase tracking-widest">
                      <span className="text-[#EBC351]">Principal ${amort.totalPrincipal.toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 2 })}</span>
                      <span className="text-orange-500">{loan.interestType === 'Fixed' ? 'Fee' : 'Interest'} ${amort.totalInterest.toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 2 })}</span>
                    </div>
                    <div className="h-1.5 w-full bg-white/5 rounded-full overflow-hidden flex shadow-inner">
                      <div className="h-full bg-[#EBC351] transition-all" style={{ width: `${amort.principalPct}%` }}></div>
                      <div className="h-full bg-orange-500 transition-all" style={{ width: `${amort.interestPct}%` }}></div>
                    </div>
                  </div>
                )}
              </div>


            </div>
          )})}
        </div>
      </section>

      {/* --- EDIT INSTITUTION MODAL --- */}
      {editingInstitution && (
        <div className="fixed inset-x-0 z-[100] flex items-start justify-center p-4 bg-black/60 backdrop-blur-md animate-fadeIn overflow-y-auto" style={{ top: '20px', bottom: '160px' }}>
          <div className="bg-[#1C1C1E] rounded-3xl shadow-2xl w-full max-w-2xl overflow-hidden my-auto border border-white/10">
            <div className="px-6 py-3 border-b border-white/5 flex justify-between items-center">
              <h3 className="text-base font-black text-white tracking-wide">{editingInstitution.id ? 'Edit Bank' : 'Add Bank'}</h3>
              <button onClick={() => setEditingInstitution(null)} className="text-white/40 hover:text-white transition">
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" /></svg>
              </button>
            </div>
            <div className="p-6 space-y-8 max-h-[60dvh] overflow-y-auto custom-scrollbar">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="md:col-span-2">
                  <label className="block text-[9px] font-black text-white/40 uppercase tracking-widest mb-2">Bank / Institution Name</label>
                  <input className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-xl outline-none focus:border-[#EBC351] text-white text-sm font-bold transition-colors" value={editingInstitution.name || ''} placeholder="e.g. Mercury" onChange={e => setEditingInstitution({ ...editingInstitution, name: e.target.value })} />
                </div>
                <div>
                  <label className="block text-[9px] font-black text-white/40 uppercase tracking-widest mb-2">Login Email/User</label>
                  <input className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-xl outline-none focus:border-[#EBC351] text-white text-sm font-bold transition-colors" value={editingInstitution.username || ''} placeholder="user@example.com" onChange={e => setEditingInstitution({ ...editingInstitution, username: e.target.value })} />
                </div>
                <div>
                  <label className="block text-[9px] font-black text-white/40 uppercase tracking-widest mb-2">Password</label>
                  <input className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-xl outline-none focus:border-[#EBC351] text-white text-sm font-bold transition-colors" type="text" value={editingInstitution.password || ''} placeholder="••••••" onChange={e => setEditingInstitution({ ...editingInstitution, password: e.target.value })} />
                </div>
                <div className="md:col-span-2">
                  <label className="block text-[9px] font-black text-white/40 uppercase tracking-widest mb-2">Login Portal URL</label>
                  <input className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-xl outline-none focus:border-[#EBC351] text-white text-sm font-bold transition-colors" value={editingInstitution.loginUrl || ''} placeholder="https://bank.com/login" onChange={e => setEditingInstitution({ ...editingInstitution, loginUrl: e.target.value })} />
                </div>
              </div>

              <div className="border-t border-white/5 pt-8">
                <div className="mb-8">
                  <button onClick={() => handleAddInstAccount('Credit Card')} className="w-full bg-[#1C1C1E] border border-white/5 hover:border-[#EBC351]/50 p-4 rounded-2xl flex flex-col items-center justify-center gap-2 transition-all active:scale-95 group">
                    <span className="text-2xl group-hover:scale-110 transition-transform">💳</span>
                    <span className="text-[10px] font-black text-white/60 group-hover:text-white uppercase tracking-widest text-center">Add Card</span>
                  </button>

                  {/* Cards List */}
                  <div className="space-y-4 mt-6">
                    {(editingInstitution.accounts || []).map((acc, idx) => {
                      if (!['Credit Card', 'Debit Card', 'Debit (Linked)', 'FSA', 'HSA'].includes(acc.type)) return null;
                      return (
                        <div key={idx} className="bg-white/5 p-4 rounded-xl flex flex-col md:flex-row gap-4 items-start md:items-start border border-white/5">
                          <div className="flex-1 w-full space-y-4">
                            <div className="grid grid-cols-2 md:grid-cols-4 gap-4 w-full">
                              <div className="md:col-span-1">
                                <label className="block text-[8px] font-black text-white/40 uppercase tracking-widest mb-1">Card Nickname</label>
                                <input className="w-full px-3 py-2 bg-black/50 border border-white/10 rounded-lg outline-none focus:border-[#EBC351] text-white text-xs font-bold" placeholder="e.g. Chase Sapphire" value={acc.name} onChange={e => handleUpdateInstAccount(idx, { name: e.target.value })} />
                              </div>
                              <div className="md:col-span-1">
                                <label className="block text-[8px] font-black text-white/40 uppercase tracking-widest mb-1">Type</label>
                                <select className="w-full px-3 py-2 bg-black/50 border border-white/10 rounded-lg outline-none focus:border-[#EBC351] text-white text-xs font-bold" value={acc.type} onChange={e => handleUpdateInstAccount(idx, { type: e.target.value as any })}>
                                  <option value="Credit Card">Credit Card</option>
                                  <option value="Debit (Linked)">Debit (Linked)</option>
                                  <option value="FSA">FSA</option>
                                  <option value="HSA">HSA</option>
                                </select>
                              </div>
                              <div className="md:col-span-1">
                                <label className="block text-[8px] font-black text-white/40 uppercase tracking-widest mb-1">Last 4</label>
                                <input className="w-full px-3 py-2 bg-black/50 border border-white/10 rounded-lg outline-none focus:border-[#EBC351] text-white text-xs font-bold font-mono tracking-widest" placeholder="1234" value={acc.last4} maxLength={4} onChange={e => handleUpdateInstAccount(idx, { last4: e.target.value })} />
                              </div>
                              <div className="md:col-span-1">
                                <label className="block text-[8px] font-black text-white/40 uppercase tracking-widest mb-1">Autopay</label>
                                <select className="w-full px-3 py-2 bg-black/50 border border-white/10 rounded-lg outline-none focus:border-[#EBC351] text-white text-xs font-bold" value={acc.autopay || 'N/A'} onChange={e => handleUpdateInstAccount(idx, { autopay: e.target.value as any })}>
                                  <option value="Yes">Yes</option>
                                  <option value="No">No</option>
                                  <option value="N/A">N/A</option>
                                </select>
                              </div>
                            </div>
                            
                            {/* Toggle Button for Details */}
                            <div className="pt-3 border-t border-white/5 flex justify-center mt-2">
                              <button onClick={() => toggleAccountExpanded(idx)} className="text-[#EBC351] text-[9px] font-black uppercase flex items-center gap-1 hover:text-white transition-colors">
                                {expandedAccounts.has(idx) ? 'Minimize' : 'Expand Details'}
                                <svg className={`w-3 h-3 transform transition-transform ${expandedAccounts.has(idx) ? 'rotate-180' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M19 9l-7 7-7-7" /></svg>
                              </button>
                            </div>

                            {expandedAccounts.has(idx) && (
                              <div className="pt-4 border-t border-white/5 grid grid-cols-2 md:grid-cols-4 gap-4 w-full animate-fadeIn">
                              <div className="md:col-span-1">
                                <label className="block text-[8px] font-black text-white/40 uppercase tracking-widest mb-1">Card Holder</label>
                                <input className="w-full px-3 py-2 bg-black/50 border border-white/10 rounded-lg outline-none focus:border-[#EBC351] text-white text-xs font-bold" placeholder="NAME" value={acc.cardHolder || ''} onChange={e => handleUpdateInstAccount(idx, { cardHolder: e.target.value })} />
                              </div>
                              <div className="md:col-span-1">
                                <label className="block text-[8px] font-black text-white/40 uppercase tracking-widest mb-1">Network</label>
                                <select className="w-full px-3 py-2 bg-black/50 border border-white/10 rounded-lg outline-none focus:border-[#EBC351] text-white text-xs font-bold" value={acc.network || 'Visa'} onChange={e => handleUpdateInstAccount(idx, { network: e.target.value as any })}>
                                  <option value="Visa">Visa</option>
                                  <option value="Mastercard">Mastercard</option>
                                  <option value="Amex">Amex</option>
                                  <option value="Discover">Discover</option>
                                  <option value="Other">Other</option>
                                </select>
                              </div>
                              <div className="md:col-span-1">
                                <label className="block text-[8px] font-black text-white/40 uppercase tracking-widest mb-1">Expiry</label>
                                <input className="w-full px-3 py-2 bg-black/50 border border-white/10 rounded-lg outline-none focus:border-[#EBC351] text-white text-xs font-bold font-mono tracking-widest" placeholder="MM/YY" maxLength={5} value={acc.expiry || ''} onChange={e => handleUpdateInstAccount(idx, { expiry: e.target.value })} />
                              </div>
                              <div className="md:col-span-1">
                                <label className="block text-[8px] font-black text-white/40 uppercase tracking-widest mb-1">Status</label>
                                <select className="w-full px-3 py-2 bg-black/50 border border-white/10 rounded-lg outline-none focus:border-[#EBC351] text-white text-xs font-bold" value={acc.status || 'Active'} onChange={e => handleUpdateInstAccount(idx, { status: e.target.value as any })}>
                                  <option value="Active">Active</option>
                                  <option value="Frozen">Frozen</option>
                                  <option value="Expired">Expired</option>
                                </select>
                              </div>
                                <div className="md:col-span-2">
                                  <label className="block text-[8px] font-black text-white/40 uppercase tracking-widest mb-1">Paid From</label>
                                  <input className="w-full px-3 py-2 bg-black/50 border border-white/10 rounded-lg outline-none focus:border-[#EBC351] text-white text-xs font-bold" placeholder="e.g. Chase Checking" value={acc.paidFrom || ''} onChange={e => handleUpdateInstAccount(idx, { paidFrom: e.target.value })} />
                                </div>
                                <div className="md:col-span-2">
                                  <label className="block text-[8px] font-black text-white/40 uppercase tracking-widest mb-1">Paid On</label>
                                  <input className="w-full px-3 py-2 bg-black/50 border border-white/10 rounded-lg outline-none focus:border-[#EBC351] text-white text-xs font-bold" placeholder="e.g. 15th of Month" value={acc.paidOn || ''} onChange={e => handleUpdateInstAccount(idx, { paidOn: e.target.value })} />
                                </div>
                                {acc.type === 'Credit Card' ? (
                                  <>
                                    <div className="md:col-span-2">
                                      <label className="block text-[8px] font-black text-white/40 uppercase tracking-widest mb-1">Balance</label>
                                      <div className="relative flex items-center">
                                        <select className="absolute left-2 bg-transparent text-white/50 hover:text-white text-xs font-black outline-none cursor-pointer appearance-none z-10" value={acc.currency || 'USD'} onChange={e => handleUpdateInstAccount(idx, { currency: e.target.value })}>
                                          <option value="USD" className="bg-[#1C1C1E]">$</option>
                                          <option value="EUR" className="bg-[#1C1C1E]">€</option>
                                          <option value="GBP" className="bg-[#1C1C1E]">£</option>
                                          <option value="CAD" className="bg-[#1C1C1E]">C$</option>
                                        </select>
                                        <input className="w-full pl-8 px-3 py-2 bg-black/50 border border-white/10 rounded-lg outline-none focus:border-[#EBC351] text-white text-xs font-bold font-mono tracking-wider" type="number" placeholder="0.00" value={acc.balance} onChange={e => handleUpdateInstAccount(idx, { balance: parseFloat(e.target.value) })} />
                                      </div>
                                    </div>
                                    <div className="md:col-span-2">
                                      <label className="block text-[8px] font-black text-white/40 uppercase tracking-widest mb-1">Credit Limit</label>
                                      <div className="relative flex items-center">
                                        <select className="absolute left-2 bg-transparent text-white/50 hover:text-white text-xs font-black outline-none cursor-pointer appearance-none z-10" value={acc.currency || 'USD'} onChange={e => handleUpdateInstAccount(idx, { currency: e.target.value })}>
                                          <option value="USD" className="bg-[#1C1C1E]">$</option>
                                          <option value="EUR" className="bg-[#1C1C1E]">€</option>
                                          <option value="GBP" className="bg-[#1C1C1E]">£</option>
                                          <option value="CAD" className="bg-[#1C1C1E]">C$</option>
                                        </select>
                                        <input className="w-full pl-8 px-3 py-2 bg-black/50 border border-white/10 rounded-lg outline-none focus:border-[#EBC351] text-white text-xs font-bold font-mono tracking-wider" type="number" placeholder="Limit" value={acc.limit || ''} onChange={e => handleUpdateInstAccount(idx, { limit: parseFloat(e.target.value) })} />
                                      </div>
                                    </div>
                                  </>
                                ) : (
                                  <div className="md:col-span-2">
                                    <label className="block text-[8px] font-black text-white/40 uppercase tracking-widest mb-1">Balance</label>
                                    <div className="relative flex items-center">
                                      <select className="absolute left-2 bg-transparent text-white/50 hover:text-white text-xs font-black outline-none cursor-pointer appearance-none z-10" value={acc.currency || 'USD'} onChange={e => handleUpdateInstAccount(idx, { currency: e.target.value })}>
                                        <option value="USD" className="bg-[#1C1C1E]">$</option>
                                        <option value="EUR" className="bg-[#1C1C1E]">€</option>
                                        <option value="GBP" className="bg-[#1C1C1E]">£</option>
                                        <option value="CAD" className="bg-[#1C1C1E]">C$</option>
                                      </select>
                                      <input className="w-full pl-8 px-3 py-2 bg-black/50 border border-white/10 rounded-lg outline-none focus:border-[#EBC351] text-white text-xs font-bold font-mono tracking-wider" type="number" placeholder="0.00" value={acc.balance} onChange={e => handleUpdateInstAccount(idx, { balance: parseFloat(e.target.value) })} />
                                    </div>
                                  </div>
                                )}
                              </div>
                            )}
                          </div>
                          
                          <div className="flex w-full md:w-auto md:flex-col items-center justify-end md:self-start mt-2 md:mt-1 shrink-0 rounded-b-xl">
                            {confirmDeleteAccount === idx ? (
                              <div className="flex items-center justify-between w-full md:w-auto md:flex-col bg-orange-500/10 rounded-xl p-3 md:p-1.5 border border-orange-500/30 gap-3 md:gap-0">
                                <span className="text-[10px] md:text-[8px] font-black text-orange-500 uppercase md:mb-1 whitespace-nowrap">Confirm?</span>
                                <div className="flex gap-2 md:gap-1">
                                  <button onClick={() => { handleDeleteInstAccount(idx); setConfirmDeleteAccount(null); }} className="text-xs md:text-[9px] font-black text-white hover:text-orange-500 px-6 py-2 md:px-2 md:py-1 bg-black/40 hover:bg-black/80 rounded-lg md:rounded transition-colors active:scale-95">YES</button>
                                  <button onClick={() => setConfirmDeleteAccount(null)} className="text-xs md:text-[9px] font-black text-white/40 hover:text-white px-6 py-2 md:px-2 md:py-1 bg-black/40 hover:bg-black/80 rounded-lg md:rounded transition-colors active:scale-95">NO</button>
                                </div>
                              </div>
                            ) : (
                              <button onClick={() => setConfirmDeleteAccount(idx)} className="text-white/40 border border-white/10 hover:border-orange-500/50 hover:text-orange-500 bg-black/20 md:bg-transparent md:border-transparent p-3 md:p-2 transition rounded-xl w-full md:w-auto flex items-center justify-center gap-2 active:scale-95">
                                <svg className="w-5 h-5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                                <span className="md:hidden text-[10px] font-black uppercase tracking-widest">Remove Card</span>
                              </button>
                            )}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>

                <div className="mb-8 pt-4 border-t border-white/5">
                  <button onClick={() => handleAddInstAccount('Checking')} className="w-full bg-[#1C1C1E] border border-white/5 hover:border-[#EBC351]/50 p-4 rounded-2xl flex flex-col items-center justify-center gap-2 transition-all active:scale-95 group">
                    <span className="text-2xl group-hover:scale-110 transition-transform">🏦</span>
                    <span className="text-[10px] font-black text-white/60 group-hover:text-white uppercase tracking-widest text-center">Add Account</span>
                  </button>
                </div>


                <div className="space-y-4">
                  {(editingInstitution.accounts || []).map((acc, idx) => {
                    if (['Credit Card', 'Debit Card', 'Debit (Linked)', 'FSA', 'HSA'].includes(acc.type)) return null;
                    return (
                      <div key={idx} className="bg-white/5 p-4 rounded-xl flex flex-col md:flex-row gap-4 items-start md:items-start border border-white/5">
                        <div className="flex-1 w-full space-y-4">
                          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 w-full">
                            <div className="md:col-span-1">
                              <input className="w-full px-3 py-2 bg-black/50 border border-white/10 rounded-lg outline-none focus:border-[#EBC351] text-white text-xs font-bold" placeholder="Account Name" value={acc.name} onChange={e => handleUpdateInstAccount(idx, { name: e.target.value })} />
                            </div>
                            <div className="md:col-span-1">
                              <select className="w-full px-3 py-2 bg-black/50 border border-white/10 rounded-lg outline-none focus:border-[#EBC351] text-white text-xs font-bold" value={acc.type} onChange={e => handleUpdateInstAccount(idx, { type: e.target.value as any })}>
                                <option value="Checking">Checking</option>
                                <option value="Savings">Savings</option>
                                <option value="Investing">Investing</option>
                                <option value="401(k)">401(k)</option>
                                <option value="Roth 401(k)">Roth 401(k)</option>
                                <option value="IRA">IRA</option>
                                <option value="Roth IRA">Roth IRA</option>
                                <option value="Rollover IRA">Rollover IRA</option>
                                <option value="SEP IRA">SEP IRA</option>
                                <option value="529">529</option>
                                <option value="CD">CD</option>
                                <option value="Other">Other</option>
                              </select>
                            </div>
                            <div className="md:col-span-1">
                              <input className="w-full px-3 py-2 bg-black/50 border border-white/10 rounded-lg outline-none focus:border-[#EBC351] text-white text-xs font-bold font-mono tracking-widest" placeholder="Account Number" value={acc.last4} onChange={e => handleUpdateInstAccount(idx, { last4: e.target.value })} />
                            </div>
                            <div className="md:col-span-1 relative flex items-center">
                              <select className="absolute left-2 bg-transparent text-white/50 hover:text-white text-xs font-black outline-none cursor-pointer appearance-none z-10" value={acc.currency || 'USD'} onChange={e => handleUpdateInstAccount(idx, { currency: e.target.value })}>
                                <option value="USD" className="bg-[#1C1C1E]">$</option>
                                <option value="EUR" className="bg-[#1C1C1E]">€</option>
                                <option value="GBP" className="bg-[#1C1C1E]">£</option>
                                <option value="CAD" className="bg-[#1C1C1E]">C$</option>
                              </select>
                              <input className="w-full pl-8 px-3 py-2 bg-black/50 border border-white/10 rounded-lg outline-none focus:border-[#EBC351] text-white text-xs font-bold font-mono tracking-wider" type="number" placeholder="Balance" value={acc.balance} onChange={e => handleUpdateInstAccount(idx, { balance: parseFloat(e.target.value) })} />
                            </div>
                          </div>
                        </div>
                        
                        <div className="flex w-full md:w-auto md:flex-col items-center justify-end md:self-start mt-2 md:mt-1 shrink-0 rounded-b-xl">
                          {confirmDeleteAccount === idx ? (
                            <div className="flex items-center justify-between w-full md:w-auto md:flex-col bg-orange-500/10 rounded-xl p-3 md:p-1.5 border border-orange-500/30 gap-3 md:gap-0">
                              <span className="text-[10px] md:text-[8px] font-black text-orange-500 uppercase md:mb-1 whitespace-nowrap">Confirm?</span>
                              <div className="flex gap-2 md:gap-1">
                                <button onClick={() => { handleDeleteInstAccount(idx); setConfirmDeleteAccount(null); }} className="text-xs md:text-[9px] font-black text-white hover:text-orange-500 px-6 py-2 md:px-2 md:py-1 bg-black/40 hover:bg-black/80 rounded-lg md:rounded transition-colors active:scale-95">YES</button>
                                <button onClick={() => setConfirmDeleteAccount(null)} className="text-xs md:text-[9px] font-black text-white/40 hover:text-white px-6 py-2 md:px-2 md:py-1 bg-black/40 hover:bg-black/80 rounded-lg md:rounded transition-colors active:scale-95">NO</button>
                              </div>
                            </div>
                          ) : (
                            <button onClick={() => setConfirmDeleteAccount(idx)} className="text-white/40 border border-white/10 hover:border-orange-500/50 hover:text-orange-500 bg-black/20 md:bg-transparent md:border-transparent p-3 md:p-2 transition rounded-xl w-full md:w-auto flex items-center justify-center gap-2 active:scale-95">
                              <svg className="w-5 h-5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                              <span className="md:hidden text-[10px] font-black uppercase tracking-widest">Remove Account</span>
                            </button>
                          )}
                        </div>
                      </div>
                    );
                  })}

                </div>
              </div>
            </div>
            <div className="px-6 py-3 border-t border-white/5 flex justify-between items-center bg-black/20">
              {editingInstitution.id && (
                showDeleteConfirm ? (
                  <div className="flex items-center bg-orange-500/10 rounded-xl p-1.5 border border-orange-500/30 gap-3">
                    <span className="text-[10px] font-black text-orange-500 uppercase px-2">Confirm?</span>
                    <div className="flex gap-1">
                      <button onClick={() => { onDeleteInstitution(editingInstitution.id!); setEditingInstitution(null); setShowDeleteConfirm(false); }} className="text-[10px] font-black text-white hover:text-orange-500 px-4 py-2 bg-black/40 hover:bg-black/80 rounded-lg transition-colors">YES</button>
                      <button onClick={() => setShowDeleteConfirm(false)} className="text-[10px] font-black text-white/40 hover:text-white px-4 py-2 bg-black/40 hover:bg-black/80 rounded-lg transition-colors">NO</button>
                    </div>
                  </div>
                ) : (
                  <button onClick={() => setShowDeleteConfirm(true)} className="text-white/20 hover:text-orange-500 p-3 transition rounded-xl hover:bg-white/5 border border-transparent flex items-center justify-center">
                    <svg className="w-5 h-5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                  </button>
                )
              )}
              <div className="flex space-x-4 ml-auto">
                <button onClick={() => setEditingInstitution(null)} className="px-6 py-3 text-[11px] font-black text-white/40 uppercase tracking-widest hover:text-white transition">Cancel</button>
                <button onClick={handleSaveInstitution} className="px-8 py-3 bg-orange-500 rounded-2xl text-[11px] font-black text-white uppercase tracking-widest shadow-lg shadow-orange-500/20 hover:scale-[1.02] active:scale-95 transition">Save Bank</button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* --- EDIT CARD MODAL --- */}
      {editingCard && (
        <div className="fixed inset-x-0 z-[100] flex items-start justify-center p-4 bg-black/60 backdrop-blur-md animate-fadeIn overflow-y-auto" style={{ top: '20px', bottom: '160px' }}>
          <div className="bg-[#1C1C1E] rounded-3xl shadow-2xl w-full max-w-lg overflow-hidden my-auto border border-white/10">
            <div className="px-6 py-3 border-b border-white/5 flex justify-between items-center">
              <h3 className="text-base font-black text-white tracking-wide">
                {editingCard.id ? 'Edit Card Details' : 'Add New Card'}
              </h3>
              <button onClick={() => setEditingCard(null)} className="text-white/40 hover:text-white transition">
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" /></svg>
              </button>
            </div>

            <div className="p-6 space-y-6 overflow-y-auto max-h-[70vh]">
              <div>
                <label className="block text-[9px] font-black text-white/40 uppercase tracking-widest mb-2">Card Nickname</label>
                <input
                  className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-xl outline-none focus:border-[#EBC351] text-white text-sm font-bold transition-colors"
                  placeholder="e.g. Amex Gold - Advertising"
                  value={editingCard.name || ''}
                  onChange={e => setEditingCard({ ...editingCard, name: e.target.value })}
                />
              </div>

              <div className="grid grid-cols-2 gap-6">
                <div>
                  <label className="block text-[9px] font-black text-white/40 uppercase tracking-widest mb-2">Institution Name</label>
                  <input
                    className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-xl outline-none focus:border-[#EBC351] text-white text-sm font-bold transition-colors"
                    placeholder="e.g. Chase, Amex"
                    value={editingCard.institutionName || ''}
                    onChange={e => setEditingCard({ ...editingCard, institutionName: e.target.value })}
                  />
                </div>
                <div>
                  <label className="block text-[9px] font-black text-white/40 uppercase tracking-widest mb-2">Type</label>
                  <select
                    className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-xl outline-none focus:border-[#EBC351] text-white text-sm font-bold transition-colors"
                    value={editingCard.type || 'Credit'}
                    onChange={e => setEditingCard({ ...editingCard, type: e.target.value as any })}
                  >
                    <option value="Credit">Credit</option>
                    <option value="Debit">Debit</option>
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-6">
                <div>
                  <label className="block text-[9px] font-black text-white/40 uppercase tracking-widest mb-2">Login</label>
                  <input
                    className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-xl outline-none focus:border-[#EBC351] text-white text-sm font-bold transition-colors"
                    placeholder="username or email"
                    value={editingCard.login || ''}
                    onChange={e => setEditingCard({ ...editingCard, login: e.target.value })}
                  />
                </div>
                <div>
                  <label className="block text-[9px] font-black text-white/40 uppercase tracking-widest mb-2">Password</label>
                  <input
                    className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-xl outline-none focus:border-[#EBC351] text-white text-sm font-bold transition-colors"
                    type="password"
                    placeholder="••••••••"
                    value={editingCard.password || ''}
                    onChange={e => setEditingCard({ ...editingCard, password: e.target.value })}
                  />
                </div>
              </div>

              <div className="grid grid-cols-3 gap-6">
                <div className="col-span-2">
                  <label className="block text-[9px] font-black text-white/40 uppercase tracking-widest mb-2">Card Number (Last 4)</label>
                  <div className="relative">
                    <span className="absolute left-4 top-3.5 text-white/40 font-mono text-sm font-black tracking-widest">•••• •••• ••••</span>
                    <input
                      maxLength={4}
                      className="w-full pl-40 px-4 py-3 bg-white/5 border border-white/10 rounded-xl outline-none focus:border-[#EBC351] text-white text-sm font-bold font-mono tracking-widest transition-colors"
                      placeholder="1234"
                      value={editingCard.last4 || ''}
                      onChange={e => setEditingCard({ ...editingCard, last4: e.target.value.replace(/\D/g, '') })}
                    />
                  </div>
                </div>
                <div>
                  <label className="block text-[9px] font-black text-white/40 uppercase tracking-widest mb-2">Expiry</label>
                  <input
                    className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-xl outline-none focus:border-[#EBC351] text-white text-sm font-bold text-center font-mono tracking-widest transition-colors"
                    placeholder="MM/YY"
                    maxLength={5}
                    value={editingCard.expiry || ''}
                    onChange={e => setEditingCard({ ...editingCard, expiry: e.target.value })}
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-6">
                <div>
                  <label className="block text-[9px] font-black text-white/40 uppercase tracking-widest mb-2">Credit Limit / Balance</label>
                  <div className="relative">
                    <span className="absolute left-4 top-3.5 text-white/40 font-black">$</span>
                    <input
                      type="number"
                      className="w-full pl-8 px-4 py-3 bg-white/5 border border-white/10 rounded-xl outline-none focus:border-[#EBC351] text-white text-sm font-bold tracking-widest transition-colors"
                      value={editingCard.limit || ''}
                      onChange={e => setEditingCard({ ...editingCard, limit: parseFloat(e.target.value) })}
                    />
                  </div>
                </div>
                <div>
                  <label className="block text-[9px] font-black text-white/40 uppercase tracking-widest mb-2">Status</label>
                  <select
                    className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-xl outline-none focus:border-[#EBC351] text-white text-sm font-bold transition-colors"
                    value={editingCard.status || 'Active'}
                    onChange={e => setEditingCard({ ...editingCard, status: e.target.value as any })}
                  >
                    <option value="Active">Active</option>
                    <option value="Frozen">Frozen</option>
                    <option value="Expired">Expired</option>
                  </select>
                </div>
              </div>
            </div>

            <div className="px-6 py-3 border-t border-white/5 bg-black/20 flex items-center justify-between">
              <div>
                {editingCard.id && (
                  showDeleteConfirm ? (
                    <div className="flex items-center space-x-3">
                      <button
                        onClick={() => { onDeleteCard(editingCard.id!); setEditingCard(null); }}
                        className="bg-red-500/20 text-red-500 hover:bg-red-500 hover:text-white px-4 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest transition"
                      >
                        Confirm
                      </button>
                      <button
                        onClick={() => setShowDeleteConfirm(false)}
                        className="text-[10px] font-black text-white/40 hover:text-white uppercase tracking-widest transition"
                      >
                        Cancel
                      </button>
                    </div>
                  ) : (
                    <button
                      onClick={() => setShowDeleteConfirm(true)}
                      className="text-[10px] font-black text-white/20 hover:text-orange-500 uppercase tracking-widest transition"
                    >
                      Remove Card
                    </button>
                  )
                )}
              </div>
              <div className="flex space-x-4">
                <button
                  onClick={() => setEditingCard(null)}
                  className="px-6 py-3 text-[11px] font-black text-white/40 uppercase tracking-widest hover:text-white transition"
                >
                  Cancel
                </button>
                <button
                  onClick={handleSaveCardModal}
                  className="px-8 py-3 bg-orange-500 rounded-2xl text-[11px] font-black text-white uppercase tracking-widest shadow-lg shadow-orange-500/20 hover:scale-[1.02] active:scale-95 transition"
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
        <div className="fixed inset-x-0 z-[100] flex items-start justify-center p-4 bg-black/60 backdrop-blur-md animate-fadeIn overflow-y-auto" style={{ top: '20px', bottom: '160px' }}>
          <div className="bg-[#1C1C1E] rounded-3xl shadow-2xl w-full max-w-lg overflow-hidden my-auto border border-white/10">
            <div className="px-6 py-3 border-b border-white/5 flex justify-between items-center">
              <h3 className="text-base font-black text-white tracking-wide">
                {editingLoan.id ? 'Edit Loan Details' : 'Add New Financing'}
              </h3>
              <button onClick={() => setEditingLoan(null)} className="text-white/40 hover:text-white transition">
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" /></svg>
              </button>
            </div>

            <div className="p-6 space-y-6 overflow-y-auto max-h-[70vh]">
              <div className="flex justify-center pb-2">
                <div className={`flex bg-black/40 p-1 rounded-full border border-white/5 min-w-[200px] ${editingLoan.id ? 'pointer-events-none' : ''}`}>
                  {(!editingLoan.id || editingLoan.role === 'Lender') && (
                    <button
                      onClick={() => setEditingLoan({ ...editingLoan, role: 'Lender' })}
                      className={`py-2 rounded-full text-[10px] font-black uppercase tracking-widest transition-all shadow-sm flex-1 text-center ${editingLoan.role === 'Lender' ? 'bg-[#EBC351] text-black shadow-lg shadow-[#EBC351]/20' : 'text-white/40 hover:text-white'} ${!editingLoan.id ? 'px-6' : ''}`}
                    >
                      Lender
                    </button>
                  )}
                  {(!editingLoan.id || editingLoan.role === 'Lendee' || !editingLoan.role) && (
                    <button
                      onClick={() => setEditingLoan({ ...editingLoan, role: 'Lendee' })}
                      className={`py-2 rounded-full text-[10px] font-black uppercase tracking-widest transition-all shadow-sm flex-1 text-center ${editingLoan.role === 'Lendee' || !editingLoan.role ? 'bg-[#EBC351] text-black shadow-lg shadow-[#EBC351]/20' : 'text-white/40 hover:text-white'} ${!editingLoan.id ? 'px-6' : ''}`}
                    >
                      Lendee
                    </button>
                  )}
                </div>
              </div>

              {editingLoan.role === 'Lender' ? (
                <>
                  <div className="grid grid-cols-2 gap-6">
                    <div>
                      <label className="block text-[9px] font-black text-white/40 uppercase tracking-widest mb-2">Lent To</label>
                      <input
                        className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-xl outline-none focus:border-[#EBC351] text-white text-sm font-bold transition-colors"
                        placeholder="e.g. Acme Corp"
                        value={editingLoan.lender || ''}
                        onChange={e => setEditingLoan({ ...editingLoan, lender: e.target.value })}
                      />
                    </div>
                    <div>
                      <label className="block text-[9px] font-black text-white/40 uppercase tracking-widest mb-2">Loan Name</label>
                      <input
                        className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-xl outline-none focus:border-[#EBC351] text-white text-sm font-bold transition-colors"
                        placeholder="e.g. Bridge Loan"
                        value={editingLoan.name || ''}
                        onChange={e => setEditingLoan({ ...editingLoan, name: e.target.value })}
                      />
                    </div>
                  </div>
                  <div>
                    <label className="block text-[9px] font-black text-white/40 uppercase tracking-widest mb-2">Loan Summary</label>
                    <textarea
                      rows={2}
                      style={{
                        backgroundImage: 'linear-gradient(to bottom, transparent 31px, rgba(255,255,255,0.1) 31px, rgba(255,255,255,0.1) 32px, transparent 32px, transparent 51px, rgba(255,255,255,0.1) 51px, rgba(255,255,255,0.1) 52px, transparent 52px)',
                        backgroundAttachment: 'local',
                        lineHeight: '20px'
                      }}
                      className="w-full py-3 bg-transparent border-none outline-none focus:ring-0 text-white text-sm font-bold transition-colors resize-none custom-scrollbar"
                      placeholder="e.g. 36 Months summary..."
                      value={editingLoan.term || ''}
                      onChange={e => setEditingLoan({ ...editingLoan, term: e.target.value })}
                    />
                  </div>
                </>
              ) : (
                <>
                  <div className="grid grid-cols-2 gap-6">
                    <div>
                      <label className="block text-[9px] font-black text-white/40 uppercase tracking-widest mb-2">Lender / Institution</label>
                      <input
                        className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-xl outline-none focus:border-[#EBC351] text-white text-sm font-bold transition-colors"
                        placeholder="e.g. Silicon Valley Bank"
                        value={editingLoan.lender || ''}
                        onChange={e => setEditingLoan({ ...editingLoan, lender: e.target.value })}
                      />
                    </div>
                    <div>
                      <label className="block text-[9px] font-black text-white/40 uppercase tracking-widest mb-2">Loan ID</label>
                      <input
                        className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-xl outline-none focus:border-[#EBC351] text-white text-sm font-bold transition-colors"
                        placeholder="e.g. Series A Venture Debt"
                        value={editingLoan.name || ''}
                        onChange={e => setEditingLoan({ ...editingLoan, name: e.target.value })}
                      />
                    </div>
                  </div>
                  <div>
                    <label className="block text-[9px] font-black text-white/40 uppercase tracking-widest mb-2">Loan Summary</label>
                    <textarea
                      rows={2}
                      style={{
                        backgroundImage: 'linear-gradient(to bottom, transparent 31px, rgba(255,255,255,0.1) 31px, rgba(255,255,255,0.1) 32px, transparent 32px, transparent 51px, rgba(255,255,255,0.1) 51px, rgba(255,255,255,0.1) 52px, transparent 52px)',
                        backgroundAttachment: 'local',
                        lineHeight: '20px'
                      }}
                      className="w-full py-3 bg-transparent border-none outline-none focus:ring-0 text-white text-sm font-bold transition-colors resize-none custom-scrollbar"
                      placeholder="e.g. 36 Months summary..."
                      value={editingLoan.term || ''}
                      onChange={e => setEditingLoan({ ...editingLoan, term: e.target.value })}
                    />
                  </div>
                </>
              )}

              <div className="grid grid-cols-2 gap-6 pb-6">
                <div>
                  <label className="block text-[9px] font-black text-white/40 uppercase tracking-widest mb-2">Loan Date</label>
                  <input
                    type="date"
                    className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-xl outline-none focus:border-[#EBC351] text-white text-sm font-bold transition-colors [color-scheme:dark]"
                    value={editingLoan.startDate || ''}
                    onChange={e => {
                      const newStart = e.target.value;
                      const totalMonths = (editingLoan.termYears || 0) * 12 + (editingLoan.termMonths || 0);
                      let newMaturity = editingLoan.maturityDate;
                      if (newStart && totalMonths > 0) {
                        const d = new Date(newStart);
                        d.setMonth(d.getMonth() + totalMonths);
                        newMaturity = d.toISOString().split('T')[0];
                      }
                      setEditingLoan({ ...editingLoan, startDate: newStart, maturityDate: newMaturity });
                    }}
                  />
                </div>
                <div>
                  <label className="block text-[9px] font-black text-white/40 uppercase tracking-widest mb-2">Maturity Date</label>
                  <input
                    type="date"
                    className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-xl outline-none focus:border-[#EBC351] text-white text-sm font-bold transition-colors [color-scheme:dark]"
                    value={(() => {
                      const totalMonths = (editingLoan.termYears || 0) * 12 + (editingLoan.termMonths || 0);
                      if (editingLoan.startDate && totalMonths > 0) {
                        const d = new Date(editingLoan.startDate);
                        d.setMonth(d.getMonth() + totalMonths);
                        return d.toISOString().split('T')[0];
                      }
                      return editingLoan.maturityDate || '';
                    })()}
                    onChange={e => {
                      const matDate = e.target.value;
                      if (editingLoan.startDate && matDate) {
                        const start = new Date(editingLoan.startDate);
                        const end = new Date(matDate);
                        let months = (end.getFullYear() - start.getFullYear()) * 12 + (end.getMonth() - start.getMonth());
                        if (months < 0) months = 0;
                        const yrs = Math.floor(months / 12);
                        const mos = months % 12;
                        setEditingLoan({ ...editingLoan, maturityDate: matDate, termYears: yrs, termMonths: mos });
                      } else {
                        setEditingLoan({ ...editingLoan, maturityDate: matDate });
                      }
                    }}
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-6">
                <div>
                  <label className="block text-[9px] font-black text-white/40 uppercase tracking-widest mb-2">Loan Amount</label>
                  <div className="relative">
                    <span className="absolute left-4 top-3.5 text-white/40 font-black">$</span>
                    <input
                      type="number"
                      className="w-full pl-8 px-4 py-3 bg-white/5 border border-white/10 rounded-xl outline-none focus:border-[#EBC351] text-white text-sm font-bold tracking-widest transition-colors"
                      value={editingLoan.principalAmount || ''}
                      onChange={e => setEditingLoan({ ...editingLoan, principalAmount: parseFloat(e.target.value) })}
                    />
                  </div>
                </div>
                {editingLoan.role !== 'Lender' ? (
                  <div>
                    <label className="block text-[9px] font-black text-white/40 uppercase tracking-widest mb-2">Paid Off</label>
                    <input
                      type="date"
                      className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-xl outline-none focus:border-[#EBC351] text-white text-sm font-bold transition-colors [color-scheme:dark]"
                      value={editingLoan.paidOffDate || ''}
                      onChange={e => setEditingLoan({ ...editingLoan, paidOffDate: e.target.value })}
                    />
                  </div>
                ) : (
                  <div>
                    <label className="block text-[9px] font-black text-white/40 uppercase tracking-widest mb-2">Interest Type</label>
                    <div className="flex bg-black/40 p-1 rounded-full border border-white/5 h-[42px] items-center">
                      <button
                        onClick={() => setEditingLoan({ ...editingLoan, interestType: 'Percentage' })}
                        className={`flex-1 h-full rounded-full text-[10px] font-black uppercase tracking-widest transition-all shadow-sm ${(!editingLoan.interestType || editingLoan.interestType === 'Percentage') ? 'bg-[#EBC351] text-black shadow-lg shadow-[#EBC351]/20' : 'text-white/40 hover:text-white'}`}
                      >
                        Interest
                      </button>
                      <button
                        onClick={() => setEditingLoan({ ...editingLoan, interestType: 'Fixed' })}
                        className={`flex-1 h-full rounded-full text-[10px] font-black uppercase tracking-widest transition-all shadow-sm ${editingLoan.interestType === 'Fixed' ? 'bg-[#EBC351] text-black shadow-lg shadow-[#EBC351]/20' : 'text-white/40 hover:text-white'}`}
                      >
                        Fixed
                      </button>
                    </div>
                  </div>
                )}
              </div>

              <div className="grid grid-cols-2 gap-6">
                <div>
                  <label className="block text-[9px] font-black text-white/40 uppercase tracking-widest mb-2">Loan Term</label>
                  <div className="flex space-x-2">
                    <select 
                      className="flex-1 w-full px-4 py-3 bg-black/50 border border-white/10 rounded-xl outline-none focus:border-[#EBC351] text-white text-sm font-bold transition-colors appearance-none"
                      value={editingLoan.termYears || 0}
                      onChange={e => {
                        const yrs = parseInt(e.target.value);
                        const mos = editingLoan.termMonths || 0;
                        const totalMonths = yrs * 12 + mos;
                        let newMaturity = editingLoan.maturityDate;
                        if (editingLoan.startDate && totalMonths > 0) {
                          const d = new Date(editingLoan.startDate);
                          d.setMonth(d.getMonth() + totalMonths);
                          newMaturity = d.toISOString().split('T')[0];
                        }
                        setEditingLoan({ ...editingLoan, termYears: yrs, maturityDate: newMaturity });
                      }}
                    >
                      <option value={0} className="bg-[#1C1C1E]">0 Years</option>
                      {[...Array(30)].map((_, i) => (
                         <option key={i+1} value={i+1} className="bg-[#1C1C1E]">{i+1} Years</option>
                      ))}
                    </select>
                    <select 
                      className="flex-1 w-full px-4 py-3 bg-black/50 border border-white/10 rounded-xl outline-none focus:border-[#EBC351] text-white text-sm font-bold transition-colors appearance-none"
                      value={editingLoan.termMonths || 0}
                      onChange={e => {
                        const mos = parseInt(e.target.value);
                        const yrs = editingLoan.termYears || 0;
                        const totalMonths = yrs * 12 + mos;
                        let newMaturity = editingLoan.maturityDate;
                        if (editingLoan.startDate && totalMonths > 0) {
                          const d = new Date(editingLoan.startDate);
                          d.setMonth(d.getMonth() + totalMonths);
                          newMaturity = d.toISOString().split('T')[0];
                        }
                        setEditingLoan({ ...editingLoan, termMonths: mos, maturityDate: newMaturity });
                      }}
                    >
                      <option value={0} className="bg-[#1C1C1E]">0 Months</option>
                      {[...Array(11)].map((_, i) => (
                         <option key={i+1} value={i+1} className="bg-[#1C1C1E]">{i+1} Months</option>
                      ))}
                    </select>
                  </div>
                </div>
                <div>
                  <label className="block text-[9px] font-black text-white/40 uppercase tracking-widest mb-2">
                    {editingLoan.interestType === 'Fixed' ? 'Fixed' : 'APR'}
                  </label>
                  <div className="flex space-x-2">
                    <div className="relative flex-1">
                      {editingLoan.interestType === 'Fixed' && <span className="absolute left-4 top-3.5 text-white/40 font-black">$</span>}
                      <input
                        type="number"
                        step={editingLoan.interestType === 'Fixed' ? "1" : "0.1"}
                        className={`w-full ${editingLoan.interestType === 'Fixed' ? 'pl-8' : ''} px-4 py-3 bg-white/5 border border-white/10 rounded-xl outline-none focus:border-[#EBC351] text-white text-sm font-bold transition-colors`}
                        value={editingLoan.interestRate || ''}
                        placeholder={editingLoan.interestType === 'Fixed' ? "e.g. 500" : "e.g. 5.5"}
                        onChange={e => setEditingLoan({ ...editingLoan, interestRate: e.target.value ? parseFloat(e.target.value) : 0 })}
                      />
                    </div>
                    {editingLoan.interestType !== 'Fixed' && (
                      <select
                        className="flex-1 px-4 py-3 bg-black/50 border border-white/10 rounded-xl outline-none focus:border-[#EBC351] text-white text-sm font-bold transition-colors appearance-none"
                        value={editingLoan.scheduleFrequency || 'Monthly'}
                        onChange={e => setEditingLoan({ ...editingLoan, scheduleFrequency: e.target.value as any })}
                      >
                        <option value="Weekly">Weekly</option>
                        <option value="Monthly">Monthly</option>
                        <option value="Yearly">Yearly</option>
                      </select>
                    )}
                  </div>
                </div>
              </div>

              {editingLoan.role === 'Lender' && (
                <div className="pt-2">
                  <button
                    onClick={(e) => { e.stopPropagation(); generatePromissoryNote(editingLoan); }}
                    className="w-full py-3 bg-white/5 border border-white/10 rounded-xl text-[10px] font-black text-white/70 uppercase tracking-widest hover:bg-white/10 hover:text-white active:scale-95 transition flex items-center justify-center gap-2"
                  >
                    <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" /></svg>
                    Generate Promissory Note
                  </button>
                </div>
              )}



              {amortizationData && (
                <div className="pt-6 mt-6 border-t border-white/5 space-y-6 animate-fadeIn">
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-[9px] font-black text-white/40 uppercase tracking-widest mb-1">
                        {amortizationData.scheduleFrequency === 'Weekly' ? 'Weekly' : amortizationData.scheduleFrequency === 'Yearly' ? 'Yearly' : 'Monthly'} Payment
                      </p>
                      <p className="text-xl font-black text-white">${amortizationData.monthlyPayment.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</p>
                    </div>
                    <div className="text-right">
                      <p className="text-[9px] font-black text-white/40 uppercase tracking-widest mb-1">Total Cost of Loan</p>
                      <p className="text-base font-black text-white">${amortizationData.totalCost.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</p>
                    </div>
                  </div>

                  <div className="space-y-2">
                    <div className="flex justify-between text-[9px] font-black uppercase tracking-widest">
                      <span className="text-[#EBC351]">Principal ({amortizationData.principalPct.toFixed(1)}%)</span>
                      <span className="text-orange-500">Interest ({amortizationData.interestPct.toFixed(1)}%)</span>
                    </div>
                    <div className="h-3 w-full bg-white/5 rounded-full overflow-hidden flex shadow-inner">
                      <div className="h-full bg-[#EBC351] transition-all duration-1000 ease-out" style={{ width: `${amortizationData.principalPct}%` }}></div>
                      <div className="h-full bg-orange-500 transition-all duration-1000 ease-out" style={{ width: `${amortizationData.interestPct}%` }}></div>
                    </div>
                    <div className="flex justify-between text-xs font-black">
                      <span className="text-white">${amortizationData.totalPrincipal.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                      <span className="text-white">${amortizationData.totalInterest.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                    </div>
                  </div>

                  <div className="pt-2">
                    <button
                      onClick={() => setShowAmortizationTable(!showAmortizationTable)}
                      className="w-full py-3 bg-white/5 hover:bg-white/10 rounded-xl text-[10px] font-black text-white uppercase tracking-widest transition flex items-center justify-center space-x-2 active:scale-95"
                    >
                      <span>{showAmortizationTable ? 'Hide Schedule' : 'Amortization Schedule'}</span>
                      <svg className={`w-4 h-4 transform transition-transform ${showAmortizationTable ? 'rotate-180' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 9l-7 7-7-7" /></svg>
                    </button>
                    
                    {showAmortizationTable && (
                      <div className="mt-4 border border-white/10 rounded-xl overflow-hidden animate-fadeIn">
                        <div className="max-h-[300px] overflow-y-auto custom-scrollbar bg-black/20">
                          <table className="w-full text-left text-xs text-white">
                            <thead className="bg-[#1C1C1E] sticky top-0 z-10 shadow-md">
                              <tr>
                                <th className="px-4 py-3 font-black text-[9px] uppercase tracking-widest text-white/40 border-b border-white/5">
                                  {amortizationData.scheduleFrequency === 'Weekly' ? 'Wk.' : amortizationData.scheduleFrequency === 'Yearly' ? 'Yr.' : 'Mo.'}
                                </th>
                                <th className="px-4 py-3 font-black text-[9px] uppercase tracking-widest text-white/40 border-b border-white/5 text-right">Payment</th>
                                <th className="px-4 py-3 font-black text-[9px] uppercase tracking-widest text-[#EBC351] border-b border-white/5 text-right">Principal</th>
                                <th className="px-4 py-3 font-black text-[9px] uppercase tracking-widest text-orange-500 border-b border-white/5 text-right">Interest</th>
                                <th className="px-4 py-3 font-black text-[9px] uppercase tracking-widest text-white/40 border-b border-white/5 text-right">Balance</th>
                              </tr>
                            </thead>
                            <tbody className="divide-y divide-white/5 font-mono">
                              {amortizationData.schedule.map((row) => (
                                <tr key={row.month} className="hover:bg-white/5 transition-colors">
                                  <td className="px-4 py-2 opacity-50">{row.month}</td>
                                  <td className="px-4 py-2 text-right opacity-90">${row.payment.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</td>
                                  <td className="px-4 py-2 text-right text-[#EBC351]">${row.principal.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</td>
                                  <td className="px-4 py-2 text-right text-orange-500">${row.interest.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</td>
                                  <td className="px-4 py-2 text-right font-bold">${row.balance.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</td>
                                </tr>
                              ))}
                            </tbody>
                          </table>
                        </div>
                      </div>
                    )}
                  </div>
                </div>
              )}
            </div>

            <div className="px-6 py-3 border-t border-white/5 bg-black/20 flex items-center justify-between">
              <div>
              {editingLoan.id && (
                showDeleteConfirm ? (
                  <div className="flex items-center bg-orange-500/10 rounded-xl p-1.5 border border-orange-500/30 gap-3">
                    <span className="text-[10px] font-black text-orange-500 uppercase px-2 whitespace-nowrap">Confirm?</span>
                    <div className="flex gap-1">
                      <button
                        onClick={() => { onDeleteLoan(editingLoan.id!); setEditingLoan(null); setShowDeleteConfirm(false); }}
                        className="text-[10px] font-black text-white hover:text-orange-500 px-4 py-2 bg-black/40 hover:bg-black/80 rounded-lg transition-colors active:scale-95"
                      >YES</button>
                      <button
                        onClick={() => setShowDeleteConfirm(false)}
                        className="text-[10px] font-black text-white/40 hover:text-white px-4 py-2 bg-black/40 hover:bg-black/80 rounded-lg transition-colors active:scale-95"
                      >NO</button>
                    </div>
                  </div>
                ) : (
                  <button
                    onClick={() => setShowDeleteConfirm(true)}
                    className="text-white/20 hover:text-orange-500 p-3 transition rounded-xl hover:bg-white/5 border border-transparent flex items-center justify-center active:scale-95"
                  >
                    <svg className="w-5 h-5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                  </button>
                )
              )}
              </div>
              <div className="flex space-x-4">
                <button
                  onClick={() => setEditingLoan(null)}
                  className="px-6 py-3 text-[11px] font-black text-white/40 uppercase tracking-widest hover:text-white transition"
                >
                  Cancel
                </button>
                <button
                  onClick={handleSaveLoanModal}
                  className="px-8 py-3 bg-orange-500 rounded-2xl text-[11px] font-black text-white uppercase tracking-widest shadow-lg shadow-orange-500/20 hover:scale-[1.02] active:scale-95 transition"
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
