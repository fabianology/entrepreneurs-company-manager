
export interface Company {
  id: string;
  name: string;
  structure: string; // e.g. LLC, C-Corp
  description: string;
  color: string;
  logoUrl?: string;
  website?: string;
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
  lastUpdated?: number; // timestamp
}

export interface SubService {
  id: string;
  name: string;
  cost: number;
  billingCycle: 'Monthly' | 'Yearly';
  purpose?: string;
  status: 'Active' | 'Cancelled' | 'Pending' | 'Paused';
}

export interface LinkedEmail {
  id: string;
  email: string;
  forwarding: string;
  usedFor: string;
  usedIn: string;
  accessMethod: string;
  notes: string[];
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
  linkedEmails?: LinkedEmail[];
  website?: string;
  loginId?: string;
  password?: string;
  twoFactorAuth?: string; // Authenticator, SMS, None
  recoveryMethod?: string;
  lastUpdated?: number; // timestamp
  pricingModel?: 'free' | 'paid';
}

export interface FinancialCard {
  id: string;
  companyId: string;
  name: string; // Nickname e.g. "Amex Gold"
  login?: string;
  password?: string;
  institutionName?: string;
  cardHolder?: string;
  last4: string;
  expiry: string; // MM/YY
  network?: 'Visa' | 'Mastercard' | 'Amex' | 'Discover' | 'Other';
  type: 'Credit' | 'Debit';
  status: 'Active' | 'Frozen' | 'Expired';
  limit?: number;
  paidFrom?: string;
  paidOn?: string;
  autopay?: 'Yes' | 'No' | 'N/A';
}

export interface InstitutionAccount {
  id: string;
  name: string;
  type: 'Checking' | 'Savings' | 'Investing' | 'CD' | 'Credit Card' | 'Debit Card' | 'Debit (Linked)' | 'FSA' | 'HSA' | '401(k)' | 'Roth 401(k)' | 'IRA' | 'Roth IRA' | 'Rollover IRA' | 'SEP IRA' | '529' | 'Other';
  last4: string;
  balance: number;
  currency?: string;
  // Card-specific parameters
  cardHolder?: string;
  expiry?: string;
  network?: 'Visa' | 'Mastercard' | 'Amex' | 'Discover' | 'Other';
  status?: 'Active' | 'Frozen' | 'Expired';
  limit?: number;
  paidFrom?: string;
  paidOn?: string;
  autopay?: 'Yes' | 'No' | 'N/A';
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
  role?: 'Lender' | 'Lendee';
  lender: string; // e.g. "Chase Bank"
  name: string; // e.g. "Startup Loan"
  principalAmount: number;
  remainingBalance: number;
  interestType?: 'Percentage' | 'Fixed';
  interestRate: number; // percentage or fixed amount
  term: string; // e.g. "36 months"
  termYears?: number;
  termMonths?: number;
  scheduleFrequency?: 'Weekly' | 'Monthly' | 'Yearly';
  monthlyPayment: number;
  startDate: string;
  maturityDate?: string;
  paidOffDate?: string;
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
