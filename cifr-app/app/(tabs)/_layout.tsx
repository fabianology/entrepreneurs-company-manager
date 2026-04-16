import { Tabs, useRouter, usePathname } from 'expo-router';
import React, { useState, useMemo, useCallback, useRef } from 'react';
import * as Haptics from 'expo-haptics';
import {
  View, Text, TouchableOpacity, TextInput, Modal,
  ScrollView, Animated, Dimensions, KeyboardAvoidingView,
  Platform, Pressable, Keyboard
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
    <View style={{ position: 'absolute', bottom: 72, left: 0, right: 0, height: '65%', backgroundColor: 'rgba(17,17,17,0.97)', borderTopLeftRadius: 32, borderTopRightRadius: 32, borderTopWidth: 1, borderColor: 'rgba(255,255,255,0.1)', overflow: 'hidden', zIndex: 200 }}>
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
import Reanimated, { useSharedValue, useAnimatedStyle, withSpring, withTiming, Easing, runOnJS, interpolate } from 'react-native-reanimated';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';

// Magnifying glass icon — scales up + bleeds color as pill passes over it (sfumato)
function AnimatedTabIcon({ pillX, index, icon, color, isActive }: {
  pillX: any; index: number; icon: any; color: string; isActive: boolean;
}) {
  const iconCenterX = index * SLOT_WIDTH + SLOT_WIDTH / 2;

  const animatedProps = useAnimatedStyle(() => {
    const pillCenter = pillX.value + PILL_WIDTH / 2;
    const distance = Math.abs(pillCenter - iconCenterX);

    // Scale: magnify as glass passes over
    const scale = interpolate(
      distance,
      [0, SLOT_WIDTH * 0.8],
      [1.45, 1.0],
      { extrapolateRight: 'clamp', extrapolateLeft: 'clamp' }
    );

    // Proximity 0→full bloom over half a slot width
    const proximity = interpolate(
      distance,
      [0, SLOT_WIDTH * 0.55],
      [1.0, 0.0],
      { extrapolateRight: 'clamp', extrapolateLeft: 'clamp' }
    );

    return { transform: [{ scale }], opacity: isActive ? 1 : 0.4 + proximity * 0.6 };
  });

  // Separate animated style for the color tint on the icon wrapper
  const colorStyle = useAnimatedStyle(() => {
    const pillCenter = pillX.value + PILL_WIDTH / 2;
    const distance = Math.abs(pillCenter - iconCenterX);
    const proximity = interpolate(
      distance,
      [0, SLOT_WIDTH * 0.55],
      [1.0, 0.0],
      { extrapolateRight: 'clamp', extrapolateLeft: 'clamp' }
    );
    // Bloom glow behind icon as glass passes
    return {
      shadowColor: color,
      shadowOpacity: isActive ? 0 : proximity * 0.9,
      shadowRadius: proximity * 8,
      shadowOffset: { width: 0, height: 0 },
    };
  });

  // Since Ionicons color prop can't be animated directly, we use opacity + shadow glow
  return (
    <Reanimated.View pointerEvents="none" style={[animatedProps, colorStyle]}>
      <Ionicons name={icon} size={18} color={isActive ? color : 'rgba(255,255,255,0.4)'} />
    </Reanimated.View>
  );
}

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
    pillX.value = withTiming(safeIndex * SLOT_WIDTH + PILL_OFFSET, {
      duration: 180, easing: Easing.out(Easing.cubic)
    });
  }, [safeIndex]);

  const lastNavigatedIndex = React.useRef(safeIndex);

  const navigateTo = (index: number) => {
    if (index !== lastNavigatedIndex.current) {
      // Strong heavy snap when landing on new page
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy);
      lastNavigatedIndex.current = index;
    }
    navigation.navigate(TAB_CONFIGS[index].name);
  };

  // Subtle tick as pill crosses slot boundaries during drag
  const lastDragSlot = React.useRef(safeIndex);
  const selectionHaptic = () => Haptics.selectionAsync();

  const pillScale = useSharedValue(1);

  const panGesture = Gesture.Pan()
    .onBegin(() => {
      startX.value = pillX.value;
      // Expand pill on touch with crisp spring
      pillScale.value = withSpring(1.35, { damping: 20, stiffness: 350 });
    })
    .onUpdate((e) => {
      const next = startX.value + e.translationX;
      pillX.value = Math.max(MIN_X, Math.min(MAX_X, next));
      // Tick haptic each time pill crosses a slot boundary
      const currentSlot = Math.round((pillX.value - PILL_OFFSET) / SLOT_WIDTH);
      const clamped = Math.max(0, Math.min(TAB_COUNT - 1, currentSlot));
      if (clamped !== lastDragSlot.current) {
        lastDragSlot.current = clamped;
        runOnJS(selectionHaptic)();
      }
    })
    .onEnd(() => {
      // Snap to nearest slot crisply
      const slot = Math.round((pillX.value - PILL_OFFSET) / SLOT_WIDTH);
      const clamped = Math.max(0, Math.min(TAB_COUNT - 1, slot));
      // Rigid, quick slide with zero bounce
      pillX.value = withTiming(clamped * SLOT_WIDTH + PILL_OFFSET, {
        duration: 200, easing: Easing.out(Easing.cubic)
      });
      // Shrink back with crisp snap
      pillScale.value = withTiming(1.0, { duration: 150, easing: Easing.out(Easing.cubic) });
      runOnJS(navigateTo)(clamped);
    });

  const pillStyle = useAnimatedStyle(() => ({
    transform: [
      { translateX: pillX.value },
      { scale: pillScale.value },
    ],
  }));

  if (pathname === '/') return null;

  // Compose pan + tap as simultaneous so both work on the same container
  const tapGesture = Gesture.Tap().onEnd((e) => {
    const slot = Math.floor(e.x / SLOT_WIDTH);
    const clamped = Math.max(0, Math.min(TAB_COUNT - 1, slot));
    pillX.value = withTiming(clamped * SLOT_WIDTH + PILL_OFFSET, {
      duration: 180, easing: Easing.out(Easing.cubic)
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
          backgroundColor: 'rgba(28,28,30,0.65)',
          borderRadius: 22,
          borderWidth: 1,
          borderColor: 'rgba(255,255,255,0.15)',
          flexDirection: 'row',
          alignItems: 'center',
          shadowColor: '#000',
          shadowOpacity: 0.5,
          shadowRadius: 20,
          elevation: 10,
          zIndex: 50,
          overflow: 'visible',
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
              overflow: 'hidden',
              // Glass base — nearly transparent fill
              backgroundColor: 'rgba(255,255,255,0.04)',
              // Bright perimeter border simulates glass edge refraction
              borderWidth: 1,
              borderColor: 'rgba(255,255,255,0.45)',
            },
          ]}
        >
          {/* Top specular highlight — the bright streak across real glass */}
          <View
            pointerEvents="none"
            style={{
              position: 'absolute',
              top: 0,
              left: 6,
              right: 6,
              height: 1.5,
              borderRadius: 1,
              backgroundColor: 'rgba(255,255,255,0.7)',
            }}
          />
          {/* Inner body — clear glass fill, no tint */}
          <View
            pointerEvents="none"
            style={{
              position: 'absolute',
              top: 2,
              left: 4,
              right: 4,
              bottom: 4,
              borderRadius: 16,
              backgroundColor: 'rgba(255,255,255,0.04)',
            }}
          />
          {/* Bottom inner shadow — gives the pill depth */}
          <View
            pointerEvents="none"
            style={{
              position: 'absolute',
              bottom: 0,
              left: 6,
              right: 6,
              height: 1,
              borderRadius: 1,
              backgroundColor: 'rgba(0,0,0,0.25)',
            }}
          />
        </Reanimated.View>

        {/* Icon labels — magnified by glass pill as it passes over */}
        {TAB_CONFIGS.map((tab, i) => {
          const isActive = i === safeIndex;
          return (
            <View
              key={tab.name}
              pointerEvents="none"
              style={{ width: SLOT_WIDTH, alignItems: 'center', justifyContent: 'center', height: '100%' }}
            >
              <AnimatedTabIcon
                pillX={pillX}
                index={i}
                icon={tab.icon}
                color={tab.color}
                isActive={isActive}
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

  // Store ref to input so we can pop keyboard back up if drag is aborted
  const searchInputRef = useRef<TextInput>(null);


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
  const TABS = ['subscriptions', 'financials', 'documents'];

  // Edge-swipe navigation — only fires when gesture begins within 60px of screen edge
  const swipeStartX = useRef(0);
  const swipeHandled = useRef(false);

  const currentTabIndex = TABS.indexOf(pathname.replace('/', ''));

  const navigateBySwipe = useCallback((direction: 'left' | 'right') => {
    const idx = currentTabIndex < 0 ? 0 : currentTabIndex;
    if (direction === 'right' && idx === 0) {
      // Swiping right from subscriptions → go to dashboard
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
      setSelectedCompanyId(null);
      setActiveView('dashboard');
      router.push('/');
      return;
    }
    const next = direction === 'left' ? Math.min(idx + 1, TABS.length - 1) : Math.max(idx - 1, 0);
    if (next !== idx) {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
      router.push(`/${TABS[next]}` as any);
    }
  }, [currentTabIndex, router, setSelectedCompanyId, setActiveView]);

  const edgeSwipeGesture = Gesture.Pan()
    .onBegin((e) => {
      swipeStartX.current = e.x;
      swipeHandled.current = false;
    })
    .onUpdate((e) => {
      if (swipeHandled.current) return;
      const isEdgeSwipe = swipeStartX.current < 60 || swipeStartX.current > SCREEN_WIDTH - 60;
      if (!isEdgeSwipe) return;
      if (Math.abs(e.translationX) > 50 && Math.abs(e.translationY) < 60) {
        swipeHandled.current = true;
        runOnJS(navigateBySwipe)(e.translationX < 0 ? 'left' : 'right');
      }
    })
    .minDistance(30)
    .activeOffsetX([-20, 20])
    .enabled(pathname !== '/');

  return (
    <GestureDetector gesture={edgeSwipeGesture}>
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

      {/* ── Search Bar (dynamic width based on page) ── */}
      <TouchableOpacity
        onPress={() => {
          Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
          setShowSearch(true);
        }}
        activeOpacity={0.85}
        hitSlop={{ top: 4, bottom: 4, left: 0, right: 0 }}
        style={{
          position: 'absolute',
          bottom: BOTTOM,
          left: pathname === '/' ? 20 : 20 + 44 + 8,
          right: pathname === '/' ? 20 : 20 + TAB_WIDTH + 8,
          height: 44,
          backgroundColor: 'rgba(28,28,30,0.65)',
          borderRadius: 22,
          borderWidth: 1,
          borderColor: 'rgba(255,255,255,0.15)',
          flexDirection: 'row',
          alignItems: 'center',
          paddingHorizontal: 12,
          gap: 6,
          zIndex: 50,
        }}
      >
        <Ionicons name="search" size={15} color="rgba(255,255,255,0.4)" />
        <Text style={{ color: 'rgba(255,255,255,0.5)', fontSize: 15, fontWeight: '400' }}>Search</Text>
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
          onPress={() => {
            Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
            setTimeout(() => Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light), 80);
            setTimeout(() => Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light), 160);
            setShowMenu(v => !v);
          }}
          style={{
            position: 'absolute',
            bottom: BOTTOM,
            left: 20,
            width: 44,
            height: 44,
            backgroundColor: showMenu ? 'rgba(255,255,255,0.25)' : 'rgba(28,28,30,0.65)',
            borderRadius: 22,
            borderWidth: 1,
            borderColor: 'rgba(255,255,255,0.15)',
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
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : 'height'} style={{ flex: 1 }}>
          <Pressable style={{ flex: 1, backgroundColor: 'rgba(0,0,0,0.7)' }} onPress={() => { setShowSearch(false); setSearchQuery(''); }}>
            <Pressable onPress={() => {}} style={{ flex: 1, justifyContent: 'flex-end' }}>
              {/* Search Input Bar pinned to keyboard */}
              <View style={{ width: '100%', zIndex: 300 }}>
                {searchQuery.length > 0 && (
                  <SearchResultsSheet
                    onClose={() => { setShowSearch(false); setSearchQuery(''); }}
                    onSelectCompany={handleSelectCompanyFromSearch}
                    onSelectSub={handleSelectSub}
                    onSelectFinancial={handleSelectFinancial}
                  />
                )}
                
                <GestureDetector gesture={
                  Gesture.Pan()
                    .runOnJS(true)
                    .onUpdate((e) => {
                      if (e.translationY > 5) {
                        Keyboard.dismiss();
                      }
                    })
                    .onEnd((e) => {
                      if (e.translationY > 40 || e.velocityY > 500) {
                        setShowSearch(false);
                        setSearchQuery('');
                      } else {
                        // Snap back up if aborted
                        searchInputRef.current?.focus();
                      }
                    })
                }>
                  <View style={{ backgroundColor: '#000', paddingTop: 10, paddingBottom: 10 }}>
                    {/* Drag Handle */}
                    <View style={{ alignItems: 'center', marginBottom: 12 }}>
                      <View style={{ width: 40, height: 4, borderRadius: 2, backgroundColor: 'rgba(255,255,255,0.2)' }} />
                    </View>

                    <View style={{ flexDirection: 'row', alignItems: 'center', marginHorizontal: 20, gap: 10 }}>
                      <View style={{ flex: 1, flexDirection: 'row', alignItems: 'center', backgroundColor: '#1C1C1E', borderRadius: 18, borderWidth: 1, borderColor: 'rgba(255,255,255,0.1)', height: 36, paddingHorizontal: 14, gap: 8 }}>
                        <Ionicons name="search" size={16} color="rgba(255,255,255,0.4)" />
                        <TextInput
                          ref={searchInputRef}
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
                          <TouchableOpacity onPress={() => { Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light); setSearchQuery(''); }}>
                            <Ionicons name="close-circle" size={16} color="rgba(255,255,255,0.3)" />
                          </TouchableOpacity>
                        )}
                      </View>
                      
                      {/* Separate Close Button */}
                      <TouchableOpacity onPress={() => { Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light); setShowSearch(false); setSearchQuery(''); }} style={{ width: 36, height: 36, borderRadius: 18, backgroundColor: 'rgba(255,255,255,0.1)', alignItems: 'center', justifyContent: 'center' }}>
                        <Ionicons name="close" size={20} color="#fff" />
                      </TouchableOpacity>
                    </View>
                  </View>
                </GestureDetector>

              </View>
            </Pressable>
          </Pressable>
        </KeyboardAvoidingView>
      </Modal>
    </View>
    </GestureDetector>
  );
}
