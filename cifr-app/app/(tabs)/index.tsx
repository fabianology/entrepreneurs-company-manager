import React, { useState, useEffect, useRef } from 'react';
import { View, Text, ScrollView, TouchableOpacity, Image, Alert } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Swipeable } from 'react-native-gesture-handler';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { useRouter } from 'expo-router';
import { useAppContext } from '../../context/AppContext';
import { Company } from '../../types';
import { getFaviconUrl } from "../../services/logoService";
import { getEntrepreneurialQuote } from '../../services/geminiService';


const getTimeAgo = (timestamp?: number) => {
  if (!timestamp) return 'Never';
  const now = Date.now();
  const diffInMs = now - timestamp;
  const diffInDays = Math.floor(diffInMs / (1000 * 60 * 60 * 24));
  if (diffInDays === 0) {
    const diffInHours = Math.floor(diffInMs / (1000 * 60 * 60));
    if (diffInHours === 0) return 'Just now';
    return `${diffInHours}h ago`;
  }
  return `${diffInDays}d ago`;
};

const calcMonthlyBurn = (companyId: string, state: any): number => {
  if (!state) return 0;
  let total = 0;
  // Active subscriptions
  (state.subscriptions || []).filter((s: any) => s.companyId === companyId && s.status === 'Active').forEach((s: any) => {
    total += s.billingCycle === 'Yearly' ? (s.cost / 12) : s.cost;
    // Sub-services
    (s.subServices || []).filter((ss: any) => ss.status === 'Active').forEach((ss: any) => {
      total += ss.billingCycle === 'Yearly' ? (ss.cost / 12) : ss.cost;
    });
  });
  // Active loans
  (state.loans || []).filter((l: any) => l.companyId === companyId && l.status === 'Active').forEach((l: any) => {
    total += l.monthlyPayment || 0;
  });
  return total;
};

