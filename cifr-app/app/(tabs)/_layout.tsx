import { Tabs, useRouter, usePathname } from 'expo-router';
import React, { useState, useMemo } from 'react';
import {
  View, Text, TouchableOpacity, TextInput, Modal,
  ScrollView, Animated, Dimensions, KeyboardAvoidingView,
  Platform, Pressable
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { HapticTab } from '@/components/haptic-tab';
import { useAppContext } from '../../context/AppContext';

const SCREEN_WIDTH = Dimensions.get('window').width;

// ──────────── Search Results Sheet ────────────
function SearchResultsSheet({
  onClose,
  onSelectCompany,
  onSelectSub,
  onSelectFinancial,
}: {
  onClose: () => void;
  onSelectCompany: (id: string) => void;
  onSelectSub: (id: string, companyId: string) => void;
  onSelectFinancial: (id: string, companyId: string) => void;
}) {
  const { globalSearchResults } = useAppContext();
  if (!globalSearchResults) return null;

  const { companies, subscriptions, financials, hasResults } = globalSearchResults;

  return (
    <View style={{ position: 'absolute', bottom: 0, left: 0, right: 0, height: '65%', backgroundColor: 'rgba(17,17,17,0.97)', borderTopLeftRadius: 32, borderTopRightRadius: 32, borderTopWidth: 1, borderColor: 'rgba(255,255,255,0.1)', overflow: 'hidden', zIndex: 200 }}>
      {/* Handle */}
      <View style={{ alignItems: 'center', paddingTop: 12, paddingBottom: 8 }}>
        <View style={{ width: 40, height: 4, borderRadius: 2, backgroundColor: 'rgba(255,255,255,0.2)' }} />
      </View>
      <ScrollView contentContainerStyle={{ padding: 24, paddingBottom: 48 }}>
        {!hasResults ? (
          <View style={{ alignItems: 'center', paddingVertical: 48 }}>
            <Ionicons name="search" size={40} color="rgba(255,255,255,0.2)" />
            <Text style={{ color: 'rgba(255,255,255,0.4)', fontWeight: '600', fontSize: 16, marginTop: 16 }}>No results found</Text>
            <Text style={{ color: 'rgba(255,255,255,0.25)', fontSize: 13, marginTop: 4 }}>Try a company, service, or keyword</Text>
          </View>
        ) : (
          <View style={{ gap: 28 }}>
            {companies.length > 0 && (
              <View style={{ gap: 8 }}>
                <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 11, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 3, marginLeft: 4 }}>Companies</Text>
                {companies.map(c => (
                  <TouchableOpacity key={c.id} onPress={() => onSelectCompany(c.id)}
                    style={{ flexDirection: 'row', alignItems: 'center', padding: 12, borderRadius: 16, borderWidth: 1, borderColor: 'rgba(255,255,255,0.1)' }}>
                    <View style={{ width: 40, height: 40, borderRadius: 12, backgroundColor: c.color, alignItems: 'center', justifyContent: 'center', marginRight: 12 }}>
                      <Text style={{ color: '#fff', fontWeight: '700', fontSize: 16 }}>{c.name.charAt(0)}</Text>
                    </View>
                    <View style={{ flex: 1 }}>
                      <Text style={{ color: '#fff', fontWeight: '700', fontSize: 15 }}>{c.name}</Text>
                      <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 12, fontWeight: '500' }}>{c.structure}</Text>
                    </View>
                    <Ionicons name="chevron-forward" size={16} color="rgba(255,255,255,0.2)" />
                  </TouchableOpacity>
                ))}
              </View>
            )}
            {subscriptions.length > 0 && (
              <View style={{ gap: 8 }}>
                <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 11, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 3, marginLeft: 4 }}>Subscriptions</Text>
                <View style={{ backgroundColor: 'rgba(255,255,255,0.05)', borderRadius: 16, borderWidth: 1, borderColor: 'rgba(255,255,255,0.1)', overflow: 'hidden' }}>
                  {subscriptions.map((s, i) => (
                    <TouchableOpacity key={s.id} onPress={() => onSelectSub(s.id, s.companyId)}
                      style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', padding: 16, borderTopWidth: i > 0 ? 1 : 0, borderTopColor: 'rgba(255,255,255,0.05)' }}>
                      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
                        <View style={{ backgroundColor: 'rgba(31,228,0,0.1)', padding: 8, borderRadius: 12 }}>
                          <Ionicons name="card" size={18} color="#1FE400" />
                        </View>
                        <View>
                          <Text style={{ color: '#fff', fontWeight: '700', fontSize: 14 }}>{s.name}</Text>
                          <Text style={{ color: 'rgba(255,255,255,0.4)', fontWeight: '700', fontSize: 11, fontFamily: 'monospace' }}>${s.cost}/mo</Text>
                        </View>
                      </View>
                      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
                        <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 10, fontWeight: '700', textTransform: 'uppercase', backgroundColor: 'rgba(255,255,255,0.1)', paddingHorizontal: 8, paddingVertical: 4, borderRadius: 8 }}>{s.companyName}</Text>
                        <Ionicons name="chevron-forward" size={14} color="#1FE400" />
                      </View>
                    </TouchableOpacity>
                  ))}
                </View>
              </View>
            )}
            {financials.length > 0 && (
              <View style={{ gap: 8 }}>
                <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 11, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 3, marginLeft: 4 }}>Financials</Text>
                <View style={{ backgroundColor: 'rgba(255,255,255,0.05)', borderRadius: 16, borderWidth: 1, borderColor: 'rgba(255,255,255,0.1)', overflow: 'hidden' }}>
                  {financials.map((f, i) => (
                    <TouchableOpacity key={f.id} onPress={() => onSelectFinancial(f.id, f.companyId)}
                      style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', padding: 16, borderTopWidth: i > 0 ? 1 : 0, borderTopColor: 'rgba(255,255,255,0.05)' }}>
                      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
                        <View style={{ backgroundColor: 'rgba(255,255,255,0.08)', padding: 8, borderRadius: 12 }}>
                          <Text style={{ fontSize: 18 }}>{f.icon}</Text>
                        </View>
                        <View>
                          <Text style={{ color: '#fff', fontWeight: '700', fontSize: 14 }}>{f.name}</Text>
                          <Text style={{ color: 'rgba(255,255,255,0.4)', fontWeight: '700', fontSize: 11, fontFamily: 'monospace' }}>{f.subtext}</Text>
                        </View>
                      </View>
                      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
                        <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 10, fontWeight: '700', textTransform: 'uppercase', backgroundColor: 'rgba(255,255,255,0.1)', paddingHorizontal: 8, paddingVertical: 4, borderRadius: 8 }}>{f.companyName}</Text>
                        <Ionicons name="chevron-forward" size={14} color="rgba(235,195,81,1)" />
                      </View>
                    </TouchableOpacity>
                  ))}
                </View>
              </View>
            )}
          </View>
        )}
      </ScrollView>
    </View>
  );
}

