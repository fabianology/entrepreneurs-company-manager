
import { AppState } from '../types';

const DB_KEY = 'founderstack_db_v1';

const now = Date.now();
const dayInMs = 24 * 60 * 60 * 1000;

// Initial Seed Data (Updated with email recall fields)
const SEED_DATA: AppState = {
  companies: [
    { id: '1', name: 'Cifr', structure: 'C-Corp', description: 'Advanced data encryption and AI analytics.', color: '#4f46e5', lastModified: now - dayInMs, lastViewed: now - 3600000 },
    { id: '2', name: 'EcoStream', structure: 'LLC', description: 'Sustainable water filtration solutions.', color: '#10b981', lastModified: now - 3 * dayInMs, lastViewed: now - 2 * dayInMs },
    { id: '3', name: 'Vortex Agency', structure: 'S-Corp', description: 'Web3 and tech growth agency.', color: '#f59e0b', lastModified: now - 10 * dayInMs, lastViewed: now - 5 * dayInMs },
  ],
  accounts: [
    { 
      id: 'a1', companyId: '1', platform: 'AWS', website: 'https://aws.amazon.com', email: 'billing@cifr.io', twoFactorAuth: 'Authenticator', recoveryMethod: 'Backup Codes', password: '••••••••',
      pricingModel: 'paid', notes: ['Main production infra', 'Linked to credit card 4242'],
      subscriptionCost: 1200.00, subscriptionInterval: 'Monthly',
      paymentMethod: 'Amex ••1002', nextBillingDate: '2024-11-30', renew: 'Auto', status: 'Active'
    },
    { 
      id: 'a2', companyId: '1', platform: 'Slack', website: 'https://slack.com', email: 'owner@cifr.io', twoFactorAuth: 'SMS', recoveryMethod: '555-0123', password: '••••••••',
      pricingModel: 'paid', notes: ['Workspace owner'],
      subscriptionCost: 15.00, subscriptionInterval: 'Monthly',
      paymentMethod: 'Visa ••4242', nextBillingDate: '2024-11-27', renew: 'Auto', status: 'Active'
    },
    { 
      id: 'a3', companyId: '2', platform: 'Shopify', website: 'https://shopify.com', email: 'sales@ecostream.com', twoFactorAuth: 'Authenticator', recoveryMethod: 'YubiKey', password: '••••••••',
      pricingModel: 'paid', notes: ['Main storefront'],
      subscriptionCost: 29.00, subscriptionInterval: 'Monthly',
      paymentMethod: 'PayPal', nextBillingDate: '2024-12-15', renew: 'Auto', status: 'Active'
    },
    { 
      id: 'a4', companyId: '3', platform: 'Stripe', website: 'https://stripe.com', email: 'agency@vortex.co', twoFactorAuth: 'Authenticator', recoveryMethod: 'Backup Codes',
      pricingModel: 'free', notes: ['Client payments'],
      subscriptionCost: 0, subscriptionInterval: 'Monthly',
      paymentMethod: 'Linked Bank', nextBillingDate: '', renew: 'Manual', status: 'Active'
    },
  ],
  subscriptions: [
    { 
      id: 's1', 
      companyId: '1', 
      name: 'Github Enterprise', 
      cost: 49.00, 
      currency: 'USD', 
      billingCycle: 'Monthly', 
      paymentMethod: 'Amex ••1002', 
      nextRenewal: '2024-11-20', 
      renew: 'Auto',
      status: 'Active',
      email: 'tech@cifr.io',
      emailPurpose: 'Receives all pull request notifications and team invites.',
      subServices: [
        { id: 'sub1', name: 'Copilot Business', cost: 19.00, status: 'Active' },
        { id: 'sub2', name: 'LFS Data Storage', cost: 5.00, status: 'Active' }
      ]
    },
    { id: 's2', companyId: '1', name: 'Zoom', cost: 15.99, currency: 'USD', billingCycle: 'Monthly', paymentMethod: 'Visa ••4242', nextRenewal: '2024-11-15', renew: 'Auto', status: 'Active', email: 'owner@cifr.io', emailPurpose: 'Primary login for CEO host access.' },
    { id: 's3', companyId: '2', name: 'Klaviyo', cost: 120.00, currency: 'USD', billingCycle: 'Monthly', paymentMethod: 'PayPal', nextRenewal: '2024-12-01', renew: 'Auto', status: 'Active', email: 'marketing@ecostream.com', emailPurpose: 'Used for bulk customer newsletter campaigns.' },
  ],
  financialCards: [
    { id: 'f1', companyId: '1', name: 'Amex Business Platinum', cardHolder: 'CIFR INC', last4: '1002', expiry: '12/28', network: 'Amex', type: 'Credit', status: 'Active', limit: 50000 },
    { id: 'f2', companyId: '1', name: 'Chase Ink Unlimited', cardHolder: 'CIFR INC', last4: '4242', expiry: '09/27', network: 'Visa', type: 'Credit', status: 'Active', limit: 25000 },
    { id: 'f3', companyId: '2', name: 'Brex', cardHolder: 'ECOSTREAM LLC', last4: '9988', expiry: '05/26', network: 'Mastercard', type: 'Credit', status: 'Active', limit: 15000 },
  ],
  loans: [
    { id: 'l1', companyId: '1', lender: 'Silicon Valley Bank', name: 'Venture Debt', principalAmount: 500000, remainingBalance: 320000, interestRate: 5.5, term: '48 months', monthlyPayment: 11200, startDate: '2023-01-15', status: 'Active' },
    { id: 'l2', companyId: '2', lender: 'Shopify Capital', name: 'Inventory Financing', principalAmount: 50000, remainingBalance: 12000, interestRate: 8.0, term: '12 months', monthlyPayment: 4500, startDate: '2024-01-10', status: 'Active' },
  ],
  institutions: [
    {
      id: 'i1',
      companyId: '1',
      name: 'Mercury Bank',
      loginUrl: 'https://mercury.com/login',
      email: 'founder@cifr.io',
      username: 'cifr_admin',
      password: 'password123',
      accounts: [
        { id: 'ia1', name: 'Main Operating', type: 'Checking', last4: '4452', balance: 145000 },
        { id: 'ia2', name: 'Tax Reserve', type: 'Savings', last4: '8821', balance: 45000 }
      ]
    }
  ],
  documents: [
    { id: 'd1', companyId: '1', name: 'Articles of Incorporation', type: 'Formation', url: '', uploadDate: '2023-01-10', notes: 'Filed in Delaware' },
    { id: 'd2', companyId: '1', name: 'EIN Letter', type: 'Legal', url: '', uploadDate: '2023-01-15', notes: 'IRS Tax ID' },
    { id: 'd3', companyId: '2', name: 'Supplier Agreement - China', type: 'Contract', url: '', uploadDate: '2023-06-20', notes: 'Main manufacturer contract' }
  ]
};

