export const HEADER_SHELL_LAYOUT = {
  topInsetClassName: "pt-3 md:pt-4",
  cardHeightClassName: "h-[64px] md:h-[68px]",
  scrollThreshold: 24,
  topMode: "top",
  scrolledMode: "scrolled",
  heroLayout: "header-overlay",
  heroClearanceContract: "floating-header-shell",
  heroClearanceClassName: "pt-36 pb-12 md:pt-40 md:pb-16 lg:pt-44 lg:pb-24",
  routeClearanceClassName: "pt-24 pb-20 md:py-24",
} as const

export type HeaderShellMode =
  (typeof HEADER_SHELL_LAYOUT)["topMode" | "scrolledMode"]
