import type { GlobalThemeOverrides } from 'naive-ui'

/** Brand colours for Naive UI; every layout's n-config-provider uses them. */
export const brandThemeOverrides: GlobalThemeOverrides = {
  common: {
    primaryColor: '#1890FF',
    primaryColorHover: '#40a9ff',
    primaryColorPressed: '#096dd9',
    primaryColorSuppl: '#40a9ff',
  },
}

/** The same brand blue, lightened for the dark reader themes. */
export const brandDarkThemeOverrides: GlobalThemeOverrides = {
  common: {
    primaryColor: '#3c9ae8',
    primaryColorHover: '#65b1f0',
    primaryColorPressed: '#2a7bc4',
    primaryColorSuppl: '#65b1f0',
  },
}