export default function DashboardScreen() {
  const router = useRouter();
  const { state, setSelectedCompanyId, filteredCompanies, handleAddCompany, handleUpdateCompany, handleDeleteCompany } = useAppContext();
  const [quote, setQuote] = useState<string>('');

  // Width of the left action – must match leftThreshold on Swipeable
  const EDIT_THRESHOLD = 96;

  // Track rapid haptic intervals per company card
  const hapticIntervals = useRef<Record<string, ReturnType<typeof setInterval>>>({});
  // Track if we already triggered from drag
  const autoTriggered = useRef<Record<string, boolean>>({});

  const startRapidHaptic = (id: string) => {
    if (hapticIntervals.current[id]) return;
    hapticIntervals.current[id] = setInterval(() => {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }, 60);
  };

  const stopRapidHaptic = (id: string) => {
    if (hapticIntervals.current[id]) {
      clearInterval(hapticIntervals.current[id]);
      delete hapticIntervals.current[id];
    }
  };

  const renderLeftActions = (company: Company, progress: Animated.AnimatedInterpolation<number>, dragX: Animated.AnimatedInterpolation<number>, swipeRef: React.RefObject<Swipeable>) => {
    // Add real-time drag listener for auto-trigger
    dragX.addListener(({ value }) => {
      if (value > EDIT_THRESHOLD + 20) { // pulled past the threshold
        if (!autoTriggered.current[company.id]) {
          autoTriggered.current[company.id] = true;
          startRapidHaptic(company.id);
        }
      } else {
         if (autoTriggered.current[company.id]) {
           autoTriggered.current[company.id] = false;
           stopRapidHaptic(company.id);
         }
      }
    });

    return (
      <View
        className="bg-blue-600 justify-center items-start rounded-3xl mb-4 p-5 pl-6 h-[85%]"
        style={{ width: EDIT_THRESHOLD }}
      >
        <Ionicons name="create-outline" size={24} color="#fff" />
      </View>
    );
  };

  const renderRightActions = (company: Company) => (
    <TouchableOpacity 
      onPress={() => {
        Alert.alert(
          "Delete Entity?",
          `Are you sure you want to permanently delete ${company.name} and all associated financial records?`,
          [
            { text: "Cancel", style: "cancel" },
            { text: "Delete", style: "destructive", onPress: () => handleDeleteCompany(company.id) }
          ]
        );
      }}
      className="bg-red-600 justify-center items-end rounded-3xl mb-4 p-5 w-24 pr-6 h-[85%]"
    >
      <Ionicons name="trash-outline" size={24} color="#fff" />
    </TouchableOpacity>
  );

  useEffect(() => {
    getEntrepreneurialQuote().then(setQuote);
  }, []);

  if (!state) {
    return (
      <View className="flex-1 bg-black items-center justify-center">
        <Text className="text-stone-500 font-semibold">Loading CiFr...</Text>
      </View>
    );
  }

  const handleCompanyPress = (company: Company) => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy);
    handleUpdateCompany(company.id, { lastViewed: Date.now() });
    setSelectedCompanyId(company.id);
    router.push(`/company/${company.id}`);
  };

  return (
    <SafeAreaView className="flex-1 bg-black">
      <ScrollView className="flex-1 p-4">
        {/* Header */}
        <View className="items-center mb-10 pt-2 pb-4">
          <Text className="text-5xl font-black tracking-tighter text-white">CiFr</Text>
          {quote ? (
            <Text className="mt-3 text-sm italic font-light text-stone-400 text-center px-4">
              "{quote.split(' - ')[0]}" — <Text className="font-medium not-italic">{quote.split(' - ')[1] || 'Unknown'}</Text>
            </Text>
          ) : null}
        </View>

        {/* Companies Grid */}
        <View className="mb-16">
          <Text className="text-sm font-bold text-white/40 uppercase tracking-widest px-2 mb-4">Your Companies</Text>
          
          {filteredCompanies.map((company) => {
            // Per-card ref so we can close after auto-navigate
            const swipeRef = React.createRef<Swipeable>();
            return (
            <Swipeable
              key={company.id}
              ref={swipeRef}
              renderLeftActions={(prog, drag) => renderLeftActions(company, prog, drag, swipeRef)}
              renderRightActions={() => renderRightActions(company)}
              leftThreshold={EDIT_THRESHOLD}
              rightThreshold={96}
              overshootLeft={true}
              onSwipeableWillOpen={(direction) => {
                // Now handled by drag listener
              }}
              onSwipeableOpen={(direction) => {
                if (direction === 'left') {
                  stopRapidHaptic(company.id);
                  Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                  handleUpdateCompany(company.id, { lastViewed: Date.now() });
                  setSelectedCompanyId(company.id);
                  swipeRef.current?.close();
                  router.push(`/company/${company.id}`);
                }
              }}
              onSwipeableClose={() => {
                 stopRapidHaptic(company.id);
                 autoTriggered.current[company.id] = false;
              }}
            >
              <TouchableOpacity
                activeOpacity={0.8}
                onPress={() => {
                  Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy);
                  handleUpdateCompany(company.id, { lastViewed: Date.now() });
                  setSelectedCompanyId(company.id);
                  router.push('/financials');
                }}
                className="bg-[#1C1C1E] border border-white/5 p-5 rounded-3xl mb-4 overflow-hidden relative"
              >
              <View className="flex-row items-center justify-between mb-5">
                <View className="flex-row items-center flex-1 mr-4">
                  <TouchableOpacity
                    onPress={() => handleCompanyPress(company)}
                    style={{ backgroundColor: (company.logoUrl || getFaviconUrl(company.website)) ? 'transparent' : (company.color || '#3b82f6') }}
                    className="w-12 h-12 rounded-xl items-center justify-center mr-4 overflow-hidden"
                  >
                    {(company.logoUrl || getFaviconUrl(company.website)) ? (
                      <Image source={{ uri: company.logoUrl || getFaviconUrl(company.website)! }} style={{ width: '70%', height: '70%' }} resizeMode="contain" />
                    ) : (
                      <Text style={{ color: '#fff', fontSize: 17, fontWeight: '700' }}>{company.name.charAt(0)}</Text>
                    )}
                  </TouchableOpacity>
                  <View className="flex-1">
                    <Text style={{ color: '#fff', fontSize: 17, fontWeight: '600', letterSpacing: 0 }} numberOfLines={1}>{company.name}</Text>
                    <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 12, fontWeight: '400', letterSpacing: 0, marginTop: 2 }}>{company.structure}</Text>
                  </View>
                </View>
                {/* Mo. Burn */}
                {(() => {
                  const burn = calcMonthlyBurn(company.id, state);
                  if (burn <= 0) return null;
                  return (
                    <View className="items-end">
                      <Text style={{ color: '#fff', fontSize: 17, fontWeight: '700', letterSpacing: 0 }}>
                        ${burn >= 1000 ? (burn / 1000).toFixed(1) + 'k' : burn.toFixed(0)}
                      </Text>
                      <Text style={{ color: 'rgba(255,255,255,0.3)', fontSize: 11, fontWeight: '500', letterSpacing: 0 }}>mo. burn</Text>
                    </View>
                  );
                })()}
              </View>

              <View className="flex-row items-center justify-between border-t border-white/5 pt-4">
                <View className="flex-col gap-1.5">
                  <View className="flex-row items-center gap-1.5">
                    <Ionicons name="time-outline" size={13} color="rgba(255,255,255,0.4)" />
                    <Text style={{ fontSize: 12, fontWeight: '400', color: 'rgba(255,255,255,0.4)' }}>
                      Modified: <Text style={{ color: 'rgba(255,255,255,0.8)', fontWeight: '500' }}>{getTimeAgo(company.lastModified)}</Text>
                    </Text>
                  </View>
                  <View className="flex-row items-center gap-1.5">
                    <Ionicons name="eye-outline" size={13} color="rgba(255,255,255,0.4)" />
                    <Text style={{ fontSize: 12, fontWeight: '400', color: 'rgba(255,255,255,0.4)' }}>
                      Viewed: <Text style={{ color: 'rgba(255,255,255,0.8)', fontWeight: '500' }}>{getTimeAgo(company.lastViewed)}</Text>
                    </Text>
                  </View>
                </View>

                {/* Inline Flex Shortcut Array with Inverse Margins */}
                <View style={{ marginRight: -10, marginBottom: -10 }} className="flex-row items-center justify-around bg-black/30 w-40 px-1 py-1 rounded-xl border border-white/5 shadow-xl">
                  <TouchableOpacity onPress={(e) => { e.stopPropagation(); Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy); handleUpdateCompany(company.id, { lastViewed: Date.now() }); setSelectedCompanyId(company.id); router.push('/subscriptions'); }} className="p-2">
                    <Ionicons name="layers" size={20} color="#60A5FA" />
                  </TouchableOpacity>
                  <TouchableOpacity onPress={(e) => { e.stopPropagation(); Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy); handleUpdateCompany(company.id, { lastViewed: Date.now() }); setSelectedCompanyId(company.id); router.push('/financials'); }} className="p-2">
                    <Ionicons name="card" size={20} color="#22c55e" />
                  </TouchableOpacity>
                  <TouchableOpacity onPress={(e) => { e.stopPropagation(); Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy); handleUpdateCompany(company.id, { lastViewed: Date.now() }); setSelectedCompanyId(company.id); router.push('/documents'); }} className="p-2">
                    <Ionicons name="document-text" size={20} color="#FBBF24" />
                  </TouchableOpacity>
                </View>
              </View>
            </TouchableOpacity>
            </Swipeable>
          );
          })}

          {/* Add Company Button */}
          <TouchableOpacity 
            onPress={() => {
              const newId = handleAddCompany({ name: 'New Entity', structure: 'LLC', color: '#4f46e5', logoUrl: '', website: '' });
              if (newId) {
                setSelectedCompanyId(newId);
                router.push(`/company/${newId}`);
              }
            }}
            className="border-2 border-dashed border-white/20 p-5 rounded-3xl items-center justify-center mt-4 border-opacity-50 hover:bg-white/5 bg-transparent"
          >
            <Ionicons name="add" size={28} color="rgba(255,255,255,0.4)" />
            <Text className="text-white/40 font-bold mt-2">Create New Entity</Text>
          </TouchableOpacity>
        </View>

      </ScrollView>
    </SafeAreaView>
  );
}