export const db = {
  load: async (): Promise<AppState> => {
    try {
      const stored = localStorage.getItem(DB_KEY);
      if (stored) {
        const parsed = JSON.parse(stored);
        // Polyfill new fields for old data
        if (!parsed.institutions) parsed.institutions = [];
        if (!parsed.documents) parsed.documents = [];
        
        // Migration: industry -> structure
        if (parsed.companies) {
            parsed.companies = parsed.companies.map((c: any) => ({
                ...c,
                structure: c.structure || c.industry || 'LLC',
                lastModified: c.lastModified || now,
                lastViewed: c.lastViewed || now
            }));
        }

        // Migration: category -> pricingModel
        if (parsed.accounts) {
             parsed.accounts = parsed.accounts.map((a: any) => ({
                 ...a,
                 pricingModel: a.pricingModel || (a.category ? a.category.toLowerCase() : 'paid'),
                 // Migration for 2FA/Recovery
                 twoFactorAuth: (a.twoFactorAuth === 'Auth App' || a.twoFactorAuth === 'Authenticator') ? 'Authenticator' : (a.twoFactorAuth === 'SMS' ? 'SMS' : 'None'),
                 recoveryMethod: a.recoveryMethod || (a.twoFactorAuth && a.twoFactorAuth !== 'Auth App' && a.twoFactorAuth !== 'SMS' ? a.twoFactorAuth : '')
             }));
        }

        return parsed;
      }
    } catch (e) {
      console.error("Failed to load DB", e);
    }
    
    // If no data exists, initialize with Seed Data
    localStorage.setItem(DB_KEY, JSON.stringify(SEED_DATA));
    return SEED_DATA;
  },

  save: async (state: AppState): Promise<boolean> => {
    try {
      localStorage.setItem(DB_KEY, JSON.stringify(state));
      return true;
    } catch (e) {
      console.error("Failed to save DB - likely quota exceeded", e);
      return false;
    }
  },
  
  clear: async (): Promise<AppState> => {
     localStorage.removeItem(DB_KEY);
     return SEED_DATA;
  }
};
