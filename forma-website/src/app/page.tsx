import Image from "next/image";
import Link from "next/link";
import { TrackedAppStoreLink } from "@/components/TrackedAppStoreLink";
import { TrackedMailtoLink } from "@/components/TrackedMailtoLink";
import { FormaLogoImage } from "@/components/icons";
import { SUPPORT_EMAIL, SITE_NAME, SITE_URL, WEBSITE_LAST_UPDATED_ISO } from "@/lib/site";
import { faqs } from "@/lib/faq";
import styles from "./page.module.css";

const trustItems = [
  "Native macOS",
  "Local-only",
  "Full undo",
  "No account",
  "Works offline",
] as const;

const ruleRows = [
  { left: "Move screenshots to", right: "~/Screenshots" },
  { left: "Rename invoices by", right: "date" },
  { left: "Sort code files into", right: "~/Projects" },
] as const;

const groupingSamples = [
  {
    label: "Images",
    count: 3,
    color: "#4A6B88",
    files: ["hero.png", "banner.jpg", "icon.svg"],
  },
  {
    label: "Documents",
    count: 2,
    color: "#5E7A63",
    files: ["report.pdf", "notes.md"],
  },
] as const;

const beforeRows = [
  "Screenshot 2024-01-15 at 3.42.17 PM.png",
  "IMG_4829.HEIC",
  "Document (3).pdf",
  "final_FINAL_v2_actual_final.docx",
  "Untitled.txt",
] as const;

const productLinks = [
  { label: "Features", href: "/#features" },
  { label: "Pricing", href: "/#pricing" },
  { label: "FAQ", href: "/support" },
] as const;

const guideLinks = [
  { label: "Organize Mac Files", href: "/blog/organize-mac-files" },
  { label: "Organize Downloads", href: "/blog/organize-downloads-folder-mac" },
  { label: "Organize Desktop", href: "/blog/organize-desktop-files-mac" },
] as const;

const legalLinks = [
  { label: "Privacy", href: "/privacy" },
  { label: "Terms", href: "/terms" },
  { label: "Support", href: "/support" },
] as const;

