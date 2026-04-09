import { useDialKit } from 'dialkit'
import { DialRoot } from 'dialkit'
import 'dialkit/styles.css'
import { motion, AnimatePresence } from 'motion/react'
import { useState } from 'react'
import './App.css'

// Forma design tokens (translated from SwiftUI)
const FORMA = {
  boneWhite: '#F5F2ED',
  obsidian: '#2A2A2A',
  steelBlue: '#5B7C99',
  sage: '#7A9E7A',
  warmOrange: '#D4944C',
  mutedBlue: '#6B8FB5',
  softGreen: '#6A9E6A',
  separator: '#E0DBD5',
}

// FormaRadius values from SwiftUI
const RADIUS = { micro: 4, small: 6, control: 8, card: 12 }

// File type thumbnail colors
const EXT_COLORS = {
  PDF: '#E8654A',
  JPG: '#4A90D9',
  XLS: '#2EA86B',
  MD: '#7C6BC4',
  FIG: '#C75B8E',
  KEY: '#D48B3E',
}

const SAMPLE_FILES = [
  { name: 'invoice-2024-Q1.pdf', ext: 'PDF', size: '2.4 MB', date: 'Mar 12', color: '#D4944C', snippet: 'Quarterly financial summary for review' },
  { name: 'vacation-alps.jpg', ext: 'JPG', size: '8.1 MB', date: 'Feb 28', color: '#5B7C99', snippet: null },
  { name: 'project-budget.xlsx', ext: 'XLS', size: '156 KB', date: 'Apr 2', color: '#7A9E7A', snippet: 'Budget allocations for Q2 planning' },
  { name: 'meeting-notes.md', ext: 'MD', size: '12 KB', date: 'Apr 5', color: '#8B6FB5', snippet: 'Action items from weekly standup' },
  { name: 'keynote-pitch-v3.key', ext: 'KEY', size: '44 MB', date: 'Apr 7', color: '#C75B8E', snippet: null },
]

// =============================================================
//  Shared File Surface Sub-components
// =============================================================

function FileCheckbox({ checked, size = 18, darkMode }) {
  return (
    <motion.div
      style={{
        width: size,
        height: size,
        borderRadius: size * 0.27,
        border: `1.5px solid ${checked
          ? FORMA.steelBlue
          : darkMode ? 'rgba(245,242,237,0.25)' : 'rgba(42,42,42,0.2)'}`,
        background: checked ? FORMA.steelBlue : 'transparent',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        cursor: 'pointer',
        flexShrink: 0,
      }}
      whileHover={{ scale: 1.1 }}
      whileTap={{ scale: 0.9 }}
    >
      {checked && (
        <svg width={size * 0.6} height={size * 0.6} viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
          <polyline points="20 6 9 17 4 12" />
        </svg>
      )}
    </motion.div>
  )
}

function FileThumbnail({ file, size, radius = 6 }) {
  const bg = EXT_COLORS[file.ext] || '#888'
  return (
    <div style={{
      width: size,
      height: size,
      borderRadius: radius,
      background: `${bg}18`,
      border: `1px solid ${bg}22`,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      flexShrink: 0,
    }}>
      <span style={{
        fontSize: Math.max(size * 0.22, 8),
        fontWeight: 700,
        color: bg,
        letterSpacing: '0.04em',
        textTransform: 'uppercase',
      }}>
        {file.ext}
      </span>
    </div>
  )
}

/* 3-stop sheen matching SwiftUI: boneWhite at 18% → 6% → 0% with screen blend */
function SheenOverlay({ opacity, radius }) {
  if (opacity <= 0) return null
  return (
    <div style={{
      position: 'absolute',
      inset: 0,
      background: `linear-gradient(135deg, rgba(245,242,237,${opacity * 3}) 0%, rgba(245,242,237,${opacity}) 50%, transparent 100%)`,
      mixBlendMode: 'screen',
      pointerEvents: 'none',
      borderRadius: radius,
    }} />
  )
}

function CategoryMarker({ color, width = 3, height = 16 }) {
  if (width <= 0) return null
  return (
    <div style={{
      width,
      minHeight: height,
      borderRadius: width,
      background: color,
      flexShrink: 0,
      opacity: 0.7,
    }} />
  )
}

