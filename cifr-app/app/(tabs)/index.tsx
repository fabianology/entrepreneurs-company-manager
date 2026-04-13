import React, { useState, useEffect } from 'react';
import { View, Text, ScrollView, TouchableOpacity } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { useAppContext } from '../../context/AppContext';
import { Company } from '../../types';
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

export default function DashboardScreen() {
  const router = useRouter();
  const { state, setSelectedCompanyId, filteredCompanies, handleAddCompany } = useAppContext();
  const [quote, setQuote] = useState<string>('');

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
          
          {filteredCompanies.map((company) => (
            <TouchableOpacity 
              key={company.id}
              onPress={() => handleCompanyPress(company)}
              className="bg-[#1C1C1E] border border-white/5 p-5 rounded-3xl mb-4 overflow-hidden"
            >
              <View className="flex-row items-center justify-between mb-5">
                <View className="flex-row items-center max-w-[85%]">
                  <View 
                    style={{ backgroundColor: company.color || '#3b82f6' }}
                    className="w-12 h-12 rounded-xl items-center justify-center mr-4"
                  >
                    <Text className="text-white font-black text-xl">{company.name.charAt(0)}</Text>
                  </View>
                  <View className="flex-1">
                    <Text className="text-lg font-black text-white tracking-tight" numberOfLines={1}>{company.name}</Text>
                    <Text className="text-[10px] font-bold text-white/40 uppercase tracking-widest mt-0.5">{company.structure}</Text>
                  </View>
                </View>
                <Ionicons name="chevron-forward" size={18} color="rgba(255,255,255,0.2)" />
              </View>

              <View className="flex-row items-end justify-between border-t border-white/5 pt-4">
                <View className="space-y-1.5">
                  <View className="flex-row items-center">
                    <Ionicons name="time-outline" size={12} color="rgba(255,255,255,0.3)" />
                    <Text className="text-[9px] font-black tracking-widest text-white/30 uppercase ml-1">
                      Modified: <Text className="text-white/70 ml-1">{getTimeAgo(company.lastModified)}</Text>
                    </Text>
                  </View>
                  <View className="flex-row items-center">
                    <Ionicons name="eye-outline" size={12} color="rgba(255,255,255,0.3)" />
                    <Text className="text-[9px] font-black tracking-widest text-white/30 uppercase ml-1">
                      Viewed: <Text className="text-white/70 ml-1">{getTimeAgo(company.lastViewed)}</Text>
                    </Text>
                  </View>
                </View>

                <View className="flex-row items-center justify-around bg-black/30 w-32 px-4 py-2 rounded-xl border border-white/5">
                  <Ionicons name="layers" size={14} color="rgba(255,255,255,0.5)" />
                  <Ionicons name="card" size={14} color="rgba(255,255,255,0.5)" />
                  <Ionicons name="document-text" size={14} color="rgba(255,255,255,0.5)" />
                </View>
              </View>
            </TouchableOpacity>>
          ))}

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