// ──────────── Quick Menu Popover ────────────
function QuickMenuPopover({ onSelectDashboard, onSelectCompany }: {
  onSelectDashboard: () => void;
  onSelectCompany: (id: string) => void;
}) {
  const { state, selectedCompanyId } = useAppContext();
  if (!state) return null;

  return (
    <View style={{
      backgroundColor: 'rgba(17,17,17,0.97)',
      borderRadius: 18,
      borderWidth: 1,
      borderColor: 'rgba(255,255,255,0.1)',
      overflow: 'hidden',
      width: 240,
      padding: 8,
      shadowColor: '#000',
      shadowOpacity: 0.6,
      shadowRadius: 24,
      elevation: 20,
    }}>
      {/* Dashboard row + gear */}
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6, marginBottom: 2 }}>
        <TouchableOpacity
          onPress={onSelectDashboard}
          style={{
            flex: 1, flexDirection: 'row', alignItems: 'center', gap: 12,
            paddingHorizontal: 14, paddingVertical: 12, borderRadius: 12,
            backgroundColor: 'rgba(255,255,255,0.04)',
          }}
        >
          <Ionicons name="grid" size={18} color="rgba(255,255,255,0.65)" />
          <Text style={{ color: 'rgba(255,255,255,0.85)', fontWeight: '600', fontSize: 14 }}>Dashboard</Text>
        </TouchableOpacity>
        <TouchableOpacity
          onPress={() => {/* admin backend — coming soon */}}
          style={{
            width: 42, height: 42, borderRadius: 12,
            backgroundColor: 'rgba(255,255,255,0.04)',
            alignItems: 'center', justifyContent: 'center',
          }}
        >
          <Ionicons name="settings-outline" size={18} color="rgba(255,255,255,0.5)" />
        </TouchableOpacity>
      </View>

      {/* Companies */}
      {state.companies.length > 0 && (
        <View>
          <Text style={{ color: 'rgba(255,255,255,0.3)', fontSize: 11, fontWeight: '500', letterSpacing: 0, paddingHorizontal: 8, paddingVertical: 6 }}>
            Jump to Company
          </Text>
          {state.companies.map(c => (
            <TouchableOpacity
              key={c.id}
              onPress={() => onSelectCompany(c.id)}
              style={{
                flexDirection: 'row', alignItems: 'center', gap: 12,
                paddingHorizontal: 14, paddingVertical: 10, borderRadius: 12,
                backgroundColor: selectedCompanyId === c.id ? 'rgba(255,255,255,0.08)' : 'transparent',
                marginBottom: 2,
              }}
            >
              <Text style={{ color: 'rgba(255,255,255,0.7)', fontWeight: '600', fontSize: 14, flex: 1 }}>
                {c.name}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      )}
    </View>
  );
}

// ──────────── Custom Tab Bar ────────────
import Reanimated, { useSharedValue, useAnimatedStyle, withSpring, runOnJS } from 'react-native-reanimated';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';

const TAB_WIDTH = 180;
const TAB_COUNT = 3;
const SLOT_WIDTH = TAB_WIDTH / TAB_COUNT; // 60px each
const PILL_WIDTH = 52;
const PILL_OFFSET = (SLOT_WIDTH - PILL_WIDTH) / 2; // centers pill in slot
const MIN_X = PILL_OFFSET;
const MAX_X = TAB_WIDTH - PILL_WIDTH - PILL_OFFSET;

const TAB_CONFIGS = [
  { name: 'subscriptions', icon: 'layers' as const, color: '#60A5FA' },
  { name: 'financials', icon: 'card' as const, color: '#22c55e' },
  { name: 'documents', icon: 'document-text' as const, color: '#FBBF24' },
];

function CustomTabBar({ state, navigation }: { state: any; navigation: any }) {
  const pathname = usePathname();
  const insets = useSafeAreaInsets();
  const BOTTOM = insets.bottom + 12;

  const activeTabIndex = TAB_CONFIGS.findIndex(
    (t) => t.name === state.routes[state.index]?.name
  );
  const safeIndex = activeTabIndex < 0 ? 0 : activeTabIndex;

  const pillX = useSharedValue(safeIndex * SLOT_WIDTH + PILL_OFFSET);
  const startX = useSharedValue(0);

  // Sync pill when tab changes externally (e.g. tap on icon)
  React.useEffect(() => {
    pillX.value = withSpring(safeIndex * SLOT_WIDTH + PILL_OFFSET, {
      damping: 18, stiffness: 180, mass: 0.6,
    });
  }, [safeIndex]);

  const navigateTo = (index: number) => {
    navigation.navigate(TAB_CONFIGS[index].name);
  };

  const panGesture = Gesture.Pan()
    .onBegin(() => {
      startX.value = pillX.value;
    })
    .onUpdate((e) => {
      const next = startX.value + e.translationX;
      pillX.value = Math.max(MIN_X, Math.min(MAX_X, next));
    })
    .onEnd(() => {
      // Snap to nearest slot
      const slot = Math.round((pillX.value - PILL_OFFSET) / SLOT_WIDTH);
      const clamped = Math.max(0, Math.min(TAB_COUNT - 1, slot));
      pillX.value = withSpring(clamped * SLOT_WIDTH + PILL_OFFSET, {
        damping: 18, stiffness: 200, mass: 0.5,
      });
      runOnJS(navigateTo)(clamped);
    });

  const pillStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: pillX.value }],
  }));

  if (pathname === '/') return null;

  // Compose pan + tap as simultaneous so both work on the same container
  const tapGesture = Gesture.Tap().onEnd((e) => {
    const slot = Math.floor(e.x / SLOT_WIDTH);
    const clamped = Math.max(0, Math.min(TAB_COUNT - 1, slot));
    pillX.value = withSpring(clamped * SLOT_WIDTH + PILL_OFFSET, {
      damping: 18, stiffness: 200, mass: 0.5,
    });
    runOnJS(navigateTo)(clamped);
  });

  const composed = Gesture.Simultaneous(panGesture, tapGesture);

  return (
    <GestureDetector gesture={composed}>
      <Reanimated.View
        style={{
          position: 'absolute',
          bottom: BOTTOM,
          right: 20,
          width: TAB_WIDTH,
          height: 44,
          backgroundColor: '#1C1C1E',
          borderRadius: 22,
          borderWidth: 1,
          borderColor: 'rgba(255,255,255,0.1)',
          flexDirection: 'row',
          alignItems: 'center',
          shadowColor: '#000',
          shadowOpacity: 0.5,
          shadowRadius: 20,
          elevation: 10,
          zIndex: 50,
          overflow: 'hidden',
        }}
      >
        {/* Liquid glass pill — purely visual, no touch interception */}
        <Reanimated.View
          pointerEvents="none"
          style={[
            pillStyle,
            {
              position: 'absolute',
              width: PILL_WIDTH,
              height: 36,
              top: 4,
              borderRadius: 18,
              backgroundColor: 'rgba(255,255,255,0.13)',
              borderWidth: 1,
              borderColor: 'rgba(255,255,255,0.28)',
            },
          ]}
        />

        {/* Icon labels — visual only, gestures handled by container */}
        {TAB_CONFIGS.map((tab, i) => {
          const isActive = i === safeIndex;
          return (
            <View
              key={tab.name}
              pointerEvents="none"
              style={{ width: SLOT_WIDTH, alignItems: 'center', justifyContent: 'center', height: '100%' }}
            >
              <Ionicons
                name={tab.icon}
                size={18}
                color={isActive ? tab.color : 'rgba(255,255,255,0.4)'}
              />
            </View>
          );
        })}
      </Reanimated.View>
    </GestureDetector>
  );
}