function FileIdentityBlock({ file, fp, textColor, secondaryText, layout = 'card' }) {
  const nameSize = layout === 'grid' ? fp.type.nameSize - 1 : fp.type.nameSize
  const showSnippet = layout === 'card' && file.snippet

  return (
    <div style={{
      display: 'flex',
      flexDirection: 'column',
      gap: 2,
      minWidth: 0,
      flex: 1,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        <CategoryMarker color={file.color} width={fp.type.markerWidth} height={nameSize + 2} />
        <div style={{
          fontSize: nameSize,
          fontWeight: fp.type.nameWeight,
          color: textColor,
          letterSpacing: '-0.01em',
          whiteSpace: 'nowrap',
          overflow: 'hidden',
          textOverflow: 'ellipsis',
        }}>
          {file.name}
        </div>
      </div>
      <div style={{
        fontSize: fp.type.metaSize,
        color: secondaryText,
        display: 'flex',
        gap: 8,
        paddingLeft: fp.type.markerWidth > 0 ? fp.type.markerWidth + 6 : 0,
      }}>
        <span>{file.ext}</span>
        <span style={{ opacity: 0.4 }}>&middot;</span>
        <span>{file.size}</span>
        <span style={{ opacity: 0.4 }}>&middot;</span>
        <span>{file.date}</span>
      </div>
      {showSnippet && (
        <div style={{
          fontSize: fp.type.metaSize,
          color: secondaryText,
          opacity: 0.65,
          whiteSpace: 'nowrap',
          overflow: 'hidden',
          textOverflow: 'ellipsis',
          marginTop: 1,
          paddingLeft: fp.type.markerWidth > 0 ? fp.type.markerWidth + 6 : 0,
        }}>
          {file.snippet}
        </div>
      )}
    </div>
  )
}

function OrganizeButton({ darkMode, accentColor = FORMA.steelBlue, bgAlpha = 0.08 }) {
  return (
    <motion.button
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 4,
        fontSize: 11,
        fontWeight: 600,
        color: darkMode ? '#F5F2ED' : accentColor,
        background: `${accentColor}${Math.round(bgAlpha * 255).toString(16).padStart(2, '0')}`,
        border: 'none',
        borderRadius: 6,
        padding: '4px 10px',
        cursor: 'pointer',
        letterSpacing: '-0.01em',
        fontFamily: 'inherit',
        whiteSpace: 'nowrap',
        flexShrink: 0,
      }}
      whileHover={{ scale: 1.06 }}
      whileTap={{ scale: 0.94 }}
    >
      Organize
      <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
        <path d="M5 12h14M12 5l7 7-7 7" />
      </svg>
    </motion.button>
  )
}

function OverflowDots({ color }) {
  return (
    <motion.button
      style={{
        width: 28,
        height: 28,
        borderRadius: 6,
        border: 'none',
        background: 'transparent',
        color,
        cursor: 'pointer',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        fontSize: 14,
        letterSpacing: 2,
        fontFamily: 'inherit',
        flexShrink: 0,
      }}
      whileHover={{ background: `${color}15` }}
    >
      &middot;&middot;&middot;
    </motion.button>
  )
}

// Helper: build dual box-shadow string (ambient + contact)
function dualShadow(fp, hovered) {
  if (hovered) {
    return [
      `0 ${fp.hoverShadow.ambientY}px ${fp.hoverShadow.ambientBlur}px rgba(0,0,0,${fp.hoverShadow.ambientAlpha})`,
      `0 ${fp.hoverShadow.contactY}px ${fp.hoverShadow.contactBlur}px rgba(0,0,0,${fp.hoverShadow.contactAlpha})`,
    ].join(', ')
  }
  return [
    `0 ${fp.restShadow.ambientY}px ${fp.restShadow.ambientBlur}px rgba(0,0,0,${fp.restShadow.ambientAlpha})`,
    `0 ${fp.restShadow.contactY}px ${fp.restShadow.contactBlur}px rgba(0,0,0,${fp.restShadow.contactAlpha})`,
  ].join(', ')
}

// Helper: border color by state
function borderForState(fp, { isHovered, isSelected, darkMode }) {
  const base = darkMode ? '245,242,237' : '42,42,42'
  if (isSelected) {
    return `${fp.selection.accent}${Math.round(fp.selection.borderAlpha * 255).toString(16).padStart(2, '0')}`
  }
  if (isHovered) {
    return `rgba(${base},${Math.min(fp.surface.borderOpacity * 2.2, 0.22)})`
  }
  return `rgba(${base},${fp.surface.borderOpacity})`
}

// =============================================================
//  File Card Row  (maps to FileRow.swift — card mode)
// =============================================================

