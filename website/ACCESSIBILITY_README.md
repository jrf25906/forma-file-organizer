# Accessibility Documentation - Forma Website
## Complete Guide to WCAG 2.1 AA Compliance

---

## 📚 DOCUMENTATION INDEX

This accessibility documentation package contains:

1. **ACCESSIBILITY_SUMMARY.md** ⭐ **START HERE**
   - Quick reference guide
   - Top 5 critical fixes
   - Implementation strategy
   - Testing checklist

2. **ACCESSIBILITY_AUDIT.md**
   - Complete WCAG 2.1 AA audit report
   - Detailed issue analysis
   - Prioritized fix list
   - Testing recommendations

3. **ACCESSIBILITY_FIXES.md**
   - Line-by-line code changes
   - Copy-paste ready fixes
   - File locations and line numbers
   - Verification steps

4. **COLOR_CONTRAST_REFERENCE.md**
   - Color contrast calculations
   - Before/after comparisons
   - Quick conversion table
   - Brand color analysis

5. **src/hooks/useReducedMotion.ts**
   - Ready-to-use React hook
   - Detects motion preferences
   - Drop-in solution

---

## 🚀 QUICK START

### For Developers (First Time)

```bash
# 1. Read the summary (5 minutes)
cat ACCESSIBILITY_SUMMARY.md

# 2. Implement Phase 1 fixes (2-3 hours)
# Open ACCESSIBILITY_FIXES.md and follow instructions

# 3. Test your changes
npm run dev
# Press Tab key on homepage - skip link should appear
# Enable VoiceOver (Cmd+F5) - test navigation

# 4. Run automated tests
# Install axe DevTools browser extension
# Or use: npm install -D @axe-core/cli
```

### For Project Managers

1. Read **ACCESSIBILITY_SUMMARY.md** (10 min)
2. Review **ACCESSIBILITY_AUDIT.md** executive summary (5 min)
3. Schedule 8-10 hours development time across 3 days
4. Plan accessibility testing session with QA team

### For Designers

1. Review **COLOR_CONTRAST_REFERENCE.md**
2. Update design system with new opacity values
3. Ensure all future designs meet 4.5:1 contrast
4. Document accessible color combinations

---

## 📋 CURRENT STATUS

**Date of Audit:** December 8, 2025
**WCAG Compliance:** ❌ Level A (partial), ❌ Level AA
**Critical Issues:** 5
**Estimated Fix Time:** 8-10 hours

### Issues Breakdown

| Priority | Count | Time to Fix | Impact |
|----------|-------|-------------|--------|
| 🔴 Critical | 5 | 6 hours | High |
| ⚠️ High | 3 | 2 hours | Medium |
| 📋 Moderate | 2 | 1 hour | Low |
| **Total** | **10** | **~9 hours** | **WCAG AA** |

---

## 🎯 THREE-PHASE IMPLEMENTATION PLAN

### Phase 1: Foundation (Day 1 - 2-3 hours)
**Goal:** Make site keyboard accessible with readable text

**Tasks:**
1. Update color contrast in `globals.css`
2. Add skip link to `layout.tsx`
3. Add skip link styles
4. Test keyboard navigation

**Deliverables:**
- ✅ Text meets 4.5:1 contrast ratio
- ✅ Skip link appears on Tab
- ✅ Keyboard users can navigate efficiently

**Files Modified:** 3
- `src/app/globals.css`
- `src/app/layout.tsx`
- `src/app/page.tsx`

---

### Phase 2: Semantics (Day 2 - 2-3 hours)
**Goal:** Make site screen reader accessible

**Tasks:**
1. Add ARIA labels to all icon buttons
2. Add focus indicator styles
3. Increase touch target sizes
4. Test with VoiceOver

**Deliverables:**
- ✅ All buttons have accessible names
- ✅ Focus indicators visible
- ✅ Touch targets ≥ 44×44px
- ✅ Screen reader announces all elements

**Files Modified:** 4
- `src/components/Navigation.tsx`
- `src/components/FAQ.tsx`
- `src/components/Pricing.tsx`
- `src/app/globals.css`

---

### Phase 3: Motion & Polish (Day 3 - 2-3 hours)
**Goal:** Respect user preferences, final testing

**Tasks:**
1. Implement `useReducedMotion` hook
2. Add CSS media query for reduced motion
3. Update `Hero.tsx` animation logic
4. Run comprehensive tests
5. Fix any remaining issues

**Deliverables:**
- ✅ Animations respect user preferences
- ✅ Zero critical issues in axe DevTools
- ✅ Lighthouse score ≥ 95
- ✅ WCAG 2.1 AA compliant

**Files Modified:** 3
- `src/hooks/useReducedMotion.ts` (already created)
- `src/components/Hero.tsx`
- `src/app/globals.css`

---

## 🧪 TESTING STRATEGY

### Automated Testing

