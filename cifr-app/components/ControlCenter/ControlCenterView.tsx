import React, { useState, useRef, useCallback } from 'react';
import {
  View, Text, Animated, LayoutChangeEvent, NativeScrollEvent, NativeSyntheticEvent
} from 'react-native';
import Reanimated, {
  FadeIn, FadeOut
} from 'react-native-reanimated';
import { useAppContext } from '../../context/AppContext';
import CompanyHeader from '../CompanyHeader';
import TabSelector, { TabName } from './TabSelector';
import QuickGlanceStrip from './QuickGlanceStrip';
import FinancialContent from './FinancialContent';
import SubscriptionContent from './SubscriptionContent';
import DocumentContent from './DocumentContent';
import { FinancialCard, Loan, Institution, Subscription, CompanyDocument } from '../../types';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

// ─────────────────────── Contextual Action Bar ───────────────────────
import { TouchableOpacity, ScrollView } from 'react-native';
import { Ionicons } from '@expo/vector-icons';

function ActionBar({ activeTab, onAction }: {
  activeTab: TabName;
  onAction: (action: string) => void;
}) {
  const actions: { key: string; label: string; icon: string; primary?: boolean }[] =
    activeTab === 'financial'
      ? [
          { key: 'addCard', label: 'Card', icon: 'add' },
          { key: 'addLoan', label: 'Loan', icon: 'add' },
          { key: 'addInstitution', label: 'Institution', icon: 'add', primary: true },
        ]
      : activeTab === 'subscriptions'
      ? [
          { key: 'addSubscription', label: 'Service', icon: 'add', primary: true },
        ]
      : [
          { key: 'addDocument', label: 'Document', icon: 'add', primary: true },
        ];

  return (
    <ScrollView
      horizontal
      showsHorizontalScrollIndicator={false}
      contentContainerStyle={{ flexGrow: 1, gap: 8, paddingVertical: 4, paddingHorizontal: 8 }}
      style={{ marginBottom: 16 }}
    >
      {actions.map((a, i) => (
        <React.Fragment key={a.key}>
          {a.primary && i > 0 && <View style={{ flex: 1 }} />}
          <TouchableOpacity
            onPress={() => onAction(a.key)}
            style={{
              backgroundColor: a.primary ? '#fff' : '#1C1C1E',
              borderRadius: 24,
              paddingHorizontal: 16,
              height: 32,
              flexDirection: 'row',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 6,
              ...(a.primary ? {} : { borderWidth: 1, borderColor: 'rgba(255,255,255,0.08)' }),
            }}
          >
            <Ionicons
              name={a.icon as any}
              size={14}
              color={a.primary ? 'rgba(0,0,0,0.5)' : 'rgba(255,255,255,0.4)'}
            />
            <Text
              style={{
                color: a.primary ? '#000' : '#fff',
                fontWeight: a.primary ? '600' : '500',
                fontSize: 12,
              }}
            >
              {a.label}
            </Text>
          </TouchableOpacity>
        </React.Fragment>
      ))}
    </ScrollView>
  );
}

// ─────────────────────── Main Control Center View ───────────────────────
interface ControlCenterViewProps {
  // Modal triggers — called when user interacts with content
  onEditInstitution: (inst: Partial<Institution>) => void;
  onEditCard: (card: Partial<FinancialCard>) => void;
  onEditLoan: (loan: Partial<Loan>) => void;
  onEditSubscription: (sub: Subscription) => void;
  onAddInstitution: () => void;
  onAddCard: () => void;
  onAddLoan: () => void;
  onNewSubscription: () => void;
  onAddDocument: () => void;
  onOpenPaidFromPicker: (companyId: string | null, currentValue: string, cb: (v: string) => void) => void;
  // Quick glance taps
  onQuickGlanceCard?: (card: FinancialCard) => void;
  onQuickGlanceSub?: (sub: Subscription) => void;
  onQuickGlanceDoc?: (doc: CompanyDocument) => void;
}

