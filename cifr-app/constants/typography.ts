/**
 * Apple HIG iOS Type Scale — SF Pro (system font on iOS)
 * Ref: https://developer.apple.com/design/human-interface-guidelines/typography
 *
 * React Native on iOS automatically uses SF Pro as the system font.
 * No font loading required. Simply don't set a fontFamily.
 */

import type { TextStyle } from 'react-native';

export const T: Record<string, TextStyle> = {
  largeTitle: { fontSize: 34, fontWeight: '400', letterSpacing: 0.4 },
  title1:     { fontSize: 28, fontWeight: '400', letterSpacing: 0.4 },
  title2:     { fontSize: 22, fontWeight: '400', letterSpacing: 0.4 },
  title3:     { fontSize: 20, fontWeight: '600', letterSpacing: 0.4 },
  headline:   { fontSize: 17, fontWeight: '600', letterSpacing: 0 },
  body:       { fontSize: 17, fontWeight: '400', letterSpacing: 0 },
  callout:    { fontSize: 16, fontWeight: '400', letterSpacing: 0 },
  subhead:    { fontSize: 15, fontWeight: '400', letterSpacing: 0 },
  footnote:   { fontSize: 13, fontWeight: '400', letterSpacing: 0 },
  caption1:   { fontSize: 12, fontWeight: '400', letterSpacing: 0 },
  caption2:   { fontSize: 11, fontWeight: '400', letterSpacing: 0.07 },
};
