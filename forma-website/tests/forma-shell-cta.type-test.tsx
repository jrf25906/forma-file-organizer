import { FormaShellCta } from "../src/components/ui/forma-shell-cta"

// @ts-expect-error size should not be part of the public CTA API
const invalid = <FormaShellCta size="lg" />

void invalid