export default function ControlCenterView(props: ControlCenterViewProps) {
  const {
    onEditInstitution, onEditCard, onEditLoan, onEditSubscription,
    onAddInstitution, onAddCard, onAddLoan, onNewSubscription, onAddDocument,
    onOpenPaidFromPicker,
    onQuickGlanceCard, onQuickGlanceSub, onQuickGlanceDoc,
  } = props;

  const { selectedCompanyId } = useAppContext();
  const insets = useSafeAreaInsets();
  const [activeTab, setActiveTab] = useState<TabName>('financial');

  // Sticky tab selector logic
  const [tabSelectorY, setTabSelectorY] = useState<number>(0);
  const [showStickyTabs, setShowStickyTabs] = useState(false);
  const scrollOffsetRef = useRef(0);

  const handleTabSelectorLayout = (e: LayoutChangeEvent) => {
    setTabSelectorY(e.nativeEvent.layout.y);
  };

  const handleScroll = (e: NativeSyntheticEvent<NativeScrollEvent>) => {
    const offsetY = e.nativeEvent.contentOffset.y;
    scrollOffsetRef.current = offsetY;
    // Show sticky when the inline tab selector scrolls above the safe area top
    const threshold = tabSelectorY - insets.top;
    setShowStickyTabs(offsetY > threshold && threshold > 0);
  };

  const handleAction = (action: string) => {
    switch (action) {
      case 'addCard': onAddCard(); break;
      case 'addLoan': onAddLoan(); break;
      case 'addInstitution': onAddInstitution(); break;
      case 'addSubscription': onNewSubscription(); break;
      case 'addDocument': onAddDocument(); break;
    }
  };

  if (!selectedCompanyId) {
    return (
      <View style={{ flex: 1, backgroundColor: '#000', alignItems: 'center', justifyContent: 'center' }}>
        <Text style={{ color: 'rgba(255,255,255,0.3)', fontWeight: '500', fontSize: 13 }}>
          Select a Company
        </Text>
      </View>
    );
  }

  const BOTTOM_PAD = insets.bottom + 120;

  return (
    <View style={{ flex: 1 }}>
      {/* Sticky Tab Selector — fixed at top when scrolled past */}
      {showStickyTabs && (
        <Reanimated.View
          entering={FadeIn.duration(150)}
          exiting={FadeOut.duration(100)}
          style={{
            position: 'absolute',
            top: 0,
            left: 0,
            right: 0,
            zIndex: 100,
            paddingTop: insets.top,
            backgroundColor: 'rgba(0,0,0,0.92)',
            borderBottomWidth: 1,
            borderBottomColor: 'rgba(255,255,255,0.08)',
          }}
        >
          <TabSelector activeTab={activeTab} onTabChange={setActiveTab} isSticky />
        </Reanimated.View>
      )}

      <ScrollView
        style={{ flex: 1 }}
        contentContainerStyle={{ padding: 16, paddingBottom: BOTTOM_PAD }}
        scrollEventThrottle={16}
        onScroll={handleScroll}
      >
        {/* Header */}
        <CompanyHeader
          activeTab={
            activeTab === 'financial' ? 'financial' :
            activeTab === 'subscriptions' ? 'subscriptions' : 'docs'
          }
        />

        {/* Tab Selector (inline) */}
        <View onLayout={handleTabSelectorLayout}>
          <TabSelector activeTab={activeTab} onTabChange={setActiveTab} />
        </View>

        {/* Quick Glance Strip */}
        <QuickGlanceStrip
          activeTab={activeTab}
          onCardPress={onQuickGlanceCard}
          onSubscriptionPress={onQuickGlanceSub}
          onDocumentPress={onQuickGlanceDoc}
        />

        {/* Action Bar */}
        <ActionBar activeTab={activeTab} onAction={handleAction} />

        {/* Content Area with animated transitions */}
        <Reanimated.View
          key={activeTab}
          entering={FadeIn.duration(200)}
          exiting={FadeOut.duration(150)}
        >
          {activeTab === 'financial' && (
            <FinancialContent
              onEditInstitution={onEditInstitution}
              onEditCard={onEditCard}
              onEditLoan={onEditLoan}
              onAddInstitution={onAddInstitution}
              onAddCard={onAddCard}
              onAddLoan={onAddLoan}
            />
          )}
          {activeTab === 'subscriptions' && (
            <SubscriptionContent
              onEditSubscription={onEditSubscription}
              onNewSubscription={onNewSubscription}
              onOpenPaidFromPicker={onOpenPaidFromPicker}
            />
          )}
          {activeTab === 'documents' && (
            <DocumentContent onAddDocument={onAddDocument} />
          )}
        </Reanimated.View>
      </ScrollView>
    </View>
  );
}
