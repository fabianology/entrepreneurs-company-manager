
export interface Company {
  id: string;
  name: string;
  structure: string; // e.g. LLC, C-Corp
  description: string;
  color: string;
  logoUrl?: string;
  lastModified?: number; // timestamp
  lastViewed?: number; // timestamp
}

export interface Account {
  id: string;
  companyId: string;
  platform: string;
  website?: string;
  email: string;
  twoFactorAuth: string; // 'Authenticator' | 'SMS' | 'None'
  recoveryMethod?: string;
  password?: string;
  pricingModel: 'free' | 'paid';
  notes: string[];
  subscriptionCost?: number;
  subscriptionInterval?: 'Monthly' | 'Yearly';
  paymentMethod?: string;
  nextBillingDate?: string;
  renew?: 'Auto' | 'Manual';
  status?: 'Active' | 'Inactive' | 'Trial';
}

export interface SubService {
  id: string;
  name: string;
  cost: number;
  status: 'Active' | 'Cancelled' | 'Pending';
}

export interface Subscription {
  id: string;
  companyId: string;
  name: string;
  cost: number;
  currency: string;
  billingCycle: 'Monthly' | 'Yearly';
  paymentMethod?: string;
  nextRenewal: string;
  renew?: 'Auto' | 'Manual';
  status: 'Active' | 'Cancelled' | 'Pending';
  subServices?: SubService[];
  email?: string;
  emailPurpose?: string;
}

export interface FinancialCard {
  id: string;
  companyId: string;
  name: string; // Nickname e.g. "Amex Gold"
  cardHolder: string;
  last4: string;
  expiry: string; // MM/YY
  network: 'Visa' | 'Mastercard' | 'Amex' | 'Discover' | 'Other';
  type: 'Credit' | 'Debit';
  status: 'Active' | 'Frozen' | 'Expired';
  limit?: number;
}

export interface InstitutionAccount {
  id: string;
  name: string;
  type: 'Checking' | 'Savings' | 'Investing' | 'CD' | 'Credit Card' | 'Debit Card' | 'Other';
  last4: string;
  balance: number;
}

export interface Institution {
  id: string;
  companyId: string;
  name: string;
  loginUrl?: string;
  username?: string;
  email?: string;
  password?: string;
  accounts: InstitutionAccount[];
}

export interface Loan {
  id: string;
  companyId: string;
  lender: string; // e.g. "Chase Bank"
  name: string; // e.g. "Startup Loan"
  principalAmount: number;
  remainingBalance: number;
  interestRate: number; // percentage
  term: string; // e.g. "36 months"
  monthlyPayment: number;
  startDate: string;
  status: 'Active' | 'Paid Off' | 'Default';
}

export interface CompanyDocument {
  id: string;
  companyId: string;
  name: string;
  type: 'Formation' | 'Legal' | 'Contract' | 'Finance' | 'Other';
  url: string;
  uploadDate: string;
  notes?: string;
}

export interface AppState {
  companies: Company[];
  accounts: Account[];
  subscriptions: Subscription[];
  financialCards: FinancialCard[];
  loans: Loan[];
  institutions: Institution[];
  documents: CompanyDocument[];
}