#### Install Tools
```bash
# Browser extensions
- axe DevTools (Chrome/Firefox/Edge)
- WAVE (Chrome/Firefox)
- Lighthouse (built into Chrome)

# Command line (optional)
npm install -D @axe-core/cli pa11y
```

#### Run Tests
```bash
# Lighthouse
npm run build
npx serve out
# Open Chrome DevTools > Lighthouse > Accessibility

# axe-core (if installed)
npx axe http://localhost:3000

# Pa11y (if installed)
npx pa11y http://localhost:3000
```

---

### Manual Testing

#### Keyboard Navigation Test
```
1. Refresh homepage
2. Press Tab key
   ✓ Skip link should appear at top
3. Press Enter on skip link
   ✓ Should jump to main content
4. Continue tabbing through page
   ✓ All interactive elements reachable
   ✓ Focus indicator visible on each
   ✓ No focus traps
5. Press Shift+Tab to go backwards
   ✓ Reverse order works correctly
```

#### Screen Reader Test (macOS)
```
1. Press Cmd+F5 to enable VoiceOver
2. Use VoiceOver commands:
   - Ctrl+Option+Right Arrow: Next element
   - Ctrl+Option+Space: Activate element
   - Ctrl+Option+H: Next heading
3. Verify announcements:
   ✓ "Toggle theme button"
   ✓ "Open menu button"
   ✓ "Skip to main content link"
   ✓ All headings announce correctly
4. Press Cmd+F5 to disable VoiceOver
```

#### Color Contrast Test
```
1. Open Chrome DevTools
2. Inspect any text element
3. In Styles panel, click color value
4. Color picker shows contrast ratio
5. Look for checkmarks:
   ✓ AA (normal text): ≥ 4.5:1
   ✓ AA (large text): ≥ 3:1
```

#### Reduced Motion Test
```
1. Open System Preferences > Accessibility
2. Enable "Reduce motion"
3. Reload website
   ✓ Floating orbs should be static
   ✓ Hero animation should show final state
   ✓ Framer Motion transitions disabled
4. Disable "Reduce motion"
   ✓ Animations return
```

#### Zoom Test
```
1. Press Cmd++ to zoom to 200%
2. Verify:
   ✓ No horizontal scrollbar
   ✓ All text readable
   ✓ No content cut off
   ✓ Buttons remain clickable
3. Press Cmd+0 to reset zoom
```

---

## 📊 EXPECTED RESULTS

### Before Fixes
```
axe DevTools:        12 issues (5 critical)
Lighthouse:          78/100
Keyboard Nav:        Difficult (no skip link)
Screen Reader:       Missing button labels
Color Contrast:      Multiple failures
Motion Preferences:  Not respected
```

### After Phase 1
```
axe DevTools:        8 issues (2 critical)
Lighthouse:          85/100
Keyboard Nav:        Good (has skip link)
Screen Reader:       Partial support
Color Contrast:      All pass
Motion Preferences:  Not respected
```

### After All Phases
```
axe DevTools:        0 critical issues
Lighthouse:          95+/100
Keyboard Nav:        Excellent
Screen Reader:       Fully accessible
Color Contrast:      All pass AA
Motion Preferences:  Fully respected
WCAG 2.1 AA:         ✅ COMPLIANT
```

---

## 🛠️ TROUBLESHOOTING

### Issue: Skip link doesn't appear
**Solution:**
1. Check `layout.tsx` - skip link should be first child of `<body>`
2. Check `globals.css` - `.skip-link:focus` should set `top: 0`
3. Clear browser cache and reload

### Issue: Color contrast still failing
**Solution:**
1. Verify you updated both dark and light mode values
2. Check `globals.css` lines 25, 35, 112-142
3. Use Chrome DevTools to inspect specific element
4. May need to hard refresh (Cmd+Shift+R)

### Issue: VoiceOver not announcing buttons
**Solution:**
1. Verify `aria-label` attribute is present
2. Check spelling - must be `aria-label`, not `ariaLabel`
3. Restart VoiceOver (Cmd+F5 twice)

### Issue: Animations still playing with reduced motion
**Solution:**
1. Check `globals.css` - media query should be present
2. Verify System Preferences > Accessibility > Reduce motion is ON
3. Hard refresh browser (Cmd+Shift+R)
4. Check `Hero.tsx` - `useReducedMotion` hook should be imported

### Issue: Focus indicators not visible
**Solution:**
1. Check `globals.css` - `:focus-visible` styles should be present
2. Make sure you're using keyboard (Tab), not mouse
3. Some browsers require `:focus-visible` polyfill for older versions

---

## 📖 LEARNING RESOURCES