export default function Home() {
  const softwareApplicationJsonLd = {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: SITE_NAME,
    applicationCategory: "ProductivityApplication",
    operatingSystem: "macOS 15+",
    offers: {
      "@type": "Offer",
      price: "29",
      priceCurrency: "USD",
      description: "One-time purchase. No subscription.",
      url: `${SITE_URL}/#pricing`,
    },
    description:
      "A file organizer for people who gave up on file organizers. Make rules, preview, approve, undo.",
    featureList: [
      "Human-readable rules",
      "Preview before moving",
      "Full undo history",
      "Local-only privacy",
    ],
    url: SITE_URL,
  };

  const organizationJsonLd = {
    "@context": "https://schema.org",
    "@type": "Organization",
    name: SITE_NAME,
    url: SITE_URL,
    sameAs: [],
  };

  const websiteJsonLd = {
    "@context": "https://schema.org",
    "@type": "WebSite",
    name: SITE_NAME,
    url: SITE_URL,
    inLanguage: "en-US",
    dateModified: WEBSITE_LAST_UPDATED_ISO,
  };

  const faqJsonLd = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: faqs.map((faqEntry) => ({
      "@type": "Question",
      name: faqEntry.question,
      acceptedAnswer: {
        "@type": "Answer",
        text: faqEntry.answer,
      },
    })),
  };

  return (
    <div className={styles.pageShell}>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify({
            "@context": "https://schema.org",
            "@graph": [
              softwareApplicationJsonLd,
              organizationJsonLd,
              websiteJsonLd,
              faqJsonLd,
            ],
          }),
        }}
      />

      <main id="top" className={styles.page}>
        <section className={styles.hero} aria-label="Hero">
          <div className={styles.heroTextCol}>
            <span className={styles.heroEyebrow}>File organization for macOS</span>
            <h1 className={styles.heroTitle}>
              A file organizer for people who gave up on file organizers.
            </h1>
            <p className={styles.heroCopy}>Make rules. Preview everything. Undo anything.</p>

            <div className={styles.heroCtaStack}>
              <div className={styles.heroCtaRow}>
                <TrackedAppStoreLink location="hero_primary" className={styles.ctaPrimary}>
                  Download for Mac
                </TrackedAppStoreLink>
                <a href="/demos/forma-app-demo.gif" className={styles.ctaSecondary}>
                  Watch 90-second demo
                </a>
              </div>
              <span className={styles.heroMeta}>$29 once · macOS 15+ · No subscription</span>
            </div>
          </div>

          <div className={styles.macbook} role="img" aria-label="MacBook app preview">
            <div className={styles.macScreen}>
              <div className={styles.notch} />
              <div className={styles.reflectionLeft} />
              <div className={styles.reflectionRight} />
              <div className={styles.topSheen} />
              <div className={styles.appWindow}>
                <Image
                  src="/screenshots/light/forma-01-hero-main-window.png"
                  alt="Forma app showing Preview Queue and rules"
                  width={620}
                  height={374}
                  priority
                />
              </div>
            </div>
            <div className={styles.macBase} aria-hidden="true">
              <div className={styles.baseDetail1} />
              <div className={styles.baseDetail2} />
              <div className={styles.baseDetail3} />
            </div>
            <div className={styles.deskShadow} aria-hidden="true" />
          </div>
        </section>

        <section className={styles.trust} aria-label="Trust line">
          {trustItems.map((item, index) => (
            <div key={item} className={styles.trustItemWrap}>
              <span className={styles.trustItem}>{item}</span>
              {index < trustItems.length - 1 ? <span className={styles.trustDot}>·</span> : null}
            </div>
          ))}
        </section>

        <section id="features" className={styles.features} aria-label="Features">
          <div className={styles.sectionHead}>
            <span className={styles.sectionLabel}>Features</span>
            <div className={styles.headLine} />
          </div>

          <article className={styles.featureHero}>
            <div className={styles.featureCopyCol}>
              <span className={styles.featureTag}>01 Rules</span>
              <h2 className={styles.featureTitleLg}>If you can say it, you can automate it.</h2>
              <span className={styles.featureBodyLg}>
                No regex. No scripts. No config files. Conditions and destinations in plain
                language — like telling a friend where to put things.
              </span>
            </div>

            <div className={styles.ruleCol} role="group" aria-label="Rule examples">
              {ruleRows.map((row) => (
                <div key={row.left} className={styles.ruleRow}>
                  <span className={styles.ruleLeft}>{row.left}</span>
                  <span className={styles.ruleRight}>{row.right}</span>
                </div>
              ))}
            </div>
          </article>

          <div className={styles.featureRow}>
            <article className={styles.miniCard}>
              <span className={`${styles.miniTag} ${styles.groupingTag}`}>02 Grouping</span>
              <h3 className={styles.miniTitle}>200 screenshots. One rule.</h3>
              <span className={styles.miniBody}>
                Similar files grouped automatically. One rule handles all of them.
              </span>

              <div className={styles.groupFiles} role="group" aria-label="Grouped examples">
                {groupingSamples.map((group) => (
                  <div key={group.label} className={styles.groupCategory}>
                    <div className={styles.groupCategoryHead}>
                      <span
                        className={styles.groupDot}
                        style={{ backgroundColor: group.color }}
                      />
                      <span className={styles.groupLabel}>
                        {group.label} ({group.count})
                      </span>
                    </div>
                    <div className={styles.groupChipRow}>
                      {group.files.map((file) => (
                        <span key={file} className={styles.groupChip}>
                          {file}
                        </span>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            </article>

            <article className={styles.miniCard}>
              <span className={`${styles.miniTag} ${styles.previewTag}`}>03 Preview</span>
              <h3 className={styles.miniTitle}>Nothing moves until you say so.</h3>
              <span className={styles.miniBody}>
                See what happens before it happens. Toggle files on or off, then approve.
              </span>

              <div className={styles.previewFiles} role="group" aria-label="Preview examples">
                <div className={styles.previewChip}>
                  <span className={styles.previewCheck} style={{ backgroundColor: "#4A6B88" }}>
                    <span className={styles.previewCheckmark}>✓</span>
                  </span>
                  <span className={styles.previewName}>Screenshot.png</span>
                  <span className={styles.previewDest}>→ ~/Screenshots</span>
                </div>
                <div className={styles.previewChip}>
                  <span className={styles.previewCheck} style={{ backgroundColor: "#B86B52" }}>
                    <span className={styles.previewCheckmark}>✓</span>
                  </span>
                  <span className={styles.previewName}>Invoice.pdf</span>
                  <span className={styles.previewDest}>→ ~/Documents</span>
                </div>
                <div className={styles.previewSkipped}>
                  <span className={styles.previewCheckEmpty} />
                  <span className={styles.previewNameSkipped}>notes.txt</span>
                  <span className={styles.previewSkippedLabel}>skipped</span>
                </div>
              </div>
            </article>
          </div>

          <article className={styles.undoStrip}>
            <div className={styles.undoLeft}>
              <span className={styles.undoTag}>04 Undo</span>
              <span className={styles.undoTitle}>Undo everything. Always.</span>
            </div>

            <span className={styles.undoCopy}>
              Full activity timeline. Reverse any move, any time. Every action is tracked.
            </span>

            <div className={styles.undoActions} role="group" aria-label="Undo action chips">
              <span className={styles.undoBtn}>Undo</span>
              <span className={styles.undoBtn}>Undo</span>
              <span className={styles.doneBtn}>Done</span>
            </div>
          </article>
        </section>

        <section className={styles.beforeAfter} aria-label="Before and after">
          <div className={styles.sectionHead}>
            <span className={styles.sectionLabel}>Before / After</span>
            <div className={styles.headLine} />
          </div>

          <div className={styles.baRowWrap}>
            <article className={styles.baCard} aria-label="Before files">
              <span className={`${styles.baTitle} ${styles.beforeTitle}`}>Before</span>
              {beforeRows.map((row) => (
                <span key={row} className={styles.baItem}>
                  {row}
                </span>
              ))}
            </article>

            <article className={styles.baCard} aria-label="After files">
              <span className={`${styles.baTitle} ${styles.afterTitle}`}>After</span>
              <span className={`${styles.baItem} ${styles.baItemAfter}`}>
                Screenshots/<span className={styles.baMeta}>3 files</span>
              </span>
              <span className={`${styles.baItem} ${styles.baItemAfter}`}>
                Documents/<span className={styles.baMeta}>2 files</span>
              </span>
              <span className={styles.baNote}>One rule. Done.</span>
            </article>
          </div>

          <div className={styles.midCta}>
            <h3 className={styles.midCtaTitle}>Ready to clean up?</h3>
            <TrackedAppStoreLink location="hero_primary" className={styles.midCtaBtn}>
              Download for Mac
            </TrackedAppStoreLink>
          </div>
        </section>

        <section id="pricing" className={styles.pricing} aria-label="Pricing">
          <div className={styles.sectionHead}>
            <span className={styles.sectionLabel}>Pricing</span>
            <div className={styles.headLine} />
          </div>

          <article className={styles.priceCard}>
            <div className={styles.priceLeftWrap}>
              <h2 className={styles.price}>$29</h2>
              <span className={styles.priceCopy}>
                One-time purchase. No subscription. No account.
                <br />
                Works offline. Yours forever.
              </span>
            </div>

            <div className={styles.priceRight}>
              <TrackedAppStoreLink location="pricing_primary" className={styles.priceBtn}>
                Download for Mac
              </TrackedAppStoreLink>
              <span className={styles.priceMeta}>Requires macOS 15+</span>
            </div>
          </article>
        </section>
      </main>

      <footer className={styles.footer} aria-label="Footer">
        <div className={styles.footerTop}>
          <div className={styles.footerBrand}>
            <Link href="/#top" className={styles.footerBrandLockup}>
              <FormaLogoImage size={24} />
              <span className={styles.footerBrandText}>Forma</span>
            </Link>
            <TrackedMailtoLink
              email={SUPPORT_EMAIL}
              location="footer"
              className={styles.footerEmail}
            >
              {SUPPORT_EMAIL}
            </TrackedMailtoLink>
          </div>

          <div className={styles.footerLinks}>
            <div className={styles.linkCol}>
              <span className={styles.linkColHead}>Product</span>
              {productLinks.map((link) => (
                <Link key={link.href} href={link.href}>
                  {link.label}
                </Link>
              ))}
            </div>
            <div className={styles.linkCol}>
              <span className={styles.linkColHead}>Guides</span>
              {guideLinks.map((link) => (
                <Link key={link.href} href={link.href}>
                  {link.label}
                </Link>
              ))}
            </div>
            <div className={styles.linkCol}>
              <span className={styles.linkColHead}>Legal</span>
              {legalLinks.map((link) => (
                <Link key={link.href} href={link.href}>
                  {link.label}
                </Link>
              ))}
            </div>
          </div>
        </div>

        <div className={styles.footerBottom}>
          <span className={styles.copyright}>© 2026 Forma. macOS app.</span>
        </div>
      </footer>
    </div>
  );
}