function FileCardRow({ file, fp, isHovered, isSelected, onHover, onSelect }) {
  const dark = fp.surface.darkMode
  const textColor = dark ? '#F5F2ED' : FORMA.obsidian
  const secondaryText = dark ? 'rgba(245,242,237,0.6)' : 'rgba(42,42,42,0.55)'

  const bgBase = dark ? '245,242,237' : '42,42,42'
  const bgAlpha = isSelected
    ? fp.selection.overlayAlpha
    : isHovered
      ? fp.hover.overlayAlpha + fp.surface.bgOpacity
      : fp.surface.bgOpacity

  return (
    <motion.div
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: fp.cardRow.gap,
        height: fp.cardRow.height,
        padding: `${fp.cardRow.paddingV}px ${fp.cardRow.paddingH}px`,
        borderRadius: fp.cardRow.radius,
        background: `rgba(${bgBase},${bgAlpha})`,
        border: `${fp.surface.borderWidth}px solid ${borderForState(fp, { isHovered, isSelected, darkMode: dark })}`,
        boxShadow: dualShadow(fp, isHovered),
        cursor: 'pointer',
        position: 'relative',
        overflow: 'hidden',
        transition: 'background 0.12s, border-color 0.12s, box-shadow 0.2s',
      }}
      animate={{
        scale: isHovered ? fp.hover.scale : isSelected ? 0.998 : 1,
        y: isHovered ? fp.hover.lift * -1 : 0,
      }}
      transition={fp.spring}
      onMouseEnter={() => onHover(true)}
      onMouseLeave={() => onHover(false)}
      onClick={() => onSelect(!isSelected)}
    >
      <SheenOverlay opacity={fp.surface.sheenOpacity} radius={fp.cardRow.radius} />
      <FileCheckbox checked={isSelected} darkMode={dark} />
      <FileThumbnail file={file} size={fp.cardRow.thumbSize} radius={fp.cardRow.radius * 0.6} />
      <FileIdentityBlock file={file} fp={fp} textColor={textColor} secondaryText={secondaryText} layout="card" />
      <div style={{ display: 'flex', alignItems: 'center', gap: 4, flexShrink: 0 }}>
        <OrganizeButton darkMode={dark} />
        <OverflowDots color={secondaryText} />
      </div>
    </motion.div>
  )
}

// =============================================================
//  File List Row  (maps to FileListRow.swift — compact mode)
// =============================================================

function FileListRow({ file, fp, isHovered, isSelected, onHover, onSelect }) {
  const dark = fp.surface.darkMode
  const textColor = dark ? '#F5F2ED' : FORMA.obsidian
  const secondaryText = dark ? 'rgba(245,242,237,0.55)' : 'rgba(42,42,42,0.5)'

  const bgBase = dark ? '245,242,237' : '42,42,42'
  const bgAlpha = isSelected
    ? fp.selection.overlayAlpha * 0.8
    : isHovered
      ? fp.hover.overlayAlpha
      : 0

  // List rows: no shadow at rest, subtle on hover (per FileListRow.swift)
  const shadow = isHovered
    ? `0 1px 4px rgba(0,0,0,${fp.restShadow.ambientAlpha * 0.5})`
    : 'none'

  return (
    <motion.div
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: fp.listRow.gap,
        height: fp.listRow.height,
        padding: `0 ${fp.listRow.paddingH}px`,
        borderRadius: fp.listRow.radius,
        background: bgAlpha > 0 ? `rgba(${bgBase},${bgAlpha})` : 'transparent',
        border: `${Math.min(fp.surface.borderWidth, 1)}px solid ${borderForState(fp, { isHovered, isSelected, darkMode: dark })}`,
        boxShadow: shadow,
        cursor: 'pointer',
        position: 'relative',
        transition: 'background 0.1s, border-color 0.1s',
      }}
      animate={{
        scale: isHovered ? 1 + (fp.hover.scale - 1) * 0.3 : 1,
      }}
      transition={fp.spring}
      onMouseEnter={() => onHover(true)}
      onMouseLeave={() => onHover(false)}
      onClick={() => onSelect(!isSelected)}
    >
      <FileCheckbox checked={isSelected} size={15} darkMode={dark} />
      <FileThumbnail file={file} size={fp.listRow.thumbSize} radius={4} />
      <FileIdentityBlock file={file} fp={fp} textColor={textColor} secondaryText={secondaryText} layout="list" />
      <div style={{
        display: 'flex',
        alignItems: 'center',
        gap: 2,
        flexShrink: 0,
        opacity: isHovered ? 1 : 0,
        transition: 'opacity 0.15s',
      }}>
        <OrganizeButton darkMode={dark} bgAlpha={0.06} />
      </div>
    </motion.div>
  )
}

// =============================================================
//  File Grid Item  (maps to FileGridItem.swift — grid tile)
// =============================================================

