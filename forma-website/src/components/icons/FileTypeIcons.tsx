// ---------------------------------------------------------------------------
// File-type SVG icons — web equivalents of SF Symbols used in the native app
// doc.text.fill → DocumentIcon | photo.fill → ImageIcon | film.fill → VideoIcon
// music.note → AudioIcon | archivebox.fill → ArchiveIcon
// ---------------------------------------------------------------------------

import type { SVGProps } from "react";

type IconProps = SVGProps<SVGSVGElement>;

export function DocumentIcon(props: IconProps) {
  return (
    <svg viewBox="0 0 24 24" fill="currentColor" {...props}>
      <path d="M6 2a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8l-6-6H6Zm7 1.5L19.5 10H14a1 1 0 0 1-1-1V3.5ZM8 13h8v1.5H8V13Zm0 3.5h5V18H8v-1.5Z" />
    </svg>
  );
}

export function ImageIcon(props: IconProps) {
  return (
    <svg viewBox="0 0 24 24" fill="currentColor" {...props}>
      <path d="M4 4a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2H4Zm13 4.5a1.5 1.5 0 1 1 0 3 1.5 1.5 0 0 1 0-3ZM4 18l4.5-6 3 3.5 2.5-3L20 18H4Z" />
    </svg>
  );
}

export function VideoIcon(props: IconProps) {
  return (
    <svg viewBox="0 0 24 24" fill="currentColor" {...props}>
      <path d="M4 4a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2H4Zm6 4.5 5 3.5-5 3.5V8.5Z" />
    </svg>
  );
}

export function AudioIcon(props: IconProps) {
  return (
    <svg viewBox="0 0 24 24" fill="currentColor" {...props}>
      <path d="M12 3v14.05A3.5 3.5 0 1 0 14 20.5V8h4V3h-6ZM10.5 20.5a2 2 0 1 1-4 0 2 2 0 0 1 4 0Z" />
    </svg>
  );
}

export function ArchiveIcon(props: IconProps) {
  return (
    <svg viewBox="0 0 24 24" fill="currentColor" {...props}>
      <path d="M2 4a1 1 0 0 1 1-1h18a1 1 0 0 1 1 1v3a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1V4Zm1 5h18v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V9Zm6 3a1 1 0 0 1 1-1h4a1 1 0 1 1 0 2h-4a1 1 0 0 1-1-1Z" />
    </svg>
  );
}
