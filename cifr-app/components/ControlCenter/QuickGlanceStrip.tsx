import React from 'react';
import { View, Text, ScrollView, TouchableOpacity, Image } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useAppContext } from '../../context/AppContext';
import { FinancialCard, Subscription, CompanyDocument } from '../../types';
import { getFaviconUrl } from '../../services/logoService';
import { TabName } from './TabSelector';

const brandColors: Record<string, string[]> = {
  amex: ['#006FCF', '#002663'],
  chase: ['#117ACA', '#002A5E'],
  citi: ['#003B70', '#001A36'],
  capitalone: ['#003468', '#001B36'],
  discover: ['#E47911', '#9A4C00'],
  bofa: ['#E31837', '#930F23'],
  wells: ['#D71E28', '#8A1118'],
  apple: ['#FFFFFF', '#E0E0E0'],
  brex: ['#000000', '#333333'],
  ramp: ['#D6F41E', '#9EBA00']
};

const fallbackColors = [
  ['#1C1C1E', '#0A0A0B'],
  ['#2C2C2E', '#1A1A1C'],
  ['#3A3A3C', '#28282A']
];

const getCardColors = (issuer: string, index: number) => {
  const normalizedIssuer = issuer.toLowerCase().replace(/[^a-z]/g, '');
  for (const [key, colors] of Object.entries(brandColors)) {
    if (normalizedIssuer.includes(key)) return colors;
  }
  return fallbackColors[index % fallbackColors.length];
};

interface QuickGlanceStripProps {
  activeTab: TabName;
  onCardPress?: (card: FinancialCard) => void;
  onSubscriptionPress?: (sub: Subscription) => void;
  onDocumentPress?: (doc: CompanyDocument) => void;
}

export default function QuickGlanceStrip({
  activeTab,
  onCardPress,
  onSubscriptionPress,
  onDocumentPress
}: QuickGlanceStripProps) {
  const { state, selectedCompanyId } = useAppContext();

  const renderContent = () => {
    if (activeTab === 'financial') {
      const cards = (state?.financialCards || []).filter(c => c.companyId === selectedCompanyId);
      
      if (cards.length === 0) {
        return <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 12 }}>No financial cards yet</Text>;
      }

      return cards.map((card, idx) => {
        const issuerName = card.institutionName || card.network || 'Bank';
        const colors = getCardColors(issuerName, idx);
        const textColor = issuerName.toLowerCase().includes('apple') || issuerName.toLowerCase().includes('ramp') ? '#000' : '#fff';
        return (
          <TouchableOpacity 
            key={card.id} 
            onPress={() => onCardPress?.(card)}
            style={{
              width: 140,
              height: 84,
              borderRadius: 12,
              padding: 12,
              justifyContent: 'space-between',
              backgroundColor: colors[0],
            }}
          >
            <Text style={{ color: textColor, fontSize: 12, fontWeight: '600' }} numberOfLines={1}>
              {card.name || issuerName}
            </Text>
            <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-end' }}>
              <Text style={{ color: textColor, opacity: 0.8, fontSize: 10 }}>{card.network}</Text>
              <Text style={{ color: textColor, fontSize: 12, fontFamily: 'monospace' }}>••{card.last4}</Text>
            </View>
          </TouchableOpacity>
        );
      });
    }

    if (activeTab === 'subscriptions') {
      const subs = (state?.subscriptions || []).filter(s => s.companyId === selectedCompanyId && s.status === 'Active');
      
      if (subs.length === 0) {
        return <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 12 }}>No active subscriptions</Text>;
      }

      return subs.map((sub) => {
        return (
          <TouchableOpacity 
            key={sub.id} 
            onPress={() => onSubscriptionPress?.(sub)}
            style={{ alignItems: 'center', width: 60 }}
          >
            <View style={{
              width: 56,
              height: 56,
              borderRadius: 28,
              backgroundColor: 'rgba(255,255,255,0.05)',
              alignItems: 'center',
              justifyContent: 'center',
              marginBottom: 4,
            }}>
              {sub.website ? (
                <Image source={{ uri: getFaviconUrl(sub.website) || undefined }} style={{ width: 28, height: 28, borderRadius: 14 }} />
              ) : (
                <Text style={{ color: '#fff', fontSize: 24, fontWeight: '700' }}>{sub.name.charAt(0)}</Text>
              )}
            </View>
            <Text style={{ color: 'rgba(255,255,255,0.7)', fontSize: 10, textAlign: 'center' }} numberOfLines={1}>
              {sub.name}
            </Text>
          </TouchableOpacity>
        );
      });
    }

    if (activeTab === 'documents') {
      const docs = (state?.documents || []).filter(d => d.companyId === selectedCompanyId);
      
      if (docs.length === 0) {
        return <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 12 }}>No documents yet</Text>;
      }

      const counts: Record<string, number> = { Formation: 0, Legal: 0, Contract: 0, Finance: 0, Other: 0 };
      docs.forEach(d => {
        if (counts[d.type] !== undefined) {
          counts[d.type]++;
        } else {
          counts.Other++;
        }
      });

      const types = [
        { label: 'Formation', color: '#a855f7' },
        { label: 'Legal', color: '#3b82f6' },
        { label: 'Contract', color: '#f59e0b' },
        { label: 'Finance', color: '#10b981' },
        { label: 'Other', color: 'rgba(255,255,255,0.3)' }
      ];

      return types.map(t => {
        if (counts[t.label] === 0) return null;
        return (
          <TouchableOpacity key={t.label} style={{
            flexDirection: 'row',
            alignItems: 'center',
            backgroundColor: 'rgba(255,255,255,0.05)',
            paddingHorizontal: 12,
            paddingVertical: 8,
            borderRadius: 16,
            borderWidth: 1,
            borderColor: 'rgba(255,255,255,0.05)'
          }}>
            <View style={{ width: 8, height: 8, borderRadius: 4, backgroundColor: t.color, marginRight: 8 }} />
            <Text style={{ color: '#fff', fontSize: 12, marginRight: 8 }}>{t.label}</Text>
            <Text style={{ color: 'rgba(255,255,255,0.5)', fontSize: 12, fontWeight: '600' }}>{counts[t.label]}</Text>
          </TouchableOpacity>
        );
      });
    }

    return null;
  };

  return (
    <View style={{ marginVertical: 16 }}>
      <Text style={{
        fontSize: 10,
        fontWeight: '700',
        color: 'rgba(255,255,255,0.25)',
        textTransform: 'uppercase',
        letterSpacing: 3,
        marginLeft: 16,
        marginBottom: 8
      }}>
        QUICK GLANCE
      </Text>
      <ScrollView 
        horizontal 
        showsHorizontalScrollIndicator={false} 
        contentContainerStyle={{ paddingHorizontal: 16, gap: 10, alignItems: 'center' }}
      >
        {renderContent()}
      </ScrollView>
    </View>
  );
}