function FileGridItem({ file, fp, isHovered, isSelected, onHover, onSelect }) {
  const dark = fp.surface.darkMode
  const textColor = dark ? '#F5F2ED' : FORMA.obsidian
  const secondaryText = dark ? 'rgba(245,242,237,0.55)' : 'rgba(42,42,42,0.5)'

  const mediaHeight = fp.gridItem.cardHeight * 0.65
  const extColor = EXT_COLORS[file.ext] || '#888'

  const bgBase = dark ? '245,242,237' : '42,42,42'
  const bgAlpha = isSelected ? fp.selection.overlayAlpha : fp.surface.bgOpacity

  return (
    <motion.div
      style={{
        display: 'flex',
        flexDirection: 'column',
        height: fp.gridItem.cardHeight,
        borderRadius: fp.gridItem.radius,
        background: `rgba(${bgBase},${bgAlpha})`,
        border: `${fp.surface.borderWidth}px solid ${borderForState(fp, { isHovered, isSelected, darkMode: dark })}`,
        boxShadow: dualShadow(fp, isHovered),
        cursor: 'pointer',
        position: 'relative',
        overflow: 'hidden',
        transition: 'border-color 0.12s, box-shadow 0.2s',
      }}
      animate={{
        scale: isHovered ? fp.hover.scale : isSelected ? 0.99 : 1,
        y: isHovered ? fp.hover.lift * -1 : 0,
      }}
      transition={fp.spring}
      onMouseEnter={() => onHover(true)}
      onMouseLeave={() => onHover(false)}
      onClick={() => onSelect(!isSelected)}
    >
      <SheenOverlay opacity={fp.surface.sheenOpacity} radius={fp.gridItem.radius} />

      {/* Media area */}
      <div style={{
        flex: '0 0 auto',
        height: mediaHeight,
        background: dark ? `${extColor}15` : `${extColor}0C`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        position: 'relative',
      }}>
        <div style={{
          fontSize: 28,
          fontWeight: 800,
          color: `${extColor}40`,
          letterSpacing: '0.06em',
        }}>
          {file.ext}
        </div>

        {/* Hover overlay: gradient scrim + actions (per FileGridItem.swift) */}
        <AnimatePresence>
          {isHovered && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.15 }}
              style={{
                position: 'absolute',
                inset: 0,
                background: 'linear-gradient(to top, rgba(0,0,0,0.5) 0%, rgba(0,0,0,0.15) 40%, transparent 100%)',
                display: 'flex',
                alignItems: 'flex-end',
                justifyContent: 'space-between',
                padding: fp.gridItem.footerPad,
              }}
            >
              <FileCheckbox checked={isSelected} size={18} darkMode={true} />
              <OrganizeButton darkMode={true} bgAlpha={0.2} />
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      {/* Footer */}
      <div style={{
        flex: 1,
        padding: fp.gridItem.footerPad,
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'center',
        gap: fp.gridItem.gap,
        borderTop: `1px solid rgba(${dark ? '245,242,237' : '42,42,42'},0.06)`,
      }}>
        <FileIdentityBlock file={file} fp={fp} textColor={textColor} secondaryText={secondaryText} layout="grid" />
      </div>
    </motion.div>
  )
}

// =============================================================
//  Quick Action Card Components (existing prototype)
// =============================================================

function ActionButton({ params, style = {} }) {
  const accentColor = params.colors.accent
  return (
    <motion.button
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 6,
        fontSize: params.typography.buttonSize,
        fontWeight: 600,
        color: params.surface.darkMode ? '#F5F2ED' : accentColor,
        background: `${accentColor}${Math.round(params.colors.buttonBgOpacity * 255).toString(16).padStart(2, '0')}`,
        border: 'none',
        borderRadius: params.layout.buttonRadius,
        padding: `${params.layout.buttonPaddingY}px ${params.layout.buttonPaddingX}px`,
        cursor: 'pointer',
        letterSpacing: '-0.01em',
        fontFamily: 'inherit',
        whiteSpace: 'nowrap',
        ...style,
      }}
      whileHover={{ scale: 1.04 }}
      whileTap={{ scale: 0.96 }}
      transition={params.spring}
    >
      {params.content.buttonLabel}
      <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
        <path d="M5 12h14M12 5l7 7-7 7" />
      </svg>
    </motion.button>
  )
}

function IconElement({ params, layout, accentColor, isHovered }) {
  return (
    <motion.div
      style={{
        ...layout.iconSection,
        width: params.layout.iconSize,
        height: params.layout.iconSize,
        borderRadius: params.layout.iconRadius,
        background: `${accentColor}${Math.round(params.colors.iconBgOpacity * 255).toString(16).padStart(2, '0')}`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        color: accentColor,
        flexShrink: 0,
      }}
      animate={{
        rotate: isHovered && params.interaction.iconRotate ? 8 : 0,
        scale: isHovered ? params.interaction.iconHoverScale : 1,
      }}
      transition={params.spring}
    >
      <svg width={params.layout.iconSize * 0.42} height={params.layout.iconSize * 0.42} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
        <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z" />
      </svg>
    </motion.div>
  )
}

function ContentBlock({ params, layout, textColor, secondaryText, accentColor, buttonPlacement }) {
  const isHeaderRight = buttonPlacement === 'header-right'
  const isUnderCount = buttonPlacement === 'under-count'

  return (
    <div style={{ ...layout.contentSection, display: 'flex', flexDirection: 'column', gap: 4 }}>
      {isHeaderRight ? (
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 8 }}>
          <div style={{
            flex: 1,
            fontSize: params.typography.titleSize,
            fontWeight: params.typography.titleWeight,
            color: textColor,
            lineHeight: 1.3,
            letterSpacing: '-0.01em',
          }}>
            {params.content.title}
          </div>
          <ActionButton params={params} />
        </div>
      ) : (
        <div style={{
          fontSize: params.typography.titleSize,
          fontWeight: params.typography.titleWeight,
          color: textColor,
          lineHeight: 1.3,
          letterSpacing: '-0.01em',
        }}>
          {params.content.title}
        </div>
      )}

      {params.content.showCount && (
        <div style={{
          fontSize: params.typography.countSize,
          fontWeight: 600,
          color: accentColor,
        }}>
          {params.content.countText}
        </div>
      )}

      {isUnderCount && (
        <div style={{ marginTop: 2 }}>
          <ActionButton params={params} />
        </div>
      )}

      {params.content.showDetail && (
        <div style={{
          fontSize: params.typography.detailSize,
          color: secondaryText,
          lineHeight: 1.4,
        }}>
          {params.content.detailText}
        </div>
      )}
    </div>
  )
}

