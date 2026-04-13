import React from 'react';
import { View, Text, ScrollView, TouchableOpacity } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { useAppContext } from '../../context/AppContext';
import { Company } from '../../types';

export default function DashboardScreen() {
  const router = useRouter();
  const { state, totalMonthlyBurn, setSelectedCompanyId, filteredCompanies, searchQuery } = useAppContext();

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
        <View className="flex-row items-center justify-between mb-8">
          <Text className="text-3xl font-black tracking-tighter text-white">CiFr</Text>
          <View className="items-end">
            <Text className="text-xs text-stone-500 font-bold uppercase tracking-widest">Total Monthly Burn</Text>
            <Text className="text-lg font-bold text-red-500">
              ${totalMonthlyBurn.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
            </Text>
          </View>
        </View>

        {/* Companies Grid */}
        <View className="space-y-4 mb-16">
          <Text className="text-sm font-bold text-white/40 uppercase tracking-widest px-2">Your Companies</Text>
          
          {filteredCompanies.map((company) => (
            <TouchableOpacity 
              key={company.id}
              onPress={() => handleCompanyPress(company)}
              className="bg-white/5 border border-white/10 p-5 rounded-3xl"
            >
              <View className="flex-row items-center justify-between mb-3">
                <View className="flex-row items-center">
                  <View 
                    style={{ backgroundColor: company.color || '#3b82f6' }}
                    className="w-12 h-12 rounded-xl items-center justify-center mr-4"
                  >
                    <Text className="text-white font-black text-xl">{company.name.charAt(0)}</Text>
                  </View>
                  <View>
                    <Text className="text-xl font-bold text-white">{company.name}</Text>
                    <Text className="text-sm font-bold text-white/40">{company.structure}</Text>
                  </View>
                </View>
                <Ionicons name="chevron-forward" size={24} color="rgba(255,255,255,0.2)" />
              </View>
              
              <Text className="text-sm text-stone-400 mt-2" numberOfLines={2}>
                {company.description}
              </Text>
            </TouchableOpacity>
          ))}

          {/* Add Company Button */}
          <TouchableOpacity className="border-2 border-dashed border-white/20 p-5 rounded-3xl items-center justify-center mt-4 border-opacity-50 hover:bg-white/5 bg-transparent">
            <Ionicons name="add" size={28} color="rgba(255,255,255,0.4)" />
            <Text className="text-white/40 font-bold mt-2">Register New Company</Text>
          </TouchableOpacity>
        </View>

      </ScrollView>
    </SafeAreaView>
  );
}