// ──────────── Root Tab Layout ────────────
export default function TabLayout() {
  const router = useRouter();
  const pathname = usePathname();
  const insets = useSafeAreaInsets();
  const { state, setSelectedCompanyId, setActiveView, searchQuery, setSearchQuery } = useAppContext();

  const [showMenu, setShowMenu] = useState(false);
  const [showSearch, setShowSearch] = useState(false);


  const handleSelectCompany = (id: string) => {
    setSelectedCompanyId(id);
    setActiveView('company');
    setShowMenu(false);
    router.push('/subscriptions');
  };

  const handleSelectDashboard = () => {
    setSelectedCompanyId(null);
    setActiveView('dashboard');
    setShowMenu(false);
    router.push('/');
  };

  const handleSelectSub = (id: string, companyId: string) => {
    setSelectedCompanyId(companyId);
    setActiveView('company');
    setShowSearch(false);
    setSearchQuery('');
    router.push('/subscriptions');
  };

  const handleSelectFinancial = (id: string, companyId: string) => {
    setSelectedCompanyId(companyId);
    setActiveView('company');
    setShowSearch(false);
    setSearchQuery('');
    router.push('/financials');
  };

  const handleSelectCompanyFromSearch = (id: string) => {
    setSelectedCompanyId(id);
    setActiveView('company');
    setShowSearch(false);
    setSearchQuery('');
    router.push('/subscriptions');
  };

  const BOTTOM = insets.bottom + 12;

  return (
    <View style={{ flex: 1, backgroundColor: '#000' }}>
      <Tabs
        sceneContainerStyle={{ backgroundColor: 'transparent' }}
        tabBar={(props) => <CustomTabBar {...props} />}
        screenOptions={{
          headerShown: false,
        }}>
        <Tabs.Screen name="index" options={{ href: null }} />
        <Tabs.Screen name="subscriptions" options={{}} />
        <Tabs.Screen name="financials" options={{}} />
        <Tabs.Screen name="documents" options={{}} />
      </Tabs>

      {/* ── Search Bar (full width, above nav row) ── */}
      <TouchableOpacity
        onPress={() => { setShowSearch(true); }}
        activeOpacity={0.85}
        hitSlop={{ top: 8, bottom: 8, left: 0, right: 0 }}
        style={{
          position: 'absolute',
          bottom: pathname === '/' ? BOTTOM : BOTTOM + 44 + 10,
          left: 20,
          right: 20,
          height: 36,
          backgroundColor: '#1C1C1E',
          borderRadius: 18,
          borderWidth: 1,
          borderColor: 'rgba(255,255,255,0.1)',
          flexDirection: 'row',
          alignItems: 'center',
          paddingHorizontal: 14,
          gap: 8,
          zIndex: 50,
        }}
      >
        <Ionicons name="search" size={16} color="rgba(255,255,255,0.4)" />
        <Text style={{ color: 'rgba(255,255,255,0.5)', fontSize: 17, fontWeight: '400' }}>Search</Text>
      </TouchableOpacity>

      {/* ── Tap-outside dismiss overlay ── */}
      {showMenu && (
        <Pressable
          onPress={() => setShowMenu(false)}
          style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, zIndex: 49 }}
        />
      )}

      {/* ── Quick Menu Popover (above button) ── */}
      {showMenu && (
        <View style={{
          position: 'absolute',
          bottom: BOTTOM + 44 + 10,
          left: 20,
          zIndex: 100,
        }}>
          <QuickMenuPopover
            onSelectDashboard={handleSelectDashboard}
            onSelectCompany={handleSelectCompany}
          />
        </View>
      )}

      {/* ── Menu Button (right) ── */}
      {pathname !== '/' && (
        <TouchableOpacity
          onPress={() => setShowMenu(v => !v)}
          style={{
            position: 'absolute',
            bottom: BOTTOM,
            left: 20,
            width: 44,
            height: 44,
            backgroundColor: showMenu ? 'rgba(255,255,255,0.15)' : '#1C1C1E',
            borderRadius: 22,
            borderWidth: 1,
            borderColor: 'rgba(255,255,255,0.1)',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 101,
          }}
        >
          <Ionicons name={showMenu ? 'close' : 'menu'} size={24} color="#fff" />
        </TouchableOpacity>
      )}

      {/* ── Search Modal ── */}
      <Modal visible={showSearch} transparent animationType="fade" onRequestClose={() => { setShowSearch(false); setSearchQuery(''); }}>
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} keyboardVerticalOffset={0} style={{ flex: 1 }}>
          <Pressable style={{ flex: 1, backgroundColor: 'rgba(0,0,0,0.7)' }} onPress={() => { setShowSearch(false); setSearchQuery(''); }}>
            <Pressable onPress={() => {}} style={{ flex: 1 }}>
              {/* Search Input Bar pinned to keyboard */}
              <View style={{ position: 'absolute', bottom: 0, left: 0, right: 0, zIndex: 300 }}>
                {searchQuery.length > 0 && (
                  <SearchResultsSheet
                    onClose={() => { setShowSearch(false); setSearchQuery(''); }}
                    onSelectCompany={handleSelectCompanyFromSearch}
                    onSelectSub={handleSelectSub}
                    onSelectFinancial={handleSelectFinancial}
                  />
                )}
                
                <View style={{ flexDirection: 'row', alignItems: 'center', marginHorizontal: 20, marginBottom: 10, gap: 10 }}>
                  <View style={{ flex: 1, flexDirection: 'row', alignItems: 'center', backgroundColor: '#1C1C1E', borderRadius: 18, borderWidth: 1, borderColor: 'rgba(255,255,255,0.1)', height: 36, paddingHorizontal: 14, gap: 8 }}>
                    <Ionicons name="search" size={16} color="rgba(255,255,255,0.4)" />
                    <TextInput
                      style={{ flex: 1, color: '#fff', fontSize: 17, fontWeight: '400' }}
                      placeholder="Search"
                      placeholderTextColor="rgba(255,255,255,0.25)"
                      value={searchQuery}
                      onChangeText={setSearchQuery}
                      autoFocus
                      returnKeyType="search"
                      onSubmitEditing={() => { setShowSearch(false); setSearchQuery(''); }}
                    />
                    {searchQuery.length > 0 && (
                      <TouchableOpacity onPress={() => setSearchQuery('')}>
                        <Ionicons name="close-circle" size={16} color="rgba(255,255,255,0.3)" />
                      </TouchableOpacity>
                    )}
                  </View>
                  
                  {/* Separate Close Button */}
                  <TouchableOpacity onPress={() => { setShowSearch(false); setSearchQuery(''); }} style={{ width: 36, height: 36, borderRadius: 18, backgroundColor: 'rgba(255,255,255,0.1)', alignItems: 'center', justifyContent: 'center' }}>
                    <Ionicons name="close" size={20} color="#fff" />
                  </TouchableOpacity>
                </View>

              </View>
            </Pressable>
          </Pressable>
        </KeyboardAvoidingView>
      </Modal>
    </View>
  );
}
