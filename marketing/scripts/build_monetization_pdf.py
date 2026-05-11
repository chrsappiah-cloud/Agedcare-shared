#!/usr/bin/env python3
# © World Class Scholars - Dr Christopher Appiah-Thompson
"""Build the WCS Care Monetization Plan PDF (fpdf2, AppTheme palette)."""
import sys
from pathlib import Path
from fpdf import FPDF

EMERALD = (0, 95, 71)
RUBY = (155, 17, 30)
DIAMOND = (245, 246, 240)
CHOCOLATE = (45, 30, 22)
GOLD = (190, 154, 56)
INK = (28, 28, 28)
MUTED = (110, 110, 110)


class Theme(FPDF):
    def header(self):
        if self.page_no() == 1:
            return
        self.set_fill_color(*EMERALD)
        self.rect(0, 0, 210, 12, "F")
        self.set_text_color(*DIAMOND)
        self.set_font("Helvetica", "B", 9)
        self.set_xy(10, 3.5)
        self.cell(0, 5, "WCS Care - TestFlight Monetization Plan", align="L")
        self.set_xy(-60, 3.5)
        self.cell(50, 5, "World Class Scholars", align="R")
        self.ln(14)

    def footer(self):
        self.set_y(-12)
        self.set_draw_color(*EMERALD)
        self.set_line_width(0.4)
        self.line(10, self.get_y(), 200, self.get_y())
        self.set_font("Helvetica", "", 8)
        self.set_text_color(*MUTED)
        self.set_y(-10)
        self.cell(0, 5, f"Page {self.page_no()}", align="C")


def h1(p, t):
    p.set_font("Helvetica", "B", 17); p.set_text_color(*EMERALD)
    p.cell(0, 9, t, ln=True)
    p.set_draw_color(*GOLD); p.set_line_width(0.8)
    y = p.get_y(); p.line(10, y, 60, y); p.ln(5)


def h2(p, t):
    p.set_font("Helvetica", "B", 12); p.set_text_color(*CHOCOLATE)
    p.cell(0, 7, t, ln=True); p.ln(0.5)


def body(p, t):
    p.set_font("Helvetica", "", 10); p.set_text_color(*INK)
    p.multi_cell(0, 5.2, t); p.ln(0.8)


def bullets(p, items):
    p.set_font("Helvetica", "", 10); p.set_text_color(*INK)
    for it in items:
        p.set_x(14)
        p.multi_cell(0, 5.2, f"-  {it}")
    p.ln(0.8)


def pill(p, x, y, w, h, text, color):
    p.set_fill_color(*color); p.set_text_color(*DIAMOND)
    p.rect(x, y, w, h, "F", round_corners=True, corner_radius=2)
    p.set_xy(x, y + 1.6); p.set_font("Helvetica", "B", 9)
    p.cell(w, h - 3, text, align="C")


def cover(p):
    p.add_page()
    p.set_fill_color(*EMERALD); p.rect(0, 0, 210, 297, "F")
    p.set_fill_color(*GOLD); p.rect(0, 145, 210, 6, "F")
    p.set_text_color(*DIAMOND)
    p.set_font("Helvetica", "B", 28); p.set_xy(15, 90); p.cell(0, 12, "WCS Care", ln=True)
    p.set_font("Helvetica", "B", 17); p.set_xy(15, 105); p.cell(0, 9, "TestFlight Monetization Plan", ln=True)
    p.set_font("Helvetica", "", 12); p.set_xy(15, 120)
    p.cell(0, 7, "From clear value -> validated demand -> sustainable revenue.", ln=True)
    p.set_xy(15, 160); p.set_font("Helvetica", "B", 11)
    p.cell(0, 6, "Version 1.0.3  -  Released for TestFlight", ln=True)
    p.set_xy(15, 168); p.set_font("Helvetica", "", 11)
    p.cell(0, 6, "World Class Scholars  -  Dr Christopher Appiah-Thompson", ln=True)
    pill(p, 15, 200, 56, 9, "Starter (Free)", CHOCOLATE)
    pill(p, 77, 200, 56, 9, "Care Pro ($9.99/mo)", RUBY)
    pill(p, 139, 200, 56, 9, "Care Team (Custom)", GOLD)


def page_principles(p):
    p.add_page(); h1(p, "Principles & Segments")
    h2(p, "Monetization Principles")
    body(p, "WCS Care monetizes by solving a specific problem for carers and dementia support "
          "teams: reducing confusion, saving time, and making daily routines more consistent. "
          "The initial commercial model stays narrow and practical. TestFlight is for learning "
          "rather than immediate revenue maximization.")
    h2(p, "Customer Segments")
    bullets(p, [
        "Individual carers - family carers wanting a lightweight daily support system.",
        "Professional carers - support workers and small care teams who value shared notes, reports, and multi-profile management.",
        "Care organizations - dementia providers, clinics, residential groups; strongest candidates for higher-value subscriptions.",
    ])
    h2(p, "Operating Rule")
    body(p, "Finish something useful, publish it, learn from feedback, and repeat. Calm "
          "consistency beats rushing for immediate sales.")


