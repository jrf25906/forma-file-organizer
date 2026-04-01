export const HEADER_SHELL_LAYOUT = {
  topInsetClassName: "pt-3 md:pt-4",
  cardHeightClassName: "h-[64px] md:h-[68px]",
  scrollThreshold: 24,
  topMode: "top",
  scrolledMode: "scrolled",
  baseShellClassName:
    "transition-[background-color,border-color,box-shadow,transform] duration-200 ease-out data-[shell-mode=top]:border-[var(--header-shell-surface-top-border)] data-[shell-mode=top]:bg-[var(--header-shell-surface-top)] data-[shell-mode=top]:shadow-[var(--header-shell-shadow-top)] data-[shell-mode=scrolled]:border-[var(--header-shell-surface-scrolled-border)] data-[shell-mode=scrolled]:bg-[var(--header-shell-surface-scrolled)] data-[shell-mode=scrolled]:shadow-[var(--header-shell-shadow-scrolled)]",
  topStateShellClassName:
    "flex items-center justify-between gap-2.5 px-3.5 md:grid md:grid-cols-[auto_minmax(0,1fr)_auto] md:items-center md:gap-4 md:px-4",
  scrolledStateShellClassName:
    "flex items-center justify-between gap-2.5 px-3.5 md:grid md:grid-cols-[auto_minmax(0,1fr)_auto] md:items-center md:gap-5 md:px-4",
  desktopNavClassName:
    "hidden items-center justify-center gap-1 overflow-hidden rounded-full border p-1 transition-all duration-200 ease-out md:flex",
  desktopNavHiddenClassName:
    "border-transparent bg-transparent opacity-0 pointer-events-none translate-y-1 focus-within:border-[var(--header-shell-border)] focus-within:bg-[var(--header-shell-surface-muted)] focus-within:opacity-100 focus-within:pointer-events-auto focus-within:translate-y-0",
  desktopNavVisibleClassName:
    "border-[var(--header-shell-border)] bg-[var(--header-shell-surface-muted)] opacity-100 translate-y-0",
  heroLayout: "header-overlay",
  heroClearanceContract: "floating-header-shell",
  heroClearanceClassName: "pt-36 pb-12 md:pt-40 md:pb-16 lg:pt-44 lg:pb-24",
  routeClearanceClassName: "pt-24 pb-20 md:py-24",
} as const

export type HeaderShellMode =
  (typeof HEADER_SHELL_LAYOUT)["topMode" | "scrolledMode"]