### WCAG Guidelines
- [WCAG 2.1 Quick Reference](https://www.w3.org/WAI/WCAG21/quickref/)
- [Understanding WCAG 2.1](https://www.w3.org/WAI/WCAG21/Understanding/)
- [How to Meet WCAG](https://www.w3.org/WAI/WCAG21/quickref/)

### Testing Tools
- [axe DevTools](https://www.deque.com/axe/devtools/)
- [WAVE Browser Extension](https://wave.webaim.org/extension/)
- [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/)

### Best Practices
- [Inclusive Components](https://inclusive-components.design/)
- [A11y Project](https://www.a11yproject.com/)
- [MDN Accessibility](https://developer.mozilla.org/en-US/docs/Web/Accessibility)

### React & Next.js
- [Next.js Accessibility](https://nextjs.org/docs/accessibility)
- [React Accessibility](https://react.dev/learn/accessibility)
- [Framer Motion Accessibility](https://www.framer.com/motion/accessibility/)

---

## 🤝 CONTRIBUTION GUIDELINES

### Before Submitting PR

1. **Run All Tests**
   ```bash
   npm run build
   npm run test:a11y  # if configured
   ```

2. **Manual Testing Checklist**
   - [ ] Keyboard navigation works
   - [ ] Skip link appears on Tab
   - [ ] Screen reader announces correctly
   - [ ] Color contrast passes in both themes
   - [ ] Reduced motion works
   - [ ] Focus indicators visible
   - [ ] Touch targets ≥ 44px

3. **Documentation**
   - Update this file if adding new components
   - Document any accessibility features
   - Note any WCAG exceptions (if justified)

### PR Template
```markdown
## Accessibility Impact

- [ ] No accessibility changes
- [ ] Improves accessibility
- [ ] Adds new accessible component
- [ ] Tested with keyboard navigation
- [ ] Tested with screen reader
- [ ] Passes axe DevTools
- [ ] Passes Lighthouse

## Testing Notes

[Describe how you tested accessibility]

## Screenshots

[Before/after if visual changes]
```

---

## 📞 SUPPORT

### Questions?
- **Technical:** Review `ACCESSIBILITY_FIXES.md` for detailed implementation
- **Testing:** Check "Testing Strategy" section above
- **WCAG Standard:** Refer to [WCAG 2.1 Quick Reference](https://www.w3.org/WAI/WCAG21/quickref/)

### Need Help?
1. Check `TROUBLESHOOTING` section above
2. Review `ACCESSIBILITY_AUDIT.md` for context
3. Consult `COLOR_CONTRAST_REFERENCE.md` for color issues
4. Test with automated tools (axe DevTools)

---

## 🎉 COMPLETION CHECKLIST

When all fixes are implemented, verify:

- [ ] All files in `ACCESSIBILITY_FIXES.md` updated
- [ ] `useReducedMotion.ts` hook copied to project
- [ ] Skip link appears on Tab press
- [ ] All icon buttons have ARIA labels
- [ ] Color contrast passes in both themes
- [ ] Focus indicators visible on all elements
- [ ] Touch targets ≥ 44×44px
- [ ] Animations respect reduced motion
- [ ] axe DevTools shows 0 critical issues
- [ ] Lighthouse accessibility score ≥ 95
- [ ] Manual keyboard testing passes
- [ ] Screen reader testing passes
- [ ] Both light and dark modes tested

### Post-Implementation

- [ ] Create accessibility statement page
- [ ] Document keyboard shortcuts
- [ ] Add accessibility section to main README
- [ ] Train team on accessibility testing
- [ ] Schedule quarterly accessibility audits

---

## 📈 MAINTENANCE

### Regular Checks (Monthly)
- Run axe DevTools on all pages
- Test new components with keyboard
- Verify color contrast on new designs
- Check for any WCAG updates

### Adding New Components
```typescript
// Checklist for new components
- [ ] Semantic HTML elements
- [ ] ARIA labels on icon buttons
- [ ] Keyboard accessible
- [ ] Focus indicators
- [ ] Color contrast ≥ 4.5:1
- [ ] Touch targets ≥ 44px
- [ ] Respects reduced motion
- [ ] Screen reader tested
```

### Version Updates
When updating dependencies:
- Re-test with axe DevTools
- Verify Framer Motion animations still respect motion preferences
- Check for new WCAG guidelines
- Update this documentation if needed

---

## 🏆 SUCCESS METRICS

After full implementation, you will have:

✅ **WCAG 2.1 Level AA Compliant**
✅ **Lighthouse Accessibility Score: 95+**
✅ **Zero Critical Issues in axe DevTools**
✅ **Fully Keyboard Navigable**
✅ **Screen Reader Compatible**
✅ **Respects Motion Preferences**
✅ **4.5:1 Minimum Color Contrast**
✅ **44×44px Touch Targets**
✅ **Inclusive for All Users**

---

**Ready to start?** Open `ACCESSIBILITY_SUMMARY.md` for the quick start guide!

**Last Updated:** December 8, 2025
**Audit Version:** 1.0
**WCAG Standard:** 2.1 Level AA
