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
  query,
  onClose,
  onSelectCompany,
  onSelectSub,
  onSelectFinancial,
}: {
  query: string;
  onClose: () => void;
  onSelectCompany: (id: string) => void;
  onSelectSub: (id: string, companyId: string) => void;
  onSelectFinancial: (id: string, companyId: string) => void;
}) {
  const { state } = useAppContext();
  if (!state) return null;
  const q = query.toLowerCase();

  const companies = state.companies.filter(c =>
    c.name?.toLowerCase().includes(q) ||
    c.structure?.toLowerCase().includes(q) ||
    c.description?.toLowerCase().includes(q)
  );

  const subscriptions = state.subscriptions
    .filter(s => s.name?.toLowerCase().includes(q))
    .map(s => ({
      ...s,
      companyName: state.companies.find(c => c.id === s.companyId)?.name,
      companyColor: state.companies.find(c => c.id === s.companyId)?.color,
    }));

  const financials = [
    ...(state.institutions || []).filter(i => i.name?.toLowerCase().includes(q))
      .map(i => ({ id: i.id, companyId: i.companyId, name: i.name, subtext: 'Institution', icon: '🏦' })),
    ...state.financialCards.filter(c => c.name?.toLowerCase().includes(q) || c.institutionName?.toLowerCase().includes(q))
      .map(c => ({ id: c.id, companyId: c.companyId, name: c.name, subtext: `Card •••• ${c.last4}`, icon: '💳' })),
    ...state.loans.filter(l => l.name?.toLowerCase().includes(q) || l.lender?.toLowerCase().includes(q))
      .map(l => ({ id: l.id, companyId: l.companyId, name: l.name, subtext: `Loan • ${l.lender}`, icon: '📑' })),
  ].map(f => ({
    ...f,
    companyName: state.companies.find(c => c.id === f.companyId)?.name,
    companyColor: state.companies.find(c => c.id === f.companyId)?.color,
  }));

  const hasResults = companies.length > 0 || subscriptions.length > 0 || financials.length > 0;

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
      {/* Dashboard row */}
      <TouchableOpacity
        onPress={onSelectDashboard}
        style={{
          flexDirection: 'row', alignItems: 'center', gap: 12,
          paddingHorizontal: 14, paddingVertical: 12, borderRadius: 12,
          backgroundColor: 'rgba(255,255,255,0.04)',
          marginBottom: 2,
        }}
      >
        <Ionicons name="grid" size={18} color="rgba(255,255,255,0.65)" />
        <Text style={{ color: 'rgba(255,255,255,0.85)', fontWeight: '600', fontSize: 14 }}>Dashboard</Text>
      </TouchableOpacity>

      {/* Companies */}
      {state.companies.length > 0 && (
        <View>
          <Text style={{ color: 'rgba(255,255,255,0.3)', fontSize: 9, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 2, paddingHorizontal: 8, paddingVertical: 6 }}>
            Jump to Company
          </Text>
          {state.companies.map(c => (
            <TouchableOpacity
              key={c.id}
              onPress={() => onSelectCompany(c.id)}
              style={{
                flexDirection: 'row', alignItems: 'center', gap: 12,
                paddingHorizontal: 14, paddingVertical: 10, borderRadius: 12,
                backgroundColor: selectedCompanyId === c.id ? '#EBC351' : 'transparent',
                marginBottom: 2,
              }}
            >
              <View style={{ width: 8, height: 8, borderRadius: 4, backgroundColor: c.color, borderWidth: 1.5, borderColor: 'rgba(255,255,255,0.25)' }} />
              <Text style={{ color: selectedCompanyId === c.id ? '#000' : 'rgba(255,255,255,0.7)', fontWeight: '600', fontSize: 14, flex: 1 }}>
                {c.name}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      )}
    </View>
  );
}

// ──────────── Root Tab Layout ────────────
export default function TabLayout() {
  const router = useRouter();
  const pathname = usePathname();
  const insets = useSafeAreaInsets();
  const { state, setSelectedCompanyId, setActiveView } = useAppContext();

  const [showMenu, setShowMenu] = useState(false);
  const [showSearch, setShowSearch] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');

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
        screenOptions={{
          tabBarActiveTintColor: '#EBC351',
          tabBarInactiveTintColor: 'rgba(255,255,255,0.4)',
          headerShown: false,
          tabBarButton: HapticTab,
          tabBarShowLabel: false,
          tabBarStyle: {
            position: 'absolute',
            bottom: BOTTOM,
            left: 20,
            width: 180,
            backgroundColor: '#1C1C1E',
            borderRadius: 40,
            height: 32,
            borderTopWidth: 0,
            borderWidth: 1,
            borderColor: 'rgba(255,255,255,0.1)',
            shadowColor: '#000',
            shadowOpacity: 0.5,
            shadowRadius: 20,
            elevation: 10,
            paddingBottom: 0,
          },
          tabBarItemStyle: { justifyContent: 'center', alignItems: 'center' }
        }}>
        <Tabs.Screen name="index" options={{ href: null, tabBarIcon: ({ color }) => <Ionicons size={20} name="home" color={color} /> }} />
        <Tabs.Screen name="subscriptions" options={{ tabBarIcon: ({ color }) => <Ionicons size={20} name="layers" color={color} /> }} />
        <Tabs.Screen name="financials" options={{ tabBarIcon: ({ color }) => <Ionicons size={20} name="card" color={color} /> }} />
        <Tabs.Screen name="documents" options={{ tabBarIcon: ({ color }) => <Ionicons size={20} name="document-text" color={color} /> }} />
      </Tabs>

      {/* ── Search Bar (full width, above nav row) ── */}
      <TouchableOpacity
        onPress={() => { setShowSearch(true); }}
        activeOpacity={0.85}
        style={{
          position: 'absolute',
          bottom: BOTTOM + 32 + 10,
          left: 20,
          right: 20,
          height: 32,
          backgroundColor: '#1C1C1E',
          borderRadius: 40,
          borderWidth: 1,
          borderColor: 'rgba(255,255,255,0.1)',
          flexDirection: 'row',
          alignItems: 'center',
          paddingHorizontal: 14,
          gap: 8,
          zIndex: 50,
        }}
      >
        <Ionicons name="search" size={13} color="rgba(255,255,255,0.3)" />
        <Text style={{ color: 'rgba(255,255,255,0.25)', fontSize: 11, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 2 }}>Search</Text>
      </TouchableOpacity>

      {/* ── Tap-outside dismiss overlay ── */}
      {showMenu && (
        <Pressable
          onPress={() => setShowMenu(false)}
          style={{ position: 'absolute', inset: 0, zIndex: 49 }}
        />
      )}

      {/* ── Quick Menu Popover (above button) ── */}
      {showMenu && (
        <View style={{
          position: 'absolute',
          bottom: BOTTOM + 32 + 10,
          right: 20,
          zIndex: 100,
        }}>
          <QuickMenuPopover
            onSelectDashboard={handleSelectDashboard}
            onSelectCompany={handleSelectCompany}
          />
        </View>
      )}

      {/* ── Menu Button (right) ── */}
      <TouchableOpacity
        onPress={() => setShowMenu(v => !v)}
        style={{
          position: 'absolute',
          bottom: BOTTOM,
          right: 20,
          width: 32,
          height: 32,
          backgroundColor: showMenu ? '#EBC351' : '#1C1C1E',
          borderRadius: 16,
          borderWidth: 1,
          borderColor: 'rgba(255,255,255,0.1)',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 101,
        }}
      >
        <Ionicons name={showMenu ? 'close' : 'menu'} size={16} color={showMenu ? '#000' : '#fff'} />
      </TouchableOpacity>

      {/* ── Search Modal ── */}
      <Modal visible={showSearch} transparent animationType="slide" onRequestClose={() => { setShowSearch(false); setSearchQuery(''); }}>
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={{ flex: 1 }}>
          <Pressable style={{ flex: 1, backgroundColor: 'rgba(0,0,0,0.7)' }} onPress={() => { setShowSearch(false); setSearchQuery(''); }}>
            <Pressable onPress={() => {}} style={{ flex: 1 }}>
              {/* Search Input Bar pinned to bottom */}
              <View style={{ position: 'absolute', bottom: 0, left: 0, right: 0, zIndex: 300 }}>
                {searchQuery.length > 0 && (
                  <SearchResultsSheet
                    query={searchQuery}
                    onClose={() => { setShowSearch(false); setSearchQuery(''); }}
                    onSelectCompany={handleSelectCompanyFromSearch}
                    onSelectSub={handleSelectSub}
                    onSelectFinancial={handleSelectFinancial}
                  />
                )}
                <View style={{ flexDirection: 'row', alignItems: 'center', backgroundColor: 'rgba(28,28,30,0.98)', borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.08)', paddingHorizontal: 16, paddingVertical: 12, paddingBottom: insets.bottom + 12, gap: 10 }}>
                  <Ionicons name="search" size={18} color="rgba(235,195,81,0.8)" />
                  <TextInput
                    style={{ flex: 1, color: '#fff', fontSize: 13, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 2 }}
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
                      <Ionicons name="close-circle" size={18} color="rgba(255,255,255,0.3)" />
                    </TouchableOpacity>
                  )}
                  <TouchableOpacity onPress={() => { setShowSearch(false); setSearchQuery(''); }}>
                    <Text style={{ color: 'rgba(255,255,255,0.4)', fontWeight: '700', fontSize: 13 }}>Cancel</Text>
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
