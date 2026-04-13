import React from 'react';
import { View, Text, Image } from 'react-native';
import { useAppContext } from '../context/AppContext';

interface CompanyHeaderProps {
  activeTab: 'subscriptions' | 'financial' | 'docs';
}

export default function CompanyHeader({ activeTab }: CompanyHeaderProps) {
  const { 
    selectedCompany, 
    selectedCompanyId, 
    subMetrics, 
    state 
  } = useAppContext();

  // If no company is specifically selected, return a highly minimized global header
  if (!selectedCompanyId || !selectedCompany || !state) {
    const generalTitle = 
      activeTab === 'subscriptions' ? 'All Services' :
      activeTab === 'financial' ? 'All Institutions' : 'All Documents';

    const largeTitle = 
      activeTab === 'subscriptions' ? 'Tech Stack' :
      activeTab === 'financial' ? 'Financials' : 'Doc Vault';

    return (
      <View style={{ marginBottom: 24, marginTop: 8 }}>
        <Text style={{ fontSize: 11, fontWeight: '700', color: 'rgba(255,255,255,0.4)', letterSpacing: 3, textTransform: 'uppercase', marginLeft: 8, marginBottom: 4 }}>
          {generalTitle}
        </Text>
        <Text style={{ fontSize: 36, fontWeight: '900', color: '#fff', paddingHorizontal: 8 }}>
          {largeTitle}
        </Text>
      </View>
    );
  }

  // Calculate generic counts for the active company
  const companyInstitutions = (state.institutions || []).filter(i => i.companyId === selectedCompanyId);
  const companyCards = state.financialCards.filter(c => c.companyId === selectedCompanyId);
  const companyLoans = state.loans.filter(l => l.companyId === selectedCompanyId);

  // Re-create the web ui's exact logo background calculation natively
  // Logo priority: 1. logoUrl (white bg), 2. website icon (white bg), 3. generic color box
  const logoBg = selectedCompany.logoUrl ? '#fff' : (selectedCompany.website ? '#fff' : selectedCompany.color);

  return (
    <View style={{ flexDirection: 'column', gap: 16, marginBottom: 24, marginTop: 8, paddingHorizontal: 8 }}>
      
      {/* Universal Pre-Title to mimic Web */}
      <Text style={{ fontSize: 11, fontWeight: '700', color: 'rgba(255,255,255,0.4)', letterSpacing: 3, textTransform: 'uppercase', marginBottom: -8 }}>
        Company Overview
      </Text>

      {/* Main Row */}
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        
        {/* Logo Tile */}
        <View style={{
          width: 48,
          height: 48,
          borderRadius: 12,
          backgroundColor: logoBg,
          alignItems: 'center',
          justifyContent: 'center',
          marginRight: 12,
          overflow: 'hidden'
        }}>
          {selectedCompany.logoUrl ? (
            <Image source={{ uri: selectedCompany.logoUrl }} style={{ width: '100%', height: '100%' }} resizeMode="cover" />
          ) : (
            <Text style={{ fontSize: 20, color: '#fff', fontWeight: '900' }}>
              {selectedCompany.name.charAt(0)}
            </Text>
          )}
        </View>

        {/* Company Title */}
        <View style={{ flex: 1, overflow: 'hidden' }}>
          <Text style={{ fontSize: 28, fontWeight: 'bold', color: '#fff' }} numberOfLines={1}>
            {selectedCompany.name}
          </Text>

          {/* DYNAMIC METRICS SUB-HEADER */}
          <View style={{ flexDirection: 'row', alignItems: 'center', marginTop: 2 }}>
            
            {activeTab === 'subscriptions' && (
              <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                {/* 💵🔥 Icon combo exactly like web */}
                <View style={{ flexDirection: 'row', alignItems: 'center', marginRight: 6 }}>
                  <Text style={{ fontSize: 16 }}>💵</Text>
                  <Text style={{ fontSize: 12, marginLeft: -2 }}>🔥</Text>
                </View>

                {/* Monthly */}
                <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                  <Text style={{ fontSize: 11, fontWeight: '500', color: 'rgba(255,255,255,0.4)', marginRight: 4 }}>mo.</Text>
                  <Text style={{ fontSize: 13, fontWeight: '600', color: '#fff', marginRight: 4 }}>${subMetrics.cycleMonthly.toFixed(0)}</Text>
                  <Text style={{ fontSize: 10, fontWeight: '500', color: 'rgba(255,255,255,0.4)' }}>({subMetrics.monthlyCount})</Text>
                </View>

                <View style={{ width: 1, height: 12, backgroundColor: 'rgba(255,255,255,0.1)', marginHorizontal: 12 }} />

                {/* Yearly */}
                <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                  <Text style={{ fontSize: 11, fontWeight: '500', color: 'rgba(255,255,255,0.4)', marginRight: 4 }}>yr.</Text>
                  <Text style={{ fontSize: 13, fontWeight: '600', color: '#fff', marginRight: 4 }}>${subMetrics.cycleYearly.toLocaleString(undefined, { maximumFractionDigits: 0 })}</Text>
                  <Text style={{ fontSize: 10, fontWeight: '500', color: 'rgba(255,255,255,0.4)' }}>({subMetrics.yearlyCount})</Text>
                </View>
              </View>
            )}

            {activeTab === 'financial' && (
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 16 }}>
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
                  <Text style={{ fontSize: 14 }}>🏦</Text>
                  <Text style={{ fontSize: 11, fontWeight: '500', color: 'rgba(255,255,255,0.4)' }}>({companyInstitutions.length})</Text>
                </View>
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
                  <Text style={{ fontSize: 14 }}>💳</Text>
                  <Text style={{ fontSize: 11, fontWeight: '500', color: 'rgba(255,255,255,0.4)' }}>({companyCards.length})</Text>
                </View>
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
                  <Text style={{ fontSize: 14 }}>📑</Text>
                  <Text style={{ fontSize: 11, fontWeight: '500', color: 'rgba(255,255,255,0.4)' }}>({companyLoans.length})</Text>
                </View>
              </View>
            )}

            {activeTab === 'docs' && (
              <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                <Text style={{ fontSize: 14, marginRight: 6 }}>📑</Text>
                <Text style={{ fontSize: 11, fontWeight: '500', color: 'rgba(255,255,255,0.4)' }}>
                  Document Vault
                </Text>
              </View>
            )}

          </View>
        </View>
        
      </View>
    </View>
  );
}