function QuickActionCard({ params, variant, isHovered, setIsHovered }) {
  const cardBg = params.surface.darkMode
    ? `rgba(245,242,237,${isHovered ? 0.09 : 0.05})`
    : `rgba(42,42,42,${isHovered ? params.surface.hoverOpacity : params.surface.bgOpacity})`

  const borderColor = params.surface.darkMode
    ? `rgba(245,242,237,${isHovered ? 0.2 : 0.12})`
    : `rgba(42,42,42,${isHovered ? 0.15 : params.surface.borderOpacity})`

  const accentColor = params.colors.accent
  const textColor = params.surface.darkMode ? '#F5F2ED' : '#2A2A2A'
  const secondaryText = params.surface.darkMode ? 'rgba(245,242,237,0.7)' : 'rgba(42,42,42,0.62)'
  const buttonPlacement = params.layout.buttonPlacement

  const layoutStyles = {
    horizontal: {
      card: { flexDirection: 'row', alignItems: 'flex-start' },
      iconSection: { flexShrink: 0 },
      contentSection: { flex: 1, minWidth: 0 },
    },
    vertical: {
      card: { flexDirection: 'column' },
      iconSection: {},
      contentSection: {},
    },
    compact: {
      card: { flexDirection: 'row', alignItems: 'center' },
      iconSection: { flexShrink: 0 },
      contentSection: { flex: 1, minWidth: 0 },
    },
  }

  const layout = layoutStyles[variant] || layoutStyles.horizontal
  const isInlineRight = buttonPlacement === 'inline-right'
  const isBottomFull = buttonPlacement === 'bottom-full'
  const isBottomLeft = buttonPlacement === 'bottom-left'
  const needsColumnWrapper = isBottomFull || isBottomLeft

  return (
    <motion.div
      style={{
        display: 'flex',
        flexDirection: needsColumnWrapper ? 'column' : layout.card.flexDirection,
        alignItems: needsColumnWrapper ? 'stretch' : layout.card.alignItems,
        gap: params.layout.gap,
        padding: params.layout.padding,
        borderRadius: params.surface.borderRadius,
        background: cardBg,
        border: `${params.surface.borderWidth}px solid ${borderColor}`,
        boxShadow: isHovered
          ? `0 ${params.shadow.hoverOffsetY}px ${params.shadow.hoverBlur}px rgba(0,0,0,${params.shadow.hoverOpacity})`
          : `0 ${params.shadow.offsetY}px ${params.shadow.blur}px rgba(0,0,0,${params.shadow.opacity})`,
        cursor: 'pointer',
        position: 'relative',
        overflow: 'hidden',
        transition: 'background 0.15s ease, border-color 0.15s ease, box-shadow 0.2s ease',
      }}
      animate={{
        scale: isHovered ? params.interaction.hoverScale : 1,
        y: isHovered ? params.interaction.hoverLift * -1 : 0,
      }}
      transition={params.spring}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
    >
      {needsColumnWrapper ? (
        <>
          <div style={{ display: 'flex', ...layout.card, gap: params.layout.gap }}>
            <IconElement params={params} layout={layout} accentColor={accentColor} isHovered={isHovered} />
            <ContentBlock params={params} layout={layout} textColor={textColor} secondaryText={secondaryText} accentColor={accentColor} buttonPlacement={buttonPlacement} />
          </div>
          <div style={{
            display: 'flex',
            justifyContent: isBottomFull ? 'stretch' : 'flex-start',
            borderTop: `1px solid ${borderColor}`,
            paddingTop: params.layout.gap,
            marginTop: 2,
          }}>
            <ActionButton params={params} style={isBottomFull ? { width: '100%', justifyContent: 'center' } : {}} />
          </div>
        </>
      ) : (
        <>
          <IconElement params={params} layout={layout} accentColor={accentColor} isHovered={isHovered} />
          <ContentBlock params={params} layout={layout} textColor={textColor} secondaryText={secondaryText} accentColor={accentColor} buttonPlacement={buttonPlacement} />
          {isInlineRight && (
            <div style={{ flexShrink: 0, alignSelf: 'center' }}>
              <ActionButton params={params} />
            </div>
          )}
        </>
      )}

      {params.content.showDismiss && (
        <motion.button
          style={{
            position: 'absolute',
            top: params.layout.padding * 0.6,
            right: params.layout.padding * 0.6,
            width: 26,
            height: 26,
            borderRadius: '50%',
            border: 'none',
            background: params.surface.darkMode ? 'rgba(245,242,237,0.08)' : 'rgba(42,42,42,0.05)',
            color: secondaryText,
            fontSize: 10,
            fontWeight: 700,
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontFamily: 'inherit',
          }}
          whileHover={{
            background: params.surface.darkMode ? 'rgba(245,242,237,0.15)' : 'rgba(42,42,42,0.1)',
            scale: 1.1,
          }}
          whileTap={{ scale: 0.9 }}
        >
          &#10005;
        </motion.button>
      )}
    </motion.div>
  )
}