def page_model(p):
    p.add_page(); h1(p, "Monetization Model")
    h2(p, "Stage 1 - TestFlight Validation")
    bullets(p, [
        "Do not charge for TestFlight access itself.",
        "Free beta access in exchange for regular feedback.",
        "Waitlist for the upcoming paid Care Pro plan.",
        "Pilot interest form for organizations.",
    ])
    h2(p, "Stage 2 - Soft Monetization After Beta")
    y = p.get_y() + 1
    pill(p, 10, y, 60, 8, "Starter - Free", CHOCOLATE)
    pill(p, 75, y, 60, 8, "Care Pro - $9.99/mo", RUBY)
    pill(p, 140, y, 60, 8, "Care Team - Custom", GOLD)
    p.ln(12)
    bullets(p, [
        "Starter: daily routines, reminders, mood logs (1 profile).",
        "Care Pro: unlimited profiles, weekly summaries, exportable reports, shared notes, premium activity packs.",
        "Care Team: multi-user staff access, reporting, shared care plans, onboarding support, admin dashboard.",
    ])


def page_gates(p):
    p.add_page(); h1(p, "Paid Feature Gates")
    body(p, "Premium features tied to measurable value, not novelty. Customers pay when the "
          "product clearly saves time, reduces confusion, or helps them avoid mistakes.")
    bullets(p, [
        "More than one care profile.",
        "Weekly caregiver summaries and exportable PDF reports.",
        "Shared care notes across staff or family members.",
        "Premium activity packs and reminiscence modules.",
        "Smart reminder templates and routine duplication.",
    ])
    h2(p, "Five Commercial Questions for the Beta")
    bullets(p, [
        "Which segment gets value fastest: family, professional, or organization?",
        "Which feature drives retention: routines, reminders, reports, or calming activities?",
        "Which message converts best: reduce confusion, save time, or improve consistency?",
        "Which plan feels credible: low-cost consumer or higher-value institutional?",
        "What proof is needed: testimonials, case studies, usage reports, clinical validation?",
    ])


def page_tactics(p):
    p.add_page(); h1(p, "TestFlight Tactics & Pricing")
    h2(p, "In-App Tactics (live in v1.0.3)")
    bullets(p, [
        "'Plans & Pricing' screen with Starter, Care Pro, Care Team (UpcomingPlansView.swift).",
        "Plan-tap demand tracking via BetaAnalytics.logPlanInterest(tier).",
        "Care Pro waitlist sheet with email capture.",
        "Care Team pilot request form linked to the Vercel pilot endpoint.",
        "Top-15 active tester interviews each month.",
    ])
    h2(p, "Pricing Strategy")
    bullets(p, [
        "Starter - free.",
        "Care Pro - monthly subscription at an accessible caregiver price (~$9.99/mo indicative).",
        "Care Team - annual institutional pricing with onboarding and support.",
    ])
    body(p, "Exact numbers will be refined from real user behavior rather than assumptions. "
          "The structure stays simple and easy to explain.")


def page_roadmap(p):
    p.add_page(); h1(p, "12-Month Monetization Roadmap")
    h2(p, "Months 1-3")
    bullets(p, [
        "Launch TestFlight to family carers and support workers.",
        "Track activation, retention, top pain points.",
        "Add plan interest tracking and pilot inquiry forms.",
        "Customer interviews every two weeks.",
    ])
    h2(p, "Months 4-6")
    bullets(p, [
        "Launch public waitlist for Care Pro.",
        "Offer early-access annual pricing to the first organizations.",
        "Produce case study + 30s demo proof assets.",
        "Finalize premium features based on what active testers actually use.",
    ])
    h2(p, "Months 7-9")
    bullets(p, [
        "Turn on subscriptions for Care Pro.",
        "Start 2-3 institutional pilots.",
        "Measure conversion from active beta users to paid users.",
    ])
    h2(p, "Months 10-12")
    bullets(p, [
        "Expand Care Team into a structured B2B offering.",
        "Add onboarding kits, reporting dashboards, renewal plans.",
        "Use customer proof in grants, partnerships, and investor conversations.",
    ])


def page_metrics(p):
    p.add_page(); h1(p, "Success Metrics & Marketing")
    h2(p, "Five Metrics That Matter")
    bullets(p, [
        "Activation rate - carers who create the first routine.",
        "Retention rate - carers still using the app after 4 and 8 weeks.",
        "Value signal rate - testers who tap into paid plan interest.",
        "Pilot conversion rate - organizations that move from demo to pilot.",
        "Paid conversion rate - active users who subscribe after launch.",
    ])
    h2(p, "Marketing Posture")
    body(p, "Every monetization asset answers three questions: What problem does this solve? "
          "Who is it for? What happens after using it consistently?")
    bullets(p, [
        "One-page pricing page with plain-language differences.",
        "Short case study from a family carer.",
        "Short case study from a professional or facility pilot.",
        "30-second demo video (already produced - see marketing/out/).",
    ])
    p.ln(6)
    p.set_draw_color(*EMERALD); p.set_line_width(0.4)
    p.line(10, p.get_y(), 200, p.get_y()); p.ln(4)
    p.set_font("Helvetica", "I", 9); p.set_text_color(*MUTED)
    p.multi_cell(0, 4.8,
        "(c) World Class Scholars - Dr Christopher Appiah-Thompson. "
        "This document accompanies WCS Care v1.0.3 (TestFlight).")


def main():
    pdf = Theme(orientation="P", unit="mm", format="A4")
    pdf.set_auto_page_break(auto=True, margin=18)
    pdf.set_margins(10, 16, 10)
    cover(pdf)
    page_principles(pdf)
    page_model(pdf)
    page_gates(pdf)
    page_tactics(pdf)
    page_roadmap(pdf)
    page_metrics(pdf)
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    out_dir.mkdir(parents=True, exist_ok=True)
    out = out_dir / "WCS_Care_Monetization_Plan.pdf"
    pdf.output(str(out))
    print(f"Saved: {out}  ({out.stat().st_size // 1024} KB, {pdf.page_no()} pages)")


if __name__ == "__main__":
    main()
