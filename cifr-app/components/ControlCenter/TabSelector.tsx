import React, { useMemo } from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useAppContext } from '../../context/AppContext';

export type TabName = 'financial' | 'subscriptions' | 'documents';

interface TabSelectorProps {
  activeTab: TabName;
  onTabChange: (tab: TabName) => void;
  isSticky?: boolean;
}

export default function TabSelector({ activeTab, onTabChange, isSticky = false }: TabSelectorProps) {
  const { state, selectedCompanyId } = useAppContext();

  const metrics = useMemo(() => {
    const institutions = (state?.institutions || []).filter(i => i.companyId === selectedCompanyId);
    const subscriptions = (state?.subscriptions || []).filter(s => s.companyId === selectedCompanyId);
    const documents = (state?.documents || []).filter(d => d.companyId === selectedCompanyId);
    const loans = (state?.loans || []).filter(l => l.companyId === selectedCompanyId);

    // Financial
    const instCount = institutions.length;
    let monthlyTotal = 0;
    institutions.forEach(i => {
      (i.accounts || []).forEach(acc => {
        monthlyTotal += (acc as any).monthlyPayment || 0;
      });
    });
    loans.forEach(l => {
      monthlyTotal += l.monthlyPayment || 0;
    });

    // Subscriptions
    const subCount = subscriptions.length;
    let monthlyBurn = 0;
    subscriptions.forEach(s => {
      if (s.billingCycle === 'Yearly') {
        monthlyBurn += (s.cost || 0) / 12;
      } else {
        monthlyBurn += s.cost || 0;
      }
      if (s.subServices) {
        s.subServices.forEach(sub => {
          monthlyBurn += sub.cost || 0;
        });
      }
    });

    // Documents
    const docCount = documents.length;

    return {
      financial: { count: instCount, total: monthlyTotal },
      subscriptions: { count: subCount, total: monthlyBurn },
      documents: { count: docCount },
    };
  }, [state, selectedCompanyId]);

  const tabs = [
    {
      id: 'financial' as TabName,
      label: 'Financial',
      icon: 'card' as const,
      color: '#22c55e',
      summary: `${metrics.financial.count} Institutions · $${metrics.financial.total.toFixed(0)}/mo`,
    },
    {
      id: 'subscriptions' as TabName,
      label: 'Subscriptions',
      icon: 'layers' as const,
      color: '#60A5FA',
      summary: `${metrics.subscriptions.count} Services · $${metrics.subscriptions.total.toFixed(0)}/mo`,
    },
    {
      id: 'documents' as TabName,
      label: 'Documents',
      icon: 'document-text' as const,
      color: '#FBBF24',
      summary: `${metrics.documents.count} Documents`,
    }
  ];

  const containerStyle = isSticky
    ? {
        flexDirection: 'row' as const,
        backgroundColor: 'rgba(0,0,0,0.85)',
        borderBottomWidth: 1,
        borderBottomColor: 'rgba(255,255,255,0.08)',
        paddingVertical: 8,
      }
    : {
        flexDirection: 'row' as const,
        backgroundColor: 'rgba(28,28,30,0.8)',
        borderRadius: 20,
        marginHorizontal: 8,
        borderWidth: 1,
        borderColor: 'rgba(255,255,255,0.06)',
        paddingVertical: 12,
      };

  return (
    <View style={containerStyle}>
      {tabs.map((tab) => {
        const isActive = activeTab === tab.id;
        return (
          <TouchableOpacity
            key={tab.id}
            onPress={() => onTabChange(tab.id)}
            style={{
              flex: 1,
              alignItems: 'center',
              borderBottomWidth: 2,
              borderBottomColor: isActive ? tab.color : 'transparent',
              paddingBottom: 4,
            }}
          >
            <Ionicons
              name={tab.icon}
              size={20}
              color={isActive ? tab.color : 'rgba(255,255,255,0.3)'}
              style={{ marginBottom: 4 }}
            />
            <Text
              style={{
                color: isActive ? '#fff' : 'rgba(255,255,255,0.5)',
                fontSize: 12,
                fontWeight: isActive ? '600' : '500',
                marginBottom: 2,
              }}
            >
              {tab.label}
            </Text>
            <Text
              style={{
                color: 'rgba(255,255,255,0.4)',
                fontSize: 9,
                fontWeight: '400',
              }}
            >
              {tab.summary}
            </Text>
          </TouchableOpacity>
        );
      })}
    </View>
  );
}
