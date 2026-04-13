import { DarkTheme, DefaultTheme, ThemeProvider } from '@react-navigation/native';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import 'react-native-reanimated';

import { useColorScheme } from '@/hooks/use-color-scheme';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { AppProvider } from '../context/AppContext';
import '../global.css';

export const unstable_settings = {
  anchor: '(tabs)',
};

export default function RootLayout() {
  const colorScheme = useColorScheme();

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <ThemeProvider value={colorScheme === 'dark' ? DarkTheme : DefaultTheme}>
      <AppProvider>
        <Stack>
          <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
          <Stack.Screen name="modal" options={{ presentation: 'modal', title: 'Modal' }} />
          <Stack.Screen name="financial/institution/[id]" options={{ presentation: 'modal', headerShown: false }} />
          <Stack.Screen name="financial/card/[id]" options={{ presentation: 'modal', headerShown: false }} />
          <Stack.Screen name="financial/loan/[id]" options={{ presentation: 'modal', headerShown: false }} />
          <Stack.Screen name="subscription/[id]" options={{ presentation: 'modal', headerShown: false }} />
          <Stack.Screen name="document/[id]" options={{ presentation: 'modal', headerShown: false }} />
          <Stack.Screen name="company/[id]" options={{ presentation: 'modal', headerShown: false }} />
        </Stack>
        <StatusBar style="auto" />
      </AppProvider>
      </ThemeProvider>
    </GestureHandlerRootView>
  );
}