// =============================================================
//  Section Label
// =============================================================

function SectionLabel({ title, subtitle, darkMode }) {
  return (
    <div style={{ marginBottom: 10 }}>
      <div style={{
        display: 'flex',
        alignItems: 'baseline',
        gap: 8,
      }}>
        <span style={{
          fontSize: 11,
          fontWeight: 700,
          textTransform: 'uppercase',
          letterSpacing: '0.06em',
          color: darkMode ? 'rgba(245,242,237,0.3)' : 'rgba(42,42,42,0.3)',
        }}>
          {title}
        </span>
        {subtitle && (
          <span style={{
            fontSize: 11,
            color: darkMode ? 'rgba(245,242,237,0.18)' : 'rgba(42,42,42,0.18)',
          }}>
            {subtitle}
          </span>
        )}
      </div>
    </div>
  )
}

// =============================================================
//  App
// =============================================================

function App() {
  const [activeTab, setActiveTab] = useState('fileSurfaces')
  const [hoveredQA, setHoveredQA] = useState({})

  // File surface interaction state: { 'card-0': { hovered, selected }, ... }
  const [fileStates, setFileStates] = useState({})
  const getFS = (key) => fileStates[key] || { hovered: false, selected: false }
  const setHover = (key, v) => setFileStates(s => ({ ...s, [key]: { ...getFS(key), hovered: v } }))
  const setSelected = (key, v) => setFileStates(s => ({ ...s, [key]: { ...getFS(key), selected: v } }))

  // — QuickActionCard DialKit panel —
  const qaParams = useDialKit('QuickActionCard', {
    layout: {
      padding: [12, 4, 32],
      gap: [8, 4, 24],
      iconSize: [44, 24, 64],
      iconRadius: [8, 0, 32],
      buttonRadius: [8, 0, 20],
      buttonPaddingX: [12, 4, 24],
      buttonPaddingY: [6, 2, 14],
      buttonPlacement: {
        type: 'select',
        options: [
          { value: 'inline-right', label: 'Inline Right (current)' },
          { value: 'header-right', label: 'Header Right (next to title)' },
          { value: 'under-count', label: 'Under Count (below file count)' },
          { value: 'bottom-left', label: 'Bottom Left (separated footer)' },
          { value: 'bottom-full', label: 'Bottom Full Width (wide CTA)' },
        ],
        default: 'inline-right',
      },
    },
    surface: {
      borderRadius: [12, 0, 28],
      borderWidth: [1, 0, 3],
      borderOpacity: [0.08, 0, 0.3],
      bgOpacity: [0.03, 0, 0.15],
      hoverOpacity: [0.06, 0, 0.2],
      darkMode: false,
    },
    shadow: {
      offsetY: [1, 0, 16],
      blur: [3, 0, 32],
      opacity: [0.04, 0, 0.3],
      hoverOffsetY: [4, 0, 24],
      hoverBlur: [12, 0, 48],
      hoverOpacity: [0.08, 0, 0.4],
    },
    colors: {
      accent: '#5B7C99',
      iconBgOpacity: [0.12, 0, 0.4],
      buttonBgOpacity: [0.1, 0, 0.4],
    },
    typography: {
      titleSize: [14, 11, 20],
      titleWeight: { type: 'select', options: ['400', '500', '600', '700'], default: '600' },
      countSize: [12, 9, 16],
      detailSize: [12, 9, 16],
      buttonSize: [12, 10, 16],
    },
    interaction: {
      hoverScale: [1.01, 1, 1.06],
      hoverLift: [1, 0, 8],
      iconHoverScale: [1.05, 1, 1.3],
      iconRotate: true,
    },
    content: {
      title: { type: 'text', default: 'Group 8 similar PDFs into Documents/Finance' },
      countText: { type: 'text', default: '8 files affected' },
      detailText: { type: 'text', default: 'invoice-2024.pdf, receipt-march.pdf, and 6 more' },
      buttonLabel: { type: 'text', default: 'Create Rule' },
      showCount: true,
      showDetail: true,
      showDismiss: true,
    },
    spring: { type: 'spring', visualDuration: 0.25, bounce: 0.15 },
    resetAll: { type: 'action', label: 'Reset All' },
  }, {
    onAction: (action) => {
      if (action === 'resetAll') window.location.reload()
    },
  })

  // — FileSurfaces DialKit panel —
  // Default values pulled from FileRow.swift, FileListRow.swift, FileGridItem.swift
  const fp = useDialKit('FileSurfaces', {
    // Card Row metrics (FileRow.swift — balanced density defaults)
    cardRow: {
      thumbSize: [48, 24, 72],
      height: [68, 40, 100],
      radius: [RADIUS.control, 0, 24],
      paddingH: [8, 2, 24],
      paddingV: [6, 2, 20],
      gap: [10, 4, 24],
    },

    // List Row metrics (FileListRow.swift — balanced density defaults)
    listRow: {
      thumbSize: [24, 16, 40],
      height: [48, 32, 72],
      radius: [RADIUS.small, 0, 16],
      paddingH: [10, 2, 24],
      gap: [8, 2, 20],
    },

    // Grid Item metrics (FileGridItem.swift — balanced density defaults)
    gridItem: {
      cardHeight: [236, 140, 340],
      radius: [RADIUS.card, 0, 28],
      footerPad: [12, 4, 24],
      gap: [6, 0, 16],
    },

    // Surface (shared across all three)
    surface: {
      borderWidth: [0.75, 0, 4],
      borderOpacity: [0.14, 0, 0.35],
      sheenOpacity: [0.06, 0, 0.25],
      bgOpacity: [0.02, 0, 0.12],
      darkMode: false,
    },

    // Shadow at rest — dual system: ambient + contact (from FileRow.swift)
    restShadow: {
      ambientY: [1, 0, 12],
      ambientBlur: [3, 0, 40],
      ambientAlpha: [0.03, 0, 0.2],
      contactY: [1, 0, 4],
      contactBlur: [1, 0, 12],
      contactAlpha: [0.05, 0, 0.25],
    },

    // Shadow on hover — elevated dual system
    hoverShadow: {
      ambientY: [2, 0, 24],
      ambientBlur: [5, 0, 56],
      ambientAlpha: [0.08, 0, 0.3],
      contactY: [1, 0, 8],
      contactBlur: [1.5, 0, 20],
      contactAlpha: [0.10, 0, 0.35],
    },

    // Typography
    type: {
      nameSize: [13, 10, 20],
      nameWeight: { type: 'select', options: ['400', '500', '600', '700'], default: '500' },
      metaSize: [11, 9, 16],
      markerWidth: [3, 0, 8],
    },

    // Interaction — hover
    hover: {
      scale: [1.008, 1, 1.05],
      lift: [1, 0, 8],
      overlayAlpha: [0.03, 0, 0.12],
    },

    // Selection
    selection: {
      overlayAlpha: [0.06, 0, 0.2],
      borderAlpha: [0.3, 0, 0.6],
      accent: '#5B7C99',
    },

    // Spring
    spring: { type: 'spring', visualDuration: 0.2, bounce: 0.12 },

    resetAll: { type: 'action', label: 'Reset All' },
  }, {
    onAction: (action) => {
      if (action === 'resetAll') window.location.reload()
    },
  })

  const darkMode = activeTab === 'fileSurfaces' ? fp.surface.darkMode : qaParams.surface.darkMode
  const bgColor = darkMode ? '#1a1a1a' : FORMA.boneWhite

  const qaVariants = ['horizontal', 'vertical', 'compact']
  const qaDescriptions = {
    horizontal: 'Current layout -- icon left, content center, action right',
    vertical: 'Stacked -- icon top, content middle, action bottom',
    compact: 'Dense -- single-line with inline action',
  }

  return (
    <>
      <DialRoot position="top-right" />

      {/* Sticky tab bar */}
      <div style={{
        position: 'sticky',
        top: 0,
        zIndex: 100,
        background: `${bgColor}ee`,
        backdropFilter: 'blur(12px)',
        WebkitBackdropFilter: 'blur(12px)',
        borderBottom: `1px solid rgba(${darkMode ? '245,242,237' : '42,42,42'},0.08)`,
        padding: '12px 40px',
        display: 'flex',
        gap: 4,
        transition: 'background 0.3s',
      }}>
        {[
          { id: 'quickActions', label: 'Quick Action Cards' },
          { id: 'fileSurfaces', label: 'File Surfaces' },
        ].map(tab => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            style={{
              padding: '6px 14px',
              borderRadius: 8,
              border: 'none',
              background: activeTab === tab.id
                ? (darkMode ? 'rgba(245,242,237,0.12)' : 'rgba(42,42,42,0.08)')
                : 'transparent',
              color: activeTab === tab.id
                ? (darkMode ? '#F5F2ED' : FORMA.obsidian)
                : (darkMode ? 'rgba(245,242,237,0.35)' : 'rgba(42,42,42,0.35)'),
              fontSize: 13,
              fontWeight: activeTab === tab.id ? 600 : 500,
              cursor: 'pointer',
              fontFamily: 'inherit',
              letterSpacing: '-0.01em',
              transition: 'all 0.15s',
            }}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Content */}
      <div style={{
        minHeight: '100vh',
        background: bgColor,
        padding: '24px 40px 80px',
        fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif',
        transition: 'background 0.3s ease',
        WebkitFontSmoothing: 'antialiased',
      }}>

        {/* ============ QUICK ACTION CARDS TAB ============ */}
        {activeTab === 'quickActions' && (
          <div style={{ maxWidth: 480, margin: '0 auto' }}>
            <h1 style={{
              fontSize: 18,
              fontWeight: 700,
              color: darkMode ? '#F5F2ED' : FORMA.obsidian,
              marginBottom: 4,
              letterSpacing: '-0.025em',
            }}>
              Quick Action Card Variations
            </h1>
            <p style={{
              fontSize: 13,
              color: darkMode ? 'rgba(245,242,237,0.45)' : 'rgba(42,42,42,0.45)',
              marginBottom: 36,
              lineHeight: 1.5,
            }}>
              Tune every property with the DialKit panel on the right. All three layout variants update in real time.
            </p>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 28 }}>
              {qaVariants.map((variant) => (
                <div key={variant}>
                  <SectionLabel title={variant} subtitle={qaDescriptions[variant]} darkMode={darkMode} />
                  <QuickActionCard
                    params={qaParams}
                    variant={variant}
                    isHovered={hoveredQA[variant] || false}
                    setIsHovered={(v) => setHoveredQA(prev => ({ ...prev, [variant]: v }))}
                  />
                </div>
              ))}
            </div>
          </div>
        )}

        {/* ============ FILE SURFACES TAB ============ */}
        {activeTab === 'fileSurfaces' && (
          <div style={{ maxWidth: 720, margin: '0 auto' }}>
            <h1 style={{
              fontSize: 18,
              fontWeight: 700,
              color: darkMode ? '#F5F2ED' : FORMA.obsidian,
              marginBottom: 4,
              letterSpacing: '-0.025em',
            }}>
              File Surface Variations
            </h1>
            <p style={{
              fontSize: 13,
              color: darkMode ? 'rgba(245,242,237,0.45)' : 'rgba(42,42,42,0.45)',
              marginBottom: 36,
              lineHeight: 1.5,
            }}>
              Card row, list row, and grid tile — tuned from the FileSurfaces panel. Click to toggle selection. Hover to preview interaction.
            </p>

            {/* — Card Rows — */}
            <SectionLabel
              title="Card Row"
              subtitle="FileRow.swift — dual shadow, sheen overlay, full accessories"
              darkMode={darkMode}
            />
            <div style={{ display: 'flex', flexDirection: 'column', gap: 6, marginBottom: 40 }}>
              {SAMPLE_FILES.slice(0, 4).map((file, i) => {
                const key = `card-${i}`
                const s = getFS(key)
                return (
                  <FileCardRow
                    key={key}
                    file={file}
                    fp={fp}
                    isHovered={s.hovered}
                    isSelected={s.selected}
                    onHover={(v) => setHover(key, v)}
                    onSelect={(v) => setSelected(key, v)}
                  />
                )
              })}
            </div>

            {/* — List Rows — */}
            <SectionLabel
              title="List Row"
              subtitle="FileListRow.swift — compact, no rest shadow, reveal-on-hover actions"
              darkMode={darkMode}
            />
            <div style={{ display: 'flex', flexDirection: 'column', gap: 2, marginBottom: 40 }}>
              {SAMPLE_FILES.map((file, i) => {
                const key = `list-${i}`
                const s = getFS(key)
                return (
                  <FileListRow
                    key={key}
                    file={file}
                    fp={fp}
                    isHovered={s.hovered}
                    isSelected={s.selected}
                    onHover={(v) => setHover(key, v)}
                    onSelect={(v) => setSelected(key, v)}
                  />
                )
              })}
            </div>

            {/* — Grid Items — */}
            <SectionLabel
              title="Grid"
              subtitle="FileGridItem.swift — media preview area, gradient scrim on hover"
              darkMode={darkMode}
            />
            <div style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(3, 1fr)',
              gap: 12,
              marginBottom: 40,
            }}>
              {SAMPLE_FILES.slice(0, 3).map((file, i) => {
                const key = `grid-${i}`
                const s = getFS(key)
                return (
                  <FileGridItem
                    key={key}
                    file={file}
                    fp={fp}
                    isHovered={s.hovered}
                    isSelected={s.selected}
                    onHover={(v) => setHover(key, v)}
                    onSelect={(v) => setSelected(key, v)}
                  />
                )
              })}
            </div>
            <div style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(3, 1fr)',
              gap: 12,
            }}>
              {SAMPLE_FILES.slice(3).map((file, i) => {
                const key = `grid-${i + 3}`
                const s = getFS(key)
                return (
                  <FileGridItem
                    key={key}
                    file={file}
                    fp={fp}
                    isHovered={s.hovered}
                    isSelected={s.selected}
                    onHover={(v) => setHover(key, v)}
                    onSelect={(v) => setSelected(key, v)}
                  />
                )
              })}
            </div>
          </div>
        )}
      </div>
    </>
  )
}

export default App
