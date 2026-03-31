import { renderToStaticMarkup } from "react-dom/server"
import { describe, expect, it } from "vitest"

import {
  NewsletterSignupForm,
  type NewsletterErrorKind,
} from "../src/components/sections/NewsletterSection"

function renderForm(errorKind: NewsletterErrorKind) {
  return renderToStaticMarkup(
    <NewsletterSignupForm
      email="person@example.com"
      formState="error"
      errorKind={errorKind}
      errorMessage="Something went wrong. Try again."
      onEmailChange={() => {}}
      onSubmit={() => {}}
    />
  )
}

describe("NewsletterSignupForm", () => {
  it("does not mark the email field invalid for submit failures", () => {
    const html = renderForm("submit")

    expect(html).not.toContain('aria-invalid="true"')
    expect(html).not.toContain("border-red-400")
    expect(html).toContain("Something went wrong. Try again.")
  })

  it("marks the email field invalid for validation failures", () => {
    const html = renderForm("validation")

    expect(html).toContain('aria-invalid="true"')
    expect(html).toContain("border-red-400")
  })
})
